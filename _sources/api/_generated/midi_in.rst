MidiIn
======

.. code-block:: dart

   class MidiIn implements Finalizable

MIDI input port (Windows / Linux only; backed by RtMidi upstream).

Enumerate device counts with [System.midiInDeviceCount] and names
with [System.midiInDeviceName], then open one with [MidiIn.open].

Two modes of consumption — subscribe to either or both:
  * [rawMessages] — full message bytes as a [Uint8List].
  * [parsedMessages] — pre-decoded channel-voice scalars.

Channel numbering has two bases. The parsed stream reports the
**wire-level, 0-based** channel (`0..15`, see
[MidiInParsedMessage.channel]), while [connectSynth]'s `channelFilter`
uses the musical layer's **1-based** numbering (`1..16`, `0` = every
channel) shared with [Synth] and [ClipEvent].

Native callbacks fire on RtMidi's internal input thread.
`NativeCallable.listener` posts each event back to the isolate that
created this `MidiIn`, so Dart code only ever sees messages
serialised in the isolate's event queue.

Constructors
------------

.. code-block:: dart

   factory MidiIn.open(int port)

Open the MIDI input device at [port].

Properties
----------

.. code-block:: dart

   bool get isOpen

Whether the underlying RtMidi port is currently open.

.. code-block:: dart

   Stream<MidiInRawMessage> get rawMessages

Broadcast stream of raw MIDI messages. Lazily installs the native
callback on first subscription and uninstalls when the last
subscriber cancels.

Messages still queued when the last subscriber cancels (or the port
is [dispose]d) are not delivered, but their native buffers are still
released.

.. code-block:: dart

   Stream<MidiInParsedMessage> get parsedMessages

Broadcast stream of pre-decoded MIDI messages. Lazily installs the
native callback on first subscription and uninstalls when the last
subscriber cancels.

Methods
-------

.. code-block:: dart

   void close()

Close the port. The instance remains valid but emits no further
messages until re-created.

.. code-block:: dart

   void connectSynth(Synth synth, {int channelFilter = 0})

Route incoming device MIDI into an internal [synth] (upstream #371).

Every channel-voice message received on the open port is mapped to the
synth's normalized note API and pushed onto its inbox on RtMidi's input
thread. [channelFilter] is a 1-based `1..16` MIDI channel to accept, or
`0` (the default) for every channel — note the parsed stream reports the
same channel 0-based, so channel 1 there is filter `1` here. May be called for several synths (up to a
small fixed cap); re-connecting an already-connected synth just updates
its channel filter. [synth] must outlive the connection —
[disconnectSynth] it (or close/dispose this port) before disposing the
synth.

.. code-block:: dart

   void disconnectSynth(Synth synth)

Stop routing incoming device MIDI into [synth]. Safe to call for a synth
that was never connected.

.. code-block:: dart

   void dispose()

Destroy the underlying native port and detach the finalizer.

Also clears both callbacks and closes [rawMessages] and
[parsedMessages] (listeners get `onDone`).

