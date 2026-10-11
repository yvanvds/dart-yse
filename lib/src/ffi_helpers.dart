import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// The Dart wrappers a native owner borrows, kept reachable until after the
/// owner's native finalizer has run (#80, #84).
///
/// The engine stores raw pointers to objects it borrows (a sound's source and
/// effect chain, a clip's synths, ...) but never owns them, and each of those
/// wrappers carries its own `NativeFinalizer`. An ordinary field on the owner
/// keeps them alive while the owner is reachable. It does not help when the
/// owner and a borrowed object become unreachable in the same collection: the
/// order of their native finalizers is unspecified, so the borrowed object
/// could be destroyed before the owner that still reads it.
///
/// A [Borrows] is the token of a Dart [Finalizer] attached to its owner. A
/// finalizer holds its token strongly until the callback has run, and the VM
/// delivers that callback through the event loop, strictly after the
/// collection that ran the owner's native finalizer. So everything held here
/// is destroyed after the owner, never before it.
///
/// The token must not refer back to its owner, or the owner can never be
/// collected: never put the owner (or an object that holds the owner) here.
final class Borrows {
  /// Hold borrowed objects for [owner] until [owner] is collected or
  /// [release] is called.
  Borrows(Object owner) {
    _keepAlive.attach(owner, this, detach: this);
  }

  static final _keepAlive = Finalizer<Borrows>((_) {});

  final _slots = <Object, Object>{};
  final _members = <Object>{};

  /// The object held in [slot], or `null`.
  Object? operator [](Object slot) => _slots[slot];

  /// Hold [value] in [slot], replacing what was there; `null` clears it.
  void operator []=(Object slot, Object? value) {
    if (value == null) {
      _slots.remove(slot);
    } else {
      _slots[slot] = value;
    }
  }

  /// Hold [value] as one member of an unordered set (a clip's synths, ...).
  void add(Object value) => _members.add(value);

  /// Stop holding the set member [value].
  void remove(Object value) => _members.remove(value);

  /// Drop everything and detach from the owner. Call from the owner's
  /// `dispose()`, after the native destroy.
  void release() {
    _keepAlive.detach(this);
    _slots.clear();
    _members.clear();
  }
}

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
