enum CompressorDetector
=======================

.. code-block:: dart

   enum CompressorDetector

Level-detector mode of a [Compressor].

Values match `YSE::DSP::MODULES::compressorDetector` (see `compressor.hpp`).

Values
------

.. _compressor_detector.peak:

``peak``

   Instantaneous linked peak.

.. _compressor_detector.rms:

``rms``

   Short mean-square window.

Constructors
------------

.. code-block:: dart

   CompressorDetector(this.native)

Properties
----------

.. code-block:: dart

   final raw.YseCompressorDetector native

