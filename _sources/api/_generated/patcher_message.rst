PatcherMessage
==============

.. code-block:: dart

   class PatcherMessage

One message a [Patcher] sent to the host, delivered by
[Patcher.messages].

[address] is the name the message was sent to (a `.s` argument or a
`pass*` target). [value] reuses the bus value vocabulary: a bang is a
[BusBang], an int a [BusInt], a float a [BusFloat], and a list or
symbol arrives as a [BusString] holding the space-separated atoms.

Constructors
------------

.. code-block:: dart

   PatcherMessage(this.address, this.value)

Pair an [address] with its [value].

Properties
----------

.. code-block:: dart

   final String address

The name the message was sent to.

.. code-block:: dart

   final BusValue value

The typed payload.

.. code-block:: dart

   int get hashCode

Methods
-------

.. code-block:: dart

   bool ==(Object other)

.. code-block:: dart

   String toString()

