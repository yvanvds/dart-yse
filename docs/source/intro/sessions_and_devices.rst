Sessions and devices
====================

A **session** is everything between ``System.instance.init()`` (or
``initOffline()``) and ``System.instance.close()``. This page covers how a
session starts, which sample rate it runs at, how to pick and switch audio
devices, how to tell whether audio is flowing, and how the engine
reconnects a device that went away. Upstream's
:yse-cpp:`Sessions and devices <intro/sessions_and_devices.html>` is the
C++ version of this page.

Every call on this page belongs on the isolate that called ``init()``; see
:doc:`mental_model`.

Starting a session
------------------

.. list-table::
   :header-rows: 1
   :widths: 26 74

   * - Call
     - What you get
   * - :py:meth:`System.init`
     - Starts the audio backend and opens the platform's default output
       device. The audio thread renders the mix. **Throws**
       :class:`YseException` (``YSE_ERR_AUDIO_DEVICE``) when no device
       opens, and leaves the engine closed.
   * - :py:meth:`System.initOffline`
     - The same engine, channel tree and DSP graph, but no audio backend and
       no audio thread. You render blocks yourself with
       :py:meth:`System.renderOffline`. Use it for tests, benchmarks and
       headless tools.

``init()`` succeeds only when a stream on the default output device is
running. It throws when the backend fails to start, when there is no
default output device, or when the device refuses to open or start the
stream (another application holds it exclusively, say). The reason is in
the engine log (:class:`Log`). A failed ``init()`` leaves no session
behind, so the usual pattern for a host that must also run without audio
hardware is:

.. code-block:: dart

   final sys = System.instance;
   try {
     sys.init();
   } on YseException catch (e) {
     print('No audio device ($e); running offline');
     sys.initOffline();
   }

Up to libYSE 2.4 (``package:yse`` 0.1.0) ``init()`` returned normally with
nothing open. A stream that has just started can still take a moment to
deliver audio; see `Is audio flowing?`_.

:py:meth:`System.close` ends the session: it closes the device, stops the
engine threads and frees the engine side of every sound and channel. It
also removes the :py:attr:`System.occlusion` callback, closes every
:class:`Bus` subscription and tap stream, closes every
:py:attr:`Patcher.messages` stream and forgets every
:py:attr:`Channel.busName`. You can ``init()`` again afterwards. The
requested sample rate and the :py:attr:`System.renderThreads` setting carry
over to the next session.

Sample rate
-----------

The sample rate is fixed for a whole session. Choose it with
:py:attr:`System.requestedSampleRate` **before** ``init()`` /
``initOffline()``:

.. code-block:: dart

   sys.requestedSampleRate = 44100;
   sys.init();
   print(sys.sessionSampleRate);   // what the device agreed to

- **With a device**, the engine asks the device for the requested rate. A
  device that refuses it is a log line and the device's own rate instead,
  never an error. :py:attr:`System.sessionSampleRate` reports what the
  session really runs at.
- **Without a request** (or after ``requestedSampleRate = 0``), ``init()``
  opens the device at its default rate.
- **Offline**, there is no device to ask, so the session runs at exactly
  the requested rate. With no request it keeps the engine's current rate:
  **48 kHz** in a fresh process (libYSE 2.4 used 44.1 kHz), but the
  previous session's rate in a process that already ran one
  (upstream `#1033 <https://github.com/yvanvds/yse-soundengine/issues/1033>`_).
  Request a rate whenever an offline render must run at a known one.

A request made during a session is only stored for the next one; to change
a running engine's rate, ``close()`` and init again. The request survives
``close()``. :py:attr:`DeviceSetup.sampleRate` cannot change a running
session's rate either.

Two getters report the rate:

- :py:attr:`System.sessionSampleRate` is the session rate. It stays the
  same through ``pause()`` / ``resume()`` and is 0 before ``init()``. Use
  it for anything you count in samples.
- :py:attr:`System.activeSampleRate` is the rate of the device that is
  open right now: 0 before ``init()``, after ``pause()`` or ``close()``,
  and in an offline session.

Offline sessions
----------------

:py:meth:`System.renderOffline` runs the work the audio thread would do
for ``blocks * System.blockSize`` frames (128 per block), on the calling
thread; the rendered audio is discarded (measure it with the channel peak
meters). Call ``update()`` between renders as in a device session, or new
sounds never start:

.. code-block:: dart

   sys.requestedSampleRate = 48000;
   sys.initOffline();
   sys.setChannelConfiguration(ChannelType.surround51, 6);   // optional

   // ... create sounds, channels, patchers ...

   for (var i = 0; i < 100; i++) {
     sys.update();
     sys.renderOffline(1);
   }
   sys.close();

**Speaker layout.** An offline session starts stereo. Change it with
:py:meth:`System.setChannelConfiguration`, called *after*
``initOffline()`` (init installs stereo itself and overwrites an earlier
call). ``outputs`` must be at least 1 (``ArgumentError`` otherwise), and
``ChannelType.custom`` creates ``outputs`` speakers whose positions you set
yourself. The new layout is applied by the next block **that mixes a
sound**: with no sound alive the engine skips the mix and the resize with
it, so ``Channel.master.numOutputs`` reports the old count until a sound
exists (upstream #1033). In a device session use ``openDevice()``
instead, which derives the layout from the device.

**An offline session stays offline.** ``resume()`` restarts the device a
session already had; an offline session has none, so ``resume()`` is a
no-op there and the auto-reconnect watchdog never opens one either. The
one way to give an offline session a device is ``openDevice()``. On
desktop that needs the audio backend (PortAudio), which ``initOffline()``
does not start, so call :py:meth:`System.refreshDevices` first:

.. code-block:: dart

   sys.initOffline();
   if (sys.refreshDevices()) {
     // pick a Device from sys.devices, then sys.openDevice(setup)
   }

When ``openDevice()`` succeeds the session becomes a device session: an
audio thread now renders the mix, so **stop calling** ``renderOffline()``.
The stream opens at the offline session's rate; a device that refuses it
makes ``openDevice()`` throw. Request the device's rate before
``initOffline()`` to be safe.

Choosing an audio device
------------------------

``init()`` opens the default output device. To use another one, list the
devices and open one with :py:meth:`System.openDevice`:

.. code-block:: dart

   final chosen = sys.devices
       .where((d) => d.outputChannelNames.length >= 6)
       .firstOrNull;
   if (chosen != null) {
     final setup = DeviceSetup()
       ..output = chosen
       ..bufferSize = 0;   // 0: let the backend choose
     try {
       sys.openDevice(setup, layout: ChannelType.auto);
     } on YseException {
       // Refused and logged; the previous device is still playing.
     }
   }

**Listing devices without opening one.** ``init()`` fills
:py:attr:`System.devices` as a side effect of opening the default device,
which may be the wrong device, held by another application, or at the
wrong rate. :py:meth:`System.refreshDevices` fills the list without
opening anything, so you can find a stored device first and open exactly
that one. It works before ``init()``, in an offline session and in a
running device session:

.. code-block:: dart

   if (!sys.refreshDevices()) {
     // The audio backend could not start; the list is empty and the
     // reason is in the engine log.
   }
   final stored = sys.devices.where(
     (d) => d.name == storedName && d.hostName == storedHost,
   );

- It returns ``false`` (with an empty list) when the backend cannot start,
  and throws only on an unexpected engine error.
- It never touches an open stream. With no stream open the backend
  restarts, so devices plugged in or removed since show up. With a stream
  open, PortAudio cannot re-scan, so a new device appears only after you
  ``closeCurrentDevice()`` (or ``close()``) and refresh again.
- The refresh **replaces** the list: :class:`Device` descriptors and
  :class:`DeviceSetup`\ s built from the old list are invalid afterwards,
  and an index may now name another device. Match by
  :py:attr:`Device.name` and :py:attr:`Device.hostName`, never by index.
  ``defaultDevice`` / ``defaultHost`` are re-read too.
- An offline session lists nothing until you refresh, and a machine with
  no audio hardware may list nothing at all.
- On a bare headless Linux machine starting PortAudio can hang, so
  headless tools that never need a device should not call it.

**Special values.** :py:attr:`Device.id` is -1 for a descriptor with no
device behind it, and ``openDevice()`` refuses it; every device in
``devices`` has a real index. :py:attr:`Device.defaultBufferSize` is 0 when
the host does not advertise one (every desktop device): 0 means
*unspecified*, and passed as ``DeviceSetup.bufferSize`` lets the backend
choose. After opening, :py:attr:`System.activeBufferSize` reports the size
it chose.

**Opening the device.** ``openDevice(setup, layout:)`` returns when a
stream is running on the new device. It throws :class:`YseException`
(``YSE_ERR_AUDIO_DEVICE``), and leaves the running stream and the speaker
layout alone, when:

- the setup has no output device;
- the device's ID is -1 or no longer resolves;
- the backend could not open or start the stream (including a device that
  refuses the session rate);
- the backend was never started (see `Offline sessions`_).

On success the speaker layout follows the device: ``layout`` is applied
with that device's output-channel count, and ``ChannelType.auto`` derives
the layout from the count. A different number of outputs makes the next
block reallocate the mix buffers, so switch devices at setup, not while
something audible plays.

On Android there is a single device ("Android Audio", stereo, through
Oboe); ``openDevice()`` only applies the speaker layout there.

**Live device state.** :py:attr:`System.activeSampleRate`,
:py:attr:`System.activeBufferSize` (frames per device callback, which is
not the engine's 128-frame block) and :py:attr:`System.activeOutputLatency`
(samples) describe the open device and are 0 while none is open.
:py:attr:`System.activeDevice` / :py:attr:`System.activeHost` name it
(``''`` when none is). :py:attr:`System.cpuLoad` is the audio callback's
run time as a fraction of its buffer; near 1.0, dropouts are likely.

Is audio flowing?
-----------------

:py:attr:`System.missedCallbacks` counts the ``update()`` calls in a row
during which the device delivered no audio. It goes back to 0 at the first
``update()`` that sees a callback, so **0 means audio is flowing**.

A stream that has just started (by ``init()``, ``resume()`` or
``openDevice()``) reads non-zero until its first callback lands, typically
tens of milliseconds. To wait for a device to come up, poll until it is 0:

.. code-block:: dart

   sys.init();
   for (var i = 0; i < 100 && sys.missedCallbacks != 0; i++) {
     sys.update();
     sys.sleep(10);
   }

A value that keeps climbing means the device has gone away or the audio
thread is starved. An offline session only ever climbs.

Reconnecting automatically
--------------------------

:py:meth:`System.setAutoReconnect` makes ``update()`` restart the output
stream when the device has delivered nothing for ``delayMs``
**milliseconds**:

.. code-block:: dart

   sys.setAutoReconnect(
     on: true,
     delayMs: 1000,
     fallbackToDefault: false,
     maxAttempts: 30,
   );

- **Which device.** The one the session had: after ``openDevice()``, that
  device, found again by name and host, with the channel count and buffer
  size it was opened with. A session that never called ``openDevice()``
  reopens whatever the default device is at that moment, which covers
  unplugged headphones. Up to libYSE 3.0 every attempt opened the default
  device.
- **Fallback.** When the session's device cannot be reopened, nothing is
  opened and the watchdog tries again ``delayMs`` later. With
  ``fallbackToDefault: true`` the default output device is opened instead
  (narrowing the layout if it has fewer outputs); the session does not
  move back by itself when its own device returns.
- **Attempt limit.** A positive ``maxAttempts`` stops after that many
  failed attempts in a row; 0 (the default) retries forever.
- **Timing.** A stream that has just started gets at least half a second
  before the watchdog acts, whatever the delay. Negative delays count as
  0. Up to libYSE 2.4 ``delayMs`` counted ``update()`` calls: at 60 updates
  per second, a value of 120 meant 2000 ms.
- **The watchdog runs inside** ``update()``. Stop calling ``update()`` and
  nothing reconnects. :py:attr:`System.missedCallbacks` itself is not
  acted on; the watchdog keeps its own wall-clock timing.

The watchdog has no callback; poll its outcome:

- :py:attr:`System.reconnectState` — a :class:`ReconnectState`:
  ``none`` (nothing happened yet), ``reconnecting``, ``restored``,
  ``fellBackToDefault`` or ``failed`` (gave up after ``maxAttempts``). It
  keeps the last attempt's outcome and resets to ``none`` on init, on a
  successful ``openDevice()`` and on every ``setAutoReconnect`` call, which
  also re-arms a watchdog that gave up.
- :py:attr:`System.reconnectCount` — attempts made this session, so you can
  notice a reconnect you did not see happen.
- :py:attr:`System.activeDevice` / :py:attr:`System.activeHost` — the
  device actually playing, e.g. after ``fellBackToDefault``.

On desktop a device unplugged and plugged back in may only be found again
after :py:meth:`System.refreshDevices`, which you can call while the state
reads ``reconnecting`` (no stream is open then):

.. code-block:: dart

   // in the host's update loop
   if (sys.reconnectState == ReconnectState.reconnecting) {
     sys.refreshDevices();
   }

``pause()`` closes the stream and ``resume()`` opens the same device again;
``resume()`` never falls back to another device.

MIDI devices
------------

MIDI device I/O exists in builds with ``YSE_ENABLE_MIDI_DEVICE``, which is
on by default on Windows and Linux and off on Android (and macOS). Without
it the counts below are 0.

- :py:attr:`System.midiInDeviceCount` / :py:attr:`System.midiOutDeviceCount`
  count the ports; 0 when the MIDI backend could not start.
- :py:meth:`System.midiInDeviceName` / :py:meth:`System.midiOutDeviceName`
  return ``''`` for an index with no port, and for every index when the
  backend is down. A non-empty name always means a real port.
- Open a port by index with :py:meth:`MidiOut.open` or
  :py:meth:`MidiIn.open`.
  ``MidiIn`` callbacks arrive on RtMidi's input thread and are bridged to
  your isolate as streams.

Where to go next
----------------

- :doc:`mental_model` — the threads and what ``update()`` drives.
- :doc:`/api/core` and :doc:`/api/devices` — the reference for
  :class:`System`, :class:`Device` and :class:`DeviceSetup`.
- :doc:`upgrading` — everything that changed since libYSE 2.4.
