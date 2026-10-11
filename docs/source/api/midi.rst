MIDI
====

Standard MIDI file playback (:class:`MidiFile`), output port
(:class:`MidiOut`), and input port (:class:`MidiIn`).

Upstream: :yse-cpp:`YSE::midiOut / midiIn <api/midi.html>`.

.. include:: _generated/midi_file.rst

.. include:: _generated/midi_out.rst

.. include:: _generated/midi_in.rst

Message types
-------------

.. include:: _generated/midi_in_raw_message.rst

.. include:: _generated/midi_in_parsed_message.rst

Channel numbering
-----------------

MIDI channels are counted from two different bases, depending on the layer:

.. list-table::
   :header-rows: 1

   * - Layer
     - Range
     - Used by
   * - Wire level (status-byte low nibble)
     - ``0..15``
     - :class:`MidiOut` sends, :class:`MidiInParsedMessage` ``channel``
   * - Musical layer
     - ``1..16``; ``0`` = omni on a synth call
     - :class:`Synth`, :class:`ClipEvent`, :class:`Note` / :class:`PNote`,
       the ``MidiIn.connectSynth`` ``channelFilter``

So MIDI channel 1 is ``0`` on a :class:`MidiOut` and ``1`` on a
:class:`Synth`. On a synth call ``0`` means *every channel*, never channel 1.
A :class:`ClipTransport` routed to a :class:`MidiOut` converts for you
(``channel - 1`` on the wire); add one yourself when feeding a parsed
:class:`MidiIn` message into a synth by hand.
