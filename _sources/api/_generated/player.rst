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

**Note**: the upstream `YSE::player::create(synth&)` factory is
commented out, and there is no other path to initialise the player's
implementation pointer. Calling any method on a freshly-constructed
[Player] therefore crashes the process (null pimpl dereference) —
this surface is dead until the synth subsystem returns to the public
API. The class is exposed here so the wrapping is in place when that
happens; do not call its methods until then.

Constructors
------------

.. code-block:: dart

   factory Player()

Construct a player.

As of engine v2.3.0 `yse_player_create` takes a `YseSynth*`. The synth
subsystem does not yet have an idiomatic Dart wrapper (tracked as a
separate issue in this batch), so a null synth is passed here — matching
the dead-surface contract documented on this class. Do not call this
class's methods until the synth wiring lands.

Properties
----------

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

The player keeps its own copy — modifying [scale] after this
call has no effect on the player.

.. code-block:: dart

   void addMotif(Motif motif, {int weight = 1})

Add a [motif] to the player's pool. Picked weighted by [weight].

.. code-block:: dart

   void removeMotif(Motif motif)

Remove a previously added motif.

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

