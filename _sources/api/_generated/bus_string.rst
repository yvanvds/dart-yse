BusString
=========

.. code-block:: dart

   class BusString extends BusValue

A string bus value (`YSE_BUS_STRING`, NUL-terminated UTF-8 engine-side).

Constructors
------------

.. code-block:: dart

   BusString(this.value)

Wrap a string bus payload.

Properties
----------

.. code-block:: dart

   final String value

The published string, copied out of engine-owned memory.

.. code-block:: dart

   int get hashCode

Methods
-------

.. code-block:: dart

   bool ==(Object other)

.. code-block:: dart

   String toString()

