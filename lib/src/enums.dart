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
