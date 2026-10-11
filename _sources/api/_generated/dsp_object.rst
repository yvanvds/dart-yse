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

Attach to a [Sound] with [Sound.setDsp]. The engine holds a borrowed
reference — the effect must outlive the sound (and per the YSE
lifetime contract, also outlive the slow-pool delete tick that
follows the sound's destruction). The Dart side holds the attached head
and every object [link]ed after it, so garbage collection never frees a
chain under a live sound or channel.

Kind-specific accessors (e.g. [q], [sweepSpeed], [setDelayTap],
[grainGain]) throw [YseException] when called on the wrong kind of
effect. The underlying C entry points `static_cast` the handle without an
RTTI check, so the wrapper checks the kind before calling into native
code. Mix-grade modules ([Compressor], [ParametricEq], ...) are typed
subclasses, so their own accessors exist only on the right type.

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

   factory DspObject.granulator({int poolSize = 48000 * 5, int maxGrains = 16})

Granular synthesis — pool of recent input, spawn short grains.

[poolSize] is the size of the circular input buffer in samples
(default 5 s at 48 kHz, the libYSE 3 default session rate; size it
from `System.sessionSampleRate` when the session runs at another
rate). [maxGrains] is the maximum number of grains alive
simultaneously.

.. code-block:: dart

   factory DspObject.patcherInsert(Patcher patcher)

Wrap a [Patcher] graph as a chainable insert effect (upstream #370).

The insert feeds the host buffer to the graph's `~adc` objects and copies
the summed `~dac` output back over it, so [patcher] should contain at
least one of each. The insert *borrows* [patcher] — it never owns or
destroys it, so [patcher] must outlive this object. The insert holds a
Dart reference to [patcher], so garbage collection never frees it under
a live insert; don't `.dispose()` it first. Drive it with the inherited
control surface ([bypass], [impact], ...).

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

   DspObject? get next

The object linked after this one in its processing chain, or `null` at
the end of the chain — so a chain can be walked:

.. code-block:: dart

   for (DspObject? fx = head; fx != null; fx = fx.next) { ... }


The result is the *same* Dart object that was passed to [link]
(`identical(a.next, b)` after `a.link(b)`), with its subclass intact —
never a new wrapper. It is read from the engine, so it reflects the
engine's own relinking: [link] inserts *between* this object and its
old successor, and disposing a chained object splices it out.

Throws [StateError] if the engine reports a successor that no live
[DspObject] wraps. Each object holds its linked successor, so this only
happens for a chain rewired outside this API.

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

Throws [YseException] on any other kind.

.. code-block:: dart

   double get sweepSpeed

.. code-block:: dart

   set sweepSpeed(double value)

Sweep-only: LFO speed in Hz. Throws [YseException] on any other kind.

.. code-block:: dart

   int get sweepDepth

.. code-block:: dart

   set sweepDepth(int value)

Sweep-only: depth as 0..100. Throws [YseException] on any other kind.

.. code-block:: dart

   int get sweepCentre

.. code-block:: dart

   set sweepCentre(int value)

Sweep-only: centre frequency as 0..100. Throws [YseException] on any
other kind.

.. code-block:: dart

   double get phaserRange

.. code-block:: dart

   set phaserRange(double value)

Phaser-only: sweep range coefficient. Throws [YseException] on any
other kind.

.. code-block:: dart

   double get differenceAmplitude

.. code-block:: dart

   set differenceAmplitude(double value)

Difference-only: carrier amplitude. Throws [YseException] on any other
kind.

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

   void link(DspObject? next)

Insert [next] after this object in the processing chain.

Passing `null` detaches this object's forward edge, terminating the
chain at this object (tail termination). This is what lets a chain be
re-linked into a new order without a former non-tail element keeping a
stale `next` that closes a cycle when the engine walks it (upstream
yvanvds/yse-soundengine#391).

The engine only borrows linked objects. Each object holds a Dart
reference to the one linked after it (following the engine's own
insert-between, unlink and splice-on-dispose rewiring), so a chain whose
head is held — by a [Sound], a `Channel` or your own variable — keeps
every link alive (#84).

.. code-block:: dart

   void unlink()

Detach this object's forward edge, terminating the chain here.

Convenience for `link(null)` — see [link]. The detached successor is no
longer held by this object.

.. code-block:: dart

   void setDelayTap(DelayTap tap, {required double timeMs, required double gain})

basicDelay / lowpassDelay / highpassDelay: configure one of three taps.

Throws [YseException] on any other kind.

.. code-block:: dart

   double delayTime(DelayTap tap)

Current delay time of [tap] in milliseconds (delay kinds only).

.. code-block:: dart

   double delayGain(DelayTap tap)

Current gain of [tap] (delay kinds only).

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

A chained object is spliced out: its predecessor is relinked to its
successor, and from then on holds that successor instead.

