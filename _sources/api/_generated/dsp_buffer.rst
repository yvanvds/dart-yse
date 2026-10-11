DspBuffer
=========

.. code-block:: dart

   class DspBuffer implements Finalizable

Single-channel float audio buffer — the fundamental container for
sample-level audio data in libYSE.

The engine's buffer classes form a single inheritance chain, mirrored
here so the type system decides which operations a buffer supports:

  - [DspBuffer] ([DspBuffer.plain]) — bare storage; pass to
    [Sound.fromBuffer].
  - [DrawableBuffer] — adds [DrawableBuffer.drawLine] /
    [DrawableBuffer.drawFlat].
  - [FileBuffer] — a drawable buffer that adds [FileBuffer.loadFile] /
    [FileBuffer.saveFile].
  - [Wavetable] — a file buffer that adds the band-limited waveform
    generators (saw / square / triangle).

The C API cannot check a buffer's subclass at runtime (it `static_cast`s
the handle and trusts the caller), so calling a subclass entry point on
a narrower buffer would write through a mistyped pointer. Each wrapper
class is only ever constructed around a handle from its own native
constructor, so a [DspBuffer.plain] simply has no `drawLine`.

**Lifetime:** the buffer must outlive any [Sound] created from it.
The engine keeps a reference for as long as the sound is live.

Constructors
------------

.. code-block:: dart

   DspBuffer.plain({required int length, int overflow = 0})

Plain single-channel buffer.

[overflow] is extra samples appended past the end, used by sources
that need a wrap-around copy of the first samples at the tail
(wavetables set this internally).

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

   void addBuffer(DspBuffer other)

Add [other] sample by sample: `this[i] += other[i]`.

Works over the first `min(length, other.length)` samples; samples past
the shorter length are left untouched. [other] may be this buffer.

.. code-block:: dart

   void subBuffer(DspBuffer other)

Subtract [other] sample by sample: `this[i] -= other[i]`.

Same span rules as [addBuffer].

.. code-block:: dart

   void mulBuffer(DspBuffer other)

Multiply by [other] sample by sample: `this[i] *= other[i]`.

Same span rules as [addBuffer].

.. code-block:: dart

   void divBuffer(DspBuffer other)

Divide by [other] sample by sample: `this[i] /= other[i]`.

Same span rules as [addBuffer]. Dividing by a zero sample gives 0,
not infinity.

.. code-block:: dart

   void copyFrom(DspBuffer src, {int srcPos = 0, int dstPos = 0, required int count})

Copy [count] samples from `src[srcPos ...]` into `this[dstPos ...]`.

Both ranges must lie inside their buffer's [length]. A range that runs
past the end copies nothing and throws [YseException]; a negative
argument throws [RangeError]. [src] may be this buffer only when the
two ranges do not overlap ([ArgumentError] otherwise). The overflow
tail (see [DspBuffer.plain]) is refreshed after the copy, so copying
into the head of a [Wavetable] keeps its wrap-around samples in sync.

.. code-block:: dart

   void swap(DspBuffer other)

Exchange the samples of this buffer and [other].

Both buffers must have the same [length]; otherwise nothing moves and
[YseException] is thrown. Only the sample values move: each buffer
keeps its own storage, Dart class and [sampleRateAdjustment].
Swapping a buffer with itself does nothing.

.. code-block:: dart

   Float32List read({int offset = 0, int? count})

Copy [count] samples starting at [offset] into a new [Float32List].

.. code-block:: dart

   int write(Float32List samples, {int offset = 0})

Copy [samples] into the buffer starting at [offset].

Returns the number of samples actually written (clamped to the
buffer length).

.. code-block:: dart

   void dispose()

Destroy the underlying native buffer and detach the finalizer.

