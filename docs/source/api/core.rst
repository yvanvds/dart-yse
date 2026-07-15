Core
====

The :class:`System` singleton drives engine lifecycle, audio-device
selection, MIDI device enumeration, and the per-frame update loop.

Upstream: :yse-cpp:`api/core.html <YSE::system>`.

.. include:: _generated/system.rst

Domain clocks
-------------

:class:`DomainClock` is a named, rampable musical beat clock owned by the
engine. Each clock integrates its tempo per audio block, so
:py:attr:`DomainClock.beatPosition` is cheap to poll at frame rate. Bind a
:class:`ClipTransport` to a clock by name to drive engine-timed playback.

.. include:: _generated/domain_clock.rst

Pos
---

.. include:: _generated/pos.rst

Exceptions
----------

.. include:: _generated/yse_exception.rst
