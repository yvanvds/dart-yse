Channel
=======

.. code-block:: dart

   class Channel

A node in the channel tree — a group of sounds that mix together.

Channels work like channel groups on a mixing console: every sound is
attached to a channel, and channels can themselves be attached to a
parent channel, forming a tree rooted at the master channel.

Use the pre-built channel singletons ([Channel.master], [Channel.fx],
etc.) directly, or build subtrees by passing them as the [parent] to
[Channel.create].

Constructors
------------

.. code-block:: dart

   factory Channel.create(String name, {required Channel parent})

Construct a new channel attached to [parent].

Throws [YseException] when the engine refuses the new channel.

Static accessors
----------------

.. code-block:: dart

   static Channel get master

The root of the channel tree. Every channel ultimately routes here.

.. code-block:: dart

   static Channel get fx

Pre-built channel for short sound effects.

.. code-block:: dart

   static Channel get music

Pre-built channel for playlists and music tracks.

.. code-block:: dart

   static Channel get ambient

Pre-built channel for environmental and ambient sounds.

.. code-block:: dart

   static Channel get voice

Pre-built channel for dialogue and voice-over.

.. code-block:: dart

   static Channel get gui

Pre-built channel for user-interface sounds.

Properties
----------

.. code-block:: dart

   double get volume

.. code-block:: dart

   set volume(double value)

Volume in the range [0.0, 1.0].

.. code-block:: dart

   bool get virtual

.. code-block:: dart

   set virtual(bool value)

Whether sounds on this channel may be virtualised when the engine
runs out of voices.

.. code-block:: dart

   bool get isValid

Whether this channel has a live implementation.

.. code-block:: dart

   String get name

Channel name (the value passed to [Channel.create]).

.. code-block:: dart

   int get numOutputs

Number of output speakers this channel feeds. Index into [peakLinear]
and [peakDb] with values in `[0, numOutputs)`.

.. code-block:: dart

   Pointer<YseChannel> get handle

Internal: native handle for cross-wrapper plumbing (sound → channel).

Methods
-------

.. code-block:: dart

   void moveTo(Channel parent)

Re-parent this channel. All attached sounds and subchannels follow.

.. code-block:: dart

   void attachReverb()

Move the global reverb effect onto this channel.

libYSE runs a single reverb instance for performance reasons. By
default it sits on the master channel; call this to restrict reverb
to a subtree.

.. code-block:: dart

   double peakLinearPre({int? output})

Peak amplitude (linear `[0.0, 1.0+]`) measured at the end of dsp(),
before the channel volume is applied. Useful for input-level meters.

Pass an [output] index in `[0, numOutputs)` for a per-speaker reading;
out-of-range indices return 0.

.. code-block:: dart

   double peakLinearPost({int? output})

Peak amplitude (linear `[0.0, 1.0+]`) measured immediately after
the channel volume is applied — what listeners hear.

.. code-block:: dart

   double peakDbPre({int? output})

[peakLinearPre] expressed in decibels. Silence reports −120 dB.

.. code-block:: dart

   double peakDbPost({int? output})

[peakLinearPost] expressed in decibels. Silence reports −120 dB.

.. code-block:: dart

   void dispose()

Destroy the underlying native channel.

No-op for the pre-built singletons (those are owned by the engine).

