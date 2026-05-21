Reverb
======

.. code-block:: dart

   class Reverb implements Finalizable

A positioned reverb zone.

Each reverb holds a set of parameters and a position in the scene. At
the end of every DSP frame the engine blends every reverb whose rolloff
radius overlaps the listener into the single shared reverb processor —
so dropping multiple zones around the world (cave, hall, bathroom)
lets the listener transition smoothly between them.

A fallback "global" reverb is also available via [System.globalReverb];
it's mixed in wherever no positioned zone reaches.

Constructors
------------

.. code-block:: dart

   factory Reverb.borrowed(Pointer<YseReverb> handle)

Internal: wrap a borrowed pointer (the global reverb singleton).

.. code-block:: dart

   factory Reverb()

Construct a new positioned reverb zone.

The native [reverb::create] runs implicitly; the handle is ready to
configure immediately.

Properties
----------

.. code-block:: dart

   bool get isValid

Whether this reverb has a live native implementation.

.. code-block:: dart

   Pos get position

.. code-block:: dart

   set position(Pos value)

Position of the zone in the scene.

.. code-block:: dart

   double get size

.. code-block:: dart

   set size(double value)

Radius within which the reverb is at full strength.

.. code-block:: dart

   double get rollOff

.. code-block:: dart

   set rollOff(double value)

Distance over which the reverb fades to zero beyond [size].

.. code-block:: dart

   bool get active

.. code-block:: dart

   set active(bool value)

Whether this reverb zone contributes to the listener mix.

.. code-block:: dart

   double get roomSize

.. code-block:: dart

   set roomSize(double value)

Simulated room size. Larger values give longer tails.

.. code-block:: dart

   double get damping

.. code-block:: dart

   set damping(double value)

High-frequency damping. Higher values darken the tail faster
(soft-material simulation).

.. code-block:: dart

   double get dry

Current dry-signal level.

.. code-block:: dart

   double get wet

Current wet-signal level.

.. code-block:: dart

   double get modulationFrequency

Current modulation frequency in Hz.

.. code-block:: dart

   double get modulationWidth

Current modulation width.

.. code-block:: dart

   set preset(ReverbPreset value)

Apply a named preset.

Methods
-------

.. code-block:: dart

   void setDryWetBalance({required double dry, required double wet})

Set the dry/wet balance in one call.

[dry] is the unprocessed signal passthrough, [wet] is the
reverberated mix. Sums above 1.0 can clip.

.. code-block:: dart

   void setModulation({required double frequency, required double width})

Add a slow LFO to the tail to break up metallic resonances.

.. code-block:: dart

   void setReflection(int reflection, {required int time, required double gain})

Configure one of the four early reflections (index 0..3).

.. code-block:: dart

   int getReflectionTime(int reflection)

Delay time of the early reflection at [reflection] (0..3).

.. code-block:: dart

   double getReflectionGain(int reflection)

Gain of the early reflection at [reflection] (0..3).

.. code-block:: dart

   void dispose()

Destroy the underlying native reverb and detach the finalizer.

No-op for the borrowed global reverb. Idempotent.

