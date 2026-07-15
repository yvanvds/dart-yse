PositionHandler
===============

.. code-block:: dart

   class PositionHandler

Which built-in per-note position handler a [Synth] attaches, and its
configuration (issue #23 / engine issue #171 — "the swarm").

A handler gives every voice its own 3D position and movement. Build one
with a factory constructor and pass it to [Synth.setPositionHandler]
*before* the synth is attached/played. All positions are in the same
coordinate frame as a [Sound] position; the shared centre of the spread /
orbit handlers can be steered at runtime with [Synth.setHandlerCenter].

Constructors
------------

.. code-block:: dart

   PositionHandler.fixed(double x, double y, double z)

Every voice sounds from one fixed position `(x, y, z)`.

.. code-block:: dart

   PositionHandler.randomSpread({double radius = 1.0, int seed = 0})

Each voice is scattered to a random point within [radius] of the centre.

A given [seed] reproduces the same scatter.

.. code-block:: dart

   PositionHandler.orbit({double radius = 1.0, double velocityRadius = 0.0, double aftertouchWiden = 0.0, double rate = 1.0, double height = 0.0, double releaseSlow = 1.0})

Each voice orbits the centre — the "swarm".

[radius] is the base orbit radius; [velocityRadius] adds extra radius at
full velocity; [aftertouchWiden] is the fraction of that extra radius
reached at full aftertouch. [rate] is the angular speed in radians per
second, [height] the vertical offset of the orbit plane, and
[releaseSlow] a rate multiplier applied once a note is released.

