System
======

.. code-block:: dart

   class System

Engine lifecycle, audio device control, global settings.

Wraps the `YSE::system` singleton accessed via `YSE::System()`. Construct
nothing directly — access the singleton through [System.instance].

Typical lifecycle:

.. code-block:: dart

   final sys = System.instance;
   sys.init();
   // ... use the engine ...
   sys.close();


All calls must be made from the same isolate that called [init]. The
audio callback runs on a private thread the wrapper never exposes.

Static accessors
----------------

.. code-block:: dart

   static System get instance

Borrowed singleton accessor — every call returns the same instance.

.. code-block:: dart

   static int get blockSize

Engine block size in frames: the fixed number of samples the engine
renders per block (128).

[renderOffline] renders `blocks * blockSize` frames. This is
independent of [activeBufferSize], the device's frames per callback.

.. code-block:: dart

   static String get version

libYSE version string (e.g. "3.1.0").

Static methods
--------------

.. code-block:: dart

   static void randomize()

Seed the engine's random generator from the system clock.

The engine is **reproducible by default**: without this call or
[randomSeed] it starts from a fixed seed, so the same patch renders the
same "random" output every run. The generator is the one behind the
patcher's `.random` object (`Obj.gRandom`), granulator jitter, the LFO
random shapes and the seedable patcher objects. It lives inside the
engine library, so seeding Dart's or the C runtime's generator
(`srand()`) has no effect on it. The engine's float draws are in
`[0, 1)`.

Call from the control isolate (never from an audio callback), typically
before building the patch or sounds; objects that drew their stream at
construction keep it. Every engine thread re-seeds on its next draw.

.. code-block:: dart

   static void randomSeed(int seed)

Seed the engine's random generator with a fixed [seed], so the same
seed replays the same sequence.

The replay is per thread: the n-th engine thread to draw after this
call gets the same stream every time — in particular the audio thread
when it is the only one drawing. See [randomize] for what the
generator drives and when to call this.

Throws [ArgumentError] when [seed] does not fit an unsigned 32-bit
integer.

Properties
----------

.. code-block:: dart

   int get requestedSampleRate

.. code-block:: dart

   set requestedSampleRate(int hz)

Sample rate in Hz requested for the next engine session, or 0 when no
request is set.

The sample rate is an application setting fixed per session: set this
**before** [init] / [initOffline]. An offline session runs exactly at
the requested rate. A device session asks the device for it; a device
that refuses is a log line plus the rate it negotiates instead, never
an error — [sessionSampleRate] reports what the session actually got.
Setting 0 clears the request: a device session then opens at the
device default, and an offline session keeps the engine's current
rate (48 kHz in a fresh process, otherwise the previous session's
rate). Request a rate explicitly when an offline render must run at a
known one.

Setting this on a running session only stores the request for the next
one; to change a running session's rate, [close] and init again. The
request survives [close].

Throws [ArgumentError] for a negative rate.

.. code-block:: dart

   int get renderThreads

.. code-block:: dart

   set renderThreads(int count)

How many worker threads help the audio thread render the mix.

The engine renders each block through a task-graph scheduler: the audio
thread (or the thread calling [renderOffline]) renders, and worker
threads take independent parts of the mix in parallel.

* `-1` (the default; any negative value reads back as -1) is auto:
  physical cores minus one, capped at 8.
* `0` renders on the audio thread alone and starts no worker —
  recommended for Android and other constrained hardware.
* `n > 0` runs exactly `n` workers (at most 64).

The setting only decides which thread renders each part of the mix,
never how it is summed, so the output is bit-identical at any worker
count. Whatever the count, a block estimated to cost less than waking a
worker is rendered by the audio thread alone.

Set this **before** [init] / [initOffline]. With no session or an
offline one it applies at once; during a device session the value is
stored for the next init. The setting survives [close]. Read
[activeRenderThreads] for the workers actually running.

Throws [YseException] (status `YSE_ERR_EXCEPTION`) when the workers
could not be started.

.. code-block:: dart

   int get activeRenderThreads

Render worker threads currently running. Differs from [renderThreads]
for auto (`-1`, resolved to a core count) and while a device session
holds a new setting for the next init.

.. code-block:: dart

   OcclusionFn? get occlusion

.. code-block:: dart

   set occlusion(OcclusionFn? fn)

The sound-occlusion callback, or `null` when none is installed.

During every [update] the engine calls it once for each sound with
[Sound.occlusion] enabled, passing the sound's and the listener's
positions (already multiplied by the distance factor). The result,
clamped to 0..1, ducks that sound's gain (`gain *= 1 - occlusion`).
Typical callbacks raycast through the game world:

.. code-block:: dart

   System.instance.occlusion = (src, lis) => world.raycast(src, lis);
   sound.occlusion = true;


There is one callback per process: installing replaces the previous
one and `null` removes it, after which sounds keep the last occlusion
value they received. [close] removes it too.

Threading: the engine invokes the callback synchronously on the thread
that calls [update] — never the audio thread — and needs its return
value, so the bridge is a `NativeCallable.isolateLocal`. That is only
sound because [update] (and [startUpdateTimer]) must run on the isolate
that installed the callback; calling [update] from another isolate or
thread is unsupported. For the same reason the old callable is closed
right after the swap: no update can be running elsewhere with the old
pair. Replacing or removing the callback from inside the callback is
allowed; the old callable is then closed in a microtask, after [update]
has returned.

An exception thrown by the callback never unwinds into the engine: the
sound is treated as unoccluded (0) for that update and the error is
reported to the [Zone] that was current when the callback was
installed, like an error in a [Timer] callback.

.. code-block:: dart

   int get missedCallbacks

Number of consecutive [update] ticks during which the device delivered
no audio callback; 0 means audio is flowing right now.

A stream that has just been started reads non-zero until its first
callback lands (the backend's start call returns before the device
runs), so poll this until it reaches 0 to wait for a device to come
up. A value that keeps climbing means a starved audio thread or a
disconnected device. A session with no device (e.g. [initOffline])
only ever climbs. [setAutoReconnect] does not act on this counter.

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

   ReconnectState get reconnectState

What the [setAutoReconnect] watchdog last did.

[ReconnectState.none] until the watchdog acts; it goes back to
[ReconnectState.none] on [init] / [initOffline], a successful
[openDevice], and every [setAutoReconnect] call. The state keeps the
last attempt's outcome, so pair it with [reconnectCount] to notice a
new attempt.

.. code-block:: dart

   int get reconnectCount

Number of reconnection attempts the watchdog has made this session,
successful or not. Lets a host notice a reconnect it did not see
happen. Reset by [init] / [initOffline].

.. code-block:: dart

   String get activeDevice

Name of the device whose output stream is open right now, or `""`
when none is.

Compare with [Device.name] (and [activeHost] with [Device.hostName])
to see which device the session is actually on — after a
[ReconnectState.fellBackToDefault], say.

.. code-block:: dart

   String get activeHost

Host API (WASAPI, ALSA, ...) of the device whose output stream is open
right now, or `""` when none is. See [activeDevice].

.. code-block:: dart

   List<Device> get devices

All audio devices visible to the engine.

[init] enumerates the devices as a side effect of opening the default
one. [initOffline] enumerates none, so an offline session lists nothing
until [refreshDevices] fills the list, and a machine with no audio
hardware may list nothing at all. Each [Device] descriptor is borrowed
from the engine; do not retain references past [close] or past a
[refreshDevices] call, which replaces the list.

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

Chosen with [requestedSampleRate] before init. With no request a
device session runs at the rate the device negotiates, and an offline
session at 48 kHz in a fresh process (the libYSE 3 default; 2.4 used
44.1 kHz) or otherwise at the previous session's rate.

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

The listener's distance below the water surface, in world units.

`<= 0` disables the effect. The low-passed, position-neutral treatment
fades in above 1 and saturates at 5. A positive depth also enables the
built-in underwater reverb zone. (This is not a normalised 0..1
strength.)

Methods
-------

.. code-block:: dart

   void init()

Initialise the engine and open the default audio device.

Succeeds only when a stream on the default output device is running.
With no default device, or one that refuses to open or start the
stream, this throws [YseException] (status `YSE_ERR_AUDIO_DEVICE`) and
leaves the engine closed. A host that must run without audio hardware
(headless CI, a server, a machine whose only device is unplugged)
should catch it and fall back to [initOffline]:

.. code-block:: dart

   try {
     sys.init();
   } on YseException {
     sys.initOffline();
   }


The session runs at [requestedSampleRate] when the device accepts it,
otherwise at the rate the device negotiates; read the result from
[sessionSampleRate]. Up to libYSE 2.4 this call succeeded silently
with nothing open.

.. code-block:: dart

   void initOffline()

Initialise the engine without opening an audio device.

For benchmarks, automated tests, and headless tooling. Drive the
engine via [renderOffline] rather than the audio callback. The session
runs exactly at [requestedSampleRate]; with no request it keeps the
engine's current rate — 48 kHz in a fresh process, otherwise the rate
of the previous session. The speaker layout is stereo; change it with
[setChannelConfiguration].

.. code-block:: dart

   void setChannelConfiguration(ChannelType layout, int outputs)

Set the speaker [layout] of a session that has no device, with
[outputs] output channels.

[openDevice] derives the layout from the device it opens, so a session
without one — [initOffline], headless CI, [renderOffline] benchmarks —
otherwise stays on the stereo layout init installs. Call this **after**
[init] / [initOffline] (init installs the stereo default itself and
overwrites an earlier call). The next audio callback or [renderOffline]
block that mixes a sound picks the new layout up and resizes the mixer
(with no sound alive the engine skips the mix, and the resize with
it), after which [Channel.numOutputs] on [Channel.master] reports
[outputs].

[ChannelType.auto] derives a layout from [outputs];
[ChannelType.custom] allocates [outputs] speakers whose positions are
set afterwards.

Throws [ArgumentError] when [outputs] is below 1 (the engine would
refuse a zero-output layout with only a log line).

.. code-block:: dart

   void renderOffline(int blocks)

Render [blocks] engine blocks (`blocks * blockSize` frames)
synchronously on the calling thread.

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

Also removes the [occlusion] callback, releases every `Bus`
subscription and tap, closing their streams (re-subscribe after the
next init), clears the send callback of every `Patcher` with a
`Patcher.messages` listener (closing that stream), and forgets every `Channel.busName` (the engine drops the
channel's bus subscription with the session).

.. code-block:: dart

   void pause()

Pause audio output. The engine keeps running but the device is silent.

.. code-block:: dart

   void resume()

Resume audio output after [pause] by restarting the device this
session already had.

After [openDevice] that is the opened device, looked up again by name
and host, with the channel count and buffer size it was opened with;
when it cannot be reopened nothing is opened (a warning is logged) and
the session never moves to another device. A session that never called
[openDevice] reopens the current default device.

A session brought up with [initOffline] has no device, so this is a
no-op there rather than an open of the platform default; use
[openDevice] to give such a session a device.

.. code-block:: dart

   void sleep(int ms)

Sleep the calling thread for [ms] milliseconds.

.. code-block:: dart

   void setAutoReconnect({required bool on, int delayMs = 1000, bool fallbackToDefault = false, int maxAttempts = 0})

Configure automatic re-opening of the output stream when the device
stops delivering callbacks (headphones unplugged, device removed).

The watchdog runs inside [update]: when the device has delivered no
audio callback for [delayMs] it closes the stream and opens it again.

**Which device.** The one this session had: after a successful
[openDevice], that device, looked up again by [Device.name] and
[Device.hostName] (indices shift when devices are re-enumerated), with
the output channels and buffer size it was opened with. A session that
never called [openDevice] (plain [init]) runs on the default output
device and reopens whatever the default is at that moment. Up to
libYSE 3.0 every attempt opened the default device, so a session on an
external interface moved silently onto the built-in output.

**Fallback.** When the session's device cannot be reopened, nothing is
opened and the watchdog tries again [delayMs] later. With
[fallbackToDefault] the default output device is opened instead, and
the speaker layout is narrowed if it has fewer outputs; the session
does not move back by itself when its own device returns. Off by
default: an audio application usually wants to know rather than be
moved to the laptop speakers.

**Timing.** [delayMs] is wall-clock milliseconds: the silence before
an attempt, and the interval between further attempts while the device
stays unavailable. Negative values are clamped to 0. A freshly started
stream that has not delivered its first callback yet is not treated as
stalled; it gets a 500 ms start-up grace regardless of [delayMs]. Up
to libYSE 2.4 the value was compared against a count of [update]
ticks and attempts fired on every tick once past it.

**Attempt limit.** A positive [maxAttempts] stops the watchdog after
that many consecutive failed attempts, so a machine with no audio
hardware does not retry forever; [reconnectState] then reads
[ReconnectState.failed]. 0 (the default) or less retries forever.

**Outcome.** [reconnectState] says what the last attempt did,
[reconnectCount] how many attempts were made, and [activeDevice] /
[activeHost] which device is actually playing. Every call resets
[reconnectState] to [ReconnectState.none] and re-arms a watchdog that
gave up.

On desktop the device is looked up in the backend's enumeration as it
stands, so a device unplugged and plugged back in may only be found
after [refreshDevices]. Call it while [reconnectState] reads
[ReconnectState.reconnecting] (no stream is open then):

.. code-block:: dart

   sys.setAutoReconnect(on: true, delayMs: 1000, maxAttempts: 30);
   // in the host's update loop:
   if (sys.reconnectState == ReconnectState.reconnecting) {
     sys.refreshDevices();
   }


A session with no device ([initOffline]) never gets one from the
watchdog: each attempt there opens nothing.

.. code-block:: dart

   bool refreshDevices()

Enumerate the audio devices without opening a stream, and report
whether the audio backend could be reached to do it.

[init] fills [devices] as part of opening the default device, which may
be the wrong one, held by another application, or at the wrong rate.
This fills it without opening anything, so a host can resolve a stored
device first and then [openDevice] exactly that one. Valid before
[init] (no session at all), on an [initOffline] session, and on a
running device session:

.. code-block:: dart

   sys.initOffline();
   if (sys.refreshDevices()) {
     final stored = sys.devices.where(
       (d) => d.name == storedName && d.hostName == storedHost,
     );
     // build a DeviceSetup from stored.first, then sys.openDevice(setup)
   }


On desktop this starts the audio backend (PortAudio) if it is not
running yet, without opening a stream. That is also what lets
[openDevice] work on an [initOffline] session in a process that never
called [init].

**Hot-plug.** With no stream open, the backend is restarted, so the
list includes devices plugged in or removed since it last started.
With a stream open (after [init], or a successful [openDevice]) the
stream is never touched, and the list is re-read from the backend's
existing enumeration: on PortAudio a device plugged in or removed while
the stream runs does not show up until you [closeCurrentDevice] (or
[close]) and call this again.

The refresh replaces the list: [Device] descriptors and [DeviceSetup]s
built from the old list are invalid afterwards, and an index may now
name a different device. Match devices by [Device.name] and
[Device.hostName], not by index. [defaultDevice] and [defaultHost] are
re-read too.

Returns `true` when the list is current; it may still be empty (a
machine with no audio devices). Returns `false` when the backend could
not start: [devices] is then empty and the backend's error is in the
engine log. Throws [YseException] only for an unexpected engine error.

On a bare headless Linux machine starting PortAudio can hang (which is
why [initOffline] does not start it), so headless tools that never
need a device should not call this.

.. code-block:: dart

   void openDevice(DeviceSetup setup, {ChannelType layout = ChannelType.auto})

Open the audio device described by [setup] with the requested speaker
[layout] (defaults to stereo-when-possible).

Throws [YseException] (status `YSE_ERR_AUDIO_DEVICE`) when the engine
opened no stream for [setup]: no output device set, an output device
whose [Device.id] is -1 or no longer resolves, a stream open error
(including a device that refuses the session rate), or an offline
session with no audio backend running. On failure the running stream
and the speaker layout are left untouched. Up to libYSE 2.4 these
failures were only logged and this call returned normally.

On an [initOffline] session, call [refreshDevices] first: it starts the
audio backend and lists the devices to pick from. Without it, a process
that has only run offline sessions has no backend running and this
throws.

The stream opens at the locked [sessionSampleRate];
[DeviceSetup.sampleRate] cannot change a running session's rate (see
[requestedSampleRate]).

.. code-block:: dart

   void closeCurrentDevice()

Close whichever audio device is currently open.

.. code-block:: dart

   String midiInDeviceName(int id)

Name of the MIDI input device at [id].

Returns `""` when there is no such device: an [id] at or past
[midiInDeviceCount], or any [id] on a host whose MIDI backend failed to
initialise. A non-empty name always means a real port.

.. code-block:: dart

   String midiOutDeviceName(int id)

Name of the MIDI output device at [id]. Pair with [MidiOut.open].

Returns `""` when there is no such device: an [id] at or past
[midiOutDeviceCount], or any [id] on a host whose MIDI backend failed
to initialise. A non-empty name always means a real port.

.. code-block:: dart

   void underwaterFx(Channel channel)

Route [channel] through the built-in underwater filter.

Attaches the engine's underwater insert to the channel's insert slot —
the same slot as [Channel.dsp]; the two replace each other.

.. code-block:: dart

   void startUpdateTimer([Duration interval = const Duration(milliseconds: 16)])

Convenience: drive [update] from a periodic [Timer].

Cancels any previously started timer first. Stopped automatically by
[close]; call [stopUpdateTimer] manually to stop without closing.

.. code-block:: dart

   void stopUpdateTimer()

Cancel the [startUpdateTimer] timer if one is running.

