YseException
============

.. code-block:: dart

   class YseException implements Exception

Exception type for every failure surfaced from the YSE engine.

Wraps a [YseStatus] code (when the underlying call returned one) and a
human-readable message — typically the engine's thread-local last-error
string at the time of failure.

Constructors
------------

.. code-block:: dart

   YseException(this.message, [this.status])

Constructs an exception with a [message] and optional [status].

Properties
----------

.. code-block:: dart

   final String message

Human-readable description of the failure.

.. code-block:: dart

   final YseStatus? status

The raw status code, if the originating C call returns one.

Methods
-------

.. code-block:: dart

   String toString()

