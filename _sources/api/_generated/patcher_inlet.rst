PatcherInlet
============

.. code-block:: dart

   class PatcherInlet

Documentation for one inlet of a [PatcherObjectType].

Properties
----------

.. code-block:: dart

   final String label

Short inlet label (e.g. `freq`).

.. code-block:: dart

   final String doc

Longer human-readable description.

.. code-block:: dart

   final String range

Documented value range (free-form text, may be empty).

.. code-block:: dart

   final Set<InletAccepts> accepts

The set of message kinds this inlet accepts.

Methods
-------

.. code-block:: dart

   String toString()

