MidiIn
======

.. code-block:: dart

   class MidiIn implements Finalizable

MIDI input port (Windows / Linux only; backed by RtMidi upstream).

Enumerate device counts with [System.midiInDeviceCount] and names
with [System.midiInDeviceName], then open one with [MidiIn.open].

Two modes of consumption — subscribe to either or both:
  * [rawMessages] — full message bytes as a [Uint8List].
  * [parsedMessages] — pre-decoded channel-voice scalars.

Native callbacks fire on RtMidi's internal input thread.
`NativeCallable.listener` posts each event back to the isolate that
created this `MidiIn`, so Dart code only ever sees messages
serialised in the isolate's event queue.

Constructors
------------

.. code-block:: dart

   factory MidiIn.open(int port)

Open the MIDI input device at [port].

Properties
----------

.. code-block:: dart

   bool get isOpen

Whether the underlying RtMidi port is currently open.

.. code-block:: dart

   Stream<MidiInRawMessage> get rawMessages

Broadcast stream of raw MIDI messages. Lazily installs the native
callback on first subscription and uninstalls when the last
subscriber cancels.

.. code-block:: dart

   Stream<MidiInParsedMessage> get parsedMessages

Broadcast stream of pre-decoded MIDI messages. Lazily installs the
native callback on first subscription and uninstalls when the last
subscriber cancels.

Methods
-------

.. code-block:: dart

   void close()

Close the port. The instance remains valid but emits no further
messages until re-created.

.. code-block:: dart

   void dispose()

Destroy the underlying native port and detach the finalizer.

