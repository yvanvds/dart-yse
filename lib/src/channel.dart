import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';
import 'library.dart';

/// A node in the channel tree — a group of sounds that mix together.
///
/// Channels work like channel groups on a mixing console: every sound is
/// attached to a channel, and channels can themselves be attached to a
/// parent channel, forming a tree rooted at the master channel.
///
/// Use the pre-built channel singletons ([Channel.master], [Channel.fx],
/// etc.) directly, or build subtrees by passing them as the [parent] to
/// [Channel.create].
class Channel {
  final YseBindings _b;
  final Pointer<YseChannel> _handle;
  final bool _owned;

  Channel._(this._b, this._handle, this._owned);

  /// Internal: wrap a borrowed pointer that the caller does not own
  /// (singletons returned by `yse_channel_*` accessors).
  factory Channel._borrowed(Pointer<YseChannel> handle) =>
      Channel._(bindings, handle, false);

  /// Construct a new channel attached to [parent].
  ///
  /// Throws [YseException] when the engine refuses the new channel.
  factory Channel.create(String name, {required Channel parent}) {
    final b = bindings;
    return using((arena) {
      final namePtr = name.toNativeUtf8(allocator: arena);
      final h = b.channel_create(namePtr.cast(), parent._handle);
      if (h.address == 0) {
        final detail = b.last_error().cast<Utf8>().toDartString();
        b.clear_last_error();
        throw YseException('Could not create channel "$name": $detail');
      }
      return Channel._(b, h, true);
    });
  }

  /// The root of the channel tree. Every channel ultimately routes here.
  static Channel get master => Channel._borrowed(bindings.channel_master());

  /// Pre-built channel for short sound effects.
  static Channel get fx => Channel._borrowed(bindings.channel_fx());

  /// Pre-built channel for playlists and music tracks.
  static Channel get music => Channel._borrowed(bindings.channel_music());

  /// Pre-built channel for environmental and ambient sounds.
  static Channel get ambient => Channel._borrowed(bindings.channel_ambient());

  /// Pre-built channel for dialogue and voice-over.
  static Channel get voice => Channel._borrowed(bindings.channel_voice());

  /// Pre-built channel for user-interface sounds.
  static Channel get gui => Channel._borrowed(bindings.channel_gui());

  /// Volume in the range [0.0, 1.0].
  double get volume => _b.channel_get_volume(_handle);
  set volume(double value) => _b.channel_set_volume(_handle, value);

  /// Re-parent this channel. All attached sounds and subchannels follow.
  void moveTo(Channel parent) => _b.channel_move_to(_handle, parent._handle);

  /// Move the global reverb effect onto this channel.
  ///
  /// libYSE runs a single reverb instance for performance reasons. By
  /// default it sits on the master channel; call this to restrict reverb
  /// to a subtree.
  void attachReverb() => _b.channel_attach_reverb(_handle);

  /// Whether sounds on this channel may be virtualised when the engine
  /// runs out of voices.
  bool get virtual => _b.channel_get_virtual(_handle) != 0;
  set virtual(bool value) => _b.channel_set_virtual(_handle, value ? 1 : 0);

  /// Whether this channel has a live implementation.
  bool get isValid => _b.channel_is_valid(_handle) != 0;

  /// Channel name (the value passed to [Channel.create]).
  String get name => _b.channel_get_name(_handle).cast<Utf8>().toDartString();

  /// Number of output speakers this channel feeds. Index into [peakLinear]
  /// and [peakDb] with values in `[0, numOutputs)`.
  int get numOutputs => _b.channel_get_num_outputs(_handle);

  /// Peak amplitude (linear `[0.0, 1.0+]`) measured at the end of dsp(),
  /// before the channel volume is applied. Useful for input-level meters.
  ///
  /// Pass an [output] index in `[0, numOutputs)` for a per-speaker reading;
  /// out-of-range indices return 0.
  double peakLinearPre({int? output}) => output == null
      ? _b.channel_get_peak_linear_pre(_handle)
      : _b.channel_get_peak_linear_pre_output(_handle, output);

  /// Peak amplitude (linear `[0.0, 1.0+]`) measured immediately after
  /// the channel volume is applied — what listeners hear.
  double peakLinearPost({int? output}) => output == null
      ? _b.channel_get_peak_linear_post(_handle)
      : _b.channel_get_peak_linear_post_output(_handle, output);

  /// [peakLinearPre] expressed in decibels. Silence reports −120 dB.
  double peakDbPre({int? output}) => output == null
      ? _b.channel_get_peak_db_pre(_handle)
      : _b.channel_get_peak_db_pre_output(_handle, output);

  /// [peakLinearPost] expressed in decibels. Silence reports −120 dB.
  double peakDbPost({int? output}) => output == null
      ? _b.channel_get_peak_db_post(_handle)
      : _b.channel_get_peak_db_post_output(_handle, output);

  /// Internal: native handle for cross-wrapper plumbing (sound → channel).
  Pointer<YseChannel> get handle => _handle;

  /// Destroy the underlying native channel.
  ///
  /// No-op for the pre-built singletons (those are owned by the engine).
  void dispose() {
    if (!_owned) return;
    _b.channel_destroy(_handle);
  }
}
