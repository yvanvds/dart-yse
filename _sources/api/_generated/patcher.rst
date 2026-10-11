Patcher
=======

.. code-block:: dart

   class Patcher implements Finalizable

Modular DSP/event graph (Max/MSP-style patcher).

Build a graph programmatically with [createObject] + [connect], or
load one from a JSON dump via [parseJson]. Drive it directly with
[passBang] / [passInt] / [passFloat] / [passString] into named
`.r` (`Obj.gReceive`) objects, or hand it to a [Sound] via
[Sound.fromPatcher] to use it as an audio source.

Constructors
------------

.. code-block:: dart

   factory Patcher({int mainOutputs = 2})

Construct a patcher with [mainOutputs] audio output channels.

Throws [YseException] if the engine rejects the configuration (e.g. a
negative [mainOutputs]).

Properties
----------

.. code-block:: dart

   Pointer<YsePatcher> get handle

Internal: native handle (used by `Sound.fromPatcher`).

.. code-block:: dart

   int get objects

Number of objects in the patcher.

Methods
-------

.. code-block:: dart

   PHandle createObject(String type, {String args = ''})

Add an object of [type] to the patcher (see [Obj] for constants).

[args] is the creation argument string (object-specific format).
The returned [PHandle] is owned by the patcher — release with
[deleteObject], never directly.

.. code-block:: dart

   void deleteObject(PHandle obj)

Remove [obj] from the patcher.

.. code-block:: dart

   void clear()

Remove every object from the patcher.

.. code-block:: dart

   void connect(PHandle from, {required int outlet, required PHandle to, required int inlet})

Connect [from]'s [outlet] to [to]'s [inlet].

.. code-block:: dart

   void disconnect(PHandle from, {required int outlet, required PHandle to, required int inlet})

Remove the connection from [from]'s [outlet] to [to]'s [inlet].

.. code-block:: dart

   String dumpJson()

Serialise the current graph to JSON.

.. code-block:: dart

   void parseJson(String content)

Load a JSON dump (as produced by [dumpJson]) into this patcher.

Loading **adds to** the current graph: objects already in the patcher
are kept and the loaded ones are created next to them. Call [clear]
first to replace the patch.

Throws [YseException] if [content] is malformed JSON or not a patch.
A failed load is rolled back: the patcher is left exactly as it was.

.. code-block:: dart

   PHandle getHandleAt(int index)

Object at position [index] in the list (0-indexed).

.. code-block:: dart

   PHandle getHandleById(int id)

Object whose ID is [id].

.. code-block:: dart

   bool passBang(String to)

Send a bang to the named `.r` receive object. Returns false if no
such receiver exists.

.. code-block:: dart

   bool passInt(int value, String to)

Send an integer to a named receiver.

.. code-block:: dart

   bool passFloat(double value, String to)

Send a float to a named receiver.

.. code-block:: dart

   bool passString(String value, String to)

Send a string to a named receiver.

.. code-block:: dart

   void dispose()

Destroy the underlying native patcher and detach the finalizer.

