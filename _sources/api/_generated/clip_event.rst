ClipEvent
=========

.. code-block:: dart

   class ClipEvent

One timed note event on a [ClipTransport].

Positioned in beats on the clip's bound [DomainClock]. The engine fires
the note-on at [startBeat] and the matching note-off [durationBeats]
later, all from the audio thread — the Dart side never dispatches a note.

Constructors
------------

.. code-block:: dart

   ClipEvent({required this.startBeat, required this.durationBeats, required this.channel, required this.pitch, this.velocity = 1.0, this.pitchBend = 0.0})

Construct a note event. [velocity] defaults to full, [pitchBend] to none.

Properties
----------

.. code-block:: dart

   final double startBeat

Beat within the loop at which the note starts (`>= 0`).

.. code-block:: dart

   final double durationBeats

Note length in beats.

.. code-block:: dart

   final int channel

MIDI channel, `1..16`.

.. code-block:: dart

   final int pitch

MIDI note number, `0..127`.

.. code-block:: dart

   final double velocity

Velocity, normalized to `[0, 1]`.

.. code-block:: dart

   final double pitchBend

Optional per-note pitch bend in `[-1, 1]` for microtonal voicing;
`0` (the default) applies no bend.

