Compressor
==========

.. code-block:: dart

   class Compressor extends DspObject

Feed-forward, stereo-linked dynamics compressor — a mix-grade
[DspObject] for a channel insert or a send return.

Attach with `Channel.dsp` or [Sound.setDsp]; the inherited [impact]
controls the wet/dry balance and [bypass] the compression. All setters
take effect immediately; the engine ramps the internal gain to keep
moves click-free.

Constructors
------------

.. code-block:: dart

   factory Compressor()

Construct a compressor with the engine's default curve.

Properties
----------

.. code-block:: dart

   CompressorDetector get detector

.. code-block:: dart

   set detector(CompressorDetector value)

Level-detector mode (peak vs. RMS).

.. code-block:: dart

   double get threshold

.. code-block:: dart

   set threshold(double db)

Threshold in dB below which no gain reduction is applied.

.. code-block:: dart

   double get ratio

.. code-block:: dart

   set ratio(double value)

Compression ratio (e.g. 4.0 is 4:1). 1.0 is no compression.

.. code-block:: dart

   double get attack

.. code-block:: dart

   set attack(double ms)

Attack time in milliseconds.

.. code-block:: dart

   double get release

.. code-block:: dart

   set release(double ms)

Release time in milliseconds.

.. code-block:: dart

   double get makeup

.. code-block:: dart

   set makeup(double db)

Make-up gain in dB applied after compression.

.. code-block:: dart

   double get gainReductionDb

Read-only meter: the gain reduction (in dB, `<= 0`) applied to the last
processed sample.

