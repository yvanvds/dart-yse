enum ReconnectState
===================

.. code-block:: dart

   enum ReconnectState

What the [System.setAutoReconnect] watchdog last did, read from
[System.reconnectState].

Values match `YSE::RECONNECT_STATE` (see `YseEngine/headers/enums.hpp`).

Values
------

.. _reconnect_state.none:

``none``

   No attempt since the session started, the last successful
   [System.openDevice], or the last [System.setAutoReconnect] call.

.. _reconnect_state.reconnecting:

``reconnecting``

   The last attempt opened nothing; the watchdog tries again after the
   delay. No stream is open, so [System.refreshDevices] can be called to
   pick up a device that was plugged back in.

.. _reconnect_state.restored:

``restored``

   The last attempt reopened the device the session had.

.. _reconnect_state.fellBackToDefault:

``fellBackToDefault``

   The session's device could not be reopened, so the default output
   device was opened instead (only with `fallbackToDefault`).

.. _reconnect_state.failed:

``failed``

   The attempt limit was reached and the watchdog stopped trying.

Constructors
------------

.. code-block:: dart

   ReconnectState(this.native)

Static methods
--------------

.. code-block:: dart

   static ReconnectState fromNative(raw.YseReconnectState native)

Maps a raw C-side [raw.YseReconnectState] to its Dart enum.

Properties
----------

.. code-block:: dart

   final raw.YseReconnectState native

The raw FFI enum value used by the C ABI.

