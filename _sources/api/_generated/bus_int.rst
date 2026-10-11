BusInt
======

.. code-block:: dart

   class BusInt extends BusValue

A 32-bit integer bus value (`YSE_BUS_INT`).

Constructors
------------

.. code-block:: dart

   BusInt(this.value)

Wrap an integer bus payload.

Properties
----------

.. code-block:: dart

   final int value

The integer payload. Published values must fit a signed 32-bit int.

.. code-block:: dart

   int get hashCode

Methods
-------

.. code-block:: dart

   bool ==(Object other)

.. code-block:: dart

   String toString()

