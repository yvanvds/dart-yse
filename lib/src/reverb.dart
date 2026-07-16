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
  void setReflection(
    int reflection, {
    required int time,
    required double gain,
  }) => _b.reverb_set_reflection(_handle, reflection, time, gain);

  /// Delay time of the early reflection at [reflection] (0..3).
  int getReflectionTime(int reflection) =>
      _b.reverb_get_reflection_time(_handle, reflection);

  /// Gain of the early reflection at [reflection] (0..3).
  double getReflectionGain(int reflection) =>
      _b.reverb_get_reflection_gain(_handle, reflection);

  /// Apply a named preset.
  set preset(ReverbPreset value) => _b.reverb_set_preset(_handle, value.native);

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

/// A complete reverb parameter set — the full payload behind a named
/// [ReverbPreset], and the custom endpoint type for a [MorphingReverb] slot.
///
/// Immutable value type. Mirrors the C `YseReverbPresetValues` (itself a
/// plain-data mirror of `YSE::REVERB::presetValues`). [earlyTimes] and
/// [earlyGains] each describe the four early reflections and are always
/// length 4.
final class ReverbPresetValues {
  /// Simulated room size, `[0, 1]`. Larger values give longer tails.
  final double roomSize;

  /// High-frequency damping, `[0, 1]`.
  final double damping;

  /// Unprocessed (dry) signal level, `[0, 1]`.
  final double dry;

  /// Reverberated (wet) signal level, `[0, 1]`.
  final double wet;

  /// Tail modulation rate in Hz (`0` = off).
  final double modulationFrequency;

  /// Tail modulation depth (`0` = off).
  final double modulationWidth;

  /// The four early-reflection delay times, in samples (`[0, 2999]`).
  final List<double> earlyTimes;

  /// The four early-reflection gains, `[0, 1]`.
  final List<double> earlyGains;

  /// Construct a parameter set. [earlyTimes] and [earlyGains], when supplied,
  /// must each have exactly four elements; both default to all-zero.
  ReverbPresetValues({
    this.roomSize = 0,
    this.damping = 0,
    this.dry = 0,
    this.wet = 0,
    this.modulationFrequency = 0,
    this.modulationWidth = 0,
    List<double>? earlyTimes,
    List<double>? earlyGains,
  }) : earlyTimes = List<double>.unmodifiable(
         earlyTimes ?? const [0.0, 0.0, 0.0, 0.0],
       ),
       earlyGains = List<double>.unmodifiable(
         earlyGains ?? const [0.0, 0.0, 0.0, 0.0],
       ) {
    if (this.earlyTimes.length != 4 || this.earlyGains.length != 4) {
      throw ArgumentError(
        'earlyTimes and earlyGains must each contain exactly 4 elements',
      );
    }
  }

  /// Read a native `YseReverbPresetValues` struct into a Dart value.
  factory ReverbPresetValues.fromNative(YseReverbPresetValues native) =>
      ReverbPresetValues(
        roomSize: native.roomsize,
        damping: native.damp,
        dry: native.dry,
        wet: native.wet,
        modulationFrequency: native.mod_frequency,
        modulationWidth: native.mod_width,
        earlyTimes: [for (var i = 0; i < 4; i++) native.early_time[i]],
        earlyGains: [for (var i = 0; i < 4; i++) native.early_gain[i]],
      );

  @override
  bool operator ==(Object other) =>
      other is ReverbPresetValues &&
      other.roomSize == roomSize &&
      other.damping == damping &&
      other.dry == dry &&
      other.wet == wet &&
      other.modulationFrequency == modulationFrequency &&
      other.modulationWidth == modulationWidth &&
      _listEq(other.earlyTimes, earlyTimes) &&
      _listEq(other.earlyGains, earlyGains);

  @override
  int get hashCode => Object.hash(
    roomSize,
    damping,
    dry,
    wet,
    modulationFrequency,
    modulationWidth,
    Object.hashAll(earlyTimes),
    Object.hashAll(earlyGains),
  );

  @override
  String toString() =>
      'ReverbPresetValues(roomSize: $roomSize, damping: $damping, '
      'dry: $dry, wet: $wet, modulationFrequency: $modulationFrequency, '
      'modulationWidth: $modulationWidth, earlyTimes: $earlyTimes, '
      'earlyGains: $earlyGains)';

  static bool _listEq(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Helpers for crossing a [ReverbPresetValues] into native memory.
extension ReverbPresetValuesNative on ReverbPresetValues {
  /// Allocate a `YseReverbPresetValues` in [arena] and populate it from this
  /// value. The pointer is valid until [arena] is released.
  Pointer<YseReverbPresetValues> toNative(Allocator arena) {
    final ptr = arena<YseReverbPresetValues>();
    ptr.ref
      ..roomsize = roomSize
      ..damp = damping
      ..dry = dry
      ..wet = wet
      ..mod_frequency = modulationFrequency
      ..mod_width = modulationWidth;
    for (var i = 0; i < 4; i++) {
      ptr.ref.early_time[i] = earlyTimes[i];
      ptr.ref.early_gain[i] = earlyGains[i];
    }
    return ptr;
  }
}
