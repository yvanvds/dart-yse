enum ChannelType
================

.. code-block:: dart

   enum ChannelType

Speaker layout for [System.openDevice].

Values are kept in lockstep with `YSE::CHANNEL_TYPE` (see
`YseEngine/headers/enums.hpp`) so the Dart enum value cast equals
the underlying C enum.

Values
------

.. _channel_type.auto:

``auto``

   Pick stereo when possible.

.. _channel_type.mono:

``mono``

.. _channel_type.stereo:

``stereo``

.. _channel_type.quad:

``quad``

.. _channel_type.surround51:

``surround51``

   5.1 surround.

.. _channel_type.surround51Side:

``surround51Side``

   5.1-side variant.

.. _channel_type.surround61:

``surround61``

   6.1 surround.

.. _channel_type.surround71:

``surround71``

   7.1 surround.

.. _channel_type.custom:

``custom``

   Custom layout — the caller is expected to set speaker positions.

Constructors
------------

.. code-block:: dart

   ChannelType(this.native)

Properties
----------

.. code-block:: dart

   final raw.YseChannelType native

The raw FFI enum value passed to the C ABI.

