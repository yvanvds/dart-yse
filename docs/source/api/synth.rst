Synth
=====

A polyphonic synthesiser voice pool rendered behind one :class:`Sound`. A
:class:`Synth` owns polyphony, voice allocation, voice stealing and full
keyboard/pedal state; you build its voice pool from a built-in voice type
(sine, virtual-analog, FM/DX7, or SFZ sampler), attach it behind a positioned
sound, then drive it with ``noteOn`` / ``noteOff`` and controller / pedal
events.

The FM voice is patched from a :class:`Dx7Bank` imported from a DX7 ``.syx``
file; the sampler voice renders an :class:`SfzInstrument`. Per-note 3D
positioning — "the swarm" — is configured with a :class:`PositionHandler`.

Upstream: :yse-cpp:`api/synth.html <YSE::synth>`.

.. include:: _generated/synth.rst

.. include:: _generated/sfz_instrument.rst

.. include:: _generated/dx7_bank.rst

.. include:: _generated/position_handler.rst
