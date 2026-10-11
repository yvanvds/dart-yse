Device
======

.. code-block:: dart

   class Device

Read-only descriptor of an audio device on the host system.

Enumerated by the engine — only valid instances are those handed out
by [System.devices]. Inspect [name], [hostName], the channel-name
lists, supported sample rates, and buffer sizes; then build a
[DeviceSetup] from one and pass it to [System.openDevice].

The getters are bound-checked by the engine: the indexed lists stop at
the counts the device reports, and the scalar getters always return a
defined value (0 for an unreported size or latency, -1 for [id]).

Constructors
------------

.. code-block:: dart

   factory Device.borrowed(Pointer<YseDevice> handle)

Internal: wrap a borrowed pointer returned by `yse_system_get_device`.

Properties
----------

.. code-block:: dart

   Pointer<YseDevice> get handle

Internal: native handle (for cross-wrapper plumbing).

.. code-block:: dart

   String get name

Device name as reported by the host.

.. code-block:: dart

   String get hostName

Host (driver) name: `ASIO`, `WASAPI`, `ALSA`, `JACK`, ...

.. code-block:: dart

   List<String> get outputChannelNames

Output channel names.

.. code-block:: dart

   List<String> get inputChannelNames

Input channel names.

.. code-block:: dart

   List<double> get sampleRates

All sample rates this device reports as supported.

.. code-block:: dart

   List<int> get bufferSizes

All buffer sizes this device reports as supported.

.. code-block:: dart

   int get defaultBufferSize

Default buffer size for this device, in frames.

0 means "the host does not advertise one", not "zero frames"; passed
on to [DeviceSetup.bufferSize] it asks the backend to choose. The
PortAudio enumerator (desktop) reports 0 for every device, so read the
negotiated size back from [System.activeBufferSize] once the device is
open.

.. code-block:: dart

   int get outputLatency

Reported output latency in samples.

.. code-block:: dart

   int get inputLatency

Reported input latency in samples.

.. code-block:: dart

   int get id

Host-assigned device ID, or `-1` when this descriptor refers to no
device.

Every device in [System.devices] carries a real, non-negative index.
[System.openDevice] refuses a setup whose output device reads -1.

Methods
-------

.. code-block:: dart

   String toString()

