Synth
=====

A polyphonic synthesiser voice pool rendered behind one :class:`Sound`. A
:class:`Synth` owns polyphony, voice allocation, voice stealing and full
keyboard/pedal state; you build its voice pool from a built-in voice type
(sine, virtual-analog, FM/DX7, or SFZ sampler), attach it behind a positioned
sound, then drive it with ``noteOn`` / ``noteOff`` and controller / pedal
events — or with ``playNote`` / ``releaseNote`` from a :class:`Note`. Synth
channels are 1-based (``1..16``, ``0`` = omni); see the channel-numbering
table on the MIDI page.

The FM voice is patched from a :class:`Dx7Bank` imported from a DX7 ``.syx``
file (``Dx7Bank.load``) or from bytes already in memory such as a bundled
asset (``Dx7Bank.fromBytes``); ``indexOf`` finds a patch by name. The sampler voice renders an :class:`SfzInstrument`. Per-note 3D
positioning — "the swarm" — is configured with a :class:`PositionHandler`.

Upstream: :yse-cpp:`api/synth.html <YSE::synth>`.

.. include:: _generated/synth.rst

.. include:: _generated/sfz_instrument.rst

.. include:: _generated/dx7_bank.rst

.. include:: _generated/position_handler.rst
