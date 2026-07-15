enum VaWaveform
===============

.. code-block:: dart

   enum VaWaveform

Oscillator waveform for a synth's virtual-analog voice
([Synth.setVaOscWave]).

Values match `YSE::SYNTH::VA_WAVEFORM` (see `synth/vaVoice.hpp`).

Values
------

.. _va_waveform.saw:

``saw``

   Band-limited sawtooth.

.. _va_waveform.pulse:

``pulse``

   Band-limited pulse with variable width (PWM).

.. _va_waveform.triangle:

``triangle``

   Band-limited triangle.

.. _va_waveform.sine:

``sine``

   Sine.

.. _va_waveform.noise:

``noise``

   White noise.

.. _va_waveform.wavetable:

``wavetable``

   Morph across the wavetable bank (see [Synth.loadVaWavetable]).

Constructors
------------

.. code-block:: dart

   VaWaveform(this.native)

Properties
----------

.. code-block:: dart

   final raw.YseVaWaveform native

The raw FFI enum value passed to the C ABI.

