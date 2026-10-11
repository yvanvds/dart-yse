Bus
===

The engine's global named bus is its message plane: a value published to an
address reaches everything listening there, whoever published it. The
:py:class:`Bus` façade gives the host all three sides of it:

- :py:meth:`Bus.publish` — send a :py:class:`BusValue` to one exact address.
- :py:meth:`Bus.subscribe` — a broadcast :class:`Stream` of every value
  published to one exact address.
- :py:meth:`Bus.tap` — a broadcast :class:`Stream` of every value published
  under an address *prefix* (byte-wise; ``''`` matches everything).

A host publish takes the same path as a live-coding script's ``yse.send``, so
host, scripts and patcher ``.s`` / ``.r`` objects all share one bus.

.. code-block:: dart

   final synth = Synth()..addSineVoices(8)..busName = 'lead';
   Bus.publish('synth.lead.note', const BusList([1, 60, 0.8]));

   final sub = Bus.subscribe('phi.ctl.play').listen((frame) {
     print('${frame.address}: ${frame.value}');
   });

Address namespaces
------------------

The engine listens on these namespaces. ``<name>`` is the bus name given to
the object; everything is matched exact-string and case-sensitively.

.. list-table::
   :header-rows: 1
   :widths: 30 30 40

   * - Address
     - Listener
     - Payload
   * - ``synth.<name>.note``
     - a :py:class:`Synth` named with ``busName``
     - ``BusList([channel, note, velocity])``
   * - ``synth.<name>.off``
     - same
     - ``BusList([channel, note])`` or ``[channel, note, velocity]``
   * - ``synth.<name>.cc``
     - same
     - ``BusList([channel, number, value])``
   * - ``synth.<name>.bend``
     - same
     - ``BusList([channel, value])``, value in ``[-1, 1]``
   * - ``synth.<name>.aftertouch``
     - same
     - ``BusList([channel, note, value])``; ``note == -1`` is channel-wide
   * - ``synth.<name>.alloff``
     - same
     - ``BusInt(channel)`` (0 = all) or ``BusBang()``
   * - ``patcher.<name>.<slot>``
     - a ``.r`` object in a named patcher
     - any kind
   * - ``sound.<name>.<prop>``
     - a named sound (``volume``, ``speed``, ``position``)
     - float / int; ``position`` takes a list of 3
   * - ``channel.<name>.<prop>``
     - a named channel (``volume``)
     - float / int

Any other address is free for host and script use; only subscribers and taps
hear it. A publish nobody listens to is not an error.

Threading and delivery
----------------------

Call every :py:class:`Bus` member from the isolate that called
:py:meth:`System.init` / :py:meth:`System.initOffline`. The engine fires
subscription and tap callbacks on that control thread — inline for a
control-thread publish, otherwise during :py:meth:`System.update` — never on
the audio thread. So a host :py:meth:`Bus.publish` dispatches synchronously:
when it returns, every engine-side listener has run and the matching frames
are queued on their streams (Dart listeners receive them in a microtask, no
``update()`` needed). Publishes made on the script or audio thread arrive
during the next ``update()``.

The callback's address, string and list payloads are engine-owned and only
valid during the call, so the bridge is a ``NativeCallable.isolateLocal`` that
copies them out before returning.

Never publish from an audio callback, or concurrently with
:py:meth:`System.close`.

Lifecycle
---------

All listeners of one address (or prefix) share a single native subscription,
created on first use and released when the last listener cancels.
:py:meth:`System.close` releases every subscription and tap and closes their
streams; subscribe again after the next init.

:py:meth:`Bus.publish` throws :py:class:`YseException` with
``YSE_ERR_NOT_INITIALIZED`` when the engine is down and
``YSE_ERR_INVALID_ARGUMENT`` for an empty address. :py:meth:`Bus.subscribe`
and :py:meth:`Bus.tap` throw :class:`StateError` when called before init.

``LiveCoding.bus`` is a deprecated forwarder to :py:meth:`Bus.tap`.

.. include:: _generated/bus.rst

.. include:: _generated/bus_value.rst

.. include:: _generated/bus_bang.rst

.. include:: _generated/bus_int.rst

.. include:: _generated/bus_float.rst

.. include:: _generated/bus_string.rst

.. include:: _generated/bus_list.rst
