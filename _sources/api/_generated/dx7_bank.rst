Dx7Bank
=======

.. code-block:: dart

   class Dx7Bank implements Finalizable

A parsed DX7 SysEx bank (issue #23 / engine issue #177).

A list of FM patches (1 for a single-voice dump, 32 for a packed bulk
dump) imported from a `.syx` file. Select a patch into a synth's FM voice
pool with [Synth.setFmPatch] — the patch is copied into the synth, so this
bank may be [dispose]d afterwards.

Constructors
------------

.. code-block:: dart

   factory Dx7Bank.load(String path)

Load and parse a DX7 `.syx` file into a bank.

Throws [YseException] if the file is missing, unreadable, has a bad
header, the wrong length, or a checksum mismatch.

.. code-block:: dart

   factory Dx7Bank.fromBytes(Uint8List data)

Parse a DX7 SysEx image already in memory (issue #67) — for hosts that
ship banks as bundled assets (Flutter assets, Android APKs) where there
is no filesystem path.

Accepts the same formats as [Dx7Bank.load]. [data] is copied into a
native buffer for the duration of the call only; neither the copy nor
[data] is retained, so a transient buffer is fine.

Throws [YseException] on empty input, a bad header, the wrong length, or
a checksum mismatch.

Properties
----------

.. code-block:: dart

   int get patchCount

Number of patches in the bank (1 or 32).

.. code-block:: dart

   Pointer<YseDx7Bank> get handle

Raw native handle, for sibling wrappers within `lib/src/`
(e.g. [Synth.setFmPatch]). Not part of the public API surface.

Methods
-------

.. code-block:: dart

   String patchName(int index)

The space-trimmed name of patch [index], or an empty string for an
out-of-range index.

.. code-block:: dart

   int? indexOf(String name)

Index of the first patch whose space-trimmed name equals [name] exactly,
or `null` when no patch matches (issue #67). The match is
case-sensitive and compares against [patchName]'s trimmed form, so pass
the name without the DX7's trailing space padding.

Pairs with [Synth.setFmPatch]:
`synth.setFmPatch(bank, bank.indexOf('E.PIANO 1')!)`.

.. code-block:: dart

   void dispose()

Release the bank. Idempotent; a double free is a logged no-op.

