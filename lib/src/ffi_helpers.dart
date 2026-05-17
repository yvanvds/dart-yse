import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Fetches a C string via the snprintf-style `(buf, cap) → required_length`
/// pattern that the `yse_*` API uses for all `std::string` returns.
///
/// Two-call dance: the first call passes `cap == 0` to learn the required
/// size; the second allocates a buffer that big and refills it.
///
/// The buffer is allocated and released within an [Arena] under the hood,
/// so callers never see raw pointers.
String fetchString(int Function(Pointer<Char> buf, int cap) fetch) {
  return using((arena) {
    final length = fetch(nullptr, 0);
    if (length == 0) return '';
    final buf = arena<Char>(length + 1);
    fetch(buf, length + 1);
    return buf.cast<Utf8>().toDartString();
  });
}
