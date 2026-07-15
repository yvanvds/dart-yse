Chorus
======

.. code-block:: dart

   class Chorus extends DspObject

Chorus / flanger — one modulated-delay [DspObject] with a [mode] switch,
for a channel insert or a send return.

[spread] fans a per-channel LFO phase offset for stereo width. Attach
with `Channel.dsp` or [Sound.setDsp]; the inherited [impact] sets the
wet/dry balance.

Constructors
------------

.. code-block:: dart

   factory Chorus()

Construct a chorus module (defaults to [ChorusMode.chorus]).

Properties
----------

.. code-block:: dart

   ChorusMode get mode

.. code-block:: dart

   set mode(ChorusMode value)

Chorus vs. flanger character.

.. code-block:: dart

   double get rate

.. code-block:: dart

   set rate(double hz)

LFO rate in Hz.

.. code-block:: dart

   double get depth

.. code-block:: dart

   set depth(double value)

Modulation depth.

.. code-block:: dart

   double get feedback

.. code-block:: dart

   set feedback(double value)

Feedback amount (comb resonance; most audible in flanger mode).

.. code-block:: dart

   double get spread

.. code-block:: dart

   set spread(double value)

Stereo spread — the per-channel LFO phase offset.

