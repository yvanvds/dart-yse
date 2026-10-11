DspMultiBuffer
==============

.. code-block:: dart

   class DspMultiBuffer implements Finalizable

A multichannel source buffer: one sample buffer per channel, for
playing stereo or surround audio held in memory through
[Sound.fromMultiBuffer].

Mirrors the engine's `MULTICHANNELBUFFER`. The constructor **copies**
each channel's samples and [DspBuffer.sampleRateAdjustment], whatever
its subclass, so the source buffers can be changed or disposed
afterwards without affecting this one. `channels[0]` is the first
output channel. Channels may differ in length; a sound plays the length
of the shortest.

**Lifetime:** the engine reads this storage for as long as a sound
plays it. A [Sound] built from it holds a Dart reference, so garbage
collection never frees it under a live sound; don't call [dispose]
before disposing every sound made from it.

Constructors
------------

.. code-block:: dart

   factory DspMultiBuffer(List<DspBuffer> channels)

Build a multichannel buffer from a copy of [channels], in order.

Throws [ArgumentError] when [channels] is empty and [YseException]
when the engine refuses (for example a disposed channel buffer).

Properties
----------

.. code-block:: dart

   Pointer<YseDspMultiBuffer> get handle

Internal: native handle (used by `Sound.fromMultiBuffer`).

.. code-block:: dart

   int get channelCount

Number of channels; 0 after [dispose].

Methods
-------

.. code-block:: dart

   void dispose()

Destroy the underlying native buffer and detach the finalizer.

Idempotent. Only call it once every sound made from this buffer has
been disposed.

