MorphingReverb
==============

.. code-block:: dart

   class MorphingReverb extends DspObject

The engine's zone/global reverb core packaged as a chainable insert whose
preset blend is a control input (upstream #369) — a mix-grade [DspObject].

Two endpoints, slot A and slot B, are each either a named [ReverbPreset]
(via [presetA] / [presetB]) or a custom [ReverbPresetValues] (via
[presetAValues] / [presetBValues]). [morph] linearly interpolates between
them (`0` = pure A, `1` = pure B, clamped to `[0, 1]`). Defaults are
A = [ReverbPreset.generic], B = [ReverbPreset.hall], [morph] = 0.

[morph] is a control-rate signal: writes are allocation- and click-free, so
any control thread may sweep it. Its wet/dry balance rides the morphed
presets (each carries its own `dry`/`wet`), so the inherited [impact] is
**not** applied — for send/return use, give both slots custom values with
`dry = 0`, `wet = 1`. Attach with `Channel.dsp` or [Sound.setDsp].

Constructors
------------

.. code-block:: dart

   factory MorphingReverb()

Construct a morphing reverb (A = generic, B = hall, morph = 0).

Properties
----------

.. code-block:: dart

   set presetA(ReverbPreset value)

Set slot A from a named [ReverbPreset].

.. code-block:: dart

   set presetB(ReverbPreset value)

Set slot B from a named [ReverbPreset].

.. code-block:: dart

   ReverbPresetValues get presetAValues

.. code-block:: dart

   set presetAValues(ReverbPresetValues values)

Slot A's current parameter set.

.. code-block:: dart

   ReverbPresetValues get presetBValues

.. code-block:: dart

   set presetBValues(ReverbPresetValues values)

Slot B's current parameter set.

.. code-block:: dart

   double get morph

.. code-block:: dart

   set morph(double value)

The morph control input: `0` = pure slot A, `1` = pure slot B, clamped
to `[0, 1]`.

