import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'channel.dart';
import 'dsp_buffer.dart';
import 'dsp_object.dart';
import 'exception.dart';
import 'library.dart';
import 'pos.dart';

/// A playable instance of an audio source.
///
/// Construct one sound per voice in the scene. The source can be a file on
/// disk (wav / ogg / flac and other formats depending on the platform);
/// buffer-backed and DSP-source variants ship in later milestones.
class Sound implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.sound_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseSound> _handle;

  Sound._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Construct a sound backed by an audio file.
  ///
  /// [filename] is an absolute path or a path relative to the working
  /// directory. [channel] routes the sound through that mixer node;
  /// pass `null` to use the master mix. [streaming] streams the audio
  /// from disk instead of loading it into memory — use for large one-off
  /// assets, avoid for sounds played repeatedly.
  ///
  /// Throws [YseException] if the file cannot be loaded.
  factory Sound.fromFile(
    String filename, {
    Channel? channel,
    bool loop = false,
    double volume = 1.0,
    bool streaming = false,
  }) {
    final b = bindings;
    final h = b.sound_create();
    if (h.address == 0) {
      throw YseException('yse_sound_create returned null');
    }
    final s = Sound._(b, h);
    try {
      using((arena) {
        final pathPtr = filename.toNativeUtf8(allocator: arena);
        final chHandle = channel?.handle ?? nullptr;
        checkStatus(
          b.sound_load_file(
            h,
            pathPtr.cast(),
            chHandle,
            loop ? 1 : 0,
            volume,
            streaming ? 1 : 0,
          ),
          b,
        );
      });
      return s;
    } catch (_) {
      s.dispose();
      rethrow;
    }
  }

  /// Construct a sound backed by an in-memory [DspBuffer].
  ///
  /// **Lifetime contract:** [buffer] must outlive this sound — the audio
  /// thread reads from it on every callback. Keep a Dart reference to the
  /// buffer for as long as the sound exists; don't `.dispose()` the
  /// buffer before disposing the sound.
  factory Sound.fromBuffer(
    DspBuffer buffer, {
    Channel? channel,
    bool loop = false,
    double volume = 1.0,
  }) {
    final b = bindings;
    final h = b.sound_create();
    if (h.address == 0) {
      throw YseException('yse_sound_create returned null');
    }
    final s = Sound._(b, h);
    try {
      final chHandle = channel?.handle ?? nullptr;
      checkStatus(
        b.sound_load_buffer(h, buffer.handle, chHandle, loop ? 1 : 0, volume),
        b,
      );
      return s;
    } catch (_) {
      s.dispose();
      rethrow;
    }
  }

  /// Whether this sound has a live native implementation.
  bool get isValid => _b.sound_is_valid(_handle) != 0;

  /// Whether the asynchronous file load has finished.
  ///
  /// Calling [play] on a not-yet-ready sound is safe — the start is queued.
  bool get isReady => _b.sound_is_ready(_handle) != 0;

  /// Whether the sound is streamed from disk (vs loaded into memory).
  bool get isStreaming => _b.sound_is_streaming(_handle) != 0;

  // ─── transport ────────────────────────────────────────────────────────────

  /// Start playback.
  void play() => _b.sound_play(_handle);

  /// Pause playback. [play] resumes from the current position.
  void pause() => _b.sound_pause(_handle);

  /// Stop playback and rewind to the start of the source.
  void stop() => _b.sound_stop(_handle);

  /// Cycle playing → paused → playing, or stopped → playing.
  void toggle() => _b.sound_toggle(_handle);

  /// Restart from the beginning regardless of current position.
  void restart() => _b.sound_restart(_handle);

  /// Whether the sound is currently playing.
  bool get isPlaying => _b.sound_is_playing(_handle) != 0;

  /// Whether the sound is currently paused.
  bool get isPaused => _b.sound_is_paused(_handle) != 0;

  /// Whether the sound is currently stopped.
  bool get isStopped => _b.sound_is_stopped(_handle) != 0;

  // ─── 3D + mixing ──────────────────────────────────────────────────────────

  /// Position of this sound in the virtual scene.
  Pos get position => Pos.fromNative(_b.sound_get_pos(_handle));
  set position(Pos value) => using((arena) {
        _b.sound_set_pos(_handle, value.toNative(arena));
      });

  /// Volume in the range [0.0, 1.0].
  double get volume => _b.sound_get_volume(_handle);
  set volume(double value) => _b.sound_set_volume(_handle, value, 0);

  /// Fade to [target] over [fade] milliseconds.
  void fadeTo(double target, {required Duration fade}) =>
      _b.sound_set_volume(_handle, target, fade.inMilliseconds);

  /// Playback speed. 2.0 is one octave up, 0.5 is one octave down.
  /// Negative plays backwards (not supported for streaming sounds).
  double get speed => _b.sound_get_speed(_handle);
  set speed(double value) => _b.sound_set_speed(_handle, value);

  /// Audible radius — beyond this distance the sound fades out.
  double get size => _b.sound_get_size(_handle);
  set size(double value) => _b.sound_set_size(_handle, value);

  /// Channel spread for multichannel sounds (no-op for mono).
  double get spread => _b.sound_get_spread(_handle);
  set spread(double value) => _b.sound_set_spread(_handle, value);

  /// Whether the sound loops continuously.
  bool get looping => _b.sound_get_looping(_handle) != 0;
  set looping(bool value) => _b.sound_set_looping(_handle, value ? 1 : 0);

  /// Whether the sound is positioned relative to the listener.
  bool get relative => _b.sound_get_relative(_handle) != 0;
  set relative(bool value) => _b.sound_set_relative(_handle, value ? 1 : 0);

  /// Whether doppler shift is enabled for this sound.
  bool get doppler => _b.sound_get_doppler(_handle) != 0;
  set doppler(bool value) => _b.sound_set_doppler(_handle, value ? 1 : 0);

  /// Shorthand for relative + listener-origin position + no doppler.
  bool get pan2D => _b.sound_get_pan2d(_handle) != 0;
  set pan2D(bool value) => _b.sound_set_pan2d(_handle, value ? 1 : 0);

  /// Whether occlusion is active for this sound. Requires a
  /// callback installed via the engine's occlusion hook.
  bool get occlusion => _b.sound_get_occlusion(_handle) != 0;
  set occlusion(bool value) => _b.sound_set_occlusion(_handle, value ? 1 : 0);

  /// Fade out over [time], then stop.
  void fadeAndStop(Duration time) =>
      _b.sound_fade_and_stop(_handle, time.inMilliseconds);

  // ─── playhead ─────────────────────────────────────────────────────────────

  /// Playhead position in samples.
  double get time => _b.sound_get_time(_handle);
  set time(double samples) => _b.sound_set_time(_handle, samples);

  /// Length of the source in samples.
  int get length => _b.sound_length(_handle);

  /// Move this sound to a different channel.
  void moveTo(Channel target) => _b.sound_move_to(_handle, target.handle);

  /// Attach a DSP effect chain to this sound.
  ///
  /// Pass `null` to clear. The engine holds a borrowed reference to [dsp]
  /// for as long as the sound is live; [dsp] must outlive this sound and
  /// the engine's slow-pool delete tick that follows its destruction.
  set dsp(DspObject? dsp) => _b.sound_set_dsp(_handle, dsp?.handle ?? nullptr);

  /// Destroy the underlying native sound and detach the finalizer.
  ///
  /// Idempotent. After [dispose] the sound is unusable.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.sound_destroy(_handle);
    _handle = nullptr;
  }
}
