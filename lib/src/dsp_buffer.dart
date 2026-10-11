import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'buffer_io.dart' show BufferIO;
import 'exception.dart';
import 'library.dart';

/// Single-channel float audio buffer — the fundamental container for
/// sample-level audio data in libYSE.
///
/// The engine's buffer classes form a single inheritance chain, mirrored
/// here so the type system decides which operations a buffer supports:
///
///   - [DspBuffer] ([DspBuffer.plain]) — bare storage; pass to
///     [Sound.fromBuffer].
///   - [DrawableBuffer] — adds [DrawableBuffer.drawLine] /
///     [DrawableBuffer.drawFlat].
///   - [FileBuffer] — a drawable buffer that adds [FileBuffer.loadFile] /
///     [FileBuffer.saveFile].
///   - [Wavetable] — a file buffer that adds the band-limited waveform
///     generators (saw / square / triangle).
///
/// The C API cannot check a buffer's subclass at runtime (it `static_cast`s
/// the handle and trusts the caller), so calling a subclass entry point on
/// a narrower buffer would write through a mistyped pointer. Each wrapper
/// class is only ever constructed around a handle from its own native
/// constructor, so a [DspBuffer.plain] simply has no `drawLine`.
///
/// **Lifetime:** the buffer must outlive any [Sound] created from it.
/// The engine keeps a reference for as long as the sound is live.
class DspBuffer implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.dsp_buffer_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseDspBuffer> _handle;

  DspBuffer._(Pointer<YseDspBuffer> handle)
    : _b = bindings,
      _handle = _checked(handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Plain single-channel buffer.
  ///
  /// [overflow] is extra samples appended past the end, used by sources
  /// that need a wrap-around copy of the first samples at the tail
  /// (wavetables set this internally).
  DspBuffer.plain({required int length, int overflow = 0})
    : this._(bindings.dsp_buffer_create(length, overflow));

  static Pointer<YseDspBuffer> _checked(Pointer<YseDspBuffer> handle) {
    if (handle.address == 0) {
      throw YseException('yse_dsp_buffer create returned null');
    }
    return handle;
  }

  /// Internal: native handle (used by `Sound.fromBuffer`).
  Pointer<YseDspBuffer> get handle => _handle;

  // ─── common ─────────────────────────────────────────────────────────────

  /// Length in samples (frames).
  int get length => _b.dsp_buffer_length(_handle);

  /// Length in milliseconds at the engine sample rate.
  int get lengthMs => _b.dsp_buffer_length_ms(_handle);

  /// Length in seconds at the engine sample rate.
  double get lengthSec => _b.dsp_buffer_length_sec(_handle);

  /// Whether every sample is zero.
  bool get isSilent => _b.dsp_buffer_is_silent(_handle) != 0;

  /// Peak absolute sample value.
  double get maxValue => _b.dsp_buffer_max_value(_handle);

  /// The last sample of the buffer.
  double get back => _b.dsp_buffer_get_back(_handle);

  /// Sample-rate adjustment factor used by the engine to play this buffer
  /// at the correct speed when its native rate differs from the engine
  /// rate.
  double get sampleRateAdjustment =>
      _b.dsp_buffer_sample_rate_adjustment(_handle);
  set sampleRateAdjustment(double value) =>
      _b.dsp_buffer_set_sample_rate_adjustment(_handle, value);

  /// Resize the buffer. Newly added samples are filled with [value].
  void resize(int length, {double value = 0.0}) =>
      _b.dsp_buffer_resize(_handle, length, value);

  /// Fill every sample with [value].
  void fill(double value) => _b.dsp_buffer_fill(_handle, value);

  /// Add [value] to every sample.
  void addScalar(double value) => _b.dsp_buffer_add_scalar(_handle, value);

  /// Multiply every sample by [value].
  void mulScalar(double value) => _b.dsp_buffer_mul_scalar(_handle, value);

  // ─── buffer math ─────────────────────────────────────────────────────────

  /// Add [other] sample by sample: `this[i] += other[i]`.
  ///
  /// Works over the first `min(length, other.length)` samples; samples past
  /// the shorter length are left untouched. [other] may be this buffer.
  void addBuffer(DspBuffer other) =>
      _b.dsp_buffer_add_buffer(_handle, other._handle);

  /// Subtract [other] sample by sample: `this[i] -= other[i]`.
  ///
  /// Same span rules as [addBuffer].
  void subBuffer(DspBuffer other) =>
      _b.dsp_buffer_sub_buffer(_handle, other._handle);

  /// Multiply by [other] sample by sample: `this[i] *= other[i]`.
  ///
  /// Same span rules as [addBuffer].
  void mulBuffer(DspBuffer other) =>
      _b.dsp_buffer_mul_buffer(_handle, other._handle);

  /// Divide by [other] sample by sample: `this[i] /= other[i]`.
  ///
  /// Same span rules as [addBuffer]. Dividing by a zero sample gives 0,
  /// not infinity.
  void divBuffer(DspBuffer other) =>
      _b.dsp_buffer_div_buffer(_handle, other._handle);

  /// Copy [count] samples from `src[srcPos ...]` into `this[dstPos ...]`.
  ///
  /// Both ranges must lie inside their buffer's [length]. A range that runs
  /// past the end copies nothing and throws [YseException]; a negative
  /// argument throws [RangeError]. [src] may be this buffer only when the
  /// two ranges do not overlap ([ArgumentError] otherwise). The overflow
  /// tail (see [DspBuffer.plain]) is refreshed after the copy, so copying
  /// into the head of a [Wavetable] keeps its wrap-around samples in sync.
  void copyFrom(
    DspBuffer src, {
    int srcPos = 0,
    int dstPos = 0,
    required int count,
  }) {
    _checkUnsigned(srcPos, 'srcPos');
    _checkUnsigned(dstPos, 'dstPos');
    _checkUnsigned(count, 'count');
    if (src._handle == _handle &&
        count > 0 &&
        srcPos < dstPos + count &&
        dstPos < srcPos + count) {
      throw ArgumentError(
        'copyFrom within one buffer needs non-overlapping ranges '
        '(srcPos $srcPos, dstPos $dstPos, count $count)',
      );
    }
    checkStatus(
      _b.dsp_buffer_copy_from(_handle, src._handle, srcPos, dstPos, count),
      _b,
    );
  }

  /// Exchange the samples of this buffer and [other].
  ///
  /// Both buffers must have the same [length]; otherwise nothing moves and
  /// [YseException] is thrown. Only the sample values move: each buffer
  /// keeps its own storage, Dart class and [sampleRateAdjustment].
  /// Swapping a buffer with itself does nothing.
  void swap(DspBuffer other) {
    checkStatus(_b.dsp_buffer_swap(_handle, other._handle), _b);
  }

  static void _checkUnsigned(int value, String name) {
    // The C API takes `unsigned int`; reject what would wrap or truncate.
    RangeError.checkValueInInterval(value, 0, 0xFFFFFFFF, name);
  }

  // ─── bulk I/O ────────────────────────────────────────────────────────────

  /// Copy [count] samples starting at [offset] into a new [Float32List].
  Float32List read({int offset = 0, int? count}) {
    final n = count ?? (length - offset);
    if (n <= 0) return Float32List(0);
    final out = Float32List(n);
    using((arena) {
      final ptr = arena<Float>(n);
      final actual = _b.dsp_buffer_read(_handle, offset, ptr, n);
      for (var i = 0; i < actual; i++) {
        out[i] = ptr[i];
      }
    });
    return out;
  }

  /// Copy [samples] into the buffer starting at [offset].
  ///
  /// Returns the number of samples actually written (clamped to the
  /// buffer length).
  int write(Float32List samples, {int offset = 0}) {
    if (samples.isEmpty) return 0;
    return using((arena) {
      final ptr = arena<Float>(samples.length);
      for (var i = 0; i < samples.length; i++) {
        ptr[i] = samples[i];
      }
      return _b.dsp_buffer_write(_handle, offset, ptr, samples.length);
    });
  }

  /// Destroy the underlying native buffer and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.dsp_buffer_destroy(_handle);
    _handle = nullptr;
  }
}

/// A [DspBuffer] with drawing primitives ([drawLine], [drawFlat]).
///
/// Mirrors the engine's `drawableBuffer`.
class DrawableBuffer extends DspBuffer {
  DrawableBuffer._(super.handle) : super._();

  /// Drawable buffer of [length] samples (plus [overflow] tail samples).
  DrawableBuffer({required int length, int overflow = 0})
    : this._(bindings.dsp_drawable_buffer_create(length, overflow));

  /// Draw a linear ramp from `(start, startValue)` to `(stop, stopValue)`.
  void drawLine({
    required int start,
    required int stop,
    required double startValue,
    required double stopValue,
  }) {
    checkStatus(
      _b.dsp_buffer_draw_line(_handle, start, stop, startValue, stopValue),
      _b,
    );
  }

  /// Fill the range `[start, stop]` with [value].
  void drawFlat({
    required int start,
    required int stop,
    required double value,
  }) {
    checkStatus(_b.dsp_buffer_draw_flat(_handle, start, stop, value), _b);
  }
}

/// A [DrawableBuffer] with built-in audio file load and save.
///
/// Mirrors the engine's `fileBuffer`.
class FileBuffer extends DrawableBuffer {
  FileBuffer._(super.handle) : super._();

  /// File buffer of [length] samples (plus [overflow] tail samples). Size
  /// it large enough for the file you intend to [loadFile].
  FileBuffer({required int length, int overflow = 0})
    : this._(bindings.dsp_file_buffer_create(length, overflow));

  /// Load one channel from an audio file.
  ///
  /// Throws [YseException] on failure (file missing, wrong channel, etc.).
  void loadFile(String filename, {int channel = 0}) {
    using((arena) {
      final cstr = filename.toNativeUtf8(allocator: arena);
      checkStatus(_b.dsp_buffer_load_file(_handle, cstr.cast(), channel), _b);
    });
  }

  /// Save the contents to a mono 32-bit float WAV file.
  ///
  /// [filename] is used verbatim (no extension is appended). The file is
  /// written at [fileSampleRate] when this buffer was loaded from a file,
  /// or at the engine sample rate otherwise.
  ///
  /// Throws [YseException] when the file cannot be created, the buffer is
  /// empty, or a custom [BufferIO] backend is active: that backend is
  /// read-only, so saving refuses rather than bypass it. File I/O — don't
  /// call it from a time-critical path.
  void saveFile(String filename) {
    using((arena) {
      final cstr = filename.toNativeUtf8(allocator: arena);
      checkStatus(_b.dsp_buffer_save_file(_handle, cstr.cast()), _b);
    });
  }

  /// Native sample rate, in Hz, of the file this buffer was last loaded
  /// from with [loadFile]; 0 before a successful load.
  ///
  /// Unlike [sampleRateAdjustment] (a ratio against the engine rate in
  /// effect at load time), this does not change when the engine is
  /// re-initialised at another rate. To re-derive the playback speed
  /// against the live session, use
  /// `fileSampleRate / System.instance.sessionSampleRate` and assign it to
  /// [sampleRateAdjustment].
  double get fileSampleRate => _b.dsp_buffer_get_file_sample_rate(_handle);
}

/// Pre-computed single-cycle wavetable. Populate it with [createSaw] /
/// [createSquare] / [createTriangle].
///
/// Mirrors the engine's `wavetable`, which derives from `fileBuffer`, so
/// a wavetable can also be drawn into, loaded and saved.
class Wavetable extends FileBuffer {
  Wavetable._(super.handle) : super._();

  /// Wavetable of [length] samples.
  Wavetable({required int length})
    : this._(bindings.dsp_wavetable_create(length));

  /// Fill the wavetable with a band-limited sawtooth wave.
  void createSaw({required int harmonics, required int length}) {
    checkStatus(_b.dsp_wavetable_create_saw(_handle, harmonics, length), _b);
  }

  /// Fill the wavetable with a band-limited square wave.
  void createSquare({required int harmonics, required int length}) {
    checkStatus(_b.dsp_wavetable_create_square(_handle, harmonics, length), _b);
  }

  /// Fill the wavetable with a band-limited triangle wave.
  void createTriangle({required int harmonics, required int length}) {
    checkStatus(
      _b.dsp_wavetable_create_triangle(_handle, harmonics, length),
      _b,
    );
  }
}

/// A multichannel source buffer: one sample buffer per channel, for
/// playing stereo or surround audio held in memory through
/// [Sound.fromMultiBuffer].
///
/// Mirrors the engine's `MULTICHANNELBUFFER`. The constructor **copies**
/// each channel's samples and [DspBuffer.sampleRateAdjustment], whatever
/// its subclass, so the source buffers can be changed or disposed
/// afterwards without affecting this one. `channels[0]` is the first
/// output channel. Channels may differ in length; a sound plays the length
/// of the shortest.
///
/// **Lifetime:** the engine reads this storage for as long as a sound
/// plays it. A [Sound] built from it holds a Dart reference, so garbage
/// collection never frees it under a live sound; don't call [dispose]
/// before disposing every sound made from it.
class DspMultiBuffer implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.dsp_multi_buffer_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseDspMultiBuffer> _handle;

  DspMultiBuffer._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Build a multichannel buffer from a copy of [channels], in order.
  ///
  /// Throws [ArgumentError] when [channels] is empty and [YseException]
  /// when the engine refuses (for example a disposed channel buffer).
  factory DspMultiBuffer(List<DspBuffer> channels) {
    if (channels.isEmpty) {
      throw ArgumentError.value(channels, 'channels', 'must not be empty');
    }
    final b = bindings;
    final handle = using((arena) {
      final ptrs = arena<Pointer<YseDspBuffer>>(channels.length);
      for (var i = 0; i < channels.length; i++) {
        ptrs[i] = channels[i]._handle;
      }
      return b.dsp_multi_buffer_create(ptrs, channels.length);
    });
    if (handle.address == 0) {
      checkStatus(YseStatus.YSE_ERR_INVALID_ARGUMENT, b);
    }
    return DspMultiBuffer._(b, handle);
  }

  /// Internal: native handle (used by `Sound.fromMultiBuffer`).
  Pointer<YseDspMultiBuffer> get handle => _handle;

  /// Number of channels; 0 after [dispose].
  int get channelCount => _b.dsp_multi_buffer_get_channel_count(_handle);

  /// Destroy the underlying native buffer and detach the finalizer.
  ///
  /// Idempotent. Only call it once every sound made from this buffer has
  /// been disposed.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.dsp_multi_buffer_destroy(_handle);
    _handle = nullptr;
  }
}
