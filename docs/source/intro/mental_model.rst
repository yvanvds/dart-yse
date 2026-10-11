Mental model
============

Six concepts cover everything ``dart-yse`` does.

System
------

:class:`System` is the engine itself. Access the singleton through
:py:attr:`System.instance`. It owns the audio device, the engine's
internal worker threads, and the scheduler that turns
:py:meth:`Sound.play` calls into samples on the sound card.

The lifecycle is:

1. ``System.instance.init()`` once at startup.
2. ``System.instance.update()`` once per frame
   (or ``startUpdateTimer()`` to drive it from a periodic ``Timer``).
3. ``System.instance.close()`` once at shutdown.

Between init and close the engine is alive and accepting commands.
**Threading constraint:** every call into ``yse`` must happen on the
same isolate that called ``init()``. The audio callback runs on a
private thread the wrapper never exposes.

**Rendering.** The engine renders audio in fixed blocks of
:py:attr:`System.blockSize` frames (128), whatever the device's
callback size; :py:meth:`System.renderOffline` takes a count of these
blocks. Each block runs through a task-graph scheduler: the audio
thread renders, and worker threads pick up independent parts of the mix
(channels, sounds) in parallel. :py:attr:`System.renderThreads` sets how
many workers there are — ``-1`` (default) for auto (physical cores
minus one, at most 8), ``0`` to render on the audio thread alone (the
right choice on Android and other constrained hardware), or an exact
count. Set it before ``init()``; during a device session a new value
waits for the next init, and it survives ``close()``. The worker count
never changes how the mix is summed, so the output is bit-identical at
any setting. :py:attr:`System.activeRenderThreads` reports the workers
running now.

**Callbacks and threads.** ``update()`` is where most engine-to-host
traffic reaches Dart, but not all of it, and the wrapper bridges each kind
according to the thread the engine calls it on:

.. list-table::
   :header-rows: 1
   :widths: 30 34 36

   * - Callback
     - Engine calls it on
     - Reaches Dart
   * - :py:attr:`System.occlusion`
     - the thread running ``update()``, once per occlusion-enabled sound
     - synchronously, inside ``update()`` (it must return a value)
   * - :py:meth:`Bus.subscribe` / :py:meth:`Bus.tap`
     - the control thread: inline for a host publish, otherwise during
       ``update()``; never the audio thread
     - as stream events, a microtask later
   * - :py:attr:`Patcher.messages`
     - whichever engine thread emitted the message (the control thread for
       ``pass*``, a worker for a timer-driven ``.metro``)
     - asynchronously, through the isolate's event loop
   * - :py:attr:`Log.messages`, :py:attr:`MidiIn.rawMessages` /
       ``parsedMessages``
     - whichever thread logged, or RtMidi's input thread
     - asynchronously, through the isolate's event loop
   * - :py:attr:`LiveCoding.errors`
     - the thread running ``update()``
     - as stream events

Audio-thread hooks (a synth's note-rewrite callback, custom voices, custom
DSP sources) are deliberately not surfaced: the audio thread cannot safely
re-enter Dart. :doc:`sessions_and_devices` covers what ``update()`` does for
devices (the auto-reconnect watchdog runs inside it).

**Randomness.** The engine's random generator (behind ``.random``,
granulator jitter and the LFO random shapes) starts from a fixed seed,
so a patch renders the same output every run. Call
:py:meth:`System.randomSeed` for a different repeatable stream or
:py:meth:`System.randomize` to seed from the clock, before building the
patch or sounds.

Listener
--------

:class:`Listener` is the singleton "ear" in the virtual scene.
Update its :py:attr:`Listener.position` every frame; the engine
computes panning, distance attenuation, and doppler shift relative
to it.

.. code-block:: dart

   Listener.instance.position = Pos(playerX, playerY, playerZ);
   Listener.instance.orient(facingDirection, up: Pos(0, 1, 0));

Sound
-----

:class:`Sound` is a playable instance — one ``Sound`` object per voice
in the scene. The source can be a file
(:py:meth:`Sound.fromFile`), an in-memory buffer
(:py:meth:`Sound.fromBuffer`), or a patcher graph
(:py:meth:`Sound.fromPatcher`). Sounds can move, loop, fade, stop,
seek; the engine de-duplicates the underlying decoded buffer when the
same file is loaded into multiple sounds.

Channel
-------

:class:`Channel` is a node in a mixing tree. Every sound is attached
to a channel; channels can themselves be attached to a parent channel,
forming a tree rooted at :py:attr:`Channel.master`. The render
scheduler (see `System`_) can mix independent channels on different
worker threads, so spreading sounds across channels lets the engine
parallelise mixing across CPU cores.

A small set of pre-built channels (:py:attr:`Channel.master`,
:py:attr:`Channel.music`, :py:attr:`Channel.ambient`,
:py:attr:`Channel.voice`, :py:attr:`Channel.gui`,
:py:attr:`Channel.fx`) is created for you. Use them as-is or as roots
for your own subtrees::

   Channel.master                (all output flows here)
   ├── Channel.music             ← background tracks
   ├── Channel.ambient           ← environment loops
   ├── Channel.voice             ← dialogue
   ├── Channel.gui               ← UI feedback
   └── Channel.fx                ← short SFX

Reverb
------

:class:`Reverb` is a positioned reverb zone — a sphere in the scene
that lends its parameters to any nearby listener. Multiple reverbs
can overlap; the engine blends them by proximity so the listener
transitions smoothly between cave, hall, and bathroom as they walk.

A "global" reverb (:py:attr:`System.globalReverb`) acts as the
fallback everywhere no positioned zone reaches.

Patcher
-------

:class:`Patcher` is a Max/MSP-style modular DSP graph: a collection of
small objects (oscillators, filters, math, MIDI, GUI controls) wired
together by inlets and outlets. Use it when a sound is not a file to
play but a network to evaluate — procedural synthesis, parameter
mapping, generative MIDI.

.. code-block:: dart

   final p = Patcher(mainOutputs: 1);
   final osc = p.createObject(Obj.dSine, args: '440');
   final out = p.createObject(Obj.dDac);
   p.connect(osc, outlet: 0, to: out, inlet: 0);
   final sound = Sound.fromPatcher(p);    // play the patcher as a sound

Graphs can be serialised with :py:meth:`Patcher.dumpJson` and rebuilt
with :py:meth:`Patcher.parseJson` — pair the engine with an external
editor or ship presets as plain text. The full set of registered
object types — every inlet, outlet, parameter, and accepted message
type — is on the :doc:`/api/patcher_objects/index` reference page,
generated directly from the C++ engine source so it can never drift.

Putting it together
-------------------

On every frame the interaction looks like:

1. The application calls ``System.instance.update()`` to advance
   engine state.
2. The application updates :py:attr:`Listener.position` to wherever
   the player / camera is.
3. Sounds attached to channels render through the channel tree.
4. Positioned reverbs nearest the listener are blended into the
   output.

That is the whole picture. Everything else — :class:`DspObject`
effects, :class:`MidiOut`, :class:`MidiIn`, the generative
:class:`Player`, :class:`Patcher` — is built on top of these six
concepts.
