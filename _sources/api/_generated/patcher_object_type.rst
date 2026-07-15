PatcherObjectType
=================

.. code-block:: dart

   class PatcherObjectType

Read-only metadata for one registered patcher object type.

Obtain one from [PatcherRegistry.type] / [PatcherRegistry.types]. Every
accessor reads live from the engine registry; the strings returned are
copied out of engine-owned storage (never freed by the caller).

Properties
----------

.. code-block:: dart

   final String name

The type identifier (matches one of the [Obj] constants).

.. code-block:: dart

   String get description

One-line human-readable description of the object.

.. code-block:: dart

   PCategory get category

Documentation category the object is filed under.

.. code-block:: dart

   bool get isDsp

Whether this is a DSP / audio-rate object (the `~` prefix convention).

.. code-block:: dart

   int get inletCount

Number of inlets on this object type.

.. code-block:: dart

   int get outletCount

Number of outlets on this object type.

.. code-block:: dart

   int get paramCount

Number of creation parameters this object type documents.

Methods
-------

.. code-block:: dart

   PatcherInlet inletAt(int idx)

Metadata for the inlet at [idx] (0-based).

.. code-block:: dart

   List<PatcherInlet> inlets()

Metadata for every inlet, in order.

.. code-block:: dart

   PatcherOutlet outletAt(int idx)

Metadata for the outlet at [idx] (0-based).

.. code-block:: dart

   List<PatcherOutlet> outlets()

Metadata for every outlet, in order.

.. code-block:: dart

   PatcherParam paramAt(int idx)

Metadata for the creation parameter at [idx] (0-based).

.. code-block:: dart

   List<PatcherParam> params()

Metadata for every creation parameter, in order.

.. code-block:: dart

   String toString()

