import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'channel.dart';
import 'device.dart';
import 'enums.dart';
import 'exception.dart';
import 'ffi_helpers.dart';
import 'library.dart';
import 'reverb.dart';

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
  /// Throws [YseException] when the audio device cannot be opened.
  void init() => checkStatus(_b.system_init(_handle), _b);

  /// Initialise the engine without opening an audio device.
  ///
  /// For benchmarks, automated tests, and headless tooling. Drive the
  /// engine via [renderOffline] rather than the audio callback.
  void initOffline() => checkStatus(_b.system_init_offline(_handle), _b);

  /// Render N audio blocks synchronously on the calling thread.
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
  void close() {
    stopUpdateTimer();
    _b.system_close(_handle);
  }

  /// Pause audio output. The engine keeps running but the device is silent.
  void pause() => _b.system_pause(_handle);

  /// Resume audio output after [pause].
  void resume() => _b.system_resume(_handle);

  /// Number of audio callbacks that have failed to complete on time.
  ///
  /// A non-zero value indicates the audio thread is starved or the device
  /// has disconnected.
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

  /// Configure automatic device reconnection.
  void setAutoReconnect({required bool on, int delayMs = 1000}) =>
      _b.system_auto_reconnect(_handle, on ? 1 : 0, delayMs);

  /// libYSE version string (e.g. "2.0.1").
  static String get version {
    final cstr = bindings.version();
    return cstr.cast<Utf8>().toDartString();
  }

  // ─── devices ────────────────────────────────────────────────────────────

  /// All audio devices visible to the engine.
  ///
  /// Available after [init] / [initOffline]. Each [Device] descriptor is
  /// borrowed from the engine; do not retain references past [close].
  List<Device> get devices {
    final n = _b.system_num_devices(_handle);
    return List<Device>.generate(
      n,
      (i) => Device.borrowed(_b.system_get_device(_handle, i)),
      growable: false,
    );
  }

  /// Open the audio device described by [setup] with the requested speaker
  /// [layout] (defaults to stereo-when-possible).
  ///
  /// Throws [YseException] if the device cannot be opened.
  void openDevice(DeviceSetup setup, {ChannelType layout = ChannelType.auto}) {
    checkStatus(
      _b.system_open_device(_handle, setup.handle, layout.native),
      _b,
    );
  }

  /// Close whichever audio device is currently open.
  void closeCurrentDevice() => _b.system_close_current_device(_handle);

  /// Name of the platform-default audio device.
  String get defaultDevice => fetchString(
        (buf, cap) => _b.system_default_device(_handle, buf, cap),
      );

  /// Name of the platform-default audio host (WASAPI, ALSA, ...).
  String get defaultHost => fetchString(
        (buf, cap) => _b.system_default_host(_handle, buf, cap),
      );

  /// Engine session sample rate in Hz. Stays constant from [init] until
  /// [close], including across [pause] / [resume] cycles where
  /// [activeSampleRate] transiently drops to 0. Returns 0 before [init].
  ///
  /// Use this for sample-count-driven scheduling that must outlive a
  /// pause; use [activeSampleRate] for live device-state UI.
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
  String midiInDeviceName(int id) => fetchString(
        (buf, cap) => _b.system_midi_in_device_name(_handle, id, buf, cap),
      );

  /// Name of the MIDI output device at [id]. Pair with [MidiOut.open].
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

  /// Route [channel] through the built-in underwater filter (low-pass +
  /// pitch shift).
  void underwaterFx(Channel channel) =>
      _b.system_underwater_fx(_handle, channel.handle);

  /// Depth of the underwater effect, in [0.0, 1.0]. 0 is dry; 1 is the
  /// maximum filter strength.
  set underwaterDepth(double value) =>
      _b.system_set_underwater_depth(_handle, value);

  /// Convenience: drive [update] from a periodic [Timer].
  ///
  /// Cancels any previously started timer first. Stopped automatically by
  /// [close]; call [stopUpdateTimer] manually to stop without closing.
  void startUpdateTimer([Duration interval = const Duration(milliseconds: 16)]) {
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
    final ok = using((arena) {
      final cname = name.toNativeUtf8(allocator: arena);
      return b.system_create_clock(sys, cname.cast(), tempo);
    });
    if (ok == 0) {
      throw YseException(
        'yse_system_create_clock: a live clock already owns the name "$name"',
      );
    }
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
