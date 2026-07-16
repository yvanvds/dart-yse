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

   void connectSynth(Synth synth)

Route this file's playback into an internal [synth] (upstream #372).

While the file plays, every note / controller / pitch-bend event it
contains is delivered to [synth] block-accurately on the audio thread.
May be called for several synths (up to a small fixed cap) to drive them
together; re-connecting an already-connected synth is a no-op. [synth]
must outlive the connection — [disconnectSynth] it (or dispose this file)
before disposing the synth.

.. code-block:: dart

   void disconnectSynth(Synth synth)

Stop routing this file's playback into [synth]. Safe to call for a synth
that was never connected.

.. code-block:: dart

   void dispose()

Destroy the underlying native file and detach the finalizer.

