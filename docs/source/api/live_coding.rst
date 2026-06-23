LiveCoding
==========

Static façade over the engine's embedded-CPython script API
(``yse_python.h``). Submit scripts with :py:meth:`LiveCoding.run` and
observe uncaught Python errors through the :py:attr:`LiveCoding.errors`
broadcast :class:`Stream`.

What live coding is
-------------------

A *live-coding* script is a chunk of Python source you hand to the
engine at runtime. Inside the interpreter the script drives the audio
engine through the ``yse`` Python DSL — a small module of scheduling
verbs that the embedded interpreter exposes:

- ``yse.send`` — push an event into the engine immediately.
- ``yse.on`` — register a callback to fire on a named engine event.
- ``yse.schedule`` — queue an action to run at a future beat / time.
- ``yse.tick`` — advance the script's logical clock by one step.
- ``yse.cancel_all`` — clear every pending scheduled action.
- ``yse.fresh_scope`` — reset the script namespace, discarding state
  accumulated by earlier submissions.

A script is submitted with :py:meth:`LiveCoding.run`, which returns
immediately — the engine takes its own copy of the source and evaluates
it on its script thread. See ``example/demo18_live_coding.dart`` for an
end-to-end submit-and-pump loop.

The full Python-side DSL is owned by the upstream engine; this wrapper
only marshals the source string in and the error text out. For the
complete verb reference see the upstream live-coding epic,
`yvanvds/yse-soundengine#119
<https://github.com/yvanvds/yse-soundengine/issues/119>`_.

Build-dependent behaviour
-------------------------

The CPython interpreter is a compile-time option. Full functionality
requires a library built with ``YSE_ENABLE_PYTHON=ON``;
:py:attr:`LiveCoding.enabled` reports which build you are running
against and is safe to query regardless of engine state.

On an ``OFF`` build the API stays callable — :py:meth:`LiveCoding.run`
does not throw. Instead the engine **synchronously** emits the sentinel
string ``"YSE compiled without YSE_ENABLE_PYTHON"`` through
:py:attr:`LiveCoding.errors` from inside the ``run`` call itself.
Subscribe to ``errors`` *before* calling ``run`` if you want to observe
that sentinel.

Error-delivery model
--------------------

Uncaught Python exceptions and syntax errors do not surface from
:py:meth:`LiveCoding.run` (which has already returned). Instead the
engine formats the traceback and delivers it on the thread that drives
:py:meth:`System.update` — the same isolate that called
:py:meth:`System.init`. Pump the update loop to receive queued
tracebacks, which arrive as strings on the
:py:attr:`LiveCoding.errors` broadcast stream. The OFF-build sentinel
above is the one exception: it fires synchronously during ``run``
rather than on a later ``update``.

.. include:: _generated/live_coding.rst
