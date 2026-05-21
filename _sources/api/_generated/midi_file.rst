MidiFile
========

.. code-block:: dart

   class MidiFile implements Finalizable

Standard MIDI-file playback.

Load a `.mid` file with [load], then control playback with
[play] / [pause] / [stop].

Constructors
------------

.. code-block:: dart

   factory MidiFile(String filename)

Load [filename] and prepare for playback. Throws [YseException]
on failure.

Methods
-------

.. code-block:: dart

   void play()

Start or resume playback.

.. code-block:: dart

   void pause()

Pause playback. Resume with [play].

.. code-block:: dart

   void stop()

Stop playback and rewind to the start.

.. code-block:: dart

   void dispose()

Destroy the underlying native file and detach the finalizer.

