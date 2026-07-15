enum InletAccepts
=================

.. code-block:: dart

   enum InletAccepts

One message kind a patcher inlet accepts ([PatcherInlet.accepts]).

The engine reports the set as an OR-ed bitmask; the wrapper decodes it
into a `Set<InletAccepts>`. Values match `YSE::PATCHER::InletType`
(mirrored by the C enum `YseInletAccepts`).

Values
------

.. _inlet_accepts.buffer:

``buffer``

   Accepts an audio-rate DSP buffer.

.. _inlet_accepts.float:

``float``

   Accepts a float.

.. _inlet_accepts.integer:

``integer``

   Accepts an integer.

.. _inlet_accepts.bang:

``bang``

   Accepts a bang.

.. _inlet_accepts.list:

``list``

   Accepts a list.

Constructors
------------

.. code-block:: dart

   InletAccepts(this.native)

Static methods
--------------

.. code-block:: dart

   static Set<InletAccepts> fromBitmask(int mask)

Decodes an engine `accepts` bitmask into the set of flags it encodes.

Properties
----------

.. code-block:: dart

   final raw.YseInletAccepts native

