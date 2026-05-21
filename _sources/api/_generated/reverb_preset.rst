enum ReverbPreset
=================

.. code-block:: dart

   enum ReverbPreset

Named reverb-tail presets for [Reverb.preset].

Values match `YSE::REVERB_PRESET`.

Values
------

.. _reverb_preset.off:

``off``

.. _reverb_preset.generic:

``generic``

.. _reverb_preset.padded:

``padded``

.. _reverb_preset.room:

``room``

.. _reverb_preset.bathroom:

``bathroom``

.. _reverb_preset.stoneroom:

``stoneroom``

.. _reverb_preset.largeroom:

``largeroom``

.. _reverb_preset.hall:

``hall``

.. _reverb_preset.cave:

``cave``

.. _reverb_preset.sewerpipe:

``sewerpipe``

.. _reverb_preset.underwater:

``underwater``

Constructors
------------

.. code-block:: dart

   ReverbPreset(this.native)

Properties
----------

.. code-block:: dart

   final raw.YseReverbPreset native

The raw FFI enum value passed to the C ABI.

