DeviceSetup
===========

.. code-block:: dart

   class DeviceSetup implements Finalizable

Configuration passed to [System.openDevice].

Build one by selecting an output [Device], optionally an input [Device],
and (also optionally) a buffer size. The engine falls back to the
device's defaults for fields you don't set. A setup with no output
device is refused by [System.openDevice].

Constructors
------------

.. code-block:: dart

   factory DeviceSetup()

Construct an empty setup. Configure with the [input], [output],
[sampleRate], and [bufferSize] setters before passing to
[System.openDevice].

Properties
----------

.. code-block:: dart

   Pointer<YseDeviceSetup> get handle

Internal: native handle (used by `System.openDevice`).

.. code-block:: dart

   set input(Device value)

Select the input device.

.. code-block:: dart

   set output(Device value)

Select the output device.

.. code-block:: dart

   set sampleRate(double value)

Sample rate in Hz to open the device at; 0 (the default) means no
request.

This does **not** change a running session's rate. The session rate is
fixed from [System.init] / [System.initOffline] until [System.close]:
when this value differs from [System.sessionSampleRate],
[System.openDevice] logs a warning and opens the stream at the session
rate anyway (and throws if the device refuses that rate). To run at a
given rate, set [System.requestedSampleRate] before init instead.

.. code-block:: dart

   set bufferSize(int value)

Device buffer size in frames per callback. 0 lets the backend choose.

.. code-block:: dart

   int get outputChannels

Output channel count of the device selected with [output] — the count
[System.openDevice] opens the stream with. 0 before an output device
is set.

Methods
-------

.. code-block:: dart

   void dispose()

Destroy the underlying native setup and detach the finalizer.

