DrawableBuffer
==============

.. code-block:: dart

   class DrawableBuffer extends DspBuffer

A [DspBuffer] with drawing primitives ([drawLine], [drawFlat]).

Mirrors the engine's `drawableBuffer`.

Constructors
------------

.. code-block:: dart

   DrawableBuffer({required int length, int overflow = 0})

Drawable buffer of [length] samples (plus [overflow] tail samples).

Methods
-------

.. code-block:: dart

   void drawLine({required int start, required int stop, required double startValue, required double stopValue})

Draw a linear ramp from `(start, startValue)` to `(stop, stopValue)`.

.. code-block:: dart

   void drawFlat({required int start, required int stop, required double value})

Fill the range `[start, stop]` with [value].

