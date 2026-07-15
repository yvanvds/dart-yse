enum ChorusMode
===============

.. code-block:: dart

   enum ChorusMode

Modulation character of a [Chorus] module.

Values match `YSE::DSP::MODULES::chorusMode` (see `chorus.hpp`).

Values
------

.. _chorus_mode.chorus:

``chorus``

   Longer base delay with a wide, slow sweep.

.. _chorus_mode.flanger:

``flanger``

   Short base delay with a feedback comb.

Constructors
------------

.. code-block:: dart

   ChorusMode(this.native)

Properties
----------

.. code-block:: dart

   final raw.YseChorusMode native

