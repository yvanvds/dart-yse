PNote
=====

.. code-block:: dart

   class PNote implements Finalizable

A [Note] with a time position — the building block of a [Motif].

Position is measured from the start of the containing motif, in
seconds.

Constructors
------------

.. code-block:: dart

   factory PNote({required double position, required double pitch, double volume = 1.0, double length = 0, int channel = 1})

Construct a positioned note.

Properties
----------

.. code-block:: dart

   Pointer<YsePNote> get handle

Internal: native handle.

.. code-block:: dart

   double get position

.. code-block:: dart

   set position(double value)

Time position from the start of the motif, in seconds.

.. code-block:: dart

   double get pitch

.. code-block:: dart

   set pitch(double value)

MIDI pitch.

.. code-block:: dart

   double get volume

.. code-block:: dart

   set volume(double value)

Velocity in `[0, 1]`.

.. code-block:: dart

   double get length

.. code-block:: dart

   set length(double value)

Duration in seconds.

Methods
-------

.. code-block:: dart

   void dispose()

Destroy the underlying native pNote and detach the finalizer.

