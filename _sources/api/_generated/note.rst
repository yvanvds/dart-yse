Note
====

.. code-block:: dart

   class Note implements Finalizable

A single musical event — pitch, volume, length, MIDI channel.

The fundamental unit for the music subsystem: [Motif]s are sequences
of [PNote]s (positioned [Note]s), and the [Player] generates notes
within a [Scale] constraint.

Constructors
------------

.. code-block:: dart

   factory Note({double pitch = 60, double volume = 1.0, double length = 0, int channel = 1})

Construct a note.

[pitch] is a MIDI pitch (60 = middle C). [volume] is velocity in
`[0, 1]`. [length] is the duration in seconds (0 = engine default).
[channel] is the MIDI channel.

Properties
----------

.. code-block:: dart

   Pointer<YseNote> get handle

Internal: native handle.

.. code-block:: dart

   double get pitch

.. code-block:: dart

   set pitch(double value)

MIDI pitch (60 = middle C).

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

.. code-block:: dart

   int get channel

.. code-block:: dart

   set channel(int value)

MIDI channel.

Methods
-------

.. code-block:: dart

   void set({required double pitch, double volume = 1.0, double length = 0, int channel = 1})

Replace all four fields in one call.

.. code-block:: dart

   void dispose()

Destroy the underlying native note and detach the finalizer.

