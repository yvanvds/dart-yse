Listener
========

.. code-block:: dart

   class Listener

Singleton 3D listener — the reference point used by the engine to pan
sounds, attenuate by distance, and compute doppler shifts.

Update [position] every frame so velocity and doppler stay coherent.
Access through [Listener.instance].

Static accessors
----------------

.. code-block:: dart

   static Listener get instance

Borrowed singleton accessor.

Properties
----------

.. code-block:: dart

   Pos get position

.. code-block:: dart

   set position(Pos value)

Current listener position in world coordinates.

.. code-block:: dart

   Pos get velocity

Velocity derived from successive [position] updates. Cannot be set directly.

.. code-block:: dart

   Pos get forward

Forward-facing unit vector of the listener.

.. code-block:: dart

   Pos get upward

Upward unit vector of the listener.

Methods
-------

.. code-block:: dart

   void orient(Pos forward, {Pos up = const Pos(0, 1, 0)})

Set the listener orientation.

[up] defaults to (0, 1, 0) — rotation confined to a horizontal plane.

