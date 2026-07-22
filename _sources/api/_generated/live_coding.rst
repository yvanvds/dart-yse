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

.. code-block:: dart

   static Stream<BusFrame> bus(String prefix)

Broadcast stream of `(address, value)` frames for every publish on the
engine's global named bus whose address starts with [prefix] (a plain
byte-wise prefix match; the empty string matches every address).

This taps the host-side view of the bus: a script's `yse.send(...)`, a
patcher `gSend` outlet, or any other engine-side publish under [prefix]
arrives here as a typed [BusValue]. A prefix tap adds no audio-thread
cost — the match happens on the engine's control thread.

Each distinct [prefix] gets its own shared broadcast bridge, mirroring
[errors]: the first subscription installs a native `yse_bus_tap`, and it
is torn down (`yse_bus_tap_destroy`) when the last listener cancels. A
later subscription reinstalls a fresh tap.

Isolate-safety matches [errors] exactly. The callback's `address`,
string, and list buffers are **owned by the engine and valid only for
the duration of the call** — there is no free function. So this uses
`NativeCallable.isolateLocal`, copying every payload out (`toDartString`
/ a typed-list copy) synchronously before the C call returns. Safe
because the engine fires the tap on the thread that drives
`yse_system_update()` — the main isolate.

Create the tap after `System.init` / `System.initOffline`; a
`System.close()` invalidates it, and it does not reattach across a
re-init (re-subscribe after the next init). If the engine rejects the
tap (e.g. called before init), a [StateError] is thrown.

