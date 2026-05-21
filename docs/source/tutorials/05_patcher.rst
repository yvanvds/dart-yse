Patcher: modular synthesis in code
==================================

Goal: build a small synthesis graph programmatically, drive its
parameters at runtime, then save and reload the graph as JSON.

This tutorial walks through ``example/demo13_patcher.dart`` line by
line. By the end you will have a sine oscillator with a named control
that re-tunes it from Dart code, plus a JSON round trip that can
rebuild the same graph from a string.

Source:
`example/demo13_patcher.dart
<https://github.com/yvanvds/dart-yse/blob/main/example/demo13_patcher.dart>`_.

If you have read the upstream libYSE ``05_patcher`` tutorial that
covers ``Demo13_Patcher.cpp`` and ``Demo14_LoadPatcher.cpp``, the
underlying graph is the same — only the call site moves from C++ to
Dart.

Mental model
------------

A :class:`Patcher` is a graph of small objects. Each object has zero
or more **inlets** (left side, accepting data) and zero or more
**outlets** (right side, emitting data). You wire them together with
:py:meth:`Patcher.connect`; data flows from outlets into inlets.

Object type strings follow a two-character convention that mirrors
Max/MSP:

- ``~`` prefix — audio-rate (DSP) object. ``~sine`` evaluates one
  sample per audio frame.
- ``.`` prefix — control-rate (event) object. ``.r`` (receive) fires
  only when you push data into it with
  :py:meth:`Patcher.passFloat` / :py:meth:`Patcher.passInt` /
  :py:meth:`Patcher.passString` / :py:meth:`Patcher.passBang`.

The full list of supported types is exposed as constants on the
:class:`Obj` class — pass any of them to
:py:meth:`Patcher.createObject` in place of raw string literals.
Every object's accepted inlets, outlets, parameters, and message
types are listed on the :doc:`/api/patcher_objects` reference page,
generated directly from the engine source so it can never drift from
what ``createObject`` actually accepts.

Creating a patcher and attaching it to a sound
----------------------------------------------

A patcher is just an object; you initialise it with the number of
audio outputs it should expose, then hand it to
:py:meth:`Sound.fromPatcher` so the engine drives the graph as a
sound source:

.. code-block:: dart

   final p = Patcher(mainOutputs: 1);                 // 1 = mono; 2 = stereo
   // ... build the graph here ...
   final sound = Sound.fromPatcher(p, volume: 0.3);
   sound.play();

The first argument to :py:meth:`Sound.fromPatcher` is the
:class:`Patcher`; the optional ``channel`` argument routes through a
specific :class:`Channel` (default: master mix). The Sound holds a
borrowed reference to the patcher — keep the ``Patcher`` instance
alive as long as the ``Sound`` is alive.

Building a graph
----------------

:py:meth:`Patcher.createObject` returns a :class:`PHandle` — an owned
pointer into the patcher's object list. There are two ways to
identify a type: the literal string (``'~sine'``) or the corresponding
constant on :class:`Obj` (:py:attr:`Obj.dSine`). Both are
interchangeable — :py:attr:`Obj.dSine` literally is the string
``'~sine'`` at runtime. Use whichever style reads better at the call
site.

.. code-block:: dart

   final sine = p.createObject(Obj.dSine, args: '220');
   final dac  = p.createObject(Obj.dDac);
   final recv = p.createObject(Obj.gReceive, args: 'freq');

The optional ``args`` parameter to :py:meth:`Patcher.createObject` is
the object's creation argument string, parsed by the object exactly
as it would in a saved patch. ``~sine`` with ``'220'`` starts
oscillating at 220 Hz; ``.r`` with ``'freq'`` registers the receive
under the name ``"freq"``; an empty ``args`` leaves the object at its
default configuration.

Connecting objects is the next step. :py:meth:`Patcher.connect` wires
one outlet to one inlet — both are zero-indexed:

.. code-block:: dart

   p.connect(sine, outlet: 0, to: dac, inlet: 0);    // audio out
   p.connect(recv, outlet: 0, to: sine, inlet: 0);   // freq control

The signal flow in this graph is: ``~sine`` (initially 220 Hz, but
overridable through the ``"freq"`` receive) → ``~dac`` (hands the
buffer back to the engine).

Driving parameters at runtime
-----------------------------

The ``.r`` (receive) objects are the patcher's external interface.
Each one has a name; calling
:py:meth:`Patcher.passFloat` /
:py:meth:`Patcher.passInt` /
:py:meth:`Patcher.passString` /
:py:meth:`Patcher.passBang` on the patcher delivers the value to
every ``.r`` registered under that name.

.. code-block:: dart

   final ok = p.passFloat(440, 'freq');     // change pitch to A4
   if (!ok) print('No receiver named "freq" — graph not wired correctly');

Return value of every ``pass*`` method is ``false`` when no receiver
was registered under that name. The four methods cover the four data
types the engine knows about:

- :py:meth:`Patcher.passFloat` for continuous controls (frequency,
  gain).
- :py:meth:`Patcher.passInt` for discrete steps (MIDI note numbers,
  selector indices).
- :py:meth:`Patcher.passString` for symbolic values (a preset name,
  an arbitrary tag the graph dispatches on).
- :py:meth:`Patcher.passBang` for bare triggers with no payload (fire
  an envelope, advance a counter).

Driving an object directly via PHandle
--------------------------------------

The :class:`PHandle` returned by :py:meth:`Patcher.createObject` is
not just a token — it exposes the object's full state to Dart. Use
this to:

- **Read structural information.** :py:attr:`PHandle.type`,
  :py:attr:`PHandle.inputs`, :py:attr:`PHandle.outputs`, and
  :py:meth:`PHandle.isDspInput` describe the object's I/O surface.
  :py:meth:`PHandle.outputDataType` returns an :class:`OutType` enum
  value (``bang``, ``float``, ``integer``, ``buffer``, ``list``,
  ``any``) describing what a given outlet emits — useful when you
  build an external patcher editor on top of the engine.
- **Walk connections.** :py:meth:`PHandle.connectionCount`,
  :py:meth:`PHandle.connectionTargetId`, and
  :py:meth:`PHandle.connectionTargetInlet` return the wiring graph
  outward from each outlet so you can serialise it yourself or check
  what is connected to what.
- **Send messages directly to a specific inlet** — bypassing the
  named-receiver layer. :py:meth:`PHandle.sendBang`,
  :py:meth:`PHandle.sendInt`, :py:meth:`PHandle.sendFloat`, and
  :py:meth:`PHandle.sendList` are the same API a connected outlet
  would call.
- **Reconfigure an object after the fact.**
  :py:meth:`PHandle.setParams` re-runs the object's creation parser
  on a new argument string — equivalent to deleting and recreating it
  but with the connections preserved.
- **Bridge a GUI.** :py:attr:`PHandle.guiValue`,
  :py:meth:`PHandle.getGuiProperty`, and
  :py:meth:`PHandle.setGuiProperty` expose the per-object metadata an
  external editor reads and writes back.

In short: ``Patcher.pass*`` is the convenient broadcast path through
named receives, and ``PHandle.send*`` is the targeted path to one
specific inlet.

Enumerating the graph
---------------------

You can ask the patcher how many objects it contains and fetch a
handle to each one by index or by ID:

.. code-block:: dart

   for (var i = 0; i < p.objects; i++) {
     final h = p.getHandleAt(i);
     print('${h.id}: ${h.type} (${h.inputs} in, ${h.outputs} out)');
   }

This is the entry point for tooling that walks an existing graph —
visualisers, exporters, automated tests that assert on object counts.

Persistence
-----------

The graph — every object, parameter, and connection — can be
serialised to JSON with :py:meth:`Patcher.dumpJson`. The result is
plain UTF-8 text, suitable for writing to disk or shipping as a
preset:

.. code-block:: dart

   final json = p.dumpJson();
   File('mypatch.yap').writeAsStringSync(json);

Reloading is the inverse — read the file, hand the contents to
:py:meth:`Patcher.parseJson`, and the patcher rebuilds itself in
place:

.. code-block:: dart

   final p2 = Patcher(mainOutputs: 1);
   p2.parseJson(File('mypatch.yap').readAsStringSync());

:py:meth:`Patcher.parseJson` replaces the current graph wholesale —
any objects already in the patcher are discarded. After loading,
re-send the initial control values so the receives have something to
forward.

The round trip — patch built once in code, saved to a string,
rebuilt from that string with no code-side knowledge of its internal
structure — is what makes external editors possible. Build the patch
in a desktop tool, ship the resulting JSON as an asset, deserialise
it at runtime.

Lifetime and cleanup
--------------------

Three rules cover the patcher's memory model:

1. A :class:`PHandle` is owned by its :class:`Patcher`. Don't try to
   ``dispose`` it directly — call :py:meth:`Patcher.deleteObject` or
   let :py:meth:`Patcher.clear` / :py:meth:`Patcher.dispose` handle
   it.
2. A :class:`Sound` created from a patcher
   (:py:meth:`Sound.fromPatcher`) holds a borrowed pointer to that
   patcher's native handle. The patcher must outlive the sound.
3. ``Patcher`` is a :py:class:`Finalizable`, so a dropped reference
   eventually frees the native graph — but for predictable timing
   (especially when the sound that wraps it is also being disposed),
   call :py:meth:`Patcher.dispose` explicitly when you're done.

Where to find the full object reference
---------------------------------------

The full set of registered object types — every inlet, outlet,
parameter, and accepted message type — is on the
:doc:`/api/patcher_objects` reference page. That page is generated
directly from the engine source (the same JSON snapshot the upstream
libYSE docs render), so it can never drift from what
:py:meth:`Patcher.createObject` actually accepts.

What you learned
----------------

- A patcher is a node graph. Objects have inlets and outlets; data
  flows along :py:meth:`Patcher.connect` edges.
- ``~`` types run at audio rate, ``.`` types fire on events.
- Use ``.r`` (receive) objects plus
  :py:meth:`Patcher.passFloat` / :py:meth:`Patcher.passInt` etc. to
  drive the graph from application code, or
  :py:meth:`PHandle.sendFloat` etc. to address one specific inlet.
- :class:`PHandle` exposes every piece of structural and runtime
  state for an object — type, connections, GUI properties.
- :py:meth:`Patcher.dumpJson` and :py:meth:`Patcher.parseJson` round-
  trip the whole graph — ship patches as plain text or build an
  external editor on top.

Next
----

- :doc:`/api/patcher` — the full :class:`Patcher` and
  :class:`PHandle` class reference.
- :doc:`/api/patcher_objects` — every patcher object, with inlets,
  outlets, parameters, and value ranges.
- :doc:`/tutorials/index` — index of remaining tutorials.
