Bus
===

.. code-block:: dart

   abstract class Bus

Host access to the engine's global named bus: publish a value to an
address, subscribe to one exact address, or tap every address under a
prefix.

The bus is the engine's message plane. A value published to an address
reaches everything listening there, whoever published it — a host
[publish], a live-coding script's `yse.send(...)`, or a patcher `.s`
(`gSend`) object. The address namespaces the engine itself listens on:

.. list-table::
   :header-rows: 1

   * - Address
     - Listener
   * - `synth.<name>.<event>`
     - a synth named with `Synth.busName`
   * - `patcher.<name>.<slot>`
     - a `.r` object in a named patcher
   * - `sound.<name>.<prop>`
     - a named sound
   * - `channel.<name>.<prop>`
     - a named channel


Anything else is free for the host and scripts to use (`phi.ctl.play`,
…): only [subscribe]rs and [tap]s hear it. All addresses match
exact-string and case-sensitively, except a [tap], which is a byte-wise
prefix match.

## Threading

Call every member from the isolate that called `System.init()` /
`System.initOffline()` — the control thread, which drives
`System.update()`. A [publish] from there dispatches synchronously: every
engine-side listener, [subscribe]r and [tap] callback has run by the time
it returns, and the matching frames are already queued on their streams
(Dart listeners receive them in a microtask, without needing an
`update()`). Publishes the engine makes from other threads (the script
thread, the audio thread) are delivered during the next `update()`.

Never publish from an audio callback, or concurrently with
`System.close()`.

## Lifecycle

[subscribe] and [tap] streams are bound to the engine session they were
created in. `System.close()` releases every native subscription and closes
every bus stream (listeners get `onDone`); subscribe again after the next
init.

Static methods
--------------

.. code-block:: dart

   static void publish(String address, BusValue value)

Publish [value] to the exact [address].

The publish takes the same path as a script's `yse.send(...)`, so it
reaches everything a script can — see the address table on [Bus]. On the
control isolate it dispatches synchronously. A publish nobody listens to
is not an error.

Throws [YseException] with status `YSE_ERR_NOT_INITIALIZED` when the
engine is not running, or `YSE_ERR_INVALID_ARGUMENT` for an empty
[address]. Throws [ArgumentError] for a [BusInt] outside the signed
32-bit range.

.. code-block:: dart

   static Stream<BusFrame> subscribe(String address)

Broadcast stream of every value published to exactly [address].

Unlike [tap], this is an exact match: a subscription to
`patcher.lead.cutoff` does not see `patcher.lead.cutoff2`. Each frame's
`address` is [address] itself.

All listeners of one [address] share a single native subscription,
created on the first call and released when the last listener cancels
(a later call creates a fresh one). See [Bus] for threading and
lifecycle.

The engine fires the native callback on the control thread — inline
for a control-thread publish, else during `System.update()` — never on
the audio thread. Its `address`, string and list payloads are
engine-owned and valid only for the duration of the call, so the bridge
is a `NativeCallable.isolateLocal` that copies everything out before
returning.

Throws [ArgumentError] for an empty [address], and [StateError] if the
engine rejects the subscription (e.g. before `System.init`).

.. code-block:: dart

   static Stream<BusFrame> tap(String prefix)

Broadcast stream of every value published to any address that starts
with [prefix] (a plain byte-wise prefix match; the empty string matches
every address). Each frame carries the full address it was published on.

A tap adds no audio-thread cost: the match happens in the engine's
control-thread dispatch. Sharing, threading, payload copying and
lifecycle are exactly as for [subscribe].

Throws [StateError] if the engine rejects the tap (e.g. before
`System.init`).

