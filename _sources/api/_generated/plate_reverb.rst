PlateReverb
===========

.. code-block:: dart

   class PlateReverb extends DspObject

Dattorro plate reverb — a mix-grade [DspObject] for a channel insert or a
send return.

Distinct from the engine's global spatial [Reverb]. `impact(0.25)` is a
natural insert mix; `impact(1)` is fully wet for send-return use. Attach
with `Channel.dsp` or [Sound.setDsp].

Constructors
------------

.. code-block:: dart

   factory PlateReverb()

Construct a plate reverb with the engine's default tail.

Properties
----------

.. code-block:: dart

   double get decay

.. code-block:: dart

   set decay(double value)

Tail decay (feedback) in `[0.0, 1.0)`.

.. code-block:: dart

   double get damping

.. code-block:: dart

   set damping(double hz)

High-frequency damping corner in Hz.

.. code-block:: dart

   double get predelay

.. code-block:: dart

   set predelay(double ms)

Pre-delay before the tail begins, in milliseconds.

