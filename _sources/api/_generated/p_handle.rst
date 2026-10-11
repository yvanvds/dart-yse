PHandle
=======

.. code-block:: dart

   class PHandle

Handle to one object inside a [Patcher].

Owned by the patcher — destruction is via [Patcher.deleteObject], not
by the [PHandle] going out of scope.

Two [PHandle]s are equal when they refer to the same engine object, so a
handle read back from [container] compares equal to the one returned by
[Patcher.createObject].

Properties
----------

.. code-block:: dart

   int get hashCode

.. code-block:: dart

   PHandle? get container

The subpatcher this object is directly inside, or `null` at the top
level. Change it with [Patcher.setContainer].

.. code-block:: dart

   int get subpatcherInlets

How many inlets this subpatcher presents to its parent: one past the
highest index claimed by a `.inlet` or `~inlet` among its direct
contents (messages and signals share one numbering). A subpatcher
whose only `.inlet` has index 2 reports 3. `0` when this object is
not an [Obj.patcher].

Ask this, not [inputs]: a subpatcher owns no pins of its own, so
[inputs] answers 0 for it.

.. code-block:: dart

   int get subpatcherOutlets

How many outlets this subpatcher presents to its parent; the
`.outlet` / `~outlet` counterpart of [subpatcherInlets]. Ask this, not
[outputs], which answers 0 for a subpatcher.

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

The object's whole live GUI state as one string — what a host polls to
draw the control. For a scalar control (`.slider`, `.i`, `.f`, `.dial`,
`.incdec`, `.t`) that is its value; for a structured one
(`.multislider`, `.rslider`, `.matrixctrl`, ...) it is every cell,
space separated, in index order. Empty for an object with no GUI state.

This is the *coherent* read: one engine call, one snapshot. The
per-cell reads ([guiValueCount], [guiValueAt]) are sampled one call at
a time and may mix cells from before and after an edit.

A poll may be **destructive**: `.b` reports a pending press and clears
it. Per object, poll either this getter or the per-cell reads once per
frame — never both, or a consume-on-read object reports its event to
one and not the other.

When [guiValueIsSettable] is `true`, [restoreGuiValue] with this
string puts the state back. Not to be confused with [getGuiProperty],
which is editor decoration persisted with the patch, not live state.

.. code-block:: dart

   int get guiValueCount

How many cells the object's GUI state has: 1 for a scalar control, the
bank size for a `.multislider`, and so on. Objects without GUI state
still answer 1 (their single cell is empty).

The count can change between this read and a following [guiValueAt]
(a list on inlet 0 resizes a `.multislider`); a read past the end
answers the empty string rather than failing.

.. code-block:: dart

   bool get guiValueIsSettable

Whether this object accepts its own GUI state back on inlet 0: `true`
when [restoreGuiValue] restores what [guiValue] read and
[setGuiValueAt] writes one cell.

`false` for objects that predate the protocol, and deliberately for
`.b`, whose value is a consume-on-read press — an event a restore could
only replay.

.. code-block:: dart

   int? get id

Patcher-assigned ID, or `null` when this handle refers to no object
(the engine's `YSE_PATCHER_ID_NONE`).

IDs start at 0 in every patcher, so 0 is a real ID. They are dense and
**reused**: deleting an object frees its number for the next object
created, so an ID identifies an object only while that object is
alive. Keep the [PHandle] if you need a reference that outlives the
number.

.. code-block:: dart

   int get inputs

Number of inlets on this object.

`0` for a subpatcher ([Obj.patcher]): its pins belong to the boundary
objects inside it. Use [subpatcherInlets] instead.

.. code-block:: dart

   int get outputs

Number of outlets on this object.

`0` for a subpatcher ([Obj.patcher]); use [subpatcherOutlets].

Methods
-------

.. code-block:: dart

   bool ==(Object other)

.. code-block:: dart

   String guiValueAt(int index)

One cell of the GUI state, or `''` for an [index] at or past
[guiValueCount]. Cell 0 of a scalar control equals [guiValue].

The targeted read for repainting one cell without re-parsing the whole
state. Reads of several cells are **not atomic** across cells; use
[guiValue] when a coherent snapshot matters. See [guiValue] for the
destructive-poll rule.

Throws [RangeError] for a negative [index].

.. code-block:: dart

   void restoreGuiValue(String state)

Restore a GUI state previously read from [guiValue].

There is no GUI-value setter in the engine by design: this sends
[state] as an ordinary list on inlet 0 (exactly
`sendList(0, state)`), so it passes through the object's own clamps
and may emit on its outlets like any other message.

Throws [StateError] when [guiValueIsSettable] is `false`.

.. code-block:: dart

   void setGuiValueAt(int index, String value)

Write one cell of the GUI state: sends `set <index> <value>` on
inlet 0. On a `.textedit` — a one-cell control whose cell is free text
and so has no `set` form — [value] is sent as the whole state instead.

The engine drops a cell write whose index is past its live count;
this wrapper rejects one past the count it reads now.

Throws [StateError] when [guiValueIsSettable] is `false`, and
[RangeError] when [index] is outside `0 <= index < guiValueCount`.

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

   int? connectionTargetId(int outlet, int connection)

ID of the target object of one [connection] from [outlet], or `null`
when there is no such edge (the engine's `YSE_PATCHER_ID_NONE`: an
outlet or connection index out of range). See [id] for ID lifetime.

.. code-block:: dart

   int? connectionTargetInlet(int outlet, int connection)

Inlet on the target reached by [connection] from [outlet], or `null`
when there is no such edge (the engine's `YSE_PATCHER_INLET_NONE`).

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

GUI properties are editor decoration — geometry, colour, anything the
host wants persisted with the patch (serialised under the `"gui"` key
by [Patcher.dumpJson]). They are opaque to the engine and are **not**
live control state; that is [guiValue].

.. code-block:: dart

   void setGuiProperty(String key, String value)

Write a GUI property: editor decoration stored with the patch, not the
object's live state. To change what a control holds, use
[restoreGuiValue] or [setGuiValueAt].

