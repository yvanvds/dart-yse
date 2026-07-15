ParametricEq
============

.. code-block:: dart

   class ParametricEq extends DspObject

Four-band parametric EQ (low shelf, two peaks, high shelf) — a mix-grade
[DspObject] for a channel insert or a send return.

Every parameter is addressed by an [EqBand]; a band with 0 dB [getGain]
is flat (bypassed). Attach with `Channel.dsp` or [Sound.setDsp].

Constructors
------------

.. code-block:: dart

   factory ParametricEq()

Construct a flat four-band parametric EQ.

Methods
-------

.. code-block:: dart

   double getFrequency(EqBand band)

Centre/corner frequency of [band] in Hz.

.. code-block:: dart

   void setFrequency(EqBand band, double hz)

Set the centre/corner frequency of [band] to [hz].

.. code-block:: dart

   double getGain(EqBand band)

Gain of [band] in dB (0 = flat / band bypass).

.. code-block:: dart

   void setGain(EqBand band, double db)

Set the gain of [band] to [db] (0 = flat / band bypass).

.. code-block:: dart

   double getQ(EqBand band)

Q (bandwidth) of [band].

.. code-block:: dart

   void setQ(EqBand band, double value)

Set the Q (bandwidth) of [band] to [value].

