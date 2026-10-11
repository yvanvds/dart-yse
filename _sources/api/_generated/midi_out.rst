MidiOut
=======

.. code-block:: dart

   class MidiOut implements Finalizable

MIDI output port (Windows / Linux only; backed by RtMidi upstream).

Enumerate device counts with [System.midiOutDeviceCount] and names
with [System.midiOutDeviceName], then open one with [MidiOut.open].

Channels here are **wire-level, 0-based** (`0..15`) — the low nibble of
the status byte. The musical layer ([Synth], [ClipEvent], `Note`) counts
`1..16` instead, so MIDI channel 1 is `0` here and `1` there. A channel
outside `0..15` is clamped into that range by the engine (libYSE 3.0.1)
rather than spilling into the status nibble, so `-1` sends on channel 0
and `16` on channel 15.

To send a message the typed helpers don't cover — a SysEx dump, or any
other complete message — use [raw].

Constructors
------------

.. code-block:: dart

   factory MidiOut.open(int port)

Open the MIDI device at [port].

When [port] does not exist or the MIDI backend cannot start, the engine
reports the RtMidi error through [Log] and the port stays unopened:
every send on it is then a silent no-op. Check [port] against
[System.midiOutDeviceCount] first.

Properties
----------

.. code-block:: dart

   set localControl(bool on)

Toggle local-keyboard control on the receiving instrument.

.. code-block:: dart

   set omni(bool on)

Toggle Omni mode on the receiving instrument.

.. code-block:: dart

   set poly(bool on)

Toggle Poly (`true`) or Mono (`false`) mode on the receiving instrument.

.. code-block:: dart

   Pointer<YseMidiOut> get handle

Internal: the raw native handle, for wiring this port as a
[ClipTransport] sink. Not part of the public surface.

Methods
-------

.. code-block:: dart

   void noteOn({required int channel, required int pitch, required int velocity})

Send Note-On. [channel] is 0..15, [pitch] is 0..127.

.. code-block:: dart

   void noteOff({required int channel, required int pitch, int velocity = 0})

Send Note-Off.

.. code-block:: dart

   void polyPressure({required int channel, required int pitch, required int value})

Send polyphonic key-pressure (aftertouch).

.. code-block:: dart

   void channelPressure({required int channel, required int value})

Send channel-pressure.

.. code-block:: dart

   void programChange({required int channel, required int value})

Send program-change.

.. code-block:: dart

   void controlChange({required int channel, required int controller, required int value})

Send control-change.

.. code-block:: dart

   void allNotesOff({int? channel})

Send All-Notes-Off on a specific [channel] (`0..15`), or on every
channel when null.

.. code-block:: dart

   void reset({int? channel})

Send Reset-All-Controllers on a specific [channel] (or all if null).

.. code-block:: dart

   void raw3(int a, int b, int c)

Send three raw MIDI bytes.

Always sends exactly three bytes, so it only suits three-byte messages
(note on/off, poly pressure, control change, pitch bend). For anything
else — a two-byte program change or channel pressure, a one-byte
realtime message, SysEx — use [raw], which sends the message as given.

.. code-block:: dart

   void raw(List<int> bytes)

Send one complete MIDI message, byte for byte — no padding and no
truncation (libYSE #748 / #903).

This is the way to send two-byte messages (program change, channel
pressure), single-byte system realtime messages, and System Exclusive
dumps of any length:

.. code-block:: dart

   out.raw([0xC0, 5]);                               // program change
   out.raw([0xF0, 0x7E, 0x7F, 0x09, 0x01, 0xF7]);    // GM System On


[bytes] is copied into native memory for the call, so it may be
reused or modified straight afterwards. An empty list is a no-op.

The message is checked before anything reaches the engine, and an
[ArgumentError] is thrown when:

* a value is outside `0..255`;
* the first byte is not a status byte (`>= 0x80`) — running status
  is not supported, every message carries its own status;
* a data byte has its high bit set (`>= 0x80`);
* the length doesn't match the status: 3 bytes for note off/on, poly
  pressure, control change, pitch bend and song position; 2 for
  program change, channel pressure, MTC quarter frame and song
  select; 1 for tune request and system realtime (`0xF8..0xFF`);
* a SysEx message (`0xF0`) doesn't end with `0xF7`;
* the status is `0xF4` / `0xF5` (undefined) or a stray `0xF7`.

Unlike the typed helpers, the channel nibble of a raw status byte is
sent as given — there is nothing to clamp.

On a port that isn't open (see [MidiOut.open]) or after [dispose] this
is a silent no-op, like every other send. A send RtMidi refuses is
reported through [Log] and dropped; it never throws across the FFI
boundary.

.. code-block:: dart

   void dispose()

Destroy the underlying native port and detach the finalizer.

