enum PCategory
==============

.. code-block:: dart

   enum PCategory

Documentation category a patcher object type is filed under
([PatcherObjectType.category]).

Drives the section headings on the patcher object reference. Values
match `YSE::PATCHER::pCategory` (mirrored by the C enum
`YsePCategory`).

Values
------

.. _p_category.unset:

``unset``

   Uncategorised — should not reach a shipped object in practice.

.. _p_category.oscillator:

``oscillator``

   Oscillators / signal generators.

.. _p_category.filter:

``filter``

   Filters.

.. _p_category.math:

``math``

   Arithmetic / math objects.

.. _p_category.generic:

``generic``

   Generic routing / utility objects.

.. _p_category.gui:

``gui``

   GUI control objects.

.. _p_category.time:

``time``

   Timing objects.

.. _p_category.midi:

``midi``

   MIDI message objects.

Constructors
------------

.. code-block:: dart

   PCategory(this.native)

Static methods
--------------

.. code-block:: dart

   static PCategory fromNative(raw.YsePCategory native)

Maps a raw C-side [raw.YsePCategory] to its Dart enum, defaulting to
[PCategory.unset] for unknown values.

Properties
----------

.. code-block:: dart

   final raw.YsePCategory native

