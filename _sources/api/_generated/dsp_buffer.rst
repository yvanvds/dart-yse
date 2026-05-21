DspBuffer
=========

.. code-block:: dart

   class DspBuffer implements Finalizable

Single-channel float audio buffer — the fundamental container for
sample-level audio data in libYSE.

Construct via the factory matching the subclass you need:
  - [DspBuffer.plain] — bare storage; pass to [Sound.fromBuffer].
  - [DspBuffer.drawable] — adds `drawLine` and envelope shaping.
  - [DspBuffer.file] — adds [loadFile] / [saveFile].
  - [DspBuffer.wavetable] — single-cycle wavetable + classic waveform
    generators (saw/square/triangle).

Subclass-specific methods throw [YseException] if the underlying
handle isn't of the expected type.

**Lifetime:** the buffer must outlive any [Sound] created from it.
The engine keeps a reference for as long as the sound is live.

Constructors
------------

.. code-block:: dart

   factory DspBuffer.plain({required int length, int overflow = 0})

Plain single-channel buffer.

[overflow] is extra samples appended past the end, used by sources
that need a wrap-around copy of the first samples at the tail
(wavetables set this internally).

.. code-block:: dart

   factory DspBuffer.drawable({required int length, int overflow = 0})

Buffer with drawing primitives (drawLine, envelope shaping).

.. code-block:: dart

   factory DspBuffer.file({required int length, int overflow = 0})

Drawable buffer with built-in file load and save.

.. code-block:: dart

   factory DspBuffer.wavetable({required int length})

Pre-computed single-cycle wavetable. Use the [createSaw] /
[createSquare] / [createTriangle] methods to populate it.

Properties
----------

.. code-block:: dart

   Pointer<YseDspBuffer> get handle

Internal: native handle (used by `Sound.fromBuffer`).

.. code-block:: dart

   int get length

Length in samples (frames).

.. code-block:: dart

   int get lengthMs

Length in milliseconds at the engine sample rate.

.. code-block:: dart

   double get lengthSec

Length in seconds at the engine sample rate.

.. code-block:: dart

   bool get isSilent

Whether every sample is zero.

.. code-block:: dart

   double get maxValue

Peak absolute sample value.

.. code-block:: dart

   double get back

The last sample of the buffer.

.. code-block:: dart

   double get sampleRateAdjustment

.. code-block:: dart

   set sampleRateAdjustment(double value)

Sample-rate adjustment factor used by the engine to play this buffer
at the correct speed when its native rate differs from the engine
rate.

Methods
-------

.. code-block:: dart

   void resize(int length, {double value = 0.0})

Resize the buffer. Newly added samples are filled with [value].

.. code-block:: dart

   void fill(double value)

Fill every sample with [value].

.. code-block:: dart

   void addScalar(double value)

Add [value] to every sample.

.. code-block:: dart

   void mulScalar(double value)

Multiply every sample by [value].

.. code-block:: dart

   Float32List read({int offset = 0, int? count})

Copy [count] samples starting at [offset] into a new [Float32List].

.. code-block:: dart

   int write(Float32List samples, {int offset = 0})

Copy [samples] into the buffer starting at [offset].

Returns the number of samples actually written (clamped to the
buffer length).

.. code-block:: dart

   void drawLine({required int start, required int stop, required double startValue, required double stopValue})

Draw a linear ramp from `(start, startValue)` to `(stop, stopValue)`.

Throws [YseException] if this buffer is not a drawable subclass.

.. code-block:: dart

   void drawFlat({required int start, required int stop, required double value})

Fill the range `[start, stop]` with [value].

Throws [YseException] if this buffer is not a drawable subclass.

.. code-block:: dart

   void loadFile(String filename, {int channel = 0})

Load one channel from an audio file.

Throws [YseException] on failure (file missing, wrong channel, etc.).

.. code-block:: dart

   void saveFile(String filename)

Save the contents to a mono WAV file.

.. code-block:: dart

   void createSaw({required int harmonics, required int length})

Fill the wavetable with a band-limited sawtooth wave.

.. code-block:: dart

   void createSquare({required int harmonics, required int length})

Fill the wavetable with a band-limited square wave.

.. code-block:: dart

   void createTriangle({required int harmonics, required int length})

Fill the wavetable with a band-limited triangle wave.

.. code-block:: dart

   void dispose()

Destroy the underlying native buffer and detach the finalizer.

