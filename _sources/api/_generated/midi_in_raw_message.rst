MidiInRawMessage
================

.. code-block:: dart

   class MidiInRawMessage

A raw MIDI message delivered through [MidiIn.rawMessages].

Bytes are copied out of the engine-owned buffer before the underlying
allocation is released, so [bytes] is safe to retain.

Constructors
------------

.. code-block:: dart

   MidiInRawMessage(this.timestamp, this.bytes)

Constructor — invoked internally by [MidiIn.rawMessages].

Properties
----------

.. code-block:: dart

   final double timestamp

Timestamp from RtMidi, in seconds (monotonically increasing within
a single port session).

.. code-block:: dart

   final Uint8List bytes

Full MIDI message bytes, exactly as RtMidi delivered them.

