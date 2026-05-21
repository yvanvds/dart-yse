Motif
=====

.. code-block:: dart

   class Motif implements Finalizable

A re-usable phrase or pattern — a sequence of [PNote]s.

Hand it to a [Player] which will trigger it at appropriate moments.

Constructors
------------

.. code-block:: dart

   factory Motif()

Construct an empty motif.

Properties
----------

.. code-block:: dart

   Pointer<YseMotif> get handle

Internal: native handle.

.. code-block:: dart

   set length(double value)

.. code-block:: dart

   double get length

Set the motif length explicitly, in seconds.

.. code-block:: dart

   bool get isEmpty

Whether the motif contains any notes.

.. code-block:: dart

   int get size

Number of notes.

Methods
-------

.. code-block:: dart

   void add(PNote note)

Append a positioned note.

.. code-block:: dart

   void clear()

Remove every note.

.. code-block:: dart

   void autoSetLength()

Set the motif length automatically to the end of the last note.

.. code-block:: dart

   void transpose(double pitch)

Transpose every note by [pitch] semitones.

.. code-block:: dart

   void setFirstPitch(Scale validPitches)

Restrict legal starting pitches.

When the [Player] picks a transposition for this motif it picks one
whose starting note belongs to [validPitches].

.. code-block:: dart

   void dispose()

Destroy the underlying native motif and detach the finalizer.

