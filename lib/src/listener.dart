import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'library.dart';
import 'pos.dart';

/// Singleton 3D listener — the reference point used by the engine to pan
/// sounds, attenuate by distance, and compute doppler shifts.
///
/// Update [position] every frame so velocity and doppler stay coherent.
/// Access through [Listener.instance].
class Listener {
  final YseBindings _b;
  final Pointer<YseListener> _handle;

  Listener._(this._b, this._handle);

  /// Borrowed singleton accessor.
  static Listener get instance {
    final b = bindings;
    return Listener._(b, b.listener_get());
  }

  /// Current listener position in world coordinates.
  Pos get position => Pos.fromNative(_b.listener_get_pos(_handle));

  /// Set the listener position.
  ///
  /// Call once per frame to keep velocity-derived effects (doppler, motion
  /// panning) accurate.
  set position(Pos value) => using((arena) {
    _b.listener_set_pos(_handle, value.toNative(arena));
  });

  /// Velocity derived from successive [position] updates. Cannot be set directly.
  Pos get velocity => Pos.fromNative(_b.listener_get_vel(_handle));

  /// Forward-facing unit vector of the listener.
  Pos get forward => Pos.fromNative(_b.listener_get_forward(_handle));

  /// Upward unit vector of the listener.
  Pos get upward => Pos.fromNative(_b.listener_get_upward(_handle));

  /// Set the listener orientation.
  ///
  /// [up] defaults to (0, 1, 0) — rotation confined to a horizontal plane.
  void orient(Pos forward, {Pos up = const Pos(0, 1, 0)}) => using((arena) {
    _b.listener_set_orient(
      _handle,
      forward.toNative(arena),
      up.toNative(arena),
    );
  });
}
