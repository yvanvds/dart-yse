ClipTransport
=============

.. code-block:: dart

   class ClipTransport implements Finalizable

Engine-driven MIDI clip playback (issue #21).

A clip loops a flat, beat-timed [ClipEvent] list against a bound
[DomainClock], dispatched from the audio thread. Because the engine owns
*when* every event fires, playback does not jitter under UI-isolate load
the way a timer-driven `noteOn`/`noteOff` over FFI does.

Wire a clip to one or more sinks — external MIDI-out ports via
[connectMidiOut] (and the [ClipTransport.new] `midiOut` shortcut). Route
the playback with [setEvents] (replaceable while playing; the engine swaps
the list at the next audio-block boundary and still delivers note-offs for
notes sounding across the swap), then [play] / [stop].

Threading (CLAUDE.md): construct and drive this from the [System] isolate.
The audio thread performs the actual dispatch; MIDI sends run on a
dedicated sender thread, so the audio callback never touches the device.

The internal-synth sink (`yse_clip_connect_synth`) is intentionally not
surfaced yet — it needs the `YSE::synth` wrapper tracked by epic #23 to
supply a typed handle. It will be added alongside that wrapper.

Constructors
------------

.. code-block:: dart

   factory ClipTransport(DomainClock clock, {MidiOut? midiOut})

Create a clip bound to [clock], optionally connecting [midiOut] as a
sink in one step.

Throws [YseException] if the native clip cannot be created or if no live
clock owns `clock.name`.

Properties
----------

.. code-block:: dart

   bool get isPlaying

Whether the clip is currently playing.

Methods
-------

.. code-block:: dart

   void bind(DomainClock clock)

Bind (or re-bind) the clip to a live domain [clock] by name. The bound
clock must outlive the clip.

Throws [YseException] if no live clock owns `clock.name`.

.. code-block:: dart

   void connectMidiOut(MidiOut out)

Route this clip's playback to an external MIDI output port. [out] must
already have opened a port. May be called for several ports.

.. code-block:: dart

   void disconnectMidiOut(MidiOut out)

Stop routing this clip to [out].

.. code-block:: dart

   void setEvents(List<ClipEvent> events, {required double loopBeats})

Replace the note-event list and set the loop length in one call.

The swap is safe while [isPlaying]: the engine applies the new list at
the next audio-block boundary and still delivers note-offs for notes
sounding across the swap. [loopBeats] is the loop length in beats; a
value `<= 0` disables looping (the events fire once). Passing an empty
[events] list clears the clip.

.. code-block:: dart

   void play()

Start (or resume) playback.

.. code-block:: dart

   void stop()

Stop playback.

.. code-block:: dart

   void dispose()

Destroy the underlying native clip and detach the finalizer.

