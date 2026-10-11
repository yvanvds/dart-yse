typedef BusFrame
================

.. code-block:: dart

   typedef BusFrame = ({String address, BusValue value});

One `(address, value)` frame delivered by [Bus.subscribe] or [Bus.tap]:
the full bus [address] the value was published on, paired with its typed
[value].

A named record — read the fields directly (`frame.address`, `frame.value`)
or destructure them (`final (:address, :value) = frame;`).

