Synth
=====

.. code-block:: dart

   class Synth implements Finalizable

A polyphonic synthesiser voice pool rendered behind one [Sound]
(issue #23 / engine issues #145–#149).

A synth owns polyphony, voice allocation, voice stealing and full
keyboard/pedal state; you drive it with note, controller and pedal events.
The usual flow is:

1. Build a voice pool from a built-in voice type — [addSineVoices],
   [addVaVoices], [addFmVoices] or [addSamplerVoices].
2. Wrap it in a positioned sound with `Sound.fromSynth` (the synth must
   outlive that sound).
3. Play notes with [noteOn] / [noteOff].

Voice cloning happens off the audio thread on the engine's setup pool, so
a synth becomes playable a short moment *after* an `addVoices` call
returns — poll [voiceCount] for the cloned count, exactly as a file-backed
[Sound] is not playable until its buffer finishes loading. Voices must be
added before the synth is attached/played; adding a group afterwards is
rejected.

Channels follow the engine convention: `0` = omni (all channels), `1..16`
address a specific MIDI channel. Velocity, controller and aftertouch
values are normalised to `[0, 1]`; the pitch wheel to `[-1, 1]`.

Threading (CLAUDE.md): construct and drive this from the [System] isolate.
The engine's audio-thread note-rewrite hook (`yse_synth_set_note_callback`)
is intentionally not surfaced — it fires on the audio thread, which cannot
safely re-enter Dart, the same reason custom voices and position handlers
stay unwrapped.

Constructors
------------

.. code-block:: dart

   factory Synth()

Create and register a synth, ready to receive voices and note events.

Throws [YseException] if the native synth cannot be allocated.

Properties
----------

.. code-block:: dart

   bool get isValid

Whether the synth has a live native implementation.

.. code-block:: dart

   int get voiceCount

Total number of allocated (cloned) voices across every group. Zero until
the setup pool finishes cloning — poll this to know the synth is
playable.

.. code-block:: dart

   Pointer<YseSynth> get handle

Raw native handle, for sibling wrappers within `lib/src/` (e.g.
`ClipTransport.connectSynth`). Not part of the public API surface.

Methods
-------

.. code-block:: dart

   void addSineVoices(int count, {int channel = 0, int lowestNote = 0, int highestNote = 127, double attack = 0.01, double decay = 0.1, double sustain = 0.8, double release = 0.2})

Add a group of [count] built-in sine voices (a sine oscillator shaped by
an ADSR envelope) responding to note numbers in `[lowestNote,
highestNote]` on [channel] (`0` = omni). May be called several times to
build layered or split keyboards. [attack], [decay] and [release] are in
seconds; [sustain] is a level in `[0, 1]`.

Must be called before the synth is played. Throws [YseException] if the
group is rejected.

.. code-block:: dart

   void addSamplerVoices(SfzInstrument instrument, int count, {int channel = 0, int lowestNote = 0, int highestNote = 127})

Add a group of [count] SFZ sampler voices rendering [instrument],
responding to note numbers in `[lowestNote, highestNote]` on [channel]
(`0` = omni). Filtering by [channel] lets a sampler pool respond only to
events broadcast on its MIDI channel — e.g. per-voice routing from a
[ClipTransport].

The instrument's region table and PCM are shared with the voice group,
which retains its own reference — so [instrument] may be disposed right
after this returns. Throws [YseException] if the group is rejected.

.. code-block:: dart

   void addVaVoices(int count, {int channel = 0, int lowestNote = 0, int highestNote = 127})

Add a group of [count] virtual-analog + wavetable voices with a fresh
default patch, responding to note numbers in `[lowestNote, highestNote]`
on [channel] (`0` = omni). Filtering by [channel] lets a VA pool respond
only to events broadcast on its MIDI channel — e.g. per-voice routing
from a [ClipTransport].

Establishes the synth's VA patch, which the `setVa*` setters steer. Call
once per synth. Throws [YseException] on failure.

.. code-block:: dart

   void addFmVoices(int count, {int channel = 0, int lowestNote = 0, int highestNote = 127})

Add a group of [count] DX7-class 6-operator FM voices with the built-in
sine test patch, responding to note numbers in `[lowestNote, highestNote]`
on [channel] (`0` = omni). Filtering by [channel] lets an FM pool respond
only to events broadcast on its MIDI channel — e.g. per-voice routing
from a [ClipTransport].

Establishes the synth's FM patch — select a DX7 voice into it with
[setFmPatch], or dial the headline params with the `setFm*` setters. Call
once per synth. Throws [YseException] on failure.

.. code-block:: dart

   void noteOn(int noteNumber, {int channel = 1, double velocity = 1.0})

Start a note. [velocity] is normalised to `[0, 1]`.

.. code-block:: dart

   void noteOff(int noteNumber, {int channel = 1, double velocity = 0.0})

Release a note. [velocity] is the release velocity, normalised to
`[0, 1]`.

.. code-block:: dart

   void allNotesOff({int channel = 0})

Release every held note on [channel] (`0` = all channels). Voices enter
their normal release; they are not cut.

.. code-block:: dart

   void pitchWheel(double value, {int channel = 1})

Bend every voice on [channel]. [value] is normalised to `[-1, 1]`
(`0` = centre).

.. code-block:: dart

   void controller(int number, double value, {int channel = 1})

Send a control-change on [channel]. [value] is normalised to `[0, 1]`.
CC 64 / 66 / 67 act as the sustain / sostenuto / soft pedals; other CC
numbers are stored as the channel's last controller value.

.. code-block:: dart

   void aftertouch(double value, {int channel = 1, int noteNumber = -1})

Apply aftertouch pressure, normalised to `[0, 1]`. A [noteNumber] of
`-1` (the default) is channel-wide; otherwise only the voice(s) sounding
that note receive it.

.. code-block:: dart

   void sustain(bool down, {int channel = 1})

Set the sustain pedal (CC 64) on [channel].

.. code-block:: dart

   void sostenuto(bool down, {int channel = 1})

Set the sostenuto pedal (CC 66) on [channel].

.. code-block:: dart

   void softPedal(bool down, {int channel = 1})

Set the soft pedal (CC 67) on [channel].

.. code-block:: dart

   void setVaOscWave(int osc, VaWaveform wave)

Set oscillator [osc]'s waveform.

.. code-block:: dart

   void setVaOscDetune(int osc, double semitones)

Set oscillator [osc]'s detune in semitones.

.. code-block:: dart

   void setVaOscLevel(int osc, double level)

Set oscillator [osc]'s output level.

.. code-block:: dart

   void setVaOscPulseWidth(int osc, double width)

Set oscillator [osc]'s pulse width (for [VaWaveform.pulse]).

.. code-block:: dart

   void setVaWavetablePosition(double position)

Set the wavetable morph position (for [VaWaveform.wavetable]).

.. code-block:: dart

   void setVaCutoff(double hz)

Set the filter cutoff in Hz.

.. code-block:: dart

   void setVaResonance(double resonance)

Set the filter resonance.

.. code-block:: dart

   void setVaKeyTracking(double amount)

Set the filter key-tracking amount.

.. code-block:: dart

   void setVaFilterEnvAmount(double octaves)

Set the filter-envelope depth in octaves.

.. code-block:: dart

   void setVaFilterVelAmount(double octaves)

Set the filter velocity depth in octaves.

.. code-block:: dart

   void setVaAmpAttack(double seconds)

Set the amplitude-envelope attack in seconds.

.. code-block:: dart

   void setVaAmpDecay(double seconds)

Set the amplitude-envelope decay in seconds.

.. code-block:: dart

   void setVaAmpSustain(double level)

Set the amplitude-envelope sustain level in `[0, 1]`.

.. code-block:: dart

   void setVaAmpRelease(double seconds)

Set the amplitude-envelope release in seconds.

.. code-block:: dart

   void setVaAmpVelAmount(double amount)

Set the amplitude velocity-sensitivity amount.

.. code-block:: dart

   void setVaFilterAttack(double seconds)

Set the filter-envelope attack in seconds.

.. code-block:: dart

   void setVaFilterDecay(double seconds)

Set the filter-envelope decay in seconds.

.. code-block:: dart

   void setVaFilterSustain(double level)

Set the filter-envelope sustain level in `[0, 1]`.

.. code-block:: dart

   void setVaFilterRelease(double seconds)

Set the filter-envelope release in seconds.

.. code-block:: dart

   void setVaLfoType(LfoType type)

Set the LFO shape.

.. code-block:: dart

   void setVaLfoRate(double hz)

Set the LFO rate in Hz.

.. code-block:: dart

   void setVaLfoToPitch(double semitones)

Set the LFO-to-pitch depth in semitones.

.. code-block:: dart

   void setVaLfoToCutoff(double octaves)

Set the LFO-to-cutoff depth in octaves.

.. code-block:: dart

   void setVaLfoToWavetable(double amount)

Set the LFO-to-wavetable morph depth.

.. code-block:: dart

   void setVaGain(double gain)

Set the VA voice's output gain.

.. code-block:: dart

   void loadVaWavetable(int slot, List<double> cycle)

Install a single-cycle waveform into the VA wavetable morph bank at
[slot]. [cycle] holds one period of normalised samples.

Setup-thread only — this reshapes table storage, so call it before the
synth is played, not while voices render.

.. code-block:: dart

   void setFmPatch(Dx7Bank bank, int index)

Copy patch [index] from a DX7 [bank] into the synth's FM patch — the way
to reach the full 155-parameter DX7 voice. The patch is copied, so [bank]
may be disposed afterwards. Throws [YseException] on failure.

.. code-block:: dart

   void setFmAlgorithm(int algorithm)

Set the FM algorithm (`0..31`).

.. code-block:: dart

   void setFmFeedback(int feedback)

Set the global feedback amount (`0..7`).

.. code-block:: dart

   void setFmTranspose(int transpose)

Set the transpose (`0..48`, `24` = none).

.. code-block:: dart

   void setFmLfoSpeed(int speed)

Set the LFO speed (`0..99`).

.. code-block:: dart

   void setFmLfoDelay(int delay)

Set the LFO delay (`0..99`).

.. code-block:: dart

   void setFmLfoWaveform(int waveform)

Set the LFO waveform (`0..5`).

.. code-block:: dart

   void setFmLfoPitchModDepth(int depth)

Set the LFO pitch-modulation depth (`0..99`).

.. code-block:: dart

   void setFmLfoAmpModDepth(int depth)

Set the LFO amplitude-modulation depth (`0..99`).

.. code-block:: dart

   void setFmPitchModSens(int sensitivity)

Set the pitch-modulation sensitivity (`0..7`).

.. code-block:: dart

   void setFmOpOutputLevel(int op, int level)

Set operator [op]'s output level (`0..99`).

.. code-block:: dart

   void setFmOpFreqCoarse(int op, int coarse)

Set operator [op]'s coarse frequency (`0..31`).

.. code-block:: dart

   void setFmOpFreqFine(int op, int fine)

Set operator [op]'s fine frequency (`0..99`).

.. code-block:: dart

   void setFmOpDetune(int op, int detune)

Set operator [op]'s detune (`0..14`, `7` = centre).

.. code-block:: dart

   void setFmOpOscMode(int op, int mode)

Set operator [op]'s oscillator mode (`0` = ratio, `1` = fixed).

.. code-block:: dart

   void setFmOpEnabled(int op, bool enabled)

Enable or disable operator [op].

.. code-block:: dart

   void setPositionHandler(PositionHandler handler)

Attach one of the built-in per-note position [handler]s, giving every
voice its own 3D position and movement.

Must be called *before* the synth is attached/played — like the
`add*Voices` methods, the engine rejects a handler swap once the voice
pool is built (it logs a warning and keeps the existing handler). Throws
[YseException] only for an unknown handler kind.

.. code-block:: dart

   void setHandlerCenter(double x, double y, double z)

Move the shared centre `(x, y, z)` that the spread / orbit handlers read.

A bounded, allocation-free message safe to call every control tick; all
of the synth's live handlers pick up the new centre on the next audio
block.

.. code-block:: dart

   void setNotePosition(int noteNumber, double x, double y, double z, {int channel = 1})

Imperatively place the voice(s) sounding [noteNumber] on [channel] at
`(x, y, z)` — for app-driven trajectories. Primarily useful when no
position handler is attached (a handler re-steers the voice next block).

.. code-block:: dart

   Pos getVoicePosition(int noteNumber, {int channel = 1})

Best-effort snapshot of the current position of a voice sounding
[noteNumber] on [channel]. Returns [Pos.zero] if none is sounding. A
single snapshot intended for tests / metering, not a readback stream.

.. code-block:: dart

   void dispose()

Destroy the underlying native synth and detach the finalizer.

Idempotent. Dispose any [Sound] rendering this synth *before* the synth.

