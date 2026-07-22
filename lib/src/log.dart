import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'enums.dart';
import 'ffi_helpers.dart';
import 'library.dart';

/// Engine logging facility.
///
/// Two ways to consume log output:
///   1. Default file sink — controlled via [logfile] and [level].
///   2. The [messages] broadcast stream — install once and listen
///      from any Dart code. Replaces the file sink for the duration
///      of the subscription.
///
/// Logging is only active between `System().init()` and
/// `System().close()`.
class Log {
  final YseBindings _b;
  final Pointer<YseLog> _handle;

  Log._(this._b, this._handle);

  /// Borrowed singleton accessor.
  static Log get instance {
    final b = bindings;
    return Log._(b, b.log_get());
  }

  /// Send an application-level message to the YSE log. Emitted at
  /// error-level so it survives filters set above [LogLevel.debug].
  void sendMessage(String message) => using((arena) {
    final cstr = message.toNativeUtf8(allocator: arena);
    _b.log_send_message(_handle, cstr.cast());
  });

  /// Current log-level filter. Messages above the chosen level are dropped.
  LogLevel get level {
    final raw = _b.log_get_level(_handle);
    return LogLevel.values.firstWhere(
      (e) => e.native == raw,
      orElse: () => LogLevel.none,
    );
  }

  set level(LogLevel value) => _b.log_set_level(_handle, value.native);

  /// Path of the default log file (defaults to `YSElog.txt` in the
  /// process working directory). Has no effect after [messages] has
  /// been subscribed.
  String get logfile =>
      fetchString((buf, cap) => _b.log_get_logfile(_handle, buf, cap));
  set logfile(String path) => using((arena) {
    final cstr = path.toNativeUtf8(allocator: arena);
    _b.log_set_logfile(_handle, cstr.cast());
  });

  static StreamController<String>? _controller;
  static NativeCallable<Void Function(Pointer<Char>, Pointer<Void>)>? _callable;

  /// Broadcast stream of log messages from the engine.
  ///
  /// Subscribing replaces the default file sink with an in-process
  /// callback that forwards every message into the stream. The first
  /// subscription installs the bridge; subsequent subscribers share
  /// the same stream.
  ///
  /// Cancel the last subscription (or close the engine) to release the
  /// callback. Callbacks run on whichever thread emitted the log
  /// message — `NativeCallable.listener` posts them back to this
  /// isolate via a port, so Dart code only ever sees them serialised
  /// in the isolate's event queue.
  Stream<String> get messages {
    if (_controller != null) return _controller!.stream;
    final controller = StreamController<String>.broadcast(
      onCancel: () {
        if (_controller?.hasListener ?? false) return;
        // Last listener gone — uninstall the bridge.
        _b.log_set_callback(_handle, nullptr, nullptr);
        _callable?.close();
        _callable = null;
        _controller?.close();
        _controller = null;
      },
    );
    final freeFn = _b.log_free_message;
    final callable =
        NativeCallable<Void Function(Pointer<Char>, Pointer<Void>)>.listener((
          Pointer<Char> msg,
          Pointer<Void> _,
        ) {
          // The bridge transferred ownership of the malloc'd string.
          // Decode then release before bubbling it up.
          try {
            controller.add(msg.cast<Utf8>().toDartString());
          } finally {
            freeFn(msg);
          }
        });
    _b.log_set_callback(_handle, callable.nativeFunction, nullptr);
    _callable = callable;
    _controller = controller;
    return controller.stream;
  }
}
