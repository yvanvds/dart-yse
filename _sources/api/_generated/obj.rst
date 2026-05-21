Obj
===

.. code-block:: dart

   class Obj

Compile-time string identifiers for patcher object types.

Pass any of these to [Patcher.createObject] instead of raw string
literals. The `~` prefix marks DSP / audio-rate objects, `.` marks
control-rate objects. Mirrors `YSE::OBJ` in
`patcher/pObjectList.hpp`.

Static accessors
----------------

.. code-block:: dart

   static const String patcher

.. code-block:: dart

   static const String dDac

.. code-block:: dart

   static const String dAdc

.. code-block:: dart

   static const String dOut

.. code-block:: dart

   static const String dLine

.. code-block:: dart

   static const String gReceive

.. code-block:: dart

   static const String gSend

.. code-block:: dart

   static const String dSine

.. code-block:: dart

   static const String dSaw

.. code-block:: dart

   static const String dNoise

.. code-block:: dart

   static const String gInt

.. code-block:: dart

   static const String gFloat

.. code-block:: dart

   static const String gSlider

.. code-block:: dart

   static const String gButton

.. code-block:: dart

   static const String gToggle

.. code-block:: dart

   static const String gMessage

.. code-block:: dart

   static const String gList

.. code-block:: dart

   static const String gText

.. code-block:: dart

   static const String gCounter

.. code-block:: dart

   static const String gSwitch

.. code-block:: dart

   static const String gGate

.. code-block:: dart

   static const String gRoute

.. code-block:: dart

   static const String gAdd

.. code-block:: dart

   static const String gSubtract

.. code-block:: dart

   static const String gMultiply

.. code-block:: dart

   static const String gDivide

.. code-block:: dart

   static const String dAdd

.. code-block:: dart

   static const String dSubtract

.. code-block:: dart

   static const String dMultiply

.. code-block:: dart

   static const String dDivide

.. code-block:: dart

   static const String dClip

.. code-block:: dart

   static const String midiToFrequency

.. code-block:: dart

   static const String frequencyToMidi

.. code-block:: dart

   static const String dLowpass

.. code-block:: dart

   static const String dHighpass

.. code-block:: dart

   static const String dBandpass

.. code-block:: dart

   static const String dVcf

.. code-block:: dart

   static const String gRandom

.. code-block:: dart

   static const String gMetro

.. code-block:: dart

   static const String mOut

.. code-block:: dart

   static const String mNoteOn

.. code-block:: dart

   static const String mNoteOff

.. code-block:: dart

   static const String mControl

.. code-block:: dart

   static const String mPolyPress

.. code-block:: dart

   static const String mChanPress

.. code-block:: dart

   static const String mProgChange

Static methods
--------------

.. code-block:: dart

   static bool isValid(String type)

Whether [type] is a known object type identifier.

