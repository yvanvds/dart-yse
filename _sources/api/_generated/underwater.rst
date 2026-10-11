Underwater
==========

.. code-block:: dart

   class Underwater extends DspObject

The engine's underwater treatment as an ordinary chainable insert — a
mix-grade [DspObject] that mixes every channel toward a position-neutral,
low-passed average as [depth] grows.

[depth] is the distance below the water surface in world units: `<= 1`
is transparent, `1..5` crossfades, `>= 5` is fully neutral, and negative
values clamp to 0. Writes are allocation- and wait-free.

The wet/dry balance is inherent in [depth], so the inherited [impact] is
**not** applied by this module. It is independent of the engine's own
instance driven by [System.underwaterFx] / [System.underwaterDepth]:
use this one to put the treatment anywhere in your own insert chain.
Attach with `Channel.dsp` or [Sound.setDsp].

Constructors
------------

.. code-block:: dart

   factory Underwater()

Construct an underwater insert at depth 0 (transparent).

Properties
----------

.. code-block:: dart

   double get depth

.. code-block:: dart

   set depth(double value)

Distance below the water surface, in world units (negative clamps to 0).

