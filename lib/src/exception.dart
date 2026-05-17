import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';

/// Exception type for every failure surfaced from the YSE engine.
///
/// Wraps a [YseStatus] code (when the underlying call returned one) and a
/// human-readable message — typically the engine's thread-local last-error
/// string at the time of failure.
class YseException implements Exception {
  /// Human-readable description of the failure.
  final String message;

  /// The raw status code, if the originating C call returns one.
  final YseStatus? status;

  /// Constructs an exception with a [message] and optional [status].
  YseException(this.message, [this.status]);

  @override
  String toString() => status == null
      ? 'YseException: $message'
      : 'YseException(${status!.name}): $message';
}

/// Throws a [YseException] if [status] is anything other than [YseStatus.YSE_OK].
///
/// Pulls the human-readable detail from the engine's thread-local last-error
/// slot via `yse_last_error()`, so callers see exactly what the engine
/// reported at the failure site.
void checkStatus(YseStatus status, YseBindings b) {
  if (status == YseStatus.YSE_OK) return;
  final cstr = b.last_error();
  final detail = cstr.address == 0 ? '<no detail>' : cstr.cast<Utf8>().toDartString();
  b.clear_last_error();
  throw YseException(detail, status);
}
