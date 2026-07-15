PatcherRegistry
===============

.. code-block:: dart

   class PatcherRegistry

Read-only registry of every patcher object type the engine knows about.

The registry is the introspection surface behind the engine's own
patcher reference: it enumerates the object types
[Patcher.createObject] accepts and, per type, the documentation
metadata (description, category, and the inlet / outlet / parameter
schema). Use it to build a node palette or generate documentation
without hard-coding the catalogue.

All members are static; there is a single process-wide registry.

Threading: main-thread only, and **not** real-time safe — never call
from the audio callback (CLAUDE.md Boundaries). The engine builds its
metadata cache lazily on the first call and keeps it for the life of
the process.

Static accessors
----------------

.. code-block:: dart

   static int get typeCount

Number of registered object types.

Static methods
--------------

.. code-block:: dart

   static String typeNameAt(int index)

Type identifier at [index] in the registry (0-based, lexicographic).

Returns the empty string when [index] is out of range.

.. code-block:: dart

   static List<String> typeNames()

Every registered type identifier, in registry (lexicographic) order.

.. code-block:: dart

   static PatcherObjectType? type(String typeName)

Metadata handle for [typeName], or `null` if the registry has no such
type. Compare against [Obj] constants, e.g. `PatcherRegistry.type(Obj.dSine)`.

.. code-block:: dart

   static List<PatcherObjectType> types()

Every registered type as a metadata handle, in registry order.

.. code-block:: dart

   static String metadataJson()

A fresh JSON snapshot of every registered object's full metadata.

The engine allocates the buffer per call; this getter releases it
through `yse_free_string` before returning, so no native memory
leaks. Returns the empty string if the engine reports an allocation
failure.

