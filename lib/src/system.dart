import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'bus.dart' show closeBusBridges;
import 'channel.dart';
import 'device.dart';
import 'enums.dart';
import 'exception.dart';
import 'ffi_helpers.dart';
import 'library.dart';
import 'pos.dart';
import 'reverb.dart';
import 'sound.dart' show Sound;

/// Sound-occlusion callback installed with [System.occlusion].
///
/// Returns how much geometry sits between [source] and [listener]: 0 for a
/// clear line of sight, 1 for fully blocked. Both positions are already
/// multiplied by the engine's distance factor.
typedef OcclusionFn = double Function(Pos source, Pos listener);

/// Engine lifecycle, audio device control, global settings.
///
/// Wraps the `YSE::system` singleton accessed via `YSE::System()`. Construct
/// nothing directly — access the singleton through [System.instance].
///
/// Typical lifecycle:
/// ```
/// final sys = System.instance;
/// sys.init();
/// // ... use the engine ...
/// sys.close();
/// ```
///
/// All calls must be made from the same isolate that called [init]. The
/// audio callback runs on a private thread the wrapper never exposes.
class System {
  final YseBindings _b;
  final Pointer<YseSystem> _handle;
  Timer? _updateTimer;

  System._(this._b, this._handle);

  /// Borrowed singleton accessor — every call returns the same instance.
  static System get instance {
    final b = bindings;
    return System._(b, b.system_get());
  }

  /// Initialise the engine and open the default audio device.
  ///
  /// Succeeds only when a stream on the default output device is running.
  /// With no default device, or one that refuses to open or start the
  /// stream, this throws [YseException] (status `YSE_ERR_AUDIO_DEVICE`) and
  /// leaves the engine closed. A host that must run without audio hardware
  /// (headless CI, a server, a machine whose only device is unplugged)
  /// should catch it and fall back to [initOffline]:
  ///
  /// ```dart
  /// try {
  ///   sys.init();
  /// } on YseException {
  ///   sys.initOffline();
  /// }
  /// ```
  ///
  /// The session runs at [requestedSampleRate] when the device accepts it,
  /// otherwise at the rate the device negotiates; read the result from
  /// [sessionSampleRate]. Up to libYSE 2.4 this call succeeded silently
  /// with nothing open.
  void init() => checkStatus(_b.system_init(_handle), _b);

  /// Initialise the engine without opening an audio device.
  ///
  /// For benchmarks, automated tests, and headless tooling. Drive the
  /// engine via [renderOffline] rather than the audio callback. The session
  /// runs exactly at [requestedSampleRate]; with no request it keeps the
  /// engine's current rate — 48 kHz in a fresh process, otherwise the rate
  /// of the previous session. The speaker layout is stereo; change it with
  /// [setChannelConfiguration].
  void initOffline() => checkStatus(_b.system_init_offline(_handle), _b);

  /// Sample rate in Hz requested for the next engine session, or 0 when no
  /// request is set.
  ///
  /// The sample rate is an application setting fixed per session: set this
  /// **before** [init] / [initOffline]. An offline session runs exactly at
  /// the requested rate. A device session asks the device for it; a device
  /// that refuses is a log line plus the rate it negotiates instead, never
  /// an error — [sessionSampleRate] reports what the session actually got.
  /// Setting 0 clears the request: a device session then opens at the
  /// device default, and an offline session keeps the engine's current
  /// rate (48 kHz in a fresh process, otherwise the previous session's
  /// rate). Request a rate explicitly when an offline render must run at a
  /// known one.
  ///
  /// Setting this on a running session only stores the request for the next
  /// one; to change a running session's rate, [close] and init again. The
  /// request survives [close].
  ///
  /// Throws [ArgumentError] for a negative rate.
  int get requestedSampleRate => _b.system_get_requested_sample_rate(_handle);
  set requestedSampleRate(int hz) {
    if (hz < 0) {
      throw ArgumentError.value(
        hz,
        'hz',
        'must be >= 0 (0 clears the request)',
      );
    }
    _b.system_request_sample_rate(_handle, hz);
  }

  /// Set the speaker [layout] of a session that has no device, with
  /// [outputs] output channels.
  ///
  /// [openDevice] derives the layout from the device it opens, so a session
  /// without one — [initOffline], headless CI, [renderOffline] benchmarks —
  /// otherwise stays on the stereo layout init installs. Call this **after**
  /// [init] / [initOffline] (init installs the stereo default itself and
  /// overwrites an earlier call). The next audio callback or [renderOffline]
  /// block that mixes a sound picks the new layout up and resizes the mixer
  /// (with no sound alive the engine skips the mix, and the resize with
  /// it), after which [Channel.numOutputs] on [Channel.master] reports
  /// [outputs].
  ///
  /// [ChannelType.auto] derives a layout from [outputs];
  /// [ChannelType.custom] allocates [outputs] speakers whose positions are
  /// set afterwards.
  ///
  /// Throws [ArgumentError] when [outputs] is below 1 (the engine would
  /// refuse a zero-output layout with only a log line).
  void setChannelConfiguration(ChannelType layout, int outputs) {
    if (outputs < 1) {
      throw ArgumentError.value(outputs, 'outputs', 'must be >= 1');
    }
    _b.system_set_channel_configuration(_handle, layout.native, outputs);
  }

  /// How many worker threads help the audio thread render the mix.
  ///
  /// The engine renders each block through a task-graph scheduler: the audio
  /// thread (or the thread calling [renderOffline]) renders, and worker
  /// threads take independent parts of the mix in parallel.
  ///
  /// * `-1` (the default; any negative value reads back as -1) is auto:
  ///   physical cores minus one, capped at 8.
  /// * `0` renders on the audio thread alone and starts no worker —
  ///   recommended for Android and other constrained hardware.
  /// * `n > 0` runs exactly `n` workers (at most 64).
  ///
  /// The setting only decides which thread renders each part of the mix,
  /// never how it is summed, so the output is bit-identical at any worker
  /// count. Whatever the count, a block estimated to cost less than waking a
  /// worker is rendered by the audio thread alone.
  ///
  /// Set this **before** [init] / [initOffline]. With no session or an
  /// offline one it applies at once; during a device session the value is
  /// stored for the next init. The setting survives [close]. Read
  /// [activeRenderThreads] for the workers actually running.
  ///
  /// Throws [YseException] (status `YSE_ERR_EXCEPTION`) when the workers
  /// could not be started.
  int get renderThreads => _b.system_get_render_threads(_handle);
  set renderThreads(int count) =>
      checkStatus(_b.system_set_render_threads(_handle, count), _b);

  /// Render worker threads currently running. Differs from [renderThreads]
  /// for auto (`-1`, resolved to a core count) and while a device session
  /// holds a new setting for the next init.
  int get activeRenderThreads => _b.system_get_active_render_threads(_handle);

  /// Engine block size in frames: the fixed number of samples the engine
  /// renders per block (128).
  ///
  /// [renderOffline] renders `blocks * blockSize` frames. This is
  /// independent of [activeBufferSize], the device's frames per callback.
  static int get blockSize => bindings.block_size();

  /// Seed the engine's random generator from the system clock.
  ///
  /// The engine is **reproducible by default**: without this call or
  /// [randomSeed] it starts from a fixed seed, so the same patch renders the
  /// same "random" output every run. The generator is the one behind the
  /// patcher's `.random` object (`Obj.gRandom`), granulator jitter, the LFO
  /// random shapes and the seedable patcher objects. It lives inside the
  /// engine library, so seeding Dart's or the C runtime's generator
  /// (`srand()`) has no effect on it. The engine's float draws are in
  /// `[0, 1)`.
  ///
  /// Call from the control isolate (never from an audio callback), typically
  /// before building the patch or sounds; objects that drew their stream at
  /// construction keep it. Every engine thread re-seeds on its next draw.
  static void randomize() => bindings.randomize();

  /// Seed the engine's random generator with a fixed [seed], so the same
  /// seed replays the same sequence.
  ///
  /// The replay is per thread: the n-th engine thread to draw after this
  /// call gets the same stream every time — in particular the audio thread
  /// when it is the only one drawing. See [randomize] for what the
  /// generator drives and when to call this.
  ///
  /// Throws [ArgumentError] when [seed] does not fit an unsigned 32-bit
  /// integer.
  static void randomSeed(int seed) {
    if (seed < 0 || seed > 0xFFFFFFFF) {
      throw ArgumentError.value(seed, 'seed', 'must be in 0..0xFFFFFFFF');
    }
    bindings.random_seed(seed);
  }

  /// Render [blocks] engine blocks (`blocks * blockSize` frames)
  /// synchronously on the calling thread.
  ///
  /// Only valid after [initOffline]; concurrent use with a live audio
  /// thread races the manager-update path.
  void renderOffline(int blocks) => _b.system_render_offline(_handle, blocks);

  /// Pump engine state. Call once per frame from the main thread.
  ///
  /// Drives message delivery, sound state transitions, virtualisation
  /// decisions, and listener velocity calculations.
  void update() => _b.system_update(_handle);

  /// Shut down the engine and release the audio device.
  ///
  /// Also removes the [occlusion] callback, releases every `Bus`
  /// subscription and tap, closing their streams (re-subscribe after the
  /// next init), and forgets every `Channel.busName` (the engine drops the
  /// channel's bus subscription with the session).
  void close() {
    stopUpdateTimer();
    occlusion = null;
    closeBusBridges();
    clearChannelBusNames();
    _b.system_close(_handle);
  }

  // ─── occlusion ──────────────────────────────────────────────────────────

  static OcclusionFn? _occlusionFn;
  static NativeCallable<YseOcclusionCallbackFunction>? _occlusionCallable;
  static Zone? _occlusionZone;

  /// Nesting depth of running occlusion callbacks.
  static int _occlusionDepth = 0;

  /// The sound-occlusion callback, or `null` when none is installed.
  ///
  /// During every [update] the engine calls it once for each sound with
  /// [Sound.occlusion] enabled, passing the sound's and the listener's
  /// positions (already multiplied by the distance factor). The result,
  /// clamped to 0..1, ducks that sound's gain (`gain *= 1 - occlusion`).
  /// Typical callbacks raycast through the game world:
  ///
  /// ```dart
  /// System.instance.occlusion = (src, lis) => world.raycast(src, lis);
  /// sound.occlusion = true;
  /// ```
  ///
  /// There is one callback per process: installing replaces the previous
  /// one and `null` removes it, after which sounds keep the last occlusion
  /// value they received. [close] removes it too.
  ///
  /// Threading: the engine invokes the callback synchronously on the thread
  /// that calls [update] — never the audio thread — and needs its return
  /// value, so the bridge is a `NativeCallable.isolateLocal`. That is only
  /// sound because [update] (and [startUpdateTimer]) must run on the isolate
  /// that installed the callback; calling [update] from another isolate or
  /// thread is unsupported. For the same reason the old callable is closed
  /// right after the swap: no update can be running elsewhere with the old
  /// pair. Replacing or removing the callback from inside the callback is
  /// allowed; the old callable is then closed in a microtask, after [update]
  /// has returned.
  ///
  /// An exception thrown by the callback never unwinds into the engine: the
  /// sound is treated as unoccluded (0) for that update and the error is
  /// reported to the [Zone] that was current when the callback was
  /// installed, like an error in a [Timer] callback.
  OcclusionFn? get occlusion => _occlusionFn;
  set occlusion(OcclusionFn? fn) {
    final old = _occlusionCallable;
    NativeCallable<YseOcclusionCallbackFunction>? next;
    if (fn != null) {
      next = NativeCallable<YseOcclusionCallbackFunction>.isolateLocal(
        _occlusionTrampoline,
        exceptionalReturn: 0.0,
      );
    }
    _occlusionFn = fn;
    _occlusionZone = fn == null ? null : Zone.current;
    _occlusionCallable = next;
    _b.system_set_occlusion_callback(
      _handle,
      next?.nativeFunction ?? nullptr,
      nullptr,
    );
    if (old != null) {
      if (_occlusionDepth > 0) {
        // Swapped from inside a running callback, which may be `old`'s own
        // invocation: close it only after the engine's update has returned.
        scheduleMicrotask(old.close);
      } else {
        old.close();
      }
    }
  }

  static double _occlusionTrampoline(
    Pointer<yse_pos_t> src,
    Pointer<yse_pos_t> lis,
    Pointer<Void> _,
  ) {
    // `src` and `lis` are stack copies valid only for this call: convert
    // them before running user code.
    final source = Pos.fromNative(src.ref);
    final listener = Pos.fromNative(lis.ref);
    final fn = _occlusionFn;
    if (fn == null) return 0.0;
    _occlusionDepth++;
    try {
      return fn(source, listener);
    } catch (e, st) {
      (_occlusionZone ?? Zone.root).handleUncaughtError(e, st);
      return 0.0;
    } finally {
      _occlusionDepth--;
    }
  }

  /// Pause audio output. The engine keeps running but the device is silent.
  void pause() => _b.system_pause(_handle);

  /// Resume audio output after [pause] by restarting the device this
  /// session already had.
  ///
  /// A session brought up with [initOffline] has no device, so this is a
  /// no-op there rather than an open of the platform default; use
  /// [openDevice] to give such a session a device.
  void resume() => _b.system_resume(_handle);

  /// Number of consecutive [update] ticks during which the device delivered
  /// no audio callback; 0 means audio is flowing right now.
  ///
  /// A stream that has just been started reads non-zero until its first
  /// callback lands (the backend's start call returns before the device
  /// runs), so poll this until it reaches 0 to wait for a device to come
  /// up. A value that keeps climbing means a starved audio thread or a
  /// disconnected device. A session with no device (e.g. [initOffline])
  /// only ever climbs. [setAutoReconnect] does not act on this counter.
  int get missedCallbacks => _b.system_missed_callbacks(_handle);

  /// CPU load of the audio thread as a fraction of the callback budget.
  double get cpuLoad => _b.system_cpu_load(_handle);

  /// Sleep the calling thread for [ms] milliseconds.
  void sleep(int ms) => _b.system_sleep(_handle, ms);

  /// Maximum number of concurrently audible sounds.
  ///
  /// Beyond this limit the engine virtualises the least significant
  /// sounds (typically furthest from the listener).
  int get maxSounds => _b.system_get_max_sounds(_handle);
  set maxSounds(int value) => _b.system_set_max_sounds(_handle, value);

  /// Enable or disable the built-in audio test signal.
  set audioTest(bool on) => _b.system_audio_test(_handle, on ? 1 : 0);

  /// Configure automatic re-opening of the output stream when the device
  /// stops delivering callbacks (headphones unplugged, device removed).
  ///
  /// [delayMs] is wall-clock milliseconds: the silence before an attempt,
  /// and the interval between further attempts while the device stays
  /// unavailable. Negative values are clamped to 0. A freshly started
  /// stream that has not delivered its first callback yet is not treated as
  /// stalled; it gets a 500 ms start-up grace regardless of [delayMs]. Up
  /// to libYSE 2.4 the value was compared against a count of [update]
  /// ticks and attempts fired on every tick once past it.
  void setAutoReconnect({required bool on, int delayMs = 1000}) =>
      _b.system_auto_reconnect(_handle, on ? 1 : 0, delayMs);

  /// libYSE version string (e.g. "3.1.0").
  static String get version {
    final cstr = bindings.version();
    return cstr.cast<Utf8>().toDartString();
  }

  // ─── devices ────────────────────────────────────────────────────────────

  /// All audio devices visible to the engine.
  ///
  /// [init] enumerates the devices. [initOffline] enumerates none, so an
  /// offline session lists nothing until the engine's device list is
  /// refreshed, and a headless host may list nothing at all. Each [Device]
  /// descriptor is borrowed from the engine; do not retain references past
  /// [close] or past a refresh of the list.
  List<Device> get devices {
    final n = _b.system_num_devices(_handle);
    final result = <Device>[];
    for (var i = 0; i < n; i++) {
      // yse_system_get_device returns NULL past the end of the list; the
      // count and the list can disagree if a rescan races this loop.
      final d = _b.system_get_device(_handle, i);
      if (d.address == 0) break;
      result.add(Device.borrowed(d));
    }
    return List<Device>.unmodifiable(result);
  }

  /// Open the audio device described by [setup] with the requested speaker
  /// [layout] (defaults to stereo-when-possible).
  ///
  /// Throws [YseException] (status `YSE_ERR_AUDIO_DEVICE`) when the engine
  /// opened no stream for [setup]: no output device set, an output device
  /// whose [Device.id] is -1 or no longer resolves, a stream open error
  /// (including a device that refuses the session rate), or an offline
  /// session with no audio backend running. On failure the running stream
  /// and the speaker layout are left untouched. Up to libYSE 2.4 these
  /// failures were only logged and this call returned normally.
  ///
  /// The stream opens at the locked [sessionSampleRate];
  /// [DeviceSetup.sampleRate] cannot change a running session's rate (see
  /// [requestedSampleRate]).
  void openDevice(DeviceSetup setup, {ChannelType layout = ChannelType.auto}) {
    checkStatus(
      _b.system_open_device(_handle, setup.handle, layout.native),
      _b,
    );
  }

  /// Close whichever audio device is currently open.
  void closeCurrentDevice() => _b.system_close_current_device(_handle);

  /// Name of the platform-default audio device.
  String get defaultDevice =>
      fetchString((buf, cap) => _b.system_default_device(_handle, buf, cap));

  /// Name of the platform-default audio host (WASAPI, ALSA, ...).
  String get defaultHost =>
      fetchString((buf, cap) => _b.system_default_host(_handle, buf, cap));

  /// Engine session sample rate in Hz. Stays constant from [init] until
  /// [close], including across [pause] / [resume] cycles where
  /// [activeSampleRate] transiently drops to 0. Returns 0 before [init].
  ///
  /// Use this for sample-count-driven scheduling that must outlive a
  /// pause; use [activeSampleRate] for live device-state UI.
  ///
  /// Chosen with [requestedSampleRate] before init. With no request a
  /// device session runs at the rate the device negotiates, and an offline
  /// session at 48 kHz in a fresh process (the libYSE 3 default; 2.4 used
  /// 44.1 kHz) or otherwise at the previous session's rate.
  double get sessionSampleRate => _b.system_get_sample_rate(_handle);

  /// Sample rate of the currently open audio device, or 0 when no device
  /// is open (pre-init, after close, or [initOffline] path).
  double get activeSampleRate => _b.system_get_active_sample_rate(_handle);

  /// The currently open device's frames-per-callback (NOT the engine block
  /// size). Returns 0 when no device is open.
  int get activeBufferSize => _b.system_get_active_buffer_size(_handle);

  /// Output latency of the currently open device, in samples. Returns 0
  /// when no device is open. Convert to milliseconds with
  /// `(activeOutputLatency / activeSampleRate) * 1000`.
  int get activeOutputLatency => _b.system_get_active_output_latency(_handle);

  // ─── MIDI devices ───────────────────────────────────────────────────────

  /// Number of MIDI input devices visible to the engine.
  ///
  /// Windows / Linux only — other platforms always return 0.
  int get midiInDeviceCount => _b.system_num_midi_in_devices(_handle);

  /// Number of MIDI output devices visible to the engine.
  ///
  /// Windows / Linux only — other platforms always return 0.
  int get midiOutDeviceCount => _b.system_num_midi_out_devices(_handle);

  /// Name of the MIDI input device at [id].
  ///
  /// Returns `""` when there is no such device: an [id] at or past
  /// [midiInDeviceCount], or any [id] on a host whose MIDI backend failed to
  /// initialise. A non-empty name always means a real port.
  String midiInDeviceName(int id) => fetchString(
    (buf, cap) => _b.system_midi_in_device_name(_handle, id, buf, cap),
  );

  /// Name of the MIDI output device at [id]. Pair with [MidiOut.open].
  ///
  /// Returns `""` when there is no such device: an [id] at or past
  /// [midiOutDeviceCount], or any [id] on a host whose MIDI backend failed
  /// to initialise. A non-empty name always means a real port.
  String midiOutDeviceName(int id) => fetchString(
    (buf, cap) => _b.system_midi_out_device_name(_handle, id, buf, cap),
  );

  // ─── global reverb ──────────────────────────────────────────────────────

  /// The fallback reverb used wherever no positioned [Reverb] zone reaches.
  ///
  /// Disabled by default — set `globalReverb.active = true` to enable.
  /// Borrowed from the engine; do not [Reverb.dispose] this instance.
  Reverb get globalReverb =>
      Reverb.borrowed(_b.system_get_global_reverb(_handle));

  // ─── underwater FX ──────────────────────────────────────────────────────

  /// Route [channel] through the built-in underwater filter.
  ///
  /// Attaches the engine's underwater insert to the channel's insert slot —
  /// the same slot as [Channel.dsp]; the two replace each other.
  void underwaterFx(Channel channel) =>
      _b.system_underwater_fx(_handle, channel.handle);

  /// The listener's distance below the water surface, in world units.
  ///
  /// `<= 0` disables the effect. The low-passed, position-neutral treatment
  /// fades in above 1 and saturates at 5. A positive depth also enables the
  /// built-in underwater reverb zone. (This is not a normalised 0..1
  /// strength.)
  set underwaterDepth(double value) =>
      _b.system_set_underwater_depth(_handle, value);

  /// Convenience: drive [update] from a periodic [Timer].
  ///
  /// Cancels any previously started timer first. Stopped automatically by
  /// [close]; call [stopUpdateTimer] manually to stop without closing.
  void startUpdateTimer([
    Duration interval = const Duration(milliseconds: 16),
  ]) {
    stopUpdateTimer();
    _updateTimer = Timer.periodic(interval, (_) => update());
  }

  /// Cancel the [startUpdateTimer] timer if one is running.
  void stopUpdateTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }
}

/// A named musical beat-clock owned by the engine (issue #21).
///
/// A domain clock is a beat accumulator derived from the audio callback:
/// every audio block it advances by `blockSeconds * tempo / 60`, so
/// [beatPosition] is the running integral of [currentTempo]. All clocks
/// derive from the single sample clock, keeping polytemporal relationships
/// exact. Tempo is a playable, rampable control and is **not** clamped — a
/// tempo of 0 pauses the clock and a negative tempo runs it backwards.
///
/// Clocks are keyed by [name], not by an owned pointer: the engine holds the
/// clock and the *first* registration of a name wins. Bind a [ClipTransport]
/// to a clock by that same [name]; the clock must outlive every clip bound to
/// it.
///
/// Threading (CLAUDE.md): construct, [dispose] and [setTempo] are
/// control-thread calls made from the [System] isolate; [beatPosition] and
/// [currentTempo] are cheap enough to read from the UI thread at frame rate.
///
/// Unlike the pointer-backed wrappers this is **not** [Finalizable]: the
/// engine keys clocks by name, and the native destructor takes that name
/// rather than a pointer, so there is no token a [NativeFinalizer] could
/// carry. Release the clock explicitly with [dispose].
class DomainClock {
  final YseBindings _b;
  final Pointer<YseSystem> _sys;

  /// Registration name of this clock. Bind a [ClipTransport] with it.
  final String name;

  bool _alive = true;

  DomainClock._(this._b, this._sys, this.name);

  /// Create a named clock starting at [tempo] BPM.
  ///
  /// Throws [YseException] if a live clock already owns [name] (first
  /// registration wins).
  factory DomainClock(String name, {double tempo = 120.0}) {
    final b = bindings;
    final sys = b.system_get();
    final status = using((arena) {
      final cname = name.toNativeUtf8(allocator: arena);
      return b.system_create_clock(sys, cname.cast(), tempo);
    });
    checkStatus(status, b);
    return DomainClock._(b, sys, name);
  }

  /// Whether a live clock with this [name] currently exists in the engine.
  bool get exists => using((arena) {
    final cname = name.toNativeUtf8(allocator: arena);
    return _b.system_clock_exists(_sys, cname.cast()) != 0;
  });

  /// Ramp the tempo toward [target] BPM over [ramp] (zero = instant).
  ///
  /// Tempo is unclamped: 0 pauses the clock, a negative value runs it
  /// backwards.
  void setTempo(double target, {Duration ramp = Duration.zero}) =>
      using((arena) {
        final cname = name.toNativeUtf8(allocator: arena);
        _b.system_set_tempo(
          _sys,
          cname.cast(),
          target,
          ramp.inMilliseconds / 1000.0,
        );
      });

  /// Current beat position — the running integral of tempo. Returns 0 for a
  /// disposed or otherwise unknown clock.
  double get beatPosition => using((arena) {
    final cname = name.toNativeUtf8(allocator: arena);
    return _b.system_beat_position(_sys, cname.cast());
  });

  /// Current tempo in BPM. Returns 0 for a disposed or otherwise unknown
  /// clock.
  double get currentTempo => using((arena) {
    final cname = name.toNativeUtf8(allocator: arena);
    return _b.system_current_tempo(_sys, cname.cast());
  });

  /// Destroy the named clock in the engine. Idempotent. Dispose every
  /// [ClipTransport] bound to this clock first.
  void dispose() {
    if (!_alive) return;
    _alive = false;
    using((arena) {
      final cname = name.toNativeUtf8(allocator: arena);
      _b.system_destroy_clock(_sys, cname.cast());
    });
  }
}
