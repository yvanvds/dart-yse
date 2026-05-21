BufferIO
========

.. code-block:: dart

   class BufferIO implements Finalizable

Feeds sound files into the engine from in-memory byte buffers.

Register raw bytes under string IDs, then load sounds by passing
those IDs where a file path would normally go
([Sound.fromFile] with the ID as the filename). Typical use is
bundling audio assets inside a game-engine resource pack or an
Android APK where the regular file system isn't accessible.

**Important**: by default ([storeCopy] = false) the engine retains
a pointer to the caller's bytes; the Dart wrapper allocates a
permanent native copy when you [addAsset] so the GC-managed
[Uint8List] you pass in doesn't have to outlive the registration.
If you want zero-copy behaviour, call the C ABI directly.

Constructors
------------

.. code-block:: dart

   factory BufferIO({bool storeCopy = false})

Construct a BufferIO layer.

[storeCopy] tells the *engine* whether to copy when it adds a
buffer. The Dart wrapper always allocates a permanent native
copy of the bytes in [addAsset], so the engine's storeCopy flag
is mostly cosmetic — leave at false unless you know why you'd
want both layers copying.

Properties
----------

.. code-block:: dart

   bool get active

.. code-block:: dart

   set active(bool value)

Whether this layer is currently servicing sound-load requests.

Methods
-------

.. code-block:: dart

   bool exists(String id)

Whether an asset is registered under [id].

.. code-block:: dart

   bool addAsset(String id, Uint8List bytes)

Register [bytes] under [id]. Sounds can then be created by passing
[id] where a filename would normally go.

The wrapper allocates a permanent native copy of [bytes] and
retains it until [removeAsset] is called or this BufferIO is
disposed — the [bytes] argument may be a transient buffer.

.. code-block:: dart

   bool removeAsset(String id)

Unregister the asset at [id]. Returns true if it was registered.

.. code-block:: dart

   void dispose()

Destroy the underlying native layer, detach the finalizer, and
free every wrapper-owned asset buffer.

