DspObject
=========

.. code-block:: dart

   class DspObject implements Finalizable

A chainable DSP effect module — wraps `YSE::DSP::dspObject` and its
concrete subclasses (filters, delays, modulators).

Construct via the named factory matching the effect you need
(e.g. [DspObject.lowpass], [DspObject.sweep], [DspObject.granulator]),
then call the matching `set*` methods to configure parameters.

Inherited control surface ([bypass], [impact], [lfoType],
[lfoFrequency], [link]) is available on every instance.

Attach to a [Sound] with [Sound.setDsp]. The Sound holds a borrowed
reference — the effect must outlive the sound (and per the YSE
lifetime contract, also outlive the slow-pool delete tick that
follows the sound's destruction).

Subclass-specific setters are unsafe to call on the wrong subclass:
just like the C++ API, the underlying type is `static_cast`-ed
without an RTTI check.

Constructors
------------

.. code-block:: dart

   factory DspObject.lowpass()

Low-pass filter.

.. code-block:: dart

   factory DspObject.highpass()

High-pass filter.

.. code-block:: dart

   factory DspObject.bandpass()

Resonant band-pass filter.

.. code-block:: dart

   factory DspObject.sweep({SweepShape shape = SweepShape.saw})

Auto-wah / LFO-modulated resonant filter.

.. code-block:: dart

   factory DspObject.basicDelay()

Three-tap delay line.

.. code-block:: dart

   factory DspObject.lowpassDelay()

Three-tap delay with a low-pass filter in front (tape-style).

.. code-block:: dart

   factory DspObject.highpassDelay()

Three-tap delay with a high-pass filter in front.

.. code-block:: dart

   factory DspObject.phaser()

Four-stage all-pass cascade modulated by a triangle LFO.

.. code-block:: dart

   factory DspObject.ringModulator()

Ring modulator — multiplies input by an internal sine carrier.

.. code-block:: dart

   factory DspObject.difference()

FM difference-tone synthesis (clipper + sine carrier).

.. code-block:: dart

   factory DspObject.granulator({int poolSize = 44100 * 5, int maxGrains = 16})

Granular synthesis — pool of recent input, spawn short grains.

[poolSize] is the size of the circular input buffer in samples
(default ~5s at 44.1kHz). [maxGrains] is the maximum number of
grains alive simultaneously.

Properties
----------

.. code-block:: dart

   Pointer<YseDspObject> get handle

Internal: native handle (used by `Sound.setDsp`).

.. code-block:: dart

   bool get bypass

.. code-block:: dart

   set bypass(bool value)

Bypass this effect. Bypassed effects still run but pass input through
unchanged.

.. code-block:: dart

   double get impact

.. code-block:: dart

   set impact(double value)

Wet/dry mix in `[0.0, 1.0]`. 0 is fully dry, 1 is fully processed.

.. code-block:: dart

   LfoType get lfoType

.. code-block:: dart

   set lfoType(LfoType value)

Built-in modulation LFO shape. [LfoType.none] disables modulation.

.. code-block:: dart

   double get lfoFrequency

.. code-block:: dart

   set lfoFrequency(double value)

Built-in modulation LFO frequency in Hz.

.. code-block:: dart

   double get frequency

.. code-block:: dart

   set frequency(double value)

Cutoff (lowpass/highpass) or centre (bandpass/sweep) frequency in Hz.

.. code-block:: dart

   double get q

.. code-block:: dart

   set q(double value)

Bandpass-only: filter resonance (Q factor).

.. code-block:: dart

   double get sweepSpeed

.. code-block:: dart

   set sweepSpeed(double value)

Sweep-only: LFO speed in Hz.

.. code-block:: dart

   int get sweepDepth

.. code-block:: dart

   set sweepDepth(int value)

Sweep-only: depth as 0..100.

.. code-block:: dart

   int get sweepCentre

.. code-block:: dart

   set sweepCentre(int value)

Sweep-only: centre frequency as 0..100.

.. code-block:: dart

   double get phaserRange

.. code-block:: dart

   set phaserRange(double value)

Phaser-only: sweep range coefficient.

.. code-block:: dart

   double get differenceAmplitude

.. code-block:: dart

   set differenceAmplitude(double value)

Difference-only: carrier amplitude.

.. code-block:: dart

   int get grainFrequency

.. code-block:: dart

   set grainFrequency(int value)

Granulator: spawn rate in grains per second.

.. code-block:: dart

   int get grainLength

Granulator: the base grain length in samples (the [samples] argument
last passed to [setGrainLength], without the per-grain randomisation).

.. code-block:: dart

   double get grainTranspose

Granulator: the base pitch shift (the [pitch] argument last passed to
[setGrainTranspose], without the per-grain randomisation).

.. code-block:: dart

   double get grainGain

.. code-block:: dart

   set grainGain(double value)

Granulator: output gain.

Methods
-------

.. code-block:: dart

   void link(DspObject next)

Insert [next] after this object in the processing chain.

.. code-block:: dart

   void setDelayTap(DelayTap tap, {required double timeMs, required double gain})

basicDelay / lowpassDelay / highpassDelay: configure one of three taps.

.. code-block:: dart

   double delayTime(DelayTap tap)

Current delay time of [tap] in milliseconds.

.. code-block:: dart

   double delayGain(DelayTap tap)

Current gain of [tap].

.. code-block:: dart

   void setGrainLength({required int samples, int random = 0})

Granulator: grain length in samples. [random] adds variation
around [samples].

.. code-block:: dart

   void setGrainTranspose({required double pitch, double random = 0})

Granulator: pitch shift (1.0 = unchanged, 2.0 = octave up).
[random] adds variation.

.. code-block:: dart

   void dispose()

Destroy the underlying native effect and detach the finalizer.

