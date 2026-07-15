DomainClock
===========

.. code-block:: dart

   class DomainClock

A named musical beat-clock owned by the engine (issue #21).

A domain clock is a beat accumulator derived from the audio callback:
every audio block it advances by `blockSeconds * tempo / 60`, so
[beatPosition] is the running integral of [currentTempo]. All clocks
derive from the single sample clock, keeping polytemporal relationships
exact. Tempo is a playable, rampable control and is **not** clamped — a
tempo of 0 pauses the clock and a negative tempo runs it backwards.

Clocks are keyed by [name], not by an owned pointer: the engine holds the
clock and the *first* registration of a name wins. Bind a [ClipTransport]
to a clock by that same [name]; the clock must outlive every clip bound to
it.

Threading (CLAUDE.md): construct, [dispose] and [setTempo] are
control-thread calls made from the [System] isolate; [beatPosition] and
[currentTempo] are cheap enough to read from the UI thread at frame rate.

Unlike the pointer-backed wrappers this is **not** [Finalizable]: the
engine keys clocks by name, and the native destructor takes that name
rather than a pointer, so there is no token a [NativeFinalizer] could
carry. Release the clock explicitly with [dispose].

Constructors
------------

.. code-block:: dart

   factory DomainClock(String name, {double tempo = 120.0})

Create a named clock starting at [tempo] BPM.

Throws [YseException] if a live clock already owns [name] (first
registration wins).

Properties
----------

.. code-block:: dart

   final String name

Registration name of this clock. Bind a [ClipTransport] with it.

.. code-block:: dart

   bool get exists

Whether a live clock with this [name] currently exists in the engine.

.. code-block:: dart

   double get beatPosition

Current beat position — the running integral of tempo. Returns 0 for a
disposed or otherwise unknown clock.

.. code-block:: dart

   double get currentTempo

Current tempo in BPM. Returns 0 for a disposed or otherwise unknown
clock.

Methods
-------

.. code-block:: dart

   void setTempo(double target, {Duration ramp = Duration.zero})

Ramp the tempo toward [target] BPM over [ramp] (zero = instant).

Tempo is unclamped: 0 pauses the clock, a negative value runs it
backwards.

.. code-block:: dart

   void dispose()

Destroy the named clock in the engine. Idempotent. Dispose every
[ClipTransport] bound to this clock first.

