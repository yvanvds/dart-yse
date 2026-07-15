enum EqBand
===========

.. code-block:: dart

   enum EqBand

One of the four fixed bands of a [ParametricEq].

Values match `YSE::DSP::MODULES::eqBand` (see `parametricEQ.hpp`). The
`YSE_EQ_BAND_COUNT` sentinel is intentionally omitted.

Values
------

.. _eq_band.lowShelf:

``lowShelf``

   Low shelf.

.. _eq_band.peak1:

``peak1``

   First peaking band.

.. _eq_band.peak2:

``peak2``

   Second peaking band.

.. _eq_band.highShelf:

``highShelf``

   High shelf.

Constructors
------------

.. code-block:: dart

   EqBand(this.native)

Properties
----------

.. code-block:: dart

   final raw.YseEqBand native

