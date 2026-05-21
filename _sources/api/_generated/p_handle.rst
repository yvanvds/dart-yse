PHandle
=======

.. code-block:: dart

   class PHandle

Handle to one object inside a [Patcher].

Owned by the patcher — destruction is via [Patcher.deleteObject], not
by the [PHandle] going out of scope.

Properties
----------

.. code-block:: dart

   String get type

Type identifier of the underlying object (matches one of [Obj]).

.. code-block:: dart

   String get name

Display name set in the patcher source.

.. code-block:: dart

   String get params

Original creation argument string.

.. code-block:: dart

   String get guiValue

Current GUI display value for objects that have one
(sliders, toggles, ...).

.. code-block:: dart

   int get id

Patcher-assigned unique ID.

.. code-block:: dart

   int get inputs

Number of inlets on this object.

.. code-block:: dart

   int get outputs

Number of outlets on this object.

Methods
-------

.. code-block:: dart

   bool isDspInput(int inlet)

Whether [inlet] accepts an audio signal.

.. code-block:: dart

   OutType outputDataType(int pin)

Data type produced by [pin].

.. code-block:: dart

   int connectionCount(int outlet)

Number of connections leaving [outlet].

.. code-block:: dart

   int connectionTargetId(int outlet, int connection)

ID of the target object of one [connection] from [outlet].

.. code-block:: dart

   int connectionTargetInlet(int outlet, int connection)

Inlet on the target reached by [connection] from [outlet].

.. code-block:: dart

   void sendBang(int inlet)

Send a bang to [inlet].

.. code-block:: dart

   void sendInt(int inlet, int value)

Send an integer to [inlet].

.. code-block:: dart

   void sendFloat(int inlet, double value)

Send a float to [inlet].

.. code-block:: dart

   void sendList(int inlet, String value)

Send a string/list to [inlet].

.. code-block:: dart

   void setParams(String args)

Reconfigure the object with a new argument string.

.. code-block:: dart

   String getGuiProperty(String key)

Read a GUI property by [key].

.. code-block:: dart

   void setGuiProperty(String key, String value)

Write a GUI property.

