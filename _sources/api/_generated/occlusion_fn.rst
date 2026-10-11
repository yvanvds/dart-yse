typedef OcclusionFn
===================

.. code-block:: dart

   typedef OcclusionFn = double Function(Pos source, Pos listener);

Sound-occlusion callback installed with [System.occlusion].

Returns how much geometry sits between [source] and [listener]: 0 for a
clear line of sight, 1 for fully blocked. Both positions are already
multiplied by the engine's distance factor.

