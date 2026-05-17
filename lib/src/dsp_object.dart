import 'dart:ffi';

import 'bindings/yse_bindings.g.dart';
import 'enums.dart';
import 'exception.dart';
import 'library.dart';

/// A chainable DSP effect module — wraps `YSE::DSP::dspObject` and its
/// concrete subclasses (filters, delays, modulators).
///
/// Construct via the named factory matching the effect you need
/// (e.g. [DspObject.lowpass], [DspObject.sweep], [DspObject.granulator]),
/// then call the matching `set*` methods to configure parameters.
///
/// Inherited control surface ([bypass], [impact], [lfoType],
/// [lfoFrequency], [link]) is available on every instance.
///
/// Attach to a [Sound] with [Sound.setDsp]. The Sound holds a borrowed
/// reference — the effect must outlive the sound (and per the YSE
/// lifetime contract, also outlive the slow-pool delete tick that
/// follows the sound's destruction).
///
/// Subclass-specific setters are unsafe to call on the wrong subclass:
/// just like the C++ API, the underlying type is `static_cast`-ed
/// without an RTTI check.
class DspObject implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.dsp_object_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseDspObject> _handle;
  final _DspKind _kind;

  DspObject._(this._b, this._handle, this._kind) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  static DspObject _wrap(Pointer<YseDspObject> handle, _DspKind kind) {
    if (handle.address == 0) {
      throw YseException('yse_dsp_*_create returned null');
    }
    return DspObject._(bindings, handle, kind);
  }

  // ─── factories ─────────────────────────────────────────────────────────

  /// Low-pass filter.
  factory DspObject.lowpass() =>
      _wrap(bindings.dsp_lowpass_create(), _DspKind.lowpass);

  /// High-pass filter.
  factory DspObject.highpass() =>
      _wrap(bindings.dsp_highpass_create(), _DspKind.highpass);

  /// Resonant band-pass filter.
  factory DspObject.bandpass() =>
      _wrap(bindings.dsp_bandpass_create(), _DspKind.bandpass);

  /// Auto-wah / LFO-modulated resonant filter.
  factory DspObject.sweep({SweepShape shape = SweepShape.saw}) =>
      _wrap(bindings.dsp_sweep_create(shape.native), _DspKind.sweep);

  /// Three-tap delay line.
  factory DspObject.basicDelay() =>
      _wrap(bindings.dsp_basic_delay_create(), _DspKind.basicDelay);

  /// Three-tap delay with a low-pass filter in front (tape-style).
  factory DspObject.lowpassDelay() =>
      _wrap(bindings.dsp_lowpass_delay_create(), _DspKind.lowpassDelay);

  /// Three-tap delay with a high-pass filter in front.
  factory DspObject.highpassDelay() =>
      _wrap(bindings.dsp_highpass_delay_create(), _DspKind.highpassDelay);

  /// Four-stage all-pass cascade modulated by a triangle LFO.
  factory DspObject.phaser() =>
      _wrap(bindings.dsp_phaser_create(), _DspKind.phaser);

  /// Ring modulator — multiplies input by an internal sine carrier.
  factory DspObject.ringModulator() =>
      _wrap(bindings.dsp_ring_modulator_create(), _DspKind.ringModulator);

  /// FM difference-tone synthesis (clipper + sine carrier).
  factory DspObject.difference() =>
      _wrap(bindings.dsp_difference_create(), _DspKind.difference);

  /// Granular synthesis — pool of recent input, spawn short grains.
  ///
  /// [poolSize] is the size of the circular input buffer in samples
  /// (default ~5s at 44.1kHz). [maxGrains] is the maximum number of
  /// grains alive simultaneously.
  factory DspObject.granulator({
    int poolSize = 44100 * 5,
    int maxGrains = 16,
  }) =>
      _wrap(
        bindings.dsp_granulator_create(poolSize, maxGrains),
        _DspKind.granulator,
      );

  /// Internal: native handle (used by `Sound.setDsp`).
  Pointer<YseDspObject> get handle => _handle;

  // ─── inherited dspObject control surface ───────────────────────────────

  /// Bypass this effect. Bypassed effects still run but pass input through
  /// unchanged.
  bool get bypass => _b.dsp_object_get_bypass(_handle) != 0;
  set bypass(bool value) => _b.dsp_object_set_bypass(_handle, value ? 1 : 0);

  /// Wet/dry mix in `[0.0, 1.0]`. 0 is fully dry, 1 is fully processed.
  double get impact => _b.dsp_object_get_impact(_handle);
  set impact(double value) => _b.dsp_object_set_impact(_handle, value);

  /// Built-in modulation LFO shape. [LfoType.none] disables modulation.
  LfoType get lfoType => LfoType.values.firstWhere(
        (e) => e.native == _b.dsp_object_get_lfo_type(_handle),
        orElse: () => LfoType.none,
      );
  set lfoType(LfoType value) =>
      _b.dsp_object_set_lfo_type(_handle, value.native);

  /// Built-in modulation LFO frequency in Hz.
  double get lfoFrequency => _b.dsp_object_get_lfo_frequency(_handle);
  set lfoFrequency(double value) =>
      _b.dsp_object_set_lfo_frequency(_handle, value);

  /// Insert [next] after this object in the processing chain.
  void link(DspObject next) => _b.dsp_object_link(_handle, next._handle);

  // ─── filter modules ────────────────────────────────────────────────────

  /// Cutoff (lowpass/highpass) or centre (bandpass/sweep) frequency in Hz.
  double get frequency {
    switch (_kind) {
      case _DspKind.lowpass:       return _b.dsp_lowpass_get_frequency(_handle);
      case _DspKind.highpass:      return _b.dsp_highpass_get_frequency(_handle);
      case _DspKind.bandpass:      return _b.dsp_bandpass_get_frequency(_handle);
      case _DspKind.phaser:        return _b.dsp_phaser_get_frequency(_handle);
      case _DspKind.ringModulator: return _b.dsp_ring_modulator_get_frequency(_handle);
      case _DspKind.difference:    return _b.dsp_difference_get_frequency(_handle);
      case _DspKind.lowpassDelay:  return _b.dsp_lowpass_delay_get_frequency(_handle);
      case _DspKind.highpassDelay: return _b.dsp_highpass_delay_get_frequency(_handle);
      // sweep frequency is int 0..100 — see [sweepCentre].
      case _DspKind.sweep:
      case _DspKind.basicDelay:
      case _DspKind.granulator:
        throw YseException('frequency getter not supported for $_kind');
    }
  }

  set frequency(double value) {
    switch (_kind) {
      case _DspKind.lowpass:       _b.dsp_lowpass_set_frequency(_handle, value); break;
      case _DspKind.highpass:      _b.dsp_highpass_set_frequency(_handle, value); break;
      case _DspKind.bandpass:      _b.dsp_bandpass_set_frequency(_handle, value); break;
      case _DspKind.phaser:        _b.dsp_phaser_set_frequency(_handle, value); break;
      case _DspKind.ringModulator: _b.dsp_ring_modulator_set_frequency(_handle, value); break;
      case _DspKind.difference:    _b.dsp_difference_set_frequency(_handle, value); break;
      case _DspKind.lowpassDelay:  _b.dsp_lowpass_delay_set_frequency(_handle, value); break;
      case _DspKind.highpassDelay: _b.dsp_highpass_delay_set_frequency(_handle, value); break;
      case _DspKind.sweep:
      case _DspKind.basicDelay:
      case _DspKind.granulator:
        throw YseException('frequency setter not supported for $_kind');
    }
  }

  /// Bandpass-only: filter resonance (Q factor).
  double get q => _b.dsp_bandpass_get_q(_handle);
  set q(double value) => _b.dsp_bandpass_set_q(_handle, value);

  // ─── sweep ────────────────────────────────────────────────────────────

  /// Sweep-only: LFO speed in Hz.
  double get sweepSpeed => _b.dsp_sweep_get_speed(_handle);
  set sweepSpeed(double value) => _b.dsp_sweep_set_speed(_handle, value);

  /// Sweep-only: depth as 0..100.
  int get sweepDepth => _b.dsp_sweep_get_depth(_handle);
  set sweepDepth(int value) => _b.dsp_sweep_set_depth(_handle, value);

  /// Sweep-only: centre frequency as 0..100.
  int get sweepCentre => _b.dsp_sweep_get_frequency(_handle);
  set sweepCentre(int value) => _b.dsp_sweep_set_frequency(_handle, value);

  // ─── delays ───────────────────────────────────────────────────────────

  /// basicDelay / lowpassDelay / highpassDelay: configure one of three taps.
  void setDelayTap(DelayTap tap, {required double timeMs, required double gain}) =>
      _b.dsp_basic_delay_set_tap(_handle, tap.native, timeMs, gain);

  /// Current delay time of [tap] in milliseconds.
  double delayTime(DelayTap tap) =>
      _b.dsp_basic_delay_get_time(_handle, tap.native);

  /// Current gain of [tap].
  double delayGain(DelayTap tap) =>
      _b.dsp_basic_delay_get_gain(_handle, tap.native);

  // ─── phaser ───────────────────────────────────────────────────────────

  /// Phaser-only: sweep range coefficient.
  double get phaserRange => _b.dsp_phaser_get_range(_handle);
  set phaserRange(double value) => _b.dsp_phaser_set_range(_handle, value);

  // ─── difference ──────────────────────────────────────────────────────

  /// Difference-only: carrier amplitude.
  double get differenceAmplitude => _b.dsp_difference_get_amplitude(_handle);
  set differenceAmplitude(double value) =>
      _b.dsp_difference_set_amplitude(_handle, value);

  // ─── granulator ───────────────────────────────────────────────────────

  /// Granulator: spawn rate in grains per second.
  int get grainFrequency => _b.dsp_granulator_get_grain_frequency(_handle);
  set grainFrequency(int value) =>
      _b.dsp_granulator_set_grain_frequency(_handle, value);

  /// Granulator: grain length in samples. [random] adds variation
  /// around [samples].
  void setGrainLength({required int samples, int random = 0}) =>
      _b.dsp_granulator_set_grain_length(_handle, samples, random);

  /// Granulator: pitch shift (1.0 = unchanged, 2.0 = octave up).
  /// [random] adds variation.
  void setGrainTranspose({required double pitch, double random = 0}) =>
      _b.dsp_granulator_set_grain_transpose(_handle, pitch, random);

  /// Granulator: output gain.
  double get grainGain => _b.dsp_granulator_get_gain(_handle);
  set grainGain(double value) => _b.dsp_granulator_set_gain(_handle, value);

  /// Destroy the underlying native effect and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.dsp_object_destroy(_handle);
    _handle = nullptr;
  }
}

enum _DspKind {
  lowpass, highpass, bandpass, sweep,
  basicDelay, lowpassDelay, highpassDelay,
  phaser, ringModulator, difference, granulator,
}
