Pos
===

.. code-block:: dart

   class Pos

3D position vector used everywhere YSE needs spatial coordinates —
sound positions, the listener position, reverb-zone centres.

Immutable value type. Construct fresh instances instead of mutating.

Constructors
------------

.. code-block:: dart

   Pos(this.x, this.y, this.z)

Construct a position with explicit components.

.. code-block:: dart

   Pos.zero()

Construct the zero vector.

.. code-block:: dart

   factory Pos.fromNative(yse_pos_t native)

Convert a freshly-returned native [yse_pos_t] struct to a Dart [Pos].

Properties
----------

.. code-block:: dart

   final double x

Cartesian X component.

.. code-block:: dart

   final double y

Cartesian Y component.

.. code-block:: dart

   final double z

Cartesian Z component.

.. code-block:: dart

   int get hashCode

Methods
-------

.. code-block:: dart

   String toString()

.. code-block:: dart

   bool ==(Object other)

