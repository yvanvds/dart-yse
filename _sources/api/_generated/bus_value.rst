BusValue
========

.. code-block:: dart

   class BusValue

A value carried on the engine's global named bus — what [Bus.publish]
sends and what [Bus.subscribe] / [Bus.tap] deliver.

The concrete subtype encodes which of the engine's five bus payload kinds
it is — [BusBang], [BusInt], [BusFloat], [BusString], or [BusList].
Because the type is sealed, an exhaustive `switch` over a [BusValue] needs
no default case; pattern-match each subtype to read its payload
(`value` for the scalar kinds, `values` for [BusList]).

Constructors
------------

.. code-block:: dart

   BusValue()

