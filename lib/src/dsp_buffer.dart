import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
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

  /// Save the contents to a mono WAV file.
  void saveFile(String filename) {
    using((arena) {
      final cstr = filename.toNativeUtf8(allocator: arena);
      checkStatus(_b.dsp_buffer_save_file(_handle, cstr.cast()), _b);
    });
  }
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
