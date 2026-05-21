enum LfoType
============

.. code-block:: dart

   enum LfoType

Low-frequency-oscillator shape used by [DspObject.lfoType].

Values match `YSE::DSP::LFO_TYPE`.

Values
------

.. _lfo_type.none:

``none``

.. _lfo_type.saw:

``saw``

.. _lfo_type.sawReversed:

``sawReversed``

.. _lfo_type.triangle:

``triangle``

.. _lfo_type.sine:

``sine``

.. _lfo_type.square:

``square``

.. _lfo_type.random:

``random``

Constructors
------------

.. code-block:: dart

   LfoType(this.native)

Properties
----------

.. code-block:: dart

   final raw.YseLfoType native

