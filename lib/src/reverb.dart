import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'enums.dart';
import 'library.dart';
import 'pos.dart';

/// A positioned reverb zone.
///
/// Each reverb holds a set of parameters and a position in the scene. At
/// the end of every DSP frame the engine blends every reverb whose rolloff
/// radius overlaps the listener into the single shared reverb processor —
/// so dropping multiple zones around the world (cave, hall, bathroom)
/// lets the listener transition smoothly between them.
///
/// A fallback "global" reverb is also available via [System.globalReverb];
/// it's mixed in wherever no positioned zone reaches.
class Reverb implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.reverb_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseReverb> _handle;
  final bool _owned;

  Reverb._(this._b, this._handle, this._owned) {
    if (_owned) {
      _finalizer.attach(this, _handle.cast(), detach: this);
    }
  }

  /// Internal: wrap a borrowed pointer (the global reverb singleton).
  factory Reverb.borrowed(Pointer<YseReverb> handle) =>
      Reverb._(bindings, handle, false);

  /// Construct a new positioned reverb zone.
  ///
  /// The native [reverb::create] runs implicitly; the handle is ready to
  /// configure immediately.
  factory Reverb() {
    final b = bindings;
    final h = b.reverb_create();
    if (h.address == 0) {
      throw StateError('yse_reverb_create returned null');
    }
    return Reverb._(b, h, true);
  }

  /// Whether this reverb has a live native implementation.
  bool get isValid => _b.reverb_is_valid(_handle) != 0;

  /// Position of the zone in the scene.
  Pos get position => Pos.fromNative(_b.reverb_get_position(_handle));
  set position(Pos value) => using((arena) {
        _b.reverb_set_position(_handle, value.toNative(arena));
      });

  /// Radius within which the reverb is at full strength.
  double get size => _b.reverb_get_size(_handle);
  set size(double value) => _b.reverb_set_size(_handle, value);

  /// Distance over which the reverb fades to zero beyond [size].
  double get rollOff => _b.reverb_get_roll_off(_handle);
  set rollOff(double value) => _b.reverb_set_roll_off(_handle, value);

  /// Whether this reverb zone contributes to the listener mix.
  bool get active => _b.reverb_get_active(_handle) != 0;
  set active(bool value) => _b.reverb_set_active(_handle, value ? 1 : 0);

  /// Simulated room size. Larger values give longer tails.
  double get roomSize => _b.reverb_get_room_size(_handle);
  set roomSize(double value) => _b.reverb_set_room_size(_handle, value);

  /// High-frequency damping. Higher values darken the tail faster
  /// (soft-material simulation).
  double get damping => _b.reverb_get_damping(_handle);
  set damping(double value) => _b.reverb_set_damping(_handle, value);

  /// Set the dry/wet balance in one call.
  ///
  /// [dry] is the unprocessed signal passthrough, [wet] is the
  /// reverberated mix. Sums above 1.0 can clip.
  void setDryWetBalance({required double dry, required double wet}) =>
      _b.reverb_set_dry_wet_balance(_handle, dry, wet);

  /// Current dry-signal level.
  double get dry => _b.reverb_get_dry(_handle);

  /// Current wet-signal level.
  double get wet => _b.reverb_get_wet(_handle);

  /// Add a slow LFO to the tail to break up metallic resonances.
  void setModulation({required double frequency, required double width}) =>
      _b.reverb_set_modulation(_handle, frequency, width);

  /// Current modulation frequency in Hz.
  double get modulationFrequency => _b.reverb_get_modulation_frequency(_handle);

  /// Current modulation width.
  double get modulationWidth => _b.reverb_get_modulation_width(_handle);

  /// Configure one of the four early reflections (index 0..3).
  void setReflection(int reflection, {required int time, required double gain}) =>
      _b.reverb_set_reflection(_handle, reflection, time, gain);

  /// Delay time of the early reflection at [reflection] (0..3).
  int getReflectionTime(int reflection) =>
      _b.reverb_get_reflection_time(_handle, reflection);

  /// Gain of the early reflection at [reflection] (0..3).
  double getReflectionGain(int reflection) =>
      _b.reverb_get_reflection_gain(_handle, reflection);

  /// Apply a named preset.
  set preset(ReverbPreset value) =>
      _b.reverb_set_preset(_handle, value.native);

  /// Destroy the underlying native reverb and detach the finalizer.
  ///
  /// No-op for the borrowed global reverb. Idempotent.
  void dispose() {
    if (!_owned || _handle.address == 0) return;
    _finalizer.detach(this);
    _b.reverb_destroy(_handle);
    _handle = nullptr;
  }
}
