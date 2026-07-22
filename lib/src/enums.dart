// Enum values are self-documenting (mono, stereo, hall, cave) — the class-
// level doc explains the set. Individual docstrings would just repeat the
// name.
// ignore_for_file: public_member_api_docs

import 'bindings/yse_bindings.g.dart' as raw;

/// Speaker layout for [System.openDevice].
///
/// Values are kept in lockstep with `YSE::CHANNEL_TYPE` (see
/// `YseEngine/headers/enums.hpp`) so the Dart enum value cast equals
/// the underlying C enum.
enum ChannelType {
  /// Pick stereo when possible.
  auto(raw.YseChannelType.YSE_CT_AUTO),
  mono(raw.YseChannelType.YSE_CT_MONO),
  stereo(raw.YseChannelType.YSE_CT_STEREO),
  quad(raw.YseChannelType.YSE_CT_QUAD),

  /// 5.1 surround.
  surround51(raw.YseChannelType.YSE_CT_51),

  /// 5.1-side variant.
  surround51Side(raw.YseChannelType.YSE_CT_51SIDE),

  /// 6.1 surround.
  surround61(raw.YseChannelType.YSE_CT_61),

  /// 7.1 surround.
  surround71(raw.YseChannelType.YSE_CT_71),

  /// Custom layout — the caller is expected to set speaker positions.
  custom(raw.YseChannelType.YSE_CT_CUSTOM);

  /// The raw FFI enum value passed to the C ABI.
  final raw.YseChannelType native;
  const ChannelType(this.native);
}

/// Low-frequency-oscillator shape used by [DspObject.lfoType].
///
/// Values match `YSE::DSP::LFO_TYPE`.
enum LfoType {
  none(raw.YseLfoType.YSE_LFO_NONE),
  saw(raw.YseLfoType.YSE_LFO_SAW),
  sawReversed(raw.YseLfoType.YSE_LFO_SAW_REVERSED),
  triangle(raw.YseLfoType.YSE_LFO_TRIANGLE),
  sine(raw.YseLfoType.YSE_LFO_SINE),
  square(raw.YseLfoType.YSE_LFO_SQUARE),
  random(raw.YseLfoType.YSE_LFO_RANDOM);

  final raw.YseLfoType native;
  const LfoType(this.native);
}

/// Oscillator waveform for a synth's virtual-analog voice
/// ([Synth.setVaOscWave]).
///
/// Values match `YSE::SYNTH::VA_WAVEFORM` (see `synth/vaVoice.hpp`).
enum VaWaveform {
  /// Band-limited sawtooth.
  saw(raw.YseVaWaveform.YSE_VA_SAW),

  /// Band-limited pulse with variable width (PWM).
  pulse(raw.YseVaWaveform.YSE_VA_PULSE),

  /// Band-limited triangle.
  triangle(raw.YseVaWaveform.YSE_VA_TRIANGLE),

  /// Sine.
  sine(raw.YseVaWaveform.YSE_VA_SINE),

  /// White noise.
  noise(raw.YseVaWaveform.YSE_VA_NOISE),

  /// Morph across the wavetable bank (see [Synth.loadVaWavetable]).
  wavetable(raw.YseVaWaveform.YSE_VA_WAVETABLE);

  /// The raw FFI enum value passed to the C ABI.
  final raw.YseVaWaveform native;
  const VaWaveform(this.native);
}

/// LFO shape used by the [DspObject.sweep] constructor.
enum SweepShape {
  triangle(raw.YseDspSweepShape.YSE_SWEEP_TRIANGLE),
  saw(raw.YseDspSweepShape.YSE_SWEEP_SAW),
  square(raw.YseDspSweepShape.YSE_SWEEP_SQUARE);

  final raw.YseDspSweepShape native;
  const SweepShape(this.native);
}

/// Log-level filter for [Log].
///
/// Values match `YSE::ERROR_LEVEL`.
enum LogLevel {
  none(raw.YseErrorLevel.YSE_EL_NONE),
  error(raw.YseErrorLevel.YSE_EL_ERROR),
  warning(raw.YseErrorLevel.YSE_EL_WARNING),
  debug(raw.YseErrorLevel.YSE_EL_DEBUG);

  final raw.YseErrorLevel native;
  const LogLevel(this.native);
}

/// Data type produced by a patcher outlet ([PHandle.outputDataType]).
///
/// Values match `YSE::OUT_TYPE`.
enum OutType {
  invalid(raw.YseOutType.YSE_OUT_INVALID),
  bang(raw.YseOutType.YSE_OUT_BANG),
  float(raw.YseOutType.YSE_OUT_FLOAT),
  integer(raw.YseOutType.YSE_OUT_INT),
  buffer(raw.YseOutType.YSE_OUT_BUFFER),
  list(raw.YseOutType.YSE_OUT_LIST),
  any(raw.YseOutType.YSE_OUT_ANY);

  final raw.YseOutType native;
  const OutType(this.native);

  /// Maps a raw C-side [raw.YseOutType] to its Dart enum, defaulting to
  /// [OutType.invalid] for unknown values.
  static OutType fromNative(raw.YseOutType native) => values.firstWhere(
    (e) => e.native == native,
    orElse: () => OutType.invalid,
  );
}

/// Documentation category a patcher object type is filed under
/// ([PatcherObjectType.category]).
///
/// Drives the section headings on the patcher object reference. Values
/// match `YSE::PATCHER::pCategory` (mirrored by the C enum
/// `YsePCategory`).
enum PCategory {
  /// Uncategorised — should not reach a shipped object in practice.
  unset(raw.YsePCategory.YSE_PCAT_UNSET),

  /// Oscillators / signal generators.
  oscillator(raw.YsePCategory.YSE_PCAT_OSC),

  /// Filters.
  filter(raw.YsePCategory.YSE_PCAT_FILTER),

  /// Arithmetic / math objects.
  math(raw.YsePCategory.YSE_PCAT_MATH),

  /// Generic routing / utility objects.
  generic(raw.YsePCategory.YSE_PCAT_GENERIC),

  /// GUI control objects.
  gui(raw.YsePCategory.YSE_PCAT_GUI),

  /// Timing objects.
  time(raw.YsePCategory.YSE_PCAT_TIME),

  /// MIDI message objects.
  midi(raw.YsePCategory.YSE_PCAT_MIDI);

  final raw.YsePCategory native;
  const PCategory(this.native);

  /// Maps a raw C-side [raw.YsePCategory] to its Dart enum, defaulting to
  /// [PCategory.unset] for unknown values.
  static PCategory fromNative(raw.YsePCategory native) => values.firstWhere(
    (e) => e.native == native,
    orElse: () => PCategory.unset,
  );
}

/// One message kind a patcher inlet accepts ([PatcherInlet.accepts]).
///
/// The engine reports the set as an OR-ed bitmask; the wrapper decodes it
/// into a `Set<InletAccepts>`. Values match `YSE::PATCHER::InletType`
/// (mirrored by the C enum `YseInletAccepts`).
enum InletAccepts {
  /// Accepts an audio-rate DSP buffer.
  buffer(raw.YseInletAccepts.YSE_IN_ACCEPTS_BUFFER),

  /// Accepts a float.
  float(raw.YseInletAccepts.YSE_IN_ACCEPTS_FLOAT),

  /// Accepts an integer.
  integer(raw.YseInletAccepts.YSE_IN_ACCEPTS_INT),

  /// Accepts a bang.
  bang(raw.YseInletAccepts.YSE_IN_ACCEPTS_BANG),

  /// Accepts a list.
  list(raw.YseInletAccepts.YSE_IN_ACCEPTS_LIST);

  final raw.YseInletAccepts native;
  const InletAccepts(this.native);

  /// Decodes an engine `accepts` bitmask into the set of flags it encodes.
  static Set<InletAccepts> fromBitmask(int mask) => {
    for (final a in values)
      if (mask & a.native.value != 0) a,
  };
}

/// One of the three delay taps on a [DspObject.basicDelay] (and its
/// filtered subclasses).
enum DelayTap {
  first(raw.YseDspDelayTap.YSE_DELAY_TAP_FIRST),
  second(raw.YseDspDelayTap.YSE_DELAY_TAP_SECOND),
  third(raw.YseDspDelayTap.YSE_DELAY_TAP_THIRD);

  final raw.YseDspDelayTap native;
  const DelayTap(this.native);
}

/// Modulation character of a [Chorus] module.
///
/// Values match `YSE::DSP::MODULES::chorusMode` (see `chorus.hpp`).
enum ChorusMode {
  /// Longer base delay with a wide, slow sweep.
  chorus(raw.YseChorusMode.YSE_CHORUS_MODE_CHORUS),

  /// Short base delay with a feedback comb.
  flanger(raw.YseChorusMode.YSE_CHORUS_MODE_FLANGER);

  final raw.YseChorusMode native;
  const ChorusMode(this.native);
}

/// One of the four fixed bands of a [ParametricEq].
///
/// Values match `YSE::DSP::MODULES::eqBand` (see `parametricEQ.hpp`). The
/// `YSE_EQ_BAND_COUNT` sentinel is intentionally omitted.
enum EqBand {
  /// Low shelf.
  lowShelf(raw.YseEqBand.YSE_EQ_LOW_SHELF),

  /// First peaking band.
  peak1(raw.YseEqBand.YSE_EQ_PEAK_1),

  /// Second peaking band.
  peak2(raw.YseEqBand.YSE_EQ_PEAK_2),

  /// High shelf.
  highShelf(raw.YseEqBand.YSE_EQ_HIGH_SHELF);

  final raw.YseEqBand native;
  const EqBand(this.native);
}

/// Level-detector mode of a [Compressor].
///
/// Values match `YSE::DSP::MODULES::compressorDetector` (see `compressor.hpp`).
enum CompressorDetector {
  /// Instantaneous linked peak.
  peak(raw.YseCompressorDetector.YSE_COMPRESSOR_DETECT_PEAK),

  /// Short mean-square window.
  rms(raw.YseCompressorDetector.YSE_COMPRESSOR_DETECT_RMS);

  final raw.YseCompressorDetector native;
  const CompressorDetector(this.native);
}

/// Named reverb-tail presets for [Reverb.preset].
///
/// Values match `YSE::REVERB_PRESET`.
enum ReverbPreset {
  off(raw.YseReverbPreset.YSE_REVERB_OFF),
  generic(raw.YseReverbPreset.YSE_REVERB_GENERIC),
  padded(raw.YseReverbPreset.YSE_REVERB_PADDED),
  room(raw.YseReverbPreset.YSE_REVERB_ROOM),
  bathroom(raw.YseReverbPreset.YSE_REVERB_BATHROOM),
  stoneroom(raw.YseReverbPreset.YSE_REVERB_STONEROOM),
  largeroom(raw.YseReverbPreset.YSE_REVERB_LARGEROOM),
  hall(raw.YseReverbPreset.YSE_REVERB_HALL),
  cave(raw.YseReverbPreset.YSE_REVERB_CAVE),
  sewerpipe(raw.YseReverbPreset.YSE_REVERB_SEWERPIPE),
  underwater(raw.YseReverbPreset.YSE_REVERB_UNDERWATER);

  /// The raw FFI enum value passed to the C ABI.
  final raw.YseReverbPreset native;
  const ReverbPreset(this.native);
}
