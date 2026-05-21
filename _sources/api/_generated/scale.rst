Scale
=====

.. code-block:: dart

   class Scale implements Finalizable

A set of allowed pitches.

Drives the [Player] so its generated notes stay in key, and
constrains the transpositions a [Motif] can take.

Constructors
------------

.. code-block:: dart

   factory Scale()

Construct an empty scale.

Properties
----------

.. code-block:: dart

   Pointer<YseScale> get handle

Internal: native handle.

.. code-block:: dart

   int get size

Number of pitches in the scale.

Methods
-------

.. code-block:: dart

   void add(double pitch, {double octaveStep = 12})

Add a pitch to the scale.

[octaveStep] controls automatic octave replication: 12 (default)
replicates the pitch at every octave; values <= 0 add only the
exact pitch.

.. code-block:: dart

   void remove(double pitch, {double octaveStep = 12})

Remove a pitch (with optional octave replication).

.. code-block:: dart

   bool has(double pitch)

Whether [pitch] is a member of the scale.

.. code-block:: dart

   double nearest(double pitch)

Nearest in-scale pitch to [pitch].

.. code-block:: dart

   void clear()

Remove every pitch.

.. code-block:: dart

   void dispose()

Destroy the underlying native scale and detach the finalizer.

