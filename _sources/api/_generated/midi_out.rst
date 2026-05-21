MidiOut
=======

.. code-block:: dart

   class MidiOut implements Finalizable

MIDI output port (Windows / Linux only; backed by RtMidi upstream).

Enumerate device counts with [System.midiOutDeviceCount] and names
with [System.midiOutDeviceName], then open one with [MidiOut.open].

Constructors
------------

.. code-block:: dart

   factory MidiOut.open(int port)

Open the MIDI device at [port].

Properties
----------

.. code-block:: dart

   set localControl(bool on)

Toggle local-keyboard control on the receiving instrument.

.. code-block:: dart

   set omni(bool on)

Toggle Omni mode on the receiving instrument.

.. code-block:: dart

   set poly(bool on)

Toggle Poly (`true`) or Mono (`false`) mode on the receiving instrument.

Methods
-------

.. code-block:: dart

   void noteOn({required int channel, required int pitch, required int velocity})

Send Note-On. [channel] is 0..15, [pitch] is 0..127.

.. code-block:: dart

   void noteOff({required int channel, required int pitch, int velocity = 0})

Send Note-Off.

.. code-block:: dart

   void polyPressure({required int channel, required int pitch, required int value})

Send polyphonic key-pressure (aftertouch).

.. code-block:: dart

   void channelPressure({required int channel, required int value})

Send channel-pressure.

.. code-block:: dart

   void programChange({required int channel, required int value})

Send program-change.

.. code-block:: dart

   void controlChange({required int channel, required int controller, required int value})

Send control-change.

.. code-block:: dart

   void allNotesOff({int? channel})

Send All-Notes-Off on a specific [channel].

.. code-block:: dart

   void reset({int? channel})

Send Reset-All-Controllers on a specific [channel] (or all if null).

.. code-block:: dart

   void raw3(int a, int b, int c)

Send three raw MIDI bytes.

.. code-block:: dart

   void dispose()

Destroy the underlying native port and detach the finalizer.

