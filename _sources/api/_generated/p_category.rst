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

.. _p_category.routing:

``routing``

   Message steering (`.gate`, `.route`, `.sel`, ...).

.. _p_category.control:

``control``

   Control flow and ordering (`.trigger`, `.uzi`, ...).

.. _p_category.list:

``list``

   Building and taking apart lists (`.pack`, `.zl`, ...).

.. _p_category.string:

``string``

   Symbols and text (`.sprintf`, `.regexp`, ...).

.. _p_category.collection:

``collection``

   Stores (`.coll`, `.table`, `.bag`, ...).

.. _p_category.dict:

``dict``

   The `.dict` family.

.. _p_category.array:

``array``

   The `.array` family.

.. _p_category.random:

``random``

   Random and probabilistic sources.

.. _p_category.io:

``io``

   Audio and host I/O (`~adc`, `~dac`, `.s`, `.r`, `.print`, ...).

.. _p_category.encapsulation:

``encapsulation``

   Subpatchers and their inlets / outlets.

.. _p_category.sequence:

``sequence``

   Timed recorders / players (`.seq`, `.mtr`, `.qlist`).

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

