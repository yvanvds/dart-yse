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
  static _LogBridge? _bridge;

  /// Broadcast stream of log messages from the engine.
  ///
  /// Subscribing replaces the default file sink with an in-process
  /// callback that forwards every message into the stream. The first
  /// subscription installs the bridge; subsequent subscribers share
  /// the same stream.
  ///
  /// Cancel the last subscription to release the callback. Callbacks
  /// run on whichever thread emitted the log message —
  /// `NativeCallable.listener` posts them back to this isolate via a
  /// port, so Dart code only ever sees them serialised in the isolate's
  /// event queue. Messages still queued when the last subscription is
  /// cancelled are not delivered, but their native strings are still
  /// released.
  Stream<String> get messages {
    if (_controller != null) return _controller!.stream;
    final controller = StreamController<String>.broadcast(
      onCancel: () {
        if (_controller?.hasListener ?? false) return;
        // Last listener gone — uninstall the bridge. Once
        // log_set_callback returns no engine thread is still inside the
        // callback (the engine holds the log sink's mutex across it), so
        // every call it will ever make is queued ahead of the drain
        // marker that retire() posts.
        _b.log_set_callback(_handle, nullptr, nullptr);
        _bridge?.retire();
        _bridge = null;
        _controller?.close();
        _controller = null;
      },
    );
    final bridge = _LogBridge(controller.add);
    _b.log_set_callback(_handle, bridge.nativeFunction, nullptr);
    _bridge = bridge;
    _controller = controller;
    return controller.stream;
  }
}

/// How many log messages the [Log.messages] bridge has released with
/// `yse_log_free_message` in this isolate, delivered or dropped.
/// Internal (not exported): lets the tests prove no native block leaks.
int get logMessagesFreed => _LogBridge._freed;

/// The `NativeCallable.listener` behind one installation of the log
/// callback.
///
/// The engine hands over a malloc'd copy of each line; the listener
/// decodes it and frees it with `yse_log_free_message`, exactly once.
///
/// Closing a listener drops the calls still queued on its port, which
/// would leak their strings. So [retire] does not close it: it detaches
/// the sink and posts a drain marker (a NULL message, which the engine
/// never sends) through the same port. Port messages arrive in order, so
/// when the marker arrives every earlier call has been freed, and only
/// then is the callable closed. Same scheme as the patcher send bridge
/// (#62).
class _LogBridge {
  static int _freed = 0;

  void Function(String)? _sink;
  late final NativeCallable<YseLogCallbackFunction> _callable;

  _LogBridge(this._sink) {
    _callable = NativeCallable<YseLogCallbackFunction>.listener(_onCall);
  }

  Pointer<NativeFunction<YseLogCallbackFunction>> get nativeFunction =>
      _callable.nativeFunction;

  void _onCall(Pointer<Char> msg, Pointer<Void> _) {
    if (msg.address == 0) {
      _callable.close(); // drain marker: nothing is queued behind it
      return;
    }
    final String text;
    try {
      text = msg.cast<Utf8>().toDartString();
    } finally {
      bindings.log_free_message(msg);
      _freed++;
    }
    _sink?.call(text);
  }

  /// Stop delivering and close the callable once its queue has drained.
  /// Call only after the engine can no longer invoke it.
  void retire() {
    _sink = null;
    _callable.nativeFunction.asFunction<DartYseLogCallbackFunction>()(
      nullptr,
      nullptr,
    );
  }
}
