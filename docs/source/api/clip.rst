Clip transport
==============

Engine-driven, beat-timed MIDI playback. A :class:`ClipTransport` loops a
flat list of :class:`ClipEvent` against a :class:`DomainClock`, dispatched
from the audio thread — so the Dart side never has to time a ``noteOn`` /
``noteOff`` itself. The event list is replaceable while playing (the engine
swaps it at the next audio-block boundary), and playback routes to one or
more :class:`MidiOut` sinks.

Upstream: :yse-cpp:`api/clip.html <YSE::clip>`.

.. include:: _generated/clip_transport.rst

.. include:: _generated/clip_event.rst
