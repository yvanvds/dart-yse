LiveCoding
==========

.. code-block:: dart

   class LiveCoding

Live-coding façade over the engine's embedded-CPython script API.

The C surface (`yse_python.h`) is a set of stateless globals — there is
no native handle — so this is a thin static façade rather than a fetched
singleton. Scripts are submitted with [run] and uncaught Python errors
surface through the [errors] stream.

The interpreter is only present on a `YSE_ENABLE_PYTHON=ON` build; query
[enabled] to tell. On an OFF build [run] is still safe to call — the
engine reports the missing feature through [errors] with a sentinel
"compiled without" message.

Static accessors
----------------

.. code-block:: dart

   static bool get enabled

Compile-time feature query. True only when the library was built with
`YSE_ENABLE_PYTHON=ON`. Safe to call regardless of engine state.

.. code-block:: dart

   static Stream<String> get errors

Broadcast stream of formatted tracebacks from uncaught Python
exceptions and syntax errors. The first subscription installs the
engine error callback; the bridge is torn down when the last
subscriber cancels (or the engine closes).

Unlike [Log.messages], the traceback string is **owned by the engine
and valid only for the duration of the call** — there is no free
function. A `NativeCallable.listener` would copy the pointer and read
it later, by which point it dangles. So this uses
`NativeCallable.isolateLocal`: the closure runs synchronously inside
the C call and copies the string with `toDartString()` before
returning. Safe because the engine fires this callback on the thread
that drives `yse_system_update()` — the main isolate.

Static methods
--------------

.. code-block:: dart

   static void run(String src)

Submit a UTF-8 [src] script for evaluation on the engine's script
thread. Returns immediately; the engine takes its own copy, so the
marshalled buffer is freed on return. Uncaught errors arrive later
through [errors] (during [System].`update()`).

