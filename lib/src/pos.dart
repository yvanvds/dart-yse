import 'dart:ffi';

import 'bindings/yse_bindings.g.dart';

/// 3D position vector used everywhere YSE needs spatial coordinates —
/// sound positions, the listener position, reverb-zone centres.
///
/// Immutable value type. Construct fresh instances instead of mutating.
final class Pos {
  /// Cartesian X component.
  final double x;

  /// Cartesian Y component.
  final double y;

  /// Cartesian Z component.
  final double z;

  /// Construct a position with explicit components.
  const Pos(this.x, this.y, this.z);

  /// Construct the zero vector.
  const Pos.zero() : x = 0, y = 0, z = 0;

  /// Convert a freshly-returned native [yse_pos_t] struct to a Dart [Pos].
  factory Pos.fromNative(yse_pos_t native) => Pos(native.x, native.y, native.z);

  @override
  String toString() => 'Pos($x, $y, $z)';

  @override
  bool operator ==(Object other) =>
      other is Pos && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Helpers for crossing a [Pos] into / out of native memory.
extension PosNative on Pos {
  /// Allocate a `yse_pos_t` in [arena] and populate it from this [Pos].
  ///
  /// The pointer is valid until [arena] is released.
  Pointer<yse_pos_t> toNative(Allocator arena) {
    final ptr = arena<yse_pos_t>();
    ptr.ref
      ..x = x
      ..y = y
      ..z = z;
    return ptr;
  }
}
