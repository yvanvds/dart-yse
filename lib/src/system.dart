import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';
import 'library.dart';

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
