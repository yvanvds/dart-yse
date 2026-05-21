DeviceSetup
===========

.. code-block:: dart

   class DeviceSetup implements Finalizable

Configuration passed to [System.openDevice].

Build one by selecting an output [Device], optionally an input [Device],
and (also optionally) explicit sample-rate / buffer-size overrides. The
engine falls back to the device's defaults for fields you don't set.

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

Override the device's default sample rate.

.. code-block:: dart

   set bufferSize(int value)

Override the device's default buffer size.

Methods
-------

.. code-block:: dart

   void dispose()

Destroy the underlying native setup and detach the finalizer.

