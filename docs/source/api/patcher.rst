Patcher
=======

Modular Max/MSP-style DSP / event graphs. A :class:`Patcher` owns a
collection of :class:`PHandle`-shaped objects wired together by inlets
and outlets. The graph can be built programmatically, driven from
Dart code, serialised to JSON, and replayed.

Upstream: :yse-cpp:`api/patcher.html <YSE::patcher>` /
:yse-cpp:`api/patcher.html <YSE::pHandle>` /
:yse-cpp:`api/patcher.html <YSE::pObjectList>`.

For an end-to-end walk-through, see :doc:`/tutorials/05_patcher`. The
list of object types ``createObject`` accepts is on the
:doc:`patcher_objects/index` reference page.

Patcher
-------

.. include:: _generated/patcher.rst

PHandle
-------

A :class:`PHandle` is the wrapper's view of one object inside a
:class:`Patcher`. The handle is owned by the patcher — destruction is
through :py:meth:`Patcher.deleteObject`, never by letting the handle
go out of scope. Use :class:`PHandle` to inspect an object's
structure (type, inlets, outlets), walk its outgoing connections,
push messages straight to one of its inlets, and read or write its
GUI metadata.

.. include:: _generated/p_handle.rst

GUI controls
------------

An editor draws a control by polling its **GUI value**, a list of string
cells. Scalar controls (``.slider``, ``.i``, ``.f``, ``.dial``,
``.incdec``, ``.t``) have one cell; structured ones (``.multislider``,
``.rslider``, ``.matrixctrl``, ``.kslider``, ``.function``,
``.xyslider``, ``.umenu``, ...) have several.

- **Read the whole state** with :py:attr:`PHandle.guiValue` — one engine
  call, one coherent snapshot, cells space separated.
- **Read one cell** with :py:attr:`PHandle.guiValueCount` and
  :py:meth:`PHandle.guiValueAt`. These are sampled one call at a time and
  are **not atomic** across cells (an edit can land between two reads, and
  the count can change), so use ``guiValue`` when coherence matters. A
  read past the count answers ``''``.
- **Write** — there is no setter, by design. State goes back in as an
  ordinary message on inlet 0, passing the object's own clamps and outlet
  sends. :py:meth:`PHandle.restoreGuiValue` sends a saved ``guiValue``
  string back; :py:meth:`PHandle.setGuiValueAt` sends ``set <index>
  <value>`` (on ``.textedit``, whose one cell is free text, the value is
  sent as the whole state instead). Both require
  :py:attr:`PHandle.guiValueIsSettable` and are thin wrappers over
  ``sendList(0, ...)``.

Polls can be **destructive**: ``.b`` reports a pending press and clears
it, which is also why ``.b`` is not settable. For a given object, poll
either the whole-state read *or* the per-cell reads once per frame, never
both. Cell strings are engine-formatted (zero reads ``0.``); parse them
rather than comparing text.

GUI *properties* (:py:meth:`PHandle.getGuiProperty` /
:py:meth:`PHandle.setGuiProperty`) are a different thing: editor
decoration such as geometry or colour, opaque to the engine and persisted
with the patch under the ``"gui"`` key of :py:meth:`Patcher.dumpJson`.
They are not live control state.

All of these are synchronous engine calls on the isolate that called
``System.init()``; none involves a callback.

Host I/O
--------

A patcher talks to the host three ways:

- **In, by name** — :py:meth:`Patcher.passBang`, ``passInt``,
  ``passFloat`` and ``passString`` deliver a value to every ``.r``
  (``Obj.gReceive``) object with that name in the patcher.
- **Out, by name** — :py:attr:`Patcher.messages` is a broadcast stream of
  every message the patcher sends to a name *no* ``.r`` in it receives:
  a ``.s`` (``Obj.gSend``) in the patch, or a ``pass*`` call with nothing
  listening. Each :class:`PatcherMessage` carries that name and a
  :class:`BusValue` (lists arrive as a :class:`BusString`). The native
  callback is installed on the first listen and cleared on the last
  cancel; while it is installed, ``pass*`` returns ``true`` even for a
  name nothing receives.
- **The bus** — in a patcher named ``foo``, a ``.s x`` also publishes to
  ``patcher.foo.x`` and a ``.r x`` hears a :py:meth:`Bus.publish` to that
  address. See :doc:`bus`.

The engine calls the send callback on whichever thread emitted the
message: the control thread for a ``pass*`` or a ``PHandle.send*``, an
engine worker thread for a timer-driven one (a millisecond ``.metro``),
never the audio thread. The wrapper therefore bridges it with a
``NativeCallable.listener``: messages are queued to the isolate and
delivered asynchronously from its event loop, so listeners may call back
into the patcher. Every native message block is freed exactly once,
including messages still in flight when :py:meth:`Patcher.dispose` or
``System.close()`` tears the stream down.

.. include:: _generated/patcher_message.rst

OutType
-------

Outlet data-type enum returned by :py:meth:`PHandle.outputDataType`.

.. include:: _generated/out_type.rst

Registry introspection
----------------------

Read-only access to the engine's patcher object *registry* — the same
in-code documentation that drives the :doc:`patcher_objects/index` reference.
Use :class:`PatcherRegistry` to enumerate the registered object types and,
per type, read the description, category, and inlet / outlet / parameter
schema without hard-coding the catalogue.

.. include:: _generated/patcher_registry.rst

.. include:: _generated/patcher_object_type.rst

.. include:: _generated/patcher_inlet.rst

.. include:: _generated/patcher_outlet.rst

.. include:: _generated/patcher_param.rst

Object type constants
---------------------

The constants on :class:`Obj` are the string identifiers that
:py:meth:`Patcher.createObject` accepts. There is one for every type in
the engine registry, named after the upstream ``YSE::OBJ`` constant
(``D_SINE`` becomes ``dSine``), and ``Obj.all`` lists them. Pass the
constant or pass the raw string literal — they are interchangeable.

The class is generated by ``tool/gen_obj_constants.dart`` from the
registry of the bound ``libyse`` and upstream ``pObjectList.hpp``; rerun
it after an engine update (``--check`` reports a stale file).

Every constant on this class is the literal string the engine
recognises, e.g. ``Obj.dSine == '~sine'``. The ``~`` / ``.`` prefix
convention is the same as upstream: ``~`` marks audio-rate (DSP)
objects, ``.`` marks control-rate (event) objects.

Refer to :doc:`patcher_objects/index` for the full per-object documentation
(inlets, outlets, parameters, ranges).

.. include:: _generated/obj.rst
