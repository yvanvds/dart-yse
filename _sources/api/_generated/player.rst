Player
======

.. code-block:: dart

   class Player implements Finalizable

Generative note sequencer.

Plays random notes within configurable pitch / velocity / gap / length
ranges, optionally constrained to a [Scale], optionally drawing from
one or more weighted [Motif]s instead of pure randomness. Numeric
setters accept an optional [fade] parameter that interpolates from
the current value to the target over that many seconds.

A player has no sound of its own: it plays its notes on the [Synth] it is
constructed with. Attach that synth to a playing sound
(`Sound.fromSynth`) to hear them. The engine advances players once per
rendered audio block.

The engine *borrows* the synth, the active [Scale]s and every added
[Motif] — it keeps pointers to them, not copies. The player holds Dart
references to each, so garbage collection never frees one while the
player can still read it (#85); they are released only after the
player's own native destroy. Don't `.dispose()` any of them while the
player is alive.

Constructors
------------

.. code-block:: dart

   factory Player(Synth synth)

Construct a player that plays its notes on [synth].

[synth] must be live (not disposed). The player holds it until the
player is disposed or collected. Throws [YseException] if the engine
refuses to create the player.

Properties
----------

.. code-block:: dart

   Synth get synth

The synth this player plays its notes on.

.. code-block:: dart

   bool get isPlaying

Whether the player is currently producing notes.

Methods
-------

.. code-block:: dart

   void play()

Start producing notes.

.. code-block:: dart

   void stop()

Stop producing notes.

.. code-block:: dart

   void setMinimumPitch(double target, {Duration fade = Duration.zero})

Set the lowest pitch the player may produce (0..126). [fade] interpolates.

.. code-block:: dart

   void setMaximumPitch(double target, {Duration fade = Duration.zero})

Set the highest pitch the player may produce (1..127). [fade] interpolates.

.. code-block:: dart

   void setMinimumVelocity(double target, {Duration fade = Duration.zero})

Set the lowest velocity (0..0.999999). [fade] interpolates.

.. code-block:: dart

   void setMaximumVelocity(double target, {Duration fade = Duration.zero})

Set the highest velocity (0.000001..1). [fade] interpolates.

.. code-block:: dart

   void setMinimumGap(double target, {Duration fade = Duration.zero})

Set the minimum gap between successive notes / motifs, in seconds.

.. code-block:: dart

   void setMaximumGap(double target, {Duration fade = Duration.zero})

Set the maximum gap between successive notes / motifs, in seconds.

.. code-block:: dart

   void setMinimumLength(double target, {Duration fade = Duration.zero})

Set the minimum note length, in seconds (used when no motif is active).

.. code-block:: dart

   void setMaximumLength(double target, {Duration fade = Duration.zero})

Set the maximum note length, in seconds (used when no motif is active).

.. code-block:: dart

   void setVoices(int target, {Duration fade = Duration.zero})

Number of simultaneous voices.

.. code-block:: dart

   void setScale(Scale scale, {Duration fade = Duration.zero})

Constrain generated pitches to [scale].

With a [fade], the player cross-fades from the current scale to [scale]
over that time (the first call always applies at once).

The engine *borrows* [scale] (it keeps a pointer, not a copy), so later
changes to it apply. The player holds a Dart reference to every scale
the cross-fade may still read: the last scale set without a fade and
each fade target set since. Don't `.dispose()` them while the player is
alive.

.. code-block:: dart

   void addMotif(Motif motif, {int weight = 1})

Add a [motif] to the player's pool. Picked weighted by [weight].

The engine *borrows* [motif] (it keeps a pointer, not a copy). The
player holds a Dart reference to it until [removeMotif] or [dispose];
don't `.dispose()` the motif before then.

.. code-block:: dart

   void removeMotif(Motif motif)

Remove a previously added motif, and stop holding it.

.. code-block:: dart

   void adjustMotifWeight(Motif motif, int weight)

Adjust the selection weight of an already-added motif.

.. code-block:: dart

   void playPartialMotifs(double target, {Duration fade = Duration.zero})

Probability that the player plays only part of a motif (0..1).

.. code-block:: dart

   void playMotifs(double target, {Duration fade = Duration.zero})

Probability that the player draws notes from a motif vs. random (0..1).

.. code-block:: dart

   void fitMotifsToScale(double target, {Duration fade = Duration.zero})

Probability that motif notes are quantised to the active scale (0..1).

.. code-block:: dart

   void dispose()

Destroy the underlying native player and detach the finalizer.

The scales and motifs are released at once. The synth stays held until
this wrapper is collected: the engine retires a destroyed player on its
next audio block, and that step still sends note-offs to the synth
(upstream yvanvds/yse-soundengine#1181). If you dispose the synth
yourself, let at least one audio block run after this call first (in an
offline session, render one) — and before `System.close`.

