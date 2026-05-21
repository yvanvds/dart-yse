Sound
=====

.. code-block:: dart

   class Sound implements Finalizable

A playable instance of an audio source.

Construct one sound per voice in the scene. The source can be a file on
disk (wav / ogg / flac and other formats depending on the platform);
buffer-backed and DSP-source variants ship in later milestones.

Constructors
------------

.. code-block:: dart

   factory Sound.fromFile(String filename, {Channel? channel, bool loop = false, double volume = 1.0, bool streaming = false})

Construct a sound backed by an audio file.

[filename] is an absolute path or a path relative to the working
directory. [channel] routes the sound through that mixer node;
pass `null` to use the master mix. [streaming] streams the audio
from disk instead of loading it into memory — use for large one-off
assets, avoid for sounds played repeatedly.

Throws [YseException] if the file cannot be loaded.

.. code-block:: dart

   factory Sound.fromPatcher(Patcher patcher, {Channel? channel, double volume = 1.0})

Construct a sound driven by a [Patcher] graph.

The patcher must outlive this sound; the engine reads its `~dac`
output on every audio callback.

.. code-block:: dart

   factory Sound.fromBuffer(DspBuffer buffer, {Channel? channel, bool loop = false, double volume = 1.0})

Construct a sound backed by an in-memory [DspBuffer].

**Lifetime contract:** [buffer] must outlive this sound — the audio
thread reads from it on every callback. Keep a Dart reference to the
buffer for as long as the sound exists; don't `.dispose()` the
buffer before disposing the sound.

Properties
----------

.. code-block:: dart

   bool get isValid

Whether this sound has a live native implementation.

.. code-block:: dart

   bool get isReady

Whether the asynchronous file load has finished.

Calling [play] on a not-yet-ready sound is safe — the start is queued.

.. code-block:: dart

   bool get isStreaming

Whether the sound is streamed from disk (vs loaded into memory).

.. code-block:: dart

   bool get isPlaying

Whether the sound is currently playing.

.. code-block:: dart

   bool get isPaused

Whether the sound is currently paused.

.. code-block:: dart

   bool get isStopped

Whether the sound is currently stopped.

.. code-block:: dart

   Pos get position

.. code-block:: dart

   set position(Pos value)

Position of this sound in the virtual scene.

.. code-block:: dart

   double get volume

.. code-block:: dart

   set volume(double value)

Volume in the range [0.0, 1.0].

.. code-block:: dart

   double get speed

.. code-block:: dart

   set speed(double value)

Playback speed. 2.0 is one octave up, 0.5 is one octave down.
Negative plays backwards (not supported for streaming sounds).

.. code-block:: dart

   double get size

.. code-block:: dart

   set size(double value)

Audible radius — beyond this distance the sound fades out.

.. code-block:: dart

   double get spread

.. code-block:: dart

   set spread(double value)

Channel spread for multichannel sounds (no-op for mono).

.. code-block:: dart

   bool get looping

.. code-block:: dart

   set looping(bool value)

Whether the sound loops continuously.

.. code-block:: dart

   bool get relative

.. code-block:: dart

   set relative(bool value)

Whether the sound is positioned relative to the listener.

.. code-block:: dart

   bool get doppler

.. code-block:: dart

   set doppler(bool value)

Whether doppler shift is enabled for this sound.

.. code-block:: dart

   bool get pan2D

.. code-block:: dart

   set pan2D(bool value)

Shorthand for relative + listener-origin position + no doppler.

.. code-block:: dart

   bool get occlusion

.. code-block:: dart

   set occlusion(bool value)

Whether occlusion is active for this sound. Requires a
callback installed via the engine's occlusion hook.

.. code-block:: dart

   double get time

.. code-block:: dart

   set time(double samples)

Playhead position in samples.

.. code-block:: dart

   int get length

Length of the source in samples.

.. code-block:: dart

   set dsp(DspObject? dsp)

Attach a DSP effect chain to this sound.

Pass `null` to clear. The engine holds a borrowed reference to [dsp]
for as long as the sound is live; [dsp] must outlive this sound and
the engine's slow-pool delete tick that follows its destruction.

Methods
-------

.. code-block:: dart

   void play()

Start playback.

.. code-block:: dart

   void pause()

Pause playback. [play] resumes from the current position.

.. code-block:: dart

   void stop()

Stop playback and rewind to the start of the source.

.. code-block:: dart

   void toggle()

Cycle playing → paused → playing, or stopped → playing.

.. code-block:: dart

   void restart()

Restart from the beginning regardless of current position.

.. code-block:: dart

   void fadeTo(double target, {required Duration fade})

Fade to [target] over [fade] milliseconds.

.. code-block:: dart

   void fadeAndStop(Duration time)

Fade out over [time], then stop.

.. code-block:: dart

   void moveTo(Channel target)

Move this sound to a different channel.

.. code-block:: dart

   void dispose()

Destroy the underlying native sound and detach the finalizer.

Idempotent. After [dispose] the sound is unusable.

