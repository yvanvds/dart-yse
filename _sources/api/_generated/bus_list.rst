BusList
=======

.. code-block:: dart

   class BusList extends BusValue

A list of 32-bit floats (`YSE_BUS_LIST`).

Constructors
------------

.. code-block:: dart

   BusList(this.values)

Wrap a float-list bus payload.

Properties
----------

.. code-block:: dart

   final List<double> values

The published floats, copied out of engine-owned memory. May be empty.

.. code-block:: dart

   int get hashCode

Methods
-------

.. code-block:: dart

   bool ==(Object other)

.. code-block:: dart

   String toString()

