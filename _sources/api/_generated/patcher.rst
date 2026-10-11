Patcher
=======

.. code-block:: dart

   class Patcher implements Finalizable

Modular DSP/event graph (Max/MSP-style patcher).

Build a graph programmatically with [createObject] + [connect], or
load one from a JSON dump via [parseJson]. Drive it directly with
[passBang] / [passInt] / [passFloat] / [passString] into named
`.r` (`Obj.gReceive`) objects, listen to what it sends back out on
[messages], or hand it to a [Sound] via [Sound.fromPatcher] to use it
as an audio source.

Constructors
------------

.. code-block:: dart

   factory Patcher({int mainOutputs = 2, String? name})

Construct a patcher with [mainOutputs] audio output channels.

Pass [name] to name the patcher from the start (see [name] for the
rules); `null` or `''` keeps the auto-generated `patcher_<N>` name.

Throws [YseException] if the engine rejects the configuration (e.g. a
negative [mainOutputs], or a [name] longer than [maxNameLength]).

Static accessors
----------------

.. code-block:: dart

   static const int maxNameLength

The longest [name] the engine accepts, in characters.

Properties
----------

.. code-block:: dart

   Pointer<YsePatcher> get handle

Internal: native handle (used by `Sound.fromPatcher`).

.. code-block:: dart

   String get name

.. code-block:: dart

   set name(String? value)

The patcher's name, which scopes every bus slot inside it.

Every patcher has one: an unnamed patcher gets an auto-generated
`patcher_<N>`. A `.s` (`Obj.gSend`) object with slot `x` in a patcher
named `foo` publishes to `patcher.foo.x`, and a `.r` (`Obj.gReceive`)
with slot `x` hears a [Bus.publish] to `patcher.foo.x`. Note the
`patcher.` prefix: host code addressing a patcher slot must add it.

Setting `null` or `''` restores the auto-generated name. Renaming
re-anchors every slot under the new name. Names are **not** unique:
two patchers with the same name share their slots and stores.

The name can be set before the engine is initialised; it is applied
at init. It is saved by [dumpJson] and applied by [parseJson] unless
a name was already set.

Throws [YseException] (`invalidArgument`) for a name longer than
[maxNameLength] characters; the current name is kept.

.. code-block:: dart

   int get objects

Number of objects in the patcher.

.. code-block:: dart

   Stream<PatcherMessage> get messages

Broadcast stream of the messages this patcher sends to the host.

A message arrives here when it is sent to a name that **no `.r`
(`Obj.gReceive`) in this patcher receives**: a `.s` (`Obj.gSend`)
inside the patch, or a [passBang] / [passInt] / [passFloat] /
[passString] call with nothing listening. [PatcherMessage.address] is
that name — the `.s` argument or the `pass*` target — not the
`patcher.<name>.<slot>` bus address (a `.s` also publishes there; see
[name] and `Bus`).

The native send callback is installed when the first listener
subscribes and cleared when the last one cancels. While it is
installed, `pass*` returns `true` even for a name nothing receives
(see [passBang]). Listening before the engine is initialised is fine:
the callback takes effect at init.

## Threading

The engine calls the native callback synchronously on whichever thread
emitted the message — the control thread for a `pass*` or a
[PHandle] `send*` that drives a `.s`, but an **engine worker thread**
for a timer-driven one (a millisecond `.metro` feeding a `.s`). Never
the audio thread. Because it can run off the control thread, the
bridge is a `NativeCallable.listener`: each call is posted to this
isolate and delivered from its event loop, so listeners never run
inside an engine callback and may call back into the patcher freely.
Even a message from a `pass*` on this isolate is therefore delivered
**asynchronously**, after the call returns. Each message's native
strings are copied and released exactly once, including messages
still in flight when the stream is torn down.

## Lifecycle

[dispose] and `System.close()` clear the callback and close the stream
(listeners get `onDone`). After `System.close()`, read [messages]
again for a fresh stream. Reading it on a disposed patcher throws
[StateError].

Methods
-------

.. code-block:: dart

   PHandle createObject(String type, {String args = ''})

Add an object of [type] to the patcher (see [Obj] for constants).

[args] is the creation argument string (object-specific format).
The returned [PHandle] is owned by the patcher — release with
[deleteObject], never directly.

.. code-block:: dart

   void deleteObject(PHandle obj)

Remove [obj] from the patcher.

Deleting a subpatcher (an [Obj.patcher] object) also deletes
everything inside it, transitively — nested subpatchers and their
contents included. Any [PHandle] you still hold that pointed inside
the deleted group is **dangling** afterwards: do not use it.

.. code-block:: dart

   void clear()

Remove every object from the patcher.

.. code-block:: dart

   void setContainer(PHandle obj, PHandle? container)

Put [obj] inside the subpatcher [container], or move it back to the
top level when [container] is `null`.

A subpatcher is an object of type [Obj.patcher]. It is not a separate
[Patcher]: create its contents with [createObject] on this patcher,
then move them inside with this call. Its pins are the boundary
objects among its direct contents — `.inlet` / `~inlet`
([Obj.gInlet] / [Obj.dInlet]) and `.outlet` / `~outlet`
([Obj.gOutlet] / [Obj.dOutlet]), whose one creation argument is the
pin index. Message and signal boundaries share one index space per
side. Subpatchers nest.

Containment is addressing, not storage: nested objects stay in this
patcher's one flat graph, so nesting costs the audio thread nothing.
Moving an object changes no connection, so place objects before you
[connect] to the subpatcher's pins.

Throws [ArgumentError] when [obj] or [container] belongs to another
patcher. Throws [YseException] when the engine refuses the move —
[container] is not an [Obj.patcher] object, or the move would put a
subpatcher inside itself or one of its own descendants. A refused
move changes nothing.

.. code-block:: dart

   void connect(PHandle from, {required int outlet, required PHandle to, required int inlet})

Connect [from]'s [outlet] to [to]'s [inlet].

Either end may be a subpatcher ([Obj.patcher] object): the pin number
is resolved to the boundary object inside it that claims that index,
and the connection is recorded straight to that boundary object (so
walking the graph or [dumpJson] reports the boundary object's ID).
Connecting to a pin no boundary object claims is refused.

.. code-block:: dart

   void disconnect(PHandle from, {required int outlet, required PHandle to, required int inlet})

Remove the connection from [from]'s [outlet] to [to]'s [inlet].

A subpatcher end resolves through its boundary objects as in
[connect].

.. code-block:: dart

   String dumpJson()

Serialise the current graph to JSON.

.. code-block:: dart

   void parseJson(String content)

Load a JSON dump (as produced by [dumpJson]) into this patcher.

Loading **adds to** the current graph: objects already in the patcher
are kept and the loaded ones are created next to them. Call [clear]
first to replace the patch.

Throws [YseException] if [content] is malformed JSON or not a patch.
A failed load is rolled back: the patcher is left exactly as it was.

.. code-block:: dart

   PHandle getHandleAt(int index)

Object at position [index] in the list (0-indexed).

.. code-block:: dart

   PHandle getHandleById(int id)

Object whose ID is [id].

.. code-block:: dart

   bool passBang(String to)

Send a bang to the named `.r` receive object.

Returns `true` when a `.r` named [to] took it. While [messages] has a
listener, a name nothing receives is handed to [messages] instead and
this **also returns `true`**; it returns `false` only when neither
takes it. The same holds for [passInt], [passFloat] and [passString].

.. code-block:: dart

   bool passInt(int value, String to)

Send an integer to a named receiver. See [passBang] for the result.

.. code-block:: dart

   bool passFloat(double value, String to)

Send a float to a named receiver. See [passBang] for the result.

.. code-block:: dart

   bool passString(String value, String to)

Send a string to a named receiver. See [passBang] for the result.

.. code-block:: dart

   void dispose()

Destroy the underlying native patcher and detach the finalizer.

Also clears the send callback and closes [messages].

