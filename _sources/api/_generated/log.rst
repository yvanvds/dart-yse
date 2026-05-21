Log
===

.. code-block:: dart

   class Log

Engine logging facility.

Two ways to consume log output:
  1. Default file sink — controlled via [logfile] and [level].
  2. The [messages] broadcast stream — install once and listen
     from any Dart code. Replaces the file sink for the duration
     of the subscription.

Logging is only active between `System().init()` and
`System().close()`.

Static accessors
----------------

.. code-block:: dart

   static Log get instance

Borrowed singleton accessor.

Properties
----------

.. code-block:: dart

   LogLevel get level

.. code-block:: dart

   set level(LogLevel value)

Current log-level filter. Messages above the chosen level are dropped.

.. code-block:: dart

   String get logfile

.. code-block:: dart

   set logfile(String path)

Path of the default log file (defaults to `YSElog.txt` in the
process working directory). Has no effect after [messages] has
been subscribed.

.. code-block:: dart

   Stream<String> get messages

Broadcast stream of log messages from the engine.

Subscribing replaces the default file sink with an in-process
callback that forwards every message into the stream. The first
subscription installs the bridge; subsequent subscribers share
the same stream.

Cancel the last subscription (or close the engine) to release the
callback. Callbacks run on whichever thread emitted the log
message — `NativeCallable.listener` posts them back to this
isolate via a port, so Dart code only ever sees them serialised
in the isolate's event queue.

Methods
-------

.. code-block:: dart

   void sendMessage(String message)

Send an application-level message to the YSE log. Emitted at
error-level so it survives filters set above [LogLevel.debug].

