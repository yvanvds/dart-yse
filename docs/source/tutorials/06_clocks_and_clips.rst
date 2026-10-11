Clocks and clips
================

Goal: run a named beat clock, change its tempo while it plays, and loop a
bar of notes against it into a synth or a MIDI output port.

A **domain clock** (:class:`DomainClock`) counts beats at a tempo. A
**clip** (:class:`ClipTransport`) holds a list of notes placed in beats and
plays them against one clock, on the audio thread. Your Dart code never
schedules a single note: it edits the list and steers the tempo, and the
engine fires each note in the audio block where the clock passes it. That
is why clip playback does not jitter when the UI isolate is busy, the way
a ``Timer`` driving ``noteOn`` / ``noteOff`` over FFI does.

This tutorial walks through ``example/demo20_clocks_clips.dart``. The
complete source is at `example/demo20_clocks_clips.dart
<https://github.com/yvanvds/dart-yse/blob/main/example/demo20_clocks_clips.dart>`_.
It is the Dart counterpart of upstream's
:yse-cpp:`Clocks and clips <tutorials/15_clocks_and_clips.html>` tutorial.

Mental model
------------

- A clock has a **name**, a **tempo** in BPM and a **beat position**. It
  starts at beat 0 when you create it.
- The beat position is the running total of the tempo over time. A tempo
  change alters how fast the beats go by and never makes the position jump.
- The engine advances every clock once per 128-frame block
  (:py:attr:`System.blockSize`), on the audio thread, while a device is
  open (or on each :py:meth:`System.renderOffline` block). The clocks keep
  moving when no sound is playing. They do not move before ``init()`` or
  while the engine is paused.
- A clip is bound to one clock and reads it at the start of every block.
  It fires the notes whose beat falls between the previous block and this
  one, so it is accurate to one block: about 2.7 ms at 48 kHz.

Clocks are shared by name: the host, every clip and every patch in the
process see the same ``'main'`` clock.

Creating and steering a clock
-----------------------------

.. code-block:: dart

   final sys = System.instance;
   sys.init();

   final clock = DomainClock('main', tempo: 120);   // beat 0, 120 BPM

   clock.setTempo(90, ramp: const Duration(seconds: 4));   // glide
   clock.setTempo(140);                                    // jump now

   final beat = clock.beatPosition;
   final bpm = clock.currentTempo;

``DomainClock(name)`` throws :class:`YseException` when a live clock
already owns the name: the first registration wins. The tempo defaults to
120 BPM.

``setTempo(target, ramp:)`` changes the tempo in a straight line over
``ramp``, starting from the tempo the clock has at that moment, so a new
ramp can take over from one still running. With no ramp the change is
instant. The engine picks up tempo requests once per block, so of two
``setTempo`` calls within one block only the second counts.

The tempo is not clamped:

- **0 pauses the clock.** The beat position holds, and the clips on it stop
  firing until the tempo rises again.
- **A negative tempo runs it backwards.** Clips fire nothing while the
  clock goes backwards.

:py:attr:`DomainClock.beatPosition` and :py:attr:`DomainClock.currentTempo`
are cheap reads, fine to poll every frame to draw a playhead. Both return 0
for a disposed clock; :py:attr:`DomainClock.exists` tells the two cases
apart.

Several clocks can run at once, each at its own tempo. They all advance
from the same sample clock, so their ratios stay exact: a clock at 90 BPM
and one at 120 BPM stay at 3:4 for as long as they run.

Playing a clip into a synth
---------------------------

A clip needs a clock, a list of events and at least one target. Here the
target is a :class:`Synth` playing behind a :class:`Sound`:

.. code-block:: dart

   // Add the voices right after Synth().
   final synth = Synth()..addSineVoices(8, attack: 0.01, release: 0.2);
   final sound = Sound.fromSynth(synth, volume: 0.5)..play();

   // One bar of four quarter notes.
   final bar = [
     for (final (i, pitch) in [60, 64, 67, 72].indexed)
       ClipEvent(
         startBeat: i.toDouble(),
         durationBeats: 0.5,
         channel: 1,
         pitch: pitch,
         velocity: 0.8,
       ),
   ];

   final clip = ClipTransport(clock)
     ..connectSynth(synth)
     ..setEvents(bar, loopBeats: 4)
     ..play();

Each :class:`ClipEvent` has:

``startBeat``
   The beat within the loop where the note starts.
``durationBeats``
   The note length. The note-off comes this many beats after the note-on.
``channel``
   MIDI channel, ``1..16`` — the synth's 1-based numbering (see the channel
   table on :doc:`/api/midi`).
``pitch``
   MIDI note number, ``0..127``.
``velocity``
   ``0..1``; defaults to 1.
``pitchBend``
   ``-1..1``, 0 (the default) for none. A non-zero bend is sent as a
   pitch-wheel message on the note's channel just before the note-on: use
   the nearest semitone plus a bend for microtonal pitches.

``ClipTransport(clock)`` binds the clip to the clock by name and throws
``YseException`` if no live clock owns it. :py:meth:`ClipTransport.bind`
rebinds at any time, to the same clock or another; a failed bind throws
and also unbinds the clip, so it goes silent.

Changing a clip while it plays
------------------------------

:py:meth:`ClipTransport.setEvents` replaces the whole list and sets the
loop length. The clip picks up the new list at the next block, without
locking the audio thread, so you can call it as often as the music changes:

.. code-block:: dart

   clip.setEvents(newBar, loopBeats: 4);

A note that is sounding when the list changes still gets its note-off on
time, even if the new list no longer contains it. A ``loopBeats`` of 0 or
less turns looping off, so each event plays once; an empty list clears the
clip.

:py:meth:`ClipTransport.stop` ends playback and sends a note-off for exactly
the notes this clip still has sounding — not a global all-notes-off, so
other clips on the same synth or port keep theirs. ``play()`` starts again,
and :py:attr:`ClipTransport.isPlaying` reports the state.

Timing rules
------------

Event times are measured on the **clock**, not from the moment you call
``play()``. That keeps clips in step with each other, with some
consequences:

- **Loops line up with the clock.** A 4-beat loop plays its beat-0 event at
  clock beats 0, 4, 8 and so on. A clip started at clock beat 5.5 first
  plays its beat-2 event, at clock beat 6. Two clips with the same loop
  length on the same clock are always in phase.
- **A clip without a loop plays each event when the clock reaches its**
  ``startBeat``. An event the clock has already passed never plays. To play
  a phrase once starting "now", add the current position:
  ``startBeat: clock.beatPosition + offset``.
- **The first block after** ``play()`` only records where the clock is, so
  an event exactly on the clock position at that moment is skipped.
- **A paused or reversed clock fires nothing**, not even note-offs. Notes
  that are sounding wait until the clock passes their end again, or until
  you call ``stop()``.
- **Note-offs go before note-ons** within a block, so a note that ends as
  the same pitch starts again is released first.

A tempo change reaches every clip on the clock in the next block. Nothing
is rescheduled: a glide from 120 to 90 BPM bends every clip on that clock
at once.

Targets
-------

A clip sends every note to all of its targets.

**Synths.** :py:meth:`ClipTransport.connectSynth` once per synth, up to 8
per clip; ``disconnectSynth`` stops the routing. The notes reach the synth
on the audio thread, in the block where they fire. The clip holds a Dart
reference to each connected synth, so garbage collection never frees one
under it; don't ``dispose()`` a synth while it is connected.

**MIDI output ports.** On Windows and Linux, a clip can also play to an
external MIDI device, up to 4 ports per clip:

.. code-block:: dart

   final out = MidiOut.open(0);   // an unopened port is ignored
   clip.connectMidiOut(out);      // or ClipTransport(clock, midiOut: out)

The audio thread still decides when each note fires; it hands the message
to a separate sender thread, so the audio callback never waits on the
device. A full sender queue drops a message rather than block. A
:class:`MidiOut` receives the clip's 1-based channel as ``channel - 1`` on
the wire.

Connecting more than 8 synths or 4 ports does nothing: no error, and the
extra targets get no notes.

Lifetime
--------

A clip and its clock can be disposed in either order.

- :py:meth:`DomainClock.dispose` removes the clock. A clip bound to it
  stops firing; it does not crash.
- Creating a new clock with the same name does **not** reconnect old clips.
  Call ``bind`` on each clip again.
- :py:meth:`ClipTransport.dispose` releases the notes the clip is
  sounding, as ``stop()`` does, so dispose the clip first, then the sound,
  then the synth.
- A clip survives ``System.close()``. Closing removes every clock, so the
  clip stops firing, but it stays safe to call and to dispose, and keeps
  its events, loop length and connections. In the next session create the
  clock again and ``bind`` the clip to it.

``DomainClock`` is not garbage-collected into the engine (clocks are keyed
by name, so there is no native pointer to finalize): call ``dispose()``
when you are done with one.

Limits
------

- 256 notes sounding at once per clip; further note-ons are dropped.
- Each event plays at most 64 times in one block. This only matters for a
  very short loop at a very high tempo.
- 8 synths and 4 MIDI ports per clip.

Clocks in a patch
-----------------

Patcher objects use the same clocks by name: ``.transport`` and
``.setclock`` create clocks, and ``.tempo``, ``.metro``, ``.delay`` and the
other timed objects can count beats on them. A clip and a patch on the same
clock fire in the same block. See the :doc:`time objects
</api/patcher_objects/time>` in the object reference.

What you learned
----------------

- A :class:`DomainClock` is a named beat counter. Its tempo can jump,
  glide, pause and run backwards, and its beat position never jumps.
- A :class:`ClipTransport` plays a list of beat-timed :class:`ClipEvent`\ s
  against a clock, on the audio thread, accurate to one block.
- Loops line up with the clock's beats, not with the moment you press play.
- ``setEvents`` swaps the list while the clip plays, and sounding notes
  still end on time.
- A clip and its clock can be disposed in either order; stopping or
  disposing a clip releases the notes it is sounding.

Next
----

- :doc:`/api/clip` and :doc:`/api/core` — the :class:`ClipTransport` and
  :class:`DomainClock` reference.
- :doc:`/api/synth` — voice pools for the clip to play on.
