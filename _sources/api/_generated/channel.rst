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

.. code-block:: dart

   factory Channel.createWithSends(String name, {required Channel parent, required int sendSlots})

Construct a new channel with an explicit number of aux-[send] slots.

[Channel.create] gives every channel four send slots; use this when a
channel needs to fan out to more return buses than that. The slot count
is fixed at construction — the engine sizes it once, off the audio
thread, and never resizes — so pick a count that covers the channel's
busiest routing.

Throws [YseException] when the engine refuses the new channel.

.. code-block:: dart

   factory Channel.createReturn(String name, {int sendSlots = 4})

Construct a send/return bus — an aux bus that sits outside the normal
mix tree.

A return bus is an ordinary channel in every other respect (it keeps
[dsp] inserts, [attachReverb], [volume] and metering), but it is
excluded from the parent/child mix tree: instead, other channels route
scaled copies of their signal into it with [send], and its output folds
into the master mix after the source tree — the classic aux-send
topology.

A return may itself [send] onward into another return (e.g. a
delay → reverb chain). **The send graph must stay acyclic:** the engine
rejects and logs a wiring that would close a cycle rather than crashing,
but the edge simply will not connect.

[sendSlots] fixes how many onward sends this return can drive (see
[Channel.createWithSends]). Destroy it with [dispose] like any channel.

Throws [YseException] when the engine refuses the new bus.

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

   bool get isReturn

Whether this channel is a send/return bus (created via
[Channel.createReturn]) rather than an ordinary mix-tree channel.

.. code-block:: dart

   DspObject? get dsp

.. code-block:: dart

   set dsp(DspObject? head)

The pre-fader insert effect chain attached to this channel, or `null`
when none is attached.

Assign a [DspObject] chain head to place it in this channel's insert
slot; the effect processes the channel's summed output in place, before
reverb and the channel [volume]. Chain multiple effects with
[DspObject.link] and assign the head. Assign `null` to detach.

The channel holds only a borrowed reference: the assigned [DspObject]
(and every object linked after it) must outlive the channel, or be
detached first. This mirrors `Sound.dsp` at the channel level.

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

   void send(int slot, Channel returnBus, {double level = 1.0, bool preFader = false})

Wire send [slot] of this channel to [returnBus] at [level].

[slot] indexes this channel's send slots, `[0, sendSlots)` — four by
default, or the count fixed by [Channel.createWithSends] /
[Channel.createReturn]. [returnBus] must be a return bus (see
[isReturn]).

Sends are post-fader by default — they follow this channel's [volume].
Pass `preFader: true` for a cue-style send that is independent of the
fader.

The engine rejects and logs an illegal wiring (a target that is not a
return, a self-send, a return → return edge that would close a cycle,
or an out-of-range slot) on the calling thread; it never reaches the
audio thread. This call is a no-op on such a wiring rather than an
error.

.. code-block:: dart

   void setSendLevel(int slot, double level)

Set the level of send [slot], ramped and click-free.

Safe to call every control tick — the engine designs send levels as
modulation targets, so continuous writes fuse into the per-block ramp
without zippering (hence no fade argument).

.. code-block:: dart

   double getSendLevel(int slot)

Current target level of send [slot], or `0.0` if the slot is unset or
out of range.

.. code-block:: dart

   void clearSend(int slot)

Detach send [slot], fully disconnecting it from its return bus.

.. code-block:: dart

   void dispose()

Destroy the underlying native channel.

No-op for the pre-built singletons (those are owned by the engine).

