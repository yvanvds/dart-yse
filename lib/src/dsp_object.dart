import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'enums.dart';
import 'exception.dart';
import 'ffi_helpers.dart';
import 'library.dart';
import 'patcher.dart';
import 'reverb.dart';

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
/// Attach to a [Sound] with [Sound.setDsp]. The engine holds a borrowed
/// reference — the effect must outlive the sound (and per the YSE
/// lifetime contract, also outlive the slow-pool delete tick that
/// follows the sound's destruction). The Dart side holds the attached head
/// and every object [link]ed after it, so garbage collection never frees a
/// chain under a live sound or channel.
///
/// Kind-specific accessors (e.g. [q], [sweepSpeed], [setDelayTap],
/// [grainGain]) throw [YseException] when called on the wrong kind of
/// effect. The underlying C entry points `static_cast` the handle without an
/// RTTI check, so the wrapper checks the kind before calling into native
/// code. Mix-grade modules ([Compressor], [ParametricEq], ...) are typed
/// subclasses, so their own accessors exist only on the right type.
class DspObject implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.dsp_object_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseDspObject> _handle;
  final _DspKind _kind;

  /// What the engine borrows through this object: the [Patcher] of a
  /// [DspObject.patcherInsert] under [_source], and the object [link]ed after
  /// this one under [_next]. Held until after this object's native destroy,
  /// so garbage collection never frees a live insert's patcher or any link
  /// of a chain whose head is held (#80, #84).
  late final Borrows _borrows = Borrows(this);
  static const _source = #source;
  static const _next = #next;

  /// The object the engine links *before* this one, mirrored from the
  /// engine's own `previous` pointer so [dispose] can splice the Dart side
  /// the way the native destructor splices the chain. Weak: a successor must
  /// never keep its predecessor alive.
  WeakReference<DspObject>? _prev;

  DspObject? get _heldNext => _borrows[_next] as DspObject?;

  /// Native address → live wrapper, so [next] can hand back the *existing*
  /// Dart object for a linked handle instead of minting a second owning
  /// wrapper (which would double-free through the finalizer). Weak, so the
  /// registry never keeps an effect alive on its own.
  static final _live = <int, WeakReference<DspObject>>{};

  /// Drops a collected wrapper's registry entry — unless its address has
  /// since been reused by a newer object.
  static final _registryCleaner = Finalizer<int>((address) {
    if (_live[address]?.target == null) _live.remove(address);
  });

  DspObject._(this._b, this._handle, this._kind) {
    _finalizer.attach(this, _handle.cast(), detach: this);
    _live[_handle.address] = WeakReference(this);
    _registryCleaner.attach(this, _handle.address, detach: this);
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
  /// (default 5 s at 48 kHz, the libYSE 3 default session rate; size it
  /// from `System.sessionSampleRate` when the session runs at another
  /// rate). [maxGrains] is the maximum number of grains alive
  /// simultaneously.
  factory DspObject.granulator({
    int poolSize = 48000 * 5,
    int maxGrains = 16,
  }) => _wrap(
    bindings.dsp_granulator_create(poolSize, maxGrains),
    _DspKind.granulator,
  );

  /// Wrap a [Patcher] graph as a chainable insert effect (upstream #370).
  ///
  /// The insert feeds the host buffer to the graph's `~adc` objects and copies
  /// the summed `~dac` output back over it, so [patcher] should contain at
  /// least one of each. The insert *borrows* [patcher] — it never owns or
  /// destroys it, so [patcher] must outlive this object. The insert holds a
  /// Dart reference to [patcher], so garbage collection never frees it under
  /// a live insert; don't `.dispose()` it first. Drive it with the inherited
  /// control surface ([bypass], [impact], ...).
  factory DspObject.patcherInsert(Patcher patcher) => _wrap(
    bindings.dsp_patcher_insert_create(patcher.handle),
    _DspKind.patcherInsert,
  ).._borrows[_source] = patcher;

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
  ///
  /// Passing `null` detaches this object's forward edge, terminating the
  /// chain at this object (tail termination). This is what lets a chain be
  /// re-linked into a new order without a former non-tail element keeping a
  /// stale `next` that closes a cycle when the engine walks it (upstream
  /// yvanvds/yse-soundengine#391).
  ///
  /// The engine only borrows linked objects. Each object holds a Dart
  /// reference to the one linked after it (following the engine's own
  /// insert-between, unlink and splice-on-dispose rewiring), so a chain whose
  /// head is held — by a [Sound], a `Channel` or your own variable — keeps
  /// every link alive (#84).
  void link(DspObject? next) {
    if (next == null) {
      unlink();
      return;
    }
    _b.dsp_object_link(_handle, next._handle);
    // Mirror dspObject::link: `next` goes between this and the old successor.
    final after = _heldNext;
    next._borrows[_next] = after;
    next._prev = WeakReference(this);
    after?._prev = WeakReference(next);
    _borrows[_next] = next;
  }

  /// Detach this object's forward edge, terminating the chain here.
  ///
  /// Convenience for `link(null)` — see [link]. The detached successor is no
  /// longer held by this object.
  void unlink() {
    _b.dsp_object_link(_handle, nullptr);
    // Mirror dspObject::unlink: drop the edge and the successor's back-pointer.
    final after = _heldNext;
    if (after != null) {
      after._prev = null;
      _borrows[_next] = null;
    }
  }

  /// The object linked after this one in its processing chain, or `null` at
  /// the end of the chain — so a chain can be walked:
  ///
  /// ```dart
  /// for (DspObject? fx = head; fx != null; fx = fx.next) { ... }
  /// ```
  ///
  /// The result is the *same* Dart object that was passed to [link]
  /// (`identical(a.next, b)` after `a.link(b)`), with its subclass intact —
  /// never a new wrapper. It is read from the engine, so it reflects the
  /// engine's own relinking: [link] inserts *between* this object and its
  /// old successor, and disposing a chained object splices it out.
  ///
  /// Throws [StateError] if the engine reports a successor that no live
  /// [DspObject] wraps. Each object holds its linked successor, so this only
  /// happens for a chain rewired outside this API.
  DspObject? get next {
    final p = _b.dsp_object_get_next(_handle);
    if (p.address == 0) return null;
    final wrapper = _live[p.address]?.target;
    if (wrapper == null || wrapper._handle.address != p.address) {
      throw StateError(
        'yse_dsp_object_get_next returned a handle with no live DspObject',
      );
    }
    return wrapper;
  }

  // ─── filter modules ────────────────────────────────────────────────────

  /// Cutoff (lowpass/highpass) or centre (bandpass/sweep) frequency in Hz.
  double get frequency {
    switch (_kind) {
      case _DspKind.lowpass:
        return _b.dsp_lowpass_get_frequency(_handle);
      case _DspKind.highpass:
        return _b.dsp_highpass_get_frequency(_handle);
      case _DspKind.bandpass:
        return _b.dsp_bandpass_get_frequency(_handle);
      case _DspKind.phaser:
        return _b.dsp_phaser_get_frequency(_handle);
      case _DspKind.ringModulator:
        return _b.dsp_ring_modulator_get_frequency(_handle);
      case _DspKind.difference:
        return _b.dsp_difference_get_frequency(_handle);
      case _DspKind.lowpassDelay:
        return _b.dsp_lowpass_delay_get_frequency(_handle);
      case _DspKind.highpassDelay:
        return _b.dsp_highpass_delay_get_frequency(_handle);
      // sweep frequency is int 0..100 — see [sweepCentre].
      case _DspKind.sweep:
      case _DspKind.basicDelay:
      case _DspKind.granulator:
      // Mix-grade modules expose their own typed frequency accessors
      // ([ParametricEq.setFrequency] is per-band; the rest have none).
      case _DspKind.compressor:
      case _DspKind.eq:
      case _DspKind.chorus:
      case _DspKind.plateReverb:
      case _DspKind.feedbackDelay:
      case _DspKind.morphingReverb:
      case _DspKind.underwater:
      case _DspKind.patcherInsert:
        throw YseException('frequency getter not supported for $_kind');
    }
  }

  set frequency(double value) {
    switch (_kind) {
      case _DspKind.lowpass:
        _b.dsp_lowpass_set_frequency(_handle, value);
        break;
      case _DspKind.highpass:
        _b.dsp_highpass_set_frequency(_handle, value);
        break;
      case _DspKind.bandpass:
        _b.dsp_bandpass_set_frequency(_handle, value);
        break;
      case _DspKind.phaser:
        _b.dsp_phaser_set_frequency(_handle, value);
        break;
      case _DspKind.ringModulator:
        _b.dsp_ring_modulator_set_frequency(_handle, value);
        break;
      case _DspKind.difference:
        _b.dsp_difference_set_frequency(_handle, value);
        break;
      case _DspKind.lowpassDelay:
        _b.dsp_lowpass_delay_set_frequency(_handle, value);
        break;
      case _DspKind.highpassDelay:
        _b.dsp_highpass_delay_set_frequency(_handle, value);
        break;
      case _DspKind.sweep:
      case _DspKind.basicDelay:
      case _DspKind.granulator:
      case _DspKind.compressor:
      case _DspKind.eq:
      case _DspKind.chorus:
      case _DspKind.plateReverb:
      case _DspKind.feedbackDelay:
      case _DspKind.morphingReverb:
      case _DspKind.underwater:
      case _DspKind.patcherInsert:
        throw YseException('frequency setter not supported for $_kind');
    }
  }

  /// Kind guard for the kind-specific accessors below.
  ///
  /// The matching `yse_dsp_<kind>_*` C entry points `static_cast` the shared
  /// handle to the concrete C++ module without an RTTI check, so calling one
  /// on the wrong kind is undefined behaviour (a mistyped read or write), not
  /// an error status. This throws *before* any native call instead.
  Pointer<YseDspObject> _as(Set<_DspKind> kinds, String accessor) {
    if (!kinds.contains(_kind)) {
      throw YseException('$accessor not supported for $_kind');
    }
    return _handle;
  }

  static const _bandpass = {_DspKind.bandpass};
  static const _sweep = {_DspKind.sweep};
  static const _delays = {
    _DspKind.basicDelay,
    _DspKind.lowpassDelay,
    _DspKind.highpassDelay,
  };
  static const _phaser = {_DspKind.phaser};
  static const _difference = {_DspKind.difference};
  static const _granulator = {_DspKind.granulator};

  /// Bandpass-only: filter resonance (Q factor).
  ///
  /// Throws [YseException] on any other kind.
  double get q => _b.dsp_bandpass_get_q(_as(_bandpass, 'q'));
  set q(double value) => _b.dsp_bandpass_set_q(_as(_bandpass, 'q'), value);

  // ─── sweep ────────────────────────────────────────────────────────────

  /// Sweep-only: LFO speed in Hz. Throws [YseException] on any other kind.
  double get sweepSpeed => _b.dsp_sweep_get_speed(_as(_sweep, 'sweepSpeed'));
  set sweepSpeed(double value) =>
      _b.dsp_sweep_set_speed(_as(_sweep, 'sweepSpeed'), value);

  /// Sweep-only: depth as 0..100. Throws [YseException] on any other kind.
  int get sweepDepth => _b.dsp_sweep_get_depth(_as(_sweep, 'sweepDepth'));
  set sweepDepth(int value) =>
      _b.dsp_sweep_set_depth(_as(_sweep, 'sweepDepth'), value);

  /// Sweep-only: centre frequency as 0..100. Throws [YseException] on any
  /// other kind.
  int get sweepCentre => _b.dsp_sweep_get_frequency(_as(_sweep, 'sweepCentre'));
  set sweepCentre(int value) =>
      _b.dsp_sweep_set_frequency(_as(_sweep, 'sweepCentre'), value);

  // ─── delays ───────────────────────────────────────────────────────────

  /// basicDelay / lowpassDelay / highpassDelay: configure one of three taps.
  ///
  /// Throws [YseException] on any other kind.
  void setDelayTap(
    DelayTap tap, {
    required double timeMs,
    required double gain,
  }) => _b.dsp_basic_delay_set_tap(
    _as(_delays, 'setDelayTap'),
    tap.native,
    timeMs,
    gain,
  );

  /// Current delay time of [tap] in milliseconds (delay kinds only).
  double delayTime(DelayTap tap) =>
      _b.dsp_basic_delay_get_time(_as(_delays, 'delayTime'), tap.native);

  /// Current gain of [tap] (delay kinds only).
  double delayGain(DelayTap tap) =>
      _b.dsp_basic_delay_get_gain(_as(_delays, 'delayGain'), tap.native);

  // ─── phaser ───────────────────────────────────────────────────────────

  /// Phaser-only: sweep range coefficient. Throws [YseException] on any
  /// other kind.
  double get phaserRange =>
      _b.dsp_phaser_get_range(_as(_phaser, 'phaserRange'));
  set phaserRange(double value) =>
      _b.dsp_phaser_set_range(_as(_phaser, 'phaserRange'), value);

  // ─── difference ──────────────────────────────────────────────────────

  /// Difference-only: carrier amplitude. Throws [YseException] on any other
  /// kind.
  double get differenceAmplitude =>
      _b.dsp_difference_get_amplitude(_as(_difference, 'differenceAmplitude'));
  set differenceAmplitude(double value) => _b.dsp_difference_set_amplitude(
    _as(_difference, 'differenceAmplitude'),
    value,
  );

  // ─── granulator ───────────────────────────────────────────────────────
  //
  // Every granulator accessor throws [YseException] on any other kind.

  /// Granulator: spawn rate in grains per second.
  int get grainFrequency =>
      _b.dsp_granulator_get_grain_frequency(_as(_granulator, 'grainFrequency'));
  set grainFrequency(int value) => _b.dsp_granulator_set_grain_frequency(
    _as(_granulator, 'grainFrequency'),
    value,
  );

  /// Granulator: grain length in samples. [random] adds variation
  /// around [samples].
  void setGrainLength({required int samples, int random = 0}) =>
      _b.dsp_granulator_set_grain_length(
        _as(_granulator, 'setGrainLength'),
        samples,
        random,
      );

  /// Granulator: the base grain length in samples (the [samples] argument
  /// last passed to [setGrainLength], without the per-grain randomisation).
  int get grainLength =>
      _b.dsp_granulator_get_grain_length(_as(_granulator, 'grainLength'));

  /// Granulator: pitch shift (1.0 = unchanged, 2.0 = octave up).
  /// [random] adds variation.
  void setGrainTranspose({required double pitch, double random = 0}) =>
      _b.dsp_granulator_set_grain_transpose(
        _as(_granulator, 'setGrainTranspose'),
        pitch,
        random,
      );

  /// Granulator: the base pitch shift (the [pitch] argument last passed to
  /// [setGrainTranspose], without the per-grain randomisation).
  double get grainTranspose =>
      _b.dsp_granulator_get_grain_transpose(_as(_granulator, 'grainTranspose'));

  /// Granulator: output gain.
  double get grainGain =>
      _b.dsp_granulator_get_gain(_as(_granulator, 'grainGain'));
  set grainGain(double value) =>
      _b.dsp_granulator_set_gain(_as(_granulator, 'grainGain'), value);

  /// Destroy the underlying native effect and detach the finalizer.
  ///
  /// A chained object is spliced out: its predecessor is relinked to its
  /// successor, and from then on holds that successor instead.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _registryCleaner.detach(this);
    if (identical(_live[_handle.address]?.target, this)) {
      _live.remove(_handle.address);
    }
    _b.dsp_object_destroy(_handle);
    _handle = nullptr;
    // Mirror ~dspObject: previous->next = next; next->previous = previous.
    final before = _prev?.target;
    final after = _heldNext;
    before?._borrows[_next] = after;
    after?._prev = before == null ? null : WeakReference(before);
    _prev = null;
    _borrows.release();
  }
}

/// Feed-forward, stereo-linked dynamics compressor — a mix-grade
/// [DspObject] for a channel insert or a send return.
///
/// Attach with `Channel.dsp` or [Sound.setDsp]; the inherited [impact]
/// controls the wet/dry balance and [bypass] the compression. All setters
/// take effect immediately; the engine ramps the internal gain to keep
/// moves click-free.
class Compressor extends DspObject {
  Compressor._(Pointer<YseDspObject> handle)
    : super._(bindings, handle, _DspKind.compressor);

  /// Construct a compressor with the engine's default curve.
  factory Compressor() => Compressor._(
    _created(bindings.dsp_compressor_create(), 'yse_dsp_compressor_create'),
  );

  /// Level-detector mode (peak vs. RMS).
  CompressorDetector get detector => CompressorDetector.values.firstWhere(
    (e) => e.native == _b.dsp_compressor_get_detector(_handle),
    orElse: () => CompressorDetector.peak,
  );
  set detector(CompressorDetector value) =>
      _b.dsp_compressor_set_detector(_handle, value.native);

  /// Threshold in dB below which no gain reduction is applied.
  double get threshold => _b.dsp_compressor_get_threshold(_handle);
  set threshold(double db) => _b.dsp_compressor_set_threshold(_handle, db);

  /// Compression ratio (e.g. 4.0 is 4:1). 1.0 is no compression.
  double get ratio => _b.dsp_compressor_get_ratio(_handle);
  set ratio(double value) => _b.dsp_compressor_set_ratio(_handle, value);

  /// Attack time in milliseconds.
  double get attack => _b.dsp_compressor_get_attack(_handle);
  set attack(double ms) => _b.dsp_compressor_set_attack(_handle, ms);

  /// Release time in milliseconds.
  double get release => _b.dsp_compressor_get_release(_handle);
  set release(double ms) => _b.dsp_compressor_set_release(_handle, ms);

  /// Make-up gain in dB applied after compression.
  double get makeup => _b.dsp_compressor_get_makeup(_handle);
  set makeup(double db) => _b.dsp_compressor_set_makeup(_handle, db);

  /// Read-only meter: the gain reduction (in dB, `<= 0`) applied to the last
  /// processed sample.
  double get gainReductionDb =>
      _b.dsp_compressor_get_gain_reduction_db(_handle);
}

/// Four-band parametric EQ (low shelf, two peaks, high shelf) — a mix-grade
/// [DspObject] for a channel insert or a send return.
///
/// Every parameter is addressed by an [EqBand]; a band with 0 dB [getGain]
/// is flat (bypassed). Attach with `Channel.dsp` or [Sound.setDsp].
class ParametricEq extends DspObject {
  ParametricEq._(Pointer<YseDspObject> handle)
    : super._(bindings, handle, _DspKind.eq);

  /// Construct a flat four-band parametric EQ.
  factory ParametricEq() =>
      ParametricEq._(_created(bindings.dsp_eq_create(), 'yse_dsp_eq_create'));

  /// Centre/corner frequency of [band] in Hz.
  double getFrequency(EqBand band) =>
      _b.dsp_eq_get_frequency(_handle, band.native);

  /// Set the centre/corner frequency of [band] to [hz].
  void setFrequency(EqBand band, double hz) =>
      _b.dsp_eq_set_frequency(_handle, band.native, hz);

  /// Gain of [band] in dB (0 = flat / band bypass).
  double getGain(EqBand band) => _b.dsp_eq_get_gain(_handle, band.native);

  /// Set the gain of [band] to [db] (0 = flat / band bypass).
  void setGain(EqBand band, double db) =>
      _b.dsp_eq_set_gain(_handle, band.native, db);

  /// Q (bandwidth) of [band].
  double getQ(EqBand band) => _b.dsp_eq_get_q(_handle, band.native);

  /// Set the Q (bandwidth) of [band] to [value].
  void setQ(EqBand band, double value) =>
      _b.dsp_eq_set_q(_handle, band.native, value);
}

/// Chorus / flanger — one modulated-delay [DspObject] with a [mode] switch,
/// for a channel insert or a send return.
///
/// [spread] fans a per-channel LFO phase offset for stereo width. Attach
/// with `Channel.dsp` or [Sound.setDsp]; the inherited [impact] sets the
/// wet/dry balance.
class Chorus extends DspObject {
  Chorus._(Pointer<YseDspObject> handle)
    : super._(bindings, handle, _DspKind.chorus);

  /// Construct a chorus module (defaults to [ChorusMode.chorus]).
  factory Chorus() =>
      Chorus._(_created(bindings.dsp_chorus_create(), 'yse_dsp_chorus_create'));

  /// Chorus vs. flanger character.
  ChorusMode get mode => ChorusMode.values.firstWhere(
    (e) => e.native == _b.dsp_chorus_get_mode(_handle),
    orElse: () => ChorusMode.chorus,
  );
  set mode(ChorusMode value) => _b.dsp_chorus_set_mode(_handle, value.native);

  /// LFO rate in Hz.
  double get rate => _b.dsp_chorus_get_rate(_handle);
  set rate(double hz) => _b.dsp_chorus_set_rate(_handle, hz);

  /// Modulation depth.
  double get depth => _b.dsp_chorus_get_depth(_handle);
  set depth(double value) => _b.dsp_chorus_set_depth(_handle, value);

  /// Feedback amount (comb resonance; most audible in flanger mode).
  double get feedback => _b.dsp_chorus_get_feedback(_handle);
  set feedback(double value) => _b.dsp_chorus_set_feedback(_handle, value);

  /// Stereo spread — the per-channel LFO phase offset.
  double get spread => _b.dsp_chorus_get_spread(_handle);
  set spread(double value) => _b.dsp_chorus_set_spread(_handle, value);
}

/// Dattorro plate reverb — a mix-grade [DspObject] for a channel insert or a
/// send return.
///
/// Distinct from the engine's global spatial [Reverb]. `impact(0.25)` is a
/// natural insert mix; `impact(1)` is fully wet for send-return use. Attach
/// with `Channel.dsp` or [Sound.setDsp].
class PlateReverb extends DspObject {
  PlateReverb._(Pointer<YseDspObject> handle)
    : super._(bindings, handle, _DspKind.plateReverb);

  /// Construct a plate reverb with the engine's default tail.
  factory PlateReverb() => PlateReverb._(
    _created(bindings.dsp_plate_reverb_create(), 'yse_dsp_plate_reverb_create'),
  );

  /// Tail decay (feedback) in `[0.0, 1.0)`.
  double get decay => _b.dsp_plate_reverb_get_decay(_handle);
  set decay(double value) => _b.dsp_plate_reverb_set_decay(_handle, value);

  /// High-frequency damping corner in Hz.
  double get damping => _b.dsp_plate_reverb_get_damping(_handle);
  set damping(double hz) => _b.dsp_plate_reverb_set_damping(_handle, hz);

  /// Pre-delay before the tail begins, in milliseconds.
  double get predelay => _b.dsp_plate_reverb_get_predelay(_handle);
  set predelay(double ms) => _b.dsp_plate_reverb_set_predelay(_handle, ms);
}

/// Recirculating feedback delay — a mix-grade [DspObject] for a channel
/// insert or a send return.
///
/// A per-channel delay line with a damping low-pass in the feedback path and
/// [crossfeed] between channel pairs for ping-pong echoes. `impact(1)` is
/// echoes-only (send use). Attach with `Channel.dsp` or [Sound.setDsp].
class FeedbackDelay extends DspObject {
  FeedbackDelay._(Pointer<YseDspObject> handle)
    : super._(bindings, handle, _DspKind.feedbackDelay);

  /// Construct a feedback delay with the engine's default timing.
  factory FeedbackDelay() => FeedbackDelay._(
    _created(
      bindings.dsp_feedback_delay_create(),
      'yse_dsp_feedback_delay_create',
    ),
  );

  /// Delay time in milliseconds.
  double get time => _b.dsp_feedback_delay_get_time(_handle);
  set time(double ms) => _b.dsp_feedback_delay_set_time(_handle, ms);

  /// Feedback amount in `[0.0, 1.0)`.
  double get feedback => _b.dsp_feedback_delay_get_feedback(_handle);
  set feedback(double amount) =>
      _b.dsp_feedback_delay_set_feedback(_handle, amount);

  /// Damping low-pass corner in the feedback path, in Hz.
  double get damping => _b.dsp_feedback_delay_get_damping(_handle);
  set damping(double hz) => _b.dsp_feedback_delay_set_damping(_handle, hz);

  /// Cross-feed between the channel pair for ping-pong echoes.
  double get crossfeed => _b.dsp_feedback_delay_get_crossfeed(_handle);
  set crossfeed(double amount) =>
      _b.dsp_feedback_delay_set_crossfeed(_handle, amount);
}

/// The engine's zone/global reverb core packaged as a chainable insert whose
/// preset blend is a control input (upstream #369) — a mix-grade [DspObject].
///
/// Two endpoints, slot A and slot B, are each either a named [ReverbPreset]
/// (via [presetA] / [presetB]) or a custom [ReverbPresetValues] (via
/// [presetAValues] / [presetBValues]). [morph] linearly interpolates between
/// them (`0` = pure A, `1` = pure B, clamped to `[0, 1]`). Defaults are
/// A = [ReverbPreset.generic], B = [ReverbPreset.hall], [morph] = 0.
///
/// [morph] is a control-rate signal: writes are allocation- and click-free, so
/// any control thread may sweep it. Its wet/dry balance rides the morphed
/// presets (each carries its own `dry`/`wet`), so the inherited [impact] is
/// **not** applied — for send/return use, give both slots custom values with
/// `dry = 0`, `wet = 1`. Attach with `Channel.dsp` or [Sound.setDsp].
class MorphingReverb extends DspObject {
  MorphingReverb._(Pointer<YseDspObject> handle)
    : super._(bindings, handle, _DspKind.morphingReverb);

  /// Construct a morphing reverb (A = generic, B = hall, morph = 0).
  factory MorphingReverb() => MorphingReverb._(
    _created(
      bindings.dsp_morphing_reverb_create(),
      'yse_dsp_morphing_reverb_create',
    ),
  );

  /// Set slot A from a named [ReverbPreset].
  set presetA(ReverbPreset value) =>
      _b.dsp_morphing_reverb_set_preset_a(_handle, value.native);

  /// Set slot B from a named [ReverbPreset].
  set presetB(ReverbPreset value) =>
      _b.dsp_morphing_reverb_set_preset_b(_handle, value.native);

  /// Slot A's current parameter set.
  ReverbPresetValues get presetAValues => using((arena) {
    final out = arena<YseReverbPresetValues>();
    _b.dsp_morphing_reverb_get_preset_a(_handle, out);
    return ReverbPresetValues.fromNative(out.ref);
  });

  /// Set slot A from a custom parameter set.
  set presetAValues(ReverbPresetValues values) => using((arena) {
    _b.dsp_morphing_reverb_set_preset_a_values(_handle, values.toNative(arena));
  });

  /// Slot B's current parameter set.
  ReverbPresetValues get presetBValues => using((arena) {
    final out = arena<YseReverbPresetValues>();
    _b.dsp_morphing_reverb_get_preset_b(_handle, out);
    return ReverbPresetValues.fromNative(out.ref);
  });

  /// Set slot B from a custom parameter set.
  set presetBValues(ReverbPresetValues values) => using((arena) {
    _b.dsp_morphing_reverb_set_preset_b_values(_handle, values.toNative(arena));
  });

  /// The morph control input: `0` = pure slot A, `1` = pure slot B, clamped
  /// to `[0, 1]`.
  double get morph => _b.dsp_morphing_reverb_get_morph(_handle);
  set morph(double value) => _b.dsp_morphing_reverb_set_morph(_handle, value);
}

/// The engine's underwater treatment as an ordinary chainable insert — a
/// mix-grade [DspObject] that mixes every channel toward a position-neutral,
/// low-passed average as [depth] grows.
///
/// [depth] is the distance below the water surface in world units: `<= 1`
/// is transparent, `1..5` crossfades, `>= 5` is fully neutral, and negative
/// values clamp to 0. Writes are allocation- and wait-free.
///
/// The wet/dry balance is inherent in [depth], so the inherited [impact] is
/// **not** applied by this module. It is independent of the engine's own
/// instance driven by [System.underwaterFx] / [System.underwaterDepth]:
/// use this one to put the treatment anywhere in your own insert chain.
/// Attach with `Channel.dsp` or [Sound.setDsp].
class Underwater extends DspObject {
  Underwater._(Pointer<YseDspObject> handle)
    : super._(bindings, handle, _DspKind.underwater);

  /// Construct an underwater insert at depth 0 (transparent).
  factory Underwater() => Underwater._(
    _created(bindings.dsp_underwater_create(), 'yse_dsp_underwater_create'),
  );

  /// Distance below the water surface, in world units (negative clamps to 0).
  double get depth => _b.dsp_underwater_get_depth(_handle);
  set depth(double value) => _b.dsp_underwater_set_depth(_handle, value);
}

Pointer<YseDspObject> _created(Pointer<YseDspObject> handle, String fn) {
  if (handle.address == 0) throw YseException('$fn returned null');
  return handle;
}

enum _DspKind {
  lowpass,
  highpass,
  bandpass,
  sweep,
  basicDelay,
  lowpassDelay,
  highpassDelay,
  phaser,
  ringModulator,
  difference,
  granulator,
  compressor,
  eq,
  chorus,
  plateReverb,
  feedbackDelay,
  morphingReverb,
  underwater,
  patcherInsert,
}
