ReverbPresetValues
==================

.. code-block:: dart

   class ReverbPresetValues

A complete reverb parameter set — the full payload behind a named
[ReverbPreset], and the custom endpoint type for a [MorphingReverb] slot.

Immutable value type. Mirrors the C `YseReverbPresetValues` (itself a
plain-data mirror of `YSE::REVERB::presetValues`). [earlyTimes] and
[earlyGains] each describe the four early reflections and are always
length 4.

Constructors
------------

.. code-block:: dart

   ReverbPresetValues({this.roomSize = 0, this.damping = 0, this.dry = 0, this.wet = 0, this.modulationFrequency = 0, this.modulationWidth = 0, List<double>? earlyTimes, List<double>? earlyGains})

Construct a parameter set. [earlyTimes] and [earlyGains], when supplied,
must each have exactly four elements; both default to all-zero.

.. code-block:: dart

   factory ReverbPresetValues.fromNative(YseReverbPresetValues native)

Read a native `YseReverbPresetValues` struct into a Dart value.

.. code-block:: dart

   factory ReverbPresetValues.fromPreset(ReverbPreset preset)

The exact parameter set that `Reverb.preset = preset` applies, read from
the engine's preset table. Needs the library but no engine session.

Static methods
--------------

.. code-block:: dart

   static ReverbPresetValues lerp(ReverbPresetValues a, ReverbPresetValues b, double t)

Linear blend of [a] and [b]: every field is interpolated with [t]
clamped to `[0, 1]`, so `t == 0` returns [a] and `t == 1` returns [b]
exactly. Delegates to the engine's own morph core, so the result is
bit-identical to what a [MorphingReverb] computes. Needs the library but
no engine session.

Properties
----------

.. code-block:: dart

   final double roomSize

Simulated room size, `[0, 1]`. Larger values give longer tails.

.. code-block:: dart

   final double damping

High-frequency damping, `[0, 1]`.

.. code-block:: dart

   final double dry

Unprocessed (dry) signal level, `[0, 1]`.

.. code-block:: dart

   final double wet

Reverberated (wet) signal level, `[0, 1]`.

.. code-block:: dart

   final double modulationFrequency

Tail modulation rate in Hz (`0` = off).

.. code-block:: dart

   final double modulationWidth

Tail modulation depth (`0` = off).

.. code-block:: dart

   final List<double> earlyTimes

The four early-reflection delay times, in samples (`[0, 2999]`).

.. code-block:: dart

   final List<double> earlyGains

The four early-reflection gains, `[0, 1]`.

.. code-block:: dart

   int get hashCode

Methods
-------

.. code-block:: dart

   bool ==(Object other)

.. code-block:: dart

   String toString()

