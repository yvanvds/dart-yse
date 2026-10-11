Upgrading to package:yse 0.2.0 (libYSE 3.1)
=============================================

``package:yse`` 0.2.0 moves the binding from libYSE 2.4 to **libYSE
v3.1.0** (3.0.1 plus the device-enumeration and auto-reconnect API of
3.1). The 3.0 C ABI is not compatible with 2.4, the engine changed
several behaviours without changing a signature, and the wrapper took the
chance to fix a few unsafe spots. This page lists every change that can
break or alter a program written against ``package:yse`` 0.1.0, with the
old and the new Dart code.

It is the Dart-facing counterpart of upstream's
:yse-cpp:`Upgrading from 2.4 to 3.0 <upgrading.html>`, which has the full
engine-side reasoning. New features that change nothing existing are in
the `CHANGELOG
<https://github.com/yvanvds/dart-yse/blob/main/CHANGELOG.md>`_, not here.
Issue numbers below are dart-yse issues unless they say *upstream*.

Quick checklist
---------------

- **Everyone:** ``System.init()`` now **throws** when no audio device
  opens; the default session rate is **48 kHz**; ``setAutoReconnect``'s
  delay is wall-clock **milliseconds**. See `Sessions and devices`_.
- **Buffers:** ``DspBuffer.drawable`` / ``.file`` / ``.wavetable`` are
  gone; construct ``DrawableBuffer`` / ``FileBuffer`` / ``Wavetable``.
- **Patcher hosts:** ``PHandle.id`` and the connection getters return
  ``int?``; IDs start at 0; ``parseJson`` *adds* (call ``clear()`` first)
  and throws on bad input; anything that talks to a patcher slot over the
  bus needs the ``patcher.`` prefix.
- **Patches:** re-check ``.route``, ``.metro``, ``.counter``, ``~saw``,
  several ``~dac`` objects, ``.m`` message boxes and ``~+`` / ``~-`` /
  ``~bp`` defaults. See `Patcher objects`_.
- **Music:** ``Player()`` is now ``Player(synth)``.
- **Bus:** ``LiveCoding.bus`` is deprecated; use ``Bus.tap``.

Sessions and devices
--------------------

:doc:`sessions_and_devices` covers all of this in full.

``init()`` throws when no device opens (#56)
   In 0.1.0 (libYSE 2.4) ``System.init()`` returned normally even when the
   machine had no output device, or the device refused to open. It now
   throws :class:`YseException` (``YSE_ERR_AUDIO_DEVICE``) and leaves the
   engine closed. A host that must run without audio hardware (CI, a
   server) falls back to ``initOffline()``:

   .. code-block:: dart

      // 0.1.0
      sys.init();   // "succeeded" with nothing open

      // 0.2.0
      try {
        sys.init();
      } on YseException {
        sys.initOffline();   // render with renderOffline(), or openDevice later
      }

``openDevice()`` throws when nothing opened (#56)
   :py:meth:`System.openDevice` throws ``YseException`` when the engine
   opened no stream: no output device in the setup, a device that no
   longer resolves, a stream error (including a device that refuses the
   session rate), or an offline session with no audio backend running.
   The running stream and speaker layout are left as they were. In 0.1.0
   these failures were only logged.

48 kHz default and ``requestedSampleRate`` (#56)
   The engine's initial rate is 48000 Hz instead of 44100. A device session
   still runs at whatever the device negotiates; read it from
   :py:attr:`System.sessionSampleRate`. To ask for a rate, set
   :py:attr:`System.requestedSampleRate` **before** ``init()`` /
   ``initOffline()``. An offline session runs exactly at the requested
   rate, so offline renders that assumed 44.1 kHz change length:

   .. code-block:: dart

      sys.requestedSampleRate = 44100;   // survives close(); 0 clears it
      sys.initOffline();

   ``DeviceSetup.sampleRate`` can no longer change a running session's
   rate: close and init again with a new ``requestedSampleRate``.
   ``DspObject.granulator``'s default ``poolSize`` followed the new default
   (``48000 * 5``, was ``44100 * 5``).

``setAutoReconnect`` delay is in milliseconds; it reopens *your* device (#54, #56)
   ``delayMs`` used to be compared against a count of ``update()`` calls.
   It is now wall-clock milliseconds, with a 500 ms start-up grace for a
   stream that has not delivered its first callback. At 60 updates per
   second, ``delayMs: 20`` used to mean about 333 ms and now means 20 ms.

   The watchdog also changed device: libYSE 3.0 reopened the *default*
   device, so a session on an external interface moved silently onto the
   built-in output. In 0.2.0 it reopens the device of the last successful
   ``openDevice()`` (found again by name and host). Two new optional
   parameters and an outcome API come with it:

   .. code-block:: dart

      // 0.1.0
      sys.setAutoReconnect(on: true, delayMs: 60);   // 60 update ticks

      // 0.2.0
      sys.setAutoReconnect(
        on: true,
        delayMs: 1000,              // wall-clock ms
        fallbackToDefault: false,   // true: open the default device instead
        maxAttempts: 30,            // 0 = retry forever
      );
      // later, in the update loop:
      if (sys.reconnectState == ReconnectState.failed) { /* tell the user */ }
      print('${sys.activeDevice} on ${sys.activeHost}');

   ``System.resume()`` likewise reopens the same device and never falls
   back to another one.

``devices`` is empty on an offline session (#51, #56)
   An ``initOffline()`` session enumerates no devices.
   :py:meth:`System.refreshDevices` fills the list without opening a
   stream (before ``init``, offline, or on a running session), and is also
   what lets ``openDevice()`` work on an offline session.

Small contract changes
   - ``System.resume()`` is a no-op on an offline session.
   - ``System.missedCallbacks`` counts ``update()`` ticks in a row with no
     audio callback; 0 means audio is flowing. A freshly started stream
     reads non-zero until its first callback.
   - ``Device.defaultBufferSize`` is 0 when the host does not advertise one
     (every desktop device); 0 means *unspecified*.
   - ``Device.id`` is -1 for a descriptor with no device behind it.
   - The MIDI device-name getters return ``''`` (not ``"Invalid Call"``)
     for an index with no port, or when the MIDI backend is down.
   - ``System.underwaterDepth`` is world units below the surface (effect
     fades in above 1 and saturates at 5), not a 0..1 strength.
   - ``Channel.virtual = false`` now actually turns virtualisation off
     (upstream #864). Remove the call if you relied on the old broken
     behaviour to cap the voice count.
   - Doppler is computed from a wall clock (upstream #667), so it no
     longer scales with CPU load and can sound different under load.

Random numbers (#57)
   The engine's generator (``.random``, granulator jitter, LFO random
   shapes) is thread-safe and **reproducible by default**: without a seed
   the same patch renders the same output every run. Seed it through the
   engine, never through ``dart:math``:

   .. code-block:: dart

      System.randomize();        // time-based seed
      System.randomSeed(1234);   // repeatable stream

   Float draws are in ``[0, 1)`` instead of ``[0, 1]``.

Buffers and DSP
---------------

``DspBuffer`` subclasses are real Dart classes (#55)
   The 3.0 C API ``static_cast``\ s a buffer to the subclass an operation
   needs, so calling ``drawLine`` on a plain buffer was undefined
   behaviour. The named factories are replaced by subclass constructors,
   and the type system rules the mistake out:

   .. code-block:: dart

      // 0.1.0
      final d = DspBuffer.drawable(length: 48000);
      final f = DspBuffer.file(length: 48000 * 5);
      final w = DspBuffer.wavetable(length: 2048);

      // 0.2.0
      final d = DrawableBuffer(length: 48000);
      final f = FileBuffer(length: 48000 * 5);
      final w = Wavetable(length: 2048);
      final p = DspBuffer.plain(length: 1024);   // unchanged

   ``FileBuffer`` extends ``DrawableBuffer`` and ``Wavetable`` extends
   ``FileBuffer``, mirroring the C++ chain.

Kind-specific ``DspObject`` accessors check the kind (#72)
   ``q``, the ``sweep*`` accessors, ``setDelayTap`` / ``delayTime`` /
   ``delayGain``, ``phaserRange``, ``differenceAmplitude`` and every
   granulator accessor now throw ``YseException`` on the wrong module kind
   (e.g. ``DspObject.lowpass().q = 2``), where 0.1.0 wrote through a
   mistyped pointer. Code that called them on the right kind is unaffected.

``bandPass`` has unity gain at its centre frequency (upstream #1022)
   A ``DspObject.bandpass`` (and the patcher's ``~bp``) boosted the band at
   low Q: about +5 dB at Q 1 and a flat 2x when Q was low enough. It now
   has unity gain at the centre frequency for every Q, so a band-pass
   sounds quieter than before; remove any gain you added to compensate.

Lifetime: borrowed objects stay alive (#65, #80, #84)
   ``Sound.fromBuffer`` / ``fromMultiBuffer`` / ``fromPatcher`` /
   ``fromSynth``, ``Sound.dsp``, ``Channel.dsp``, ``DspObject.link``
   chains, ``DspObject.patcherInsert``, the ``connectSynth`` /
   ``connectMidiOut`` sinks and ``Motif.setFirstPitch`` now hold a Dart
   reference to what the engine borrows, released only after the owner's
   native destroy. Dropping your own reference no longer frees a source
   under a live sound, so workarounds that kept globals alive "just in
   case" can go. Disposing a source *explicitly* before its consumer is
   still unsupported.

Patcher
-------

Object IDs: ``int?``, 0-based, per patcher (#55)
   ``PHandle.id``, ``PHandle.connectionTargetId`` and
   ``PHandle.connectionTargetInlet`` return ``int?``: ``null`` for the
   engine's "nothing here" sentinels, where 0.1.0 returned ``0`` (which is
   now a real ID). Each patcher numbers its objects from 0 and reuses the
   smallest free number after a delete; patch files are numbered the same
   way, so two identical patches save identically.

   .. code-block:: dart

      // 0.1.0
      final target = h.connectionTargetId(0, 0);
      if (target != 0) { ... }

      // 0.2.0
      final target = h.connectionTargetId(0, 0);
      if (target != null) { ... }

   If you store object IDs outside the patch, look them up again after
   loading.

``parseJson`` adds, throws and rolls back (#55)
   ``parseJson`` has always added the file's objects to the patcher; the
   0.1.0 docs said it replaced them. It now also throws ``YseException`` on
   malformed input, and a load that fails part-way removes what it had
   created. ``Patcher()`` throws ``YseException`` when the engine rejects
   its configuration.

   .. code-block:: dart

      p.clear();          // to replace rather than merge
      p.parseJson(json);  // throws YseException on bad JSON

Bus addresses carry the ``patcher.`` prefix (#50, #55)
   A ``.s`` / ``.r`` slot is published on the global bus as
   ``patcher.<name>.<slot>``, where 2.4 used ``<name>.<slot>``. Patchers
   now have a :py:attr:`Patcher.name` (``Patcher(name: 'lead')``); an
   unnamed one keeps its ``patcher_<N>`` auto-name. The name is saved by
   ``dumpJson`` and applied by ``parseJson`` unless one was already set.

   .. code-block:: dart

      // 0.1.0: a `.s level` published to '<patcherName>.level', and a host
      // could only tap it (LiveCoding.bus); patchers could not be named.

      // 0.2.0
      final p = Patcher(name: 'lead');
      Bus.subscribe('patcher.lead.level').listen(...);
      Bus.publish('patcher.lead.freq', const BusFloat(440));

``pass*`` return value with a ``messages`` listener (#62)
   While :py:attr:`Patcher.messages` has a listener, ``passBang`` /
   ``passInt`` / ``passFloat`` / ``passString`` return ``true`` even for a
   name no ``.r`` receives: the message goes to the stream instead.

``Obj`` and ``PCategory`` (#55, #64)
   ``Obj`` now has a constant for all 305 registry objects (was 42), and
   every existing name is kept, except ``Obj.dOut`` (``~out``), which is
   removed: no engine object ever implemented it. ``PCategory`` gained the
   11 new registry categories, so an exhaustive ``switch`` over it needs
   the new cases. ``PatcherObjectType.description`` is now a
   tooltip-length summary; the long notes are in the
   :doc:`object reference </api/patcher_objects/index>`.

Patcher objects
~~~~~~~~~~~~~~~

These patches behave differently without any code change (upstream
numbers in parentheses; the
:yse-cpp:`upstream guide <upgrading.html#patcher-objects>` has the detail).

- ``.route`` (#672, #679) strips the matched selector and matches floats by
  value: ``foo 1 2`` into ``.route foo`` sends ``1 2``, ``foo`` alone sends
  a bang. ``.routepass`` behaves like the old ``.route``.
- ``.metro`` (#625, #711) applies a period change while running, keeping
  its phase; its left inlet takes ``bang`` / ``stop`` / a float.
- ``.counter`` (#956) seeds the count from its start value and inlet 1
  sets the step.
- ``~saw`` (#955) is bipolar, -1 to 1 (was a 0 to 1 ramp).
- Several ``~dac`` objects (#932) are summed instead of only the last one
  being heard. Lower the gain if a patch got louder.
- ``.m`` (#933) sends the message it spells: ``.m 60`` sends the int 60,
  ``.m bang`` a bang.
- ``.midiout`` (#748) takes numeric byte lists.
- ``~+`` / ``~-`` default their right operand to 0, and ``~bp`` defaults to
  Q 1.
- ``.programchange`` / ``.channelpressure`` no longer send an extra byte;
  ``~line stop`` holds its value.
- Creation arguments are split on runs of whitespace, and a live
  ``PHandle.setParams`` resets the parameters it leaves out (#935, #936).
- A ``.s`` value reaches a ``.r`` in the same patcher once, not twice
  (#943).

Music, synth and MIDI
---------------------

``Player(synth)`` (#85)
   ``Player()`` passed no synth to the engine, so it always threw and the
   class was unusable. The constructor now takes the :class:`Synth` the
   player plays on; attach that synth to a playing sound to hear it:

   .. code-block:: dart

      final synth = Synth()..addSineVoices(8);
      final sound = Sound.fromSynth(synth)..play();
      final player = Player(synth)..play();

   Dispose the player before the synth, and let one audio block run in
   between (see `Known upstream issues`_).

Late voice groups throw (#81)
   ``Synth.addSineVoices`` / ``addVaVoices`` / ``addFmVoices`` /
   ``addSamplerVoices`` and ``setPositionHandler`` throw ``StateError``
   once :py:attr:`Synth.voiceCount` is non-zero. The engine would have
   dropped the call with only a log line. Add every voice group right
   after ``Synth()``.

``MidiOut`` channels are clamped (upstream #1014)
   An out-of-range channel is clamped to ``0..15`` instead of corrupting the
   status byte. ``raw3`` still sends exactly three bytes; use the new
   ``MidiOut.raw`` for two-byte messages and SysEx.

Two MIDI channel bases
   Nothing changed here, but it is now documented on every class:
   ``MidiOut`` and parsed ``MidiIn`` messages use wire-level ``0..15``;
   ``Synth``, ``ClipEvent``, ``Note`` / ``PNote`` and the
   ``MidiIn.connectSynth`` filter use ``1..16`` with ``0`` = omni. See the
   table on :doc:`/api/midi`.

Clocks and clips (upstream #707, #944, #974, #975)
   A ``DomainClock`` and its ``ClipTransport``\ s can be disposed in any
   order, disposing a clip releases its sounding notes, a clip survives
   ``System.close()``, and clocks advance once per rendered block rather
   than per device callback, so beat events land later and more precisely
   on large device buffers. ``DomainClock()`` and ``ClipTransport.bind``
   report failures as ``YseException`` with the engine's error detail. See
   :doc:`/tutorials/06_clocks_and_clips`.

Bus and live coding
-------------------

``LiveCoding.bus`` → ``Bus.tap`` (#59)
   The bus has its own class. ``LiveCoding.bus`` still works but is
   deprecated and forwards to :py:meth:`Bus.tap`. ``BusValue`` and
   ``BusFrame`` moved with it; ``package:yse/yse.dart`` still exports them,
   so imports do not change.

   .. code-block:: dart

      // 0.1.0
      LiveCoding.bus('synth.').listen(print);

      // 0.2.0
      Bus.tap('synth.').listen(print);
      Bus.subscribe('synth.lead.note').listen(print);   // exact address
      Bus.publish('synth.lead.note', const BusList([1, 60, 0.8]));

``System.close()`` closes bus streams (#59)
   ``close()`` releases every subscription and tap and closes their
   streams (0.1.0 left a dead tap cached, so re-tapping the prefix after a
   re-init never fired). Subscribe again after the next ``init()``.

``Channel.name`` is not the bus name (#60)
   ``Channel.name`` is the *log* name given to ``Channel.create``. To put a
   channel on the bus, set ``Channel.busName``; ``Sound.busName`` and
   ``Synth.busName`` work the same way. ``close()`` forgets them.

Known upstream issues
---------------------

These engine issues were found while wrapping libYSE v3.1.0. They are open
upstream; the wrapper documents them, and works around them where it can
detect them.

- `#1033 <https://github.com/yvanvds/yse-soundengine/issues/1033>`_ —
  **The sample rate carries over between sessions.** An offline session
  with no ``requestedSampleRate`` runs at the previous session's rate,
  not 48 kHz. Set ``requestedSampleRate`` whenever an offline render must
  run at a known rate. Also, ``setChannelConfiguration`` takes effect only
  on a block that mixes a sound, so ``Channel.master.numOutputs`` keeps
  its old value until a sound is alive.
- `#1175 <https://github.com/yvanvds/yse-soundengine/issues/1175>`_ —
  **Destroying a never-attached synth that has VA or FM voices crashes
  the next synth attach.** Attach every voiced synth to a sound before
  disposing it (sine-only and voice-less synths are not affected).
- `#1176 <https://github.com/yvanvds/yse-soundengine/issues/1176>`_ —
  **Clearing a MIDI-in callback can race a dispatch in progress.** The
  engine's clear does not wait for a callback that is about to run, so
  when ``MidiIn.rawMessages`` loses its last listener (or the port is
  disposed) while MIDI is arriving, one in-flight message can still race
  the wrapper's teardown. Every message queued before the clear is drained
  and freed exactly once.
- `#1177 <https://github.com/yvanvds/yse-soundengine/issues/1177>`_ —
  **A synth can be built before its voices are added.** The setup job may
  claim a new synth before ``add*Voices`` runs; that synth keeps 0 voices
  with no error. Add voice groups right after ``Synth()``. The wrapper
  throws ``StateError`` for a group that arrives after the pool is built
  (when it can tell), but cannot detect a pool built empty: if
  ``voiceCount`` stays 0 after the sound plays, build a new synth.
- `#1181 <https://github.com/yvanvds/yse-soundengine/issues/1181>`_ —
  **A disposed player touches its synth on the next audio block.** The
  engine retires a destroyed ``Player`` on its next block and still sends
  note-offs to the synth then. ``Player`` keeps its synth alive until the
  wrapper is collected; if you dispose the synth yourself, let one block
  run (an ``update()`` plus a device callback or ``renderOffline(1)``)
  after ``player.dispose()``.

Where to go next
----------------

- :doc:`sessions_and_devices` — sample rates, devices, offline sessions
  and reconnecting, in full.
- :doc:`/api/bus` — publish, subscribe, tap and the address namespaces.
- :doc:`/tutorials/05_patcher` and :doc:`/api/patcher_objects/index` — the
  patcher, which grew from 42 to 305 objects.
