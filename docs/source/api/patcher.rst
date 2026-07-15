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
:doc:`patcher_objects` reference page.

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

OutType
-------

Outlet data-type enum returned by :py:meth:`PHandle.outputDataType`.

.. include:: _generated/out_type.rst

Registry introspection
----------------------

Read-only access to the engine's patcher object *registry* — the same
in-code documentation that drives the :doc:`patcher_objects` reference.
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
:py:meth:`Patcher.createObject` accepts. They mirror the upstream
``YSE::OBJ`` namespace one-for-one. Pass the constant or pass the raw
string literal — they are interchangeable.

Every constant on this class is the literal string the engine
recognises, e.g. ``Obj.dSine == '~sine'``. The ``~`` / ``.`` prefix
convention is the same as upstream: ``~`` marks audio-rate (DSP)
objects, ``.`` marks control-rate (event) objects.

Refer to :doc:`patcher_objects` for the full per-object documentation
(inlets, outlets, parameters, ranges).

.. include:: _generated/obj.rst
