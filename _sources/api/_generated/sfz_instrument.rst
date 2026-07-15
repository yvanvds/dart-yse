SfzInstrument
=============

.. code-block:: dart

   class SfzInstrument implements Finalizable

A loadable SFZ sampler instrument (issue #23 / engine issue #174).

A shareable, engine-lifetime-independent asset: a parsed SFZ region table
plus the resident PCM it references. Load one from disk with
[SfzInstrument.load], or synthesise a single-region instrument around one
sample file with [SfzInstrument.fromSample]. Hand it to a synth's sampler
voice pool via [Synth.addSamplerVoices].

The handle is reference-counted: a voice group that renders the instrument
retains its own share, so it is safe to [dispose] this handle right after
[Synth.addSamplerVoices] returns, and safe to hold or dispose it across
[System] close. Loading decodes samples on the calling isolate (never the
audio thread), so construct these off any latency-sensitive path.

Constructors
------------

.. code-block:: dart

   factory SfzInstrument.load(String path)

Load and preload an `.sfz` file, decoding every unique sample into RAM.

Throws [YseException] if the file is unreadable, empty, or has no
playable region.

.. code-block:: dart

   factory SfzInstrument.fromSample(String file, {String? name, int root = 60, int low = 0, int high = 127, double attack = 0.0, double release = 0.1, double maxLength = 0.0})

Build a one-region instrument around a single sample [file] without an
`.sfz` text file.

[root] is the key that plays the sample untransposed; [low] and [high]
bound the playable key range. [attack] and [release] are the amplitude
envelope times in seconds; [maxLength] caps a non-looping one-shot in
seconds. [name] is an optional label used only for identification.

Throws [YseException] if the sample is missing or unreadable.

Properties
----------

.. code-block:: dart

   bool get isValid

Whether the instrument is playable (a valid region table with at least
one resident sample).

.. code-block:: dart

   Pointer<YseSfzInstrument> get handle

Raw native handle, for sibling wrappers within `lib/src/`
(e.g. [Synth.addSamplerVoices]). Not part of the public API surface.

Methods
-------

.. code-block:: dart

   void dispose()

Release the instrument. Idempotent; a double free is a logged no-op.

