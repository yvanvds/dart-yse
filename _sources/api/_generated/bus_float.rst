BusFloat
========

.. code-block:: dart

   class BusFloat extends BusValue

A 32-bit float bus value (`YSE_BUS_FLOAT`).

Constructors
------------

.. code-block:: dart

   BusFloat(this.value)

Wrap a float bus payload.

Properties
----------

.. code-block:: dart

   final double value

The published float, widened to a Dart [double].

.. code-block:: dart

   int get hashCode

Methods
-------

.. code-block:: dart

   bool ==(Object other)

.. code-block:: dart

   String toString()

