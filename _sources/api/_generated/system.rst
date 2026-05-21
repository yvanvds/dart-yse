System
======

.. code-block:: dart

   class System

Engine lifecycle, audio device control, global settings.

Wraps the `YSE::system` singleton accessed via `YSE::System()`. Construct
nothing directly — access the singleton through [System.instance].

Typical lifecycle:
```
final sys = System.instance;
sys.init();
// ... use the engine ...
sys.close();
```

All calls must be made from the same isolate that called [init]. The
audio callback runs on a private thread the wrapper never exposes.

Static accessors
----------------

.. code-block:: dart

   static System get instance

Borrowed singleton accessor — every call returns the same instance.

.. code-block:: dart

   static String get version

libYSE version string (e.g. "2.0.1").

Properties
----------

.. code-block:: dart

   int get missedCallbacks

Number of audio callbacks that have failed to complete on time.

A non-zero value indicates the audio thread is starved or the device
has disconnected.

.. code-block:: dart

   double get cpuLoad

CPU load of the audio thread as a fraction of the callback budget.

.. code-block:: dart

   int get maxSounds

.. code-block:: dart

   set maxSounds(int value)

Maximum number of concurrently audible sounds.

Beyond this limit the engine virtualises the least significant
sounds (typically furthest from the listener).

.. code-block:: dart

   set audioTest(bool on)

Enable or disable the built-in audio test signal.

.. code-block:: dart

   List<Device> get devices

All audio devices visible to the engine.

Available after [init] / [initOffline]. Each [Device] descriptor is
borrowed from the engine; do not retain references past [close].

.. code-block:: dart

   String get defaultDevice

Name of the platform-default audio device.

.. code-block:: dart

   String get defaultHost

Name of the platform-default audio host (WASAPI, ALSA, ...).

.. code-block:: dart

   double get sessionSampleRate

Engine session sample rate in Hz. Stays constant from [init] until
[close], including across [pause] / [resume] cycles where
[activeSampleRate] transiently drops to 0. Returns 0 before [init].

Use this for sample-count-driven scheduling that must outlive a
pause; use [activeSampleRate] for live device-state UI.

.. code-block:: dart

   double get activeSampleRate

Sample rate of the currently open audio device, or 0 when no device
is open (pre-init, after close, or [initOffline] path).

.. code-block:: dart

   int get activeBufferSize

The currently open device's frames-per-callback (NOT the engine block
size). Returns 0 when no device is open.

.. code-block:: dart

   int get activeOutputLatency

Output latency of the currently open device, in samples. Returns 0
when no device is open. Convert to milliseconds with
`(activeOutputLatency / activeSampleRate) * 1000`.

.. code-block:: dart

   int get midiInDeviceCount

Number of MIDI input devices visible to the engine.

Windows / Linux only — other platforms always return 0.

.. code-block:: dart

   int get midiOutDeviceCount

Number of MIDI output devices visible to the engine.

Windows / Linux only — other platforms always return 0.

.. code-block:: dart

   Reverb get globalReverb

The fallback reverb used wherever no positioned [Reverb] zone reaches.

Disabled by default — set `globalReverb.active = true` to enable.
Borrowed from the engine; do not [Reverb.dispose] this instance.

.. code-block:: dart

   set underwaterDepth(double value)

Depth of the underwater effect, in [0.0, 1.0]. 0 is dry; 1 is the
maximum filter strength.

Methods
-------

.. code-block:: dart

   void init()

Initialise the engine and open the default audio device.

Throws [YseException] when the audio device cannot be opened.

.. code-block:: dart

   void initOffline()

Initialise the engine without opening an audio device.

For benchmarks, automated tests, and headless tooling. Drive the
engine via [renderOffline] rather than the audio callback.

.. code-block:: dart

   void renderOffline(int blocks)

Render N audio blocks synchronously on the calling thread.

Only valid after [initOffline]; concurrent use with a live audio
thread races the manager-update path.

.. code-block:: dart

   void update()

Pump engine state. Call once per frame from the main thread.

Drives message delivery, sound state transitions, virtualisation
decisions, and listener velocity calculations.

.. code-block:: dart

   void close()

Shut down the engine and release the audio device.

.. code-block:: dart

   void pause()

Pause audio output. The engine keeps running but the device is silent.

.. code-block:: dart

   void resume()

Resume audio output after [pause].

.. code-block:: dart

   void sleep(int ms)

Sleep the calling thread for [ms] milliseconds.

.. code-block:: dart

   void setAutoReconnect({required bool on, int delayMs = 1000})

Configure automatic device reconnection.

.. code-block:: dart

   void openDevice(DeviceSetup setup, {ChannelType layout = ChannelType.auto})

Open the audio device described by [setup] with the requested speaker
[layout] (defaults to stereo-when-possible).

Throws [YseException] if the device cannot be opened.

.. code-block:: dart

   void closeCurrentDevice()

Close whichever audio device is currently open.

.. code-block:: dart

   String midiInDeviceName(int id)

Name of the MIDI input device at [id].

.. code-block:: dart

   String midiOutDeviceName(int id)

Name of the MIDI output device at [id]. Pair with [MidiOut.open].

.. code-block:: dart

   void underwaterFx(Channel channel)

Route [channel] through the built-in underwater filter (low-pass +
pitch shift).

.. code-block:: dart

   void startUpdateTimer([Duration interval = const Duration(milliseconds: 16)])

Convenience: drive [update] from a periodic [Timer].

Cancels any previously started timer first. Stopped automatically by
[close]; call [stopUpdateTimer] manually to stop without closing.

.. code-block:: dart

   void stopUpdateTimer()

Cancel the [startUpdateTimer] timer if one is running.

