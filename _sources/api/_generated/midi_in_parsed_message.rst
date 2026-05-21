MidiInParsedMessage
===================

.. code-block:: dart

   class MidiInParsedMessage

A pre-decoded channel-voice MIDI message delivered through
[MidiIn.parsedMessages].

[status] is the high nibble of the first byte (`0x80`..`0xF0`),
[channel] is the low nibble (`0`..`15`). [data1] and [data2] are
`0` for messages shorter than 3 bytes.

Constructors
------------

.. code-block:: dart

   MidiInParsedMessage(this.timestamp, this.status, this.channel, this.data1, this.data2)

Constructor — invoked internally by [MidiIn.parsedMessages].

Properties
----------

.. code-block:: dart

   final double timestamp

Timestamp from RtMidi, in seconds.

.. code-block:: dart

   final int status

Status nibble (`0x80`..`0xF0`) — Note-On, CC, etc.

.. code-block:: dart

   final int channel

MIDI channel (`0`..`15`).

.. code-block:: dart

   final int data1

First data byte (e.g. pitch for Note-On, controller for CC).

.. code-block:: dart

   final int data2

Second data byte (e.g. velocity for Note-On, value for CC).
`0` for 1- or 2-byte messages.

