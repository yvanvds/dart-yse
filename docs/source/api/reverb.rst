Reverb
======

Positioned reverb zones. The engine blends every reverb whose roll-off
radius overlaps the listener into a single shared reverb processor.

Upstream: :yse-cpp:`api/core.html <YSE::reverb>`.

The named presets are also available as plain values:
:py:meth:`ReverbPresetValues.fromPreset` returns the exact parameter set
``Reverb.preset`` applies, :py:meth:`ReverbPresetValues.lerp` blends two sets
with the engine's own morph core, and :py:meth:`Reverb.applyValues` applies
any set to a zone. ``fromPreset`` and ``lerp`` need the library but no engine
session.

.. include:: _generated/reverb.rst

.. include:: _generated/reverb_preset_values.rst
