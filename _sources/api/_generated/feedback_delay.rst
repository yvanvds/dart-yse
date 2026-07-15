FeedbackDelay
=============

.. code-block:: dart

   class FeedbackDelay extends DspObject

Recirculating feedback delay — a mix-grade [DspObject] for a channel
insert or a send return.

A per-channel delay line with a damping low-pass in the feedback path and
[crossfeed] between channel pairs for ping-pong echoes. `impact(1)` is
echoes-only (send use). Attach with `Channel.dsp` or [Sound.setDsp].

Constructors
------------

.. code-block:: dart

   factory FeedbackDelay()

Construct a feedback delay with the engine's default timing.

Properties
----------

.. code-block:: dart

   double get time

.. code-block:: dart

   set time(double ms)

Delay time in milliseconds.

.. code-block:: dart

   double get feedback

.. code-block:: dart

   set feedback(double amount)

Feedback amount in `[0.0, 1.0)`.

.. code-block:: dart

   double get damping

.. code-block:: dart

   set damping(double hz)

Damping low-pass corner in the feedback path, in Hz.

.. code-block:: dart

   double get crossfeed

.. code-block:: dart

   set crossfeed(double amount)

Cross-feed between the channel pair for ping-pong echoes.

