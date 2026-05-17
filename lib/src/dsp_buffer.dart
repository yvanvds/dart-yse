import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';
import 'library.dart';

/// Single-channel float audio buffer — the fundamental container for
/// sample-level audio data in libYSE.
///
/// Construct via the factory matching the subclass you need:
///   - [DspBuffer.plain] — bare storage; pass to [Sound.fromBuffer].
///   - [DspBuffer.drawable] — adds `drawLine` and envelope shaping.
///   - [DspBuffer.file] — adds [loadFile] / [saveFile].
///   - [DspBuffer.wavetable] — single-cycle wavetable + classic waveform
///     generators (saw/square/triangle).
///
/// Subclass-specific methods throw [YseException] if the underlying
/// handle isn't of the expected type.
///
/// **Lifetime:** the buffer must outlive any [Sound] created from it.
/// The engine keeps a reference for as long as the sound is live.
class DspBuffer implements Finalizable {
  static final _finalizer = NativeFinalizer(
    bindings.addresses.dsp_buffer_destroy.cast(),
  );

  final YseBindings _b;
  Pointer<YseDspBuffer> _handle;

  DspBuffer._(this._b, this._handle) {
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  /// Plain single-channel buffer.
  ///
  /// [overflow] is extra samples appended past the end, used by sources
  /// that need a wrap-around copy of the first samples at the tail
  /// (wavetables set this internally).
  factory DspBuffer.plain({required int length, int overflow = 0}) =>
      _wrap(bindings.dsp_buffer_create(length, overflow));

  /// Buffer with drawing primitives (drawLine, envelope shaping).
  factory DspBuffer.drawable({required int length, int overflow = 0}) =>
      _wrap(bindings.dsp_drawable_buffer_create(length, overflow));

  /// Drawable buffer with built-in file load and save.
  factory DspBuffer.file({required int length, int overflow = 0}) =>
      _wrap(bindings.dsp_file_buffer_create(length, overflow));

  /// Pre-computed single-cycle wavetable. Use the [createSaw] /
  /// [createSquare] / [createTriangle] methods to populate it.
  factory DspBuffer.wavetable({required int length}) =>
      _wrap(bindings.dsp_wavetable_create(length));

  static DspBuffer _wrap(Pointer<YseDspBuffer> handle) {
    if (handle.address == 0) {
      throw YseException('yse_dsp_buffer create returned null');
    }
    return DspBuffer._(bindings, handle);
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

  // ─── drawableBuffer ──────────────────────────────────────────────────────

  /// Draw a linear ramp from `(start, startValue)` to `(stop, stopValue)`.
  ///
  /// Throws [YseException] if this buffer is not a drawable subclass.
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
  ///
  /// Throws [YseException] if this buffer is not a drawable subclass.
  void drawFlat({required int start, required int stop, required double value}) {
    checkStatus(_b.dsp_buffer_draw_flat(_handle, start, stop, value), _b);
  }

  // ─── fileBuffer ──────────────────────────────────────────────────────────

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

  // ─── wavetable ───────────────────────────────────────────────────────────

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
    checkStatus(_b.dsp_wavetable_create_triangle(_handle, harmonics, length), _b);
  }

  /// Destroy the underlying native buffer and detach the finalizer.
  void dispose() {
    if (_handle.address == 0) return;
    _finalizer.detach(this);
    _b.dsp_buffer_destroy(_handle);
    _handle = nullptr;
  }
}

