Wavetable
=========

.. code-block:: dart

   class Wavetable extends FileBuffer

Pre-computed single-cycle wavetable. Populate it with [createSaw] /
[createSquare] / [createTriangle].

Mirrors the engine's `wavetable`, which derives from `fileBuffer`, so
a wavetable can also be drawn into, loaded and saved.

Constructors
------------

.. code-block:: dart

   Wavetable({required int length})

Wavetable of [length] samples.

Methods
-------

.. code-block:: dart

   void createSaw({required int harmonics, required int length})

Fill the wavetable with a band-limited sawtooth wave.

.. code-block:: dart

   void createSquare({required int harmonics, required int length})

Fill the wavetable with a band-limited square wave.

.. code-block:: dart

   void createTriangle({required int harmonics, required int length})

Fill the wavetable with a band-limited triangle wave.

