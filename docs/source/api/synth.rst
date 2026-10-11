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

Two engine issues in libYSE v3.1.0 shape how a synth is set up and torn
down (see :doc:`/intro/upgrading` for the full list):

- Add every voice group right after ``Synth()``. The engine's setup job
  can build a new synth before its voices arrive and leave it at 0 voices
  with no error (upstream `#1177
  <https://github.com/yvanvds/yse-soundengine/issues/1177>`_); voice groups
  added after the pool is built throw :class:`StateError`.
- Attach a synth with VA or FM voices to a sound before disposing it.
  Disposing one that was never attached crashes the next synth that is
  attached to a sound (upstream `#1175
  <https://github.com/yvanvds/yse-soundengine/issues/1175>`_). Sine-only and
  voice-less synths are not affected.

Upstream: :yse-cpp:`YSE::synth <api/synth.html>`.

.. include:: _generated/synth.rst

.. include:: _generated/sfz_instrument.rst

.. include:: _generated/dx7_bank.rst

.. include:: _generated/position_handler.rst
