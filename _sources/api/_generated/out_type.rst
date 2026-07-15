enum OutType
============

.. code-block:: dart

   enum OutType

Data type produced by a patcher outlet ([PHandle.outputDataType]).

Values match `YSE::OUT_TYPE`.

Values
------

.. _out_type.invalid:

``invalid``

.. _out_type.bang:

``bang``

.. _out_type.float:

``float``

.. _out_type.integer:

``integer``

.. _out_type.buffer:

``buffer``

.. _out_type.list:

``list``

.. _out_type.any:

``any``

Constructors
------------

.. code-block:: dart

   OutType(this.native)

Static methods
--------------

.. code-block:: dart

   static OutType fromNative(raw.YseOutType native)

Maps a raw C-side [raw.YseOutType] to its Dart enum, defaulting to
[OutType.invalid] for unknown values.

Properties
----------

.. code-block:: dart

   final raw.YseOutType native

