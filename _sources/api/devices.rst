Devices
=======

Read-only descriptors for the audio devices visible to the engine,
plus the owned :class:`DeviceSetup` builder passed to
:py:meth:`System.openDevice`.

Fill the list with :py:meth:`System.refreshDevices` (no stream is opened,
and it works before ``init()`` and on an offline session) or as a side
effect of :py:meth:`System.init`. A refresh replaces the list, so
descriptors and setups built from the old one are invalid afterwards:
match devices by :py:attr:`Device.name` and :py:attr:`Device.hostName`,
never by index. ``openDevice`` throws :class:`YseException` when no stream
opens. :doc:`/intro/sessions_and_devices` covers device selection,
sample rates and auto-reconnect end to end.

Upstream: :yse-cpp:`YSE::device <api/devices.html>`.

.. include:: _generated/device.rst

.. include:: _generated/device_setup.rst
