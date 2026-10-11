FileBuffer
==========

.. code-block:: dart

   class FileBuffer extends DrawableBuffer

A [DrawableBuffer] with built-in audio file load and save.

Mirrors the engine's `fileBuffer`.

Constructors
------------

.. code-block:: dart

   FileBuffer({required int length, int overflow = 0})

File buffer of [length] samples (plus [overflow] tail samples). Size
it large enough for the file you intend to [loadFile].

Properties
----------

.. code-block:: dart

   double get fileSampleRate

Native sample rate, in Hz, of the file this buffer was last loaded
from with [loadFile]; 0 before a successful load.

Unlike [sampleRateAdjustment] (a ratio against the engine rate in
effect at load time), this does not change when the engine is
re-initialised at another rate. To re-derive the playback speed
against the live session, use
`fileSampleRate / System.instance.sessionSampleRate` and assign it to
[sampleRateAdjustment].

Methods
-------

.. code-block:: dart

   void loadFile(String filename, {int channel = 0})

Load one channel from an audio file.

Throws [YseException] on failure (file missing, wrong channel, etc.).

.. code-block:: dart

   void saveFile(String filename)

Save the contents to a mono 32-bit float WAV file.

[filename] is used verbatim (no extension is appended). The file is
written at [fileSampleRate] when this buffer was loaded from a file,
or at the engine sample rate otherwise.

Throws [YseException] when the file cannot be created, the buffer is
empty, or a custom [BufferIO] backend is active: that backend is
read-only, so saving refuses rather than bypass it. File I/O — don't
call it from a time-critical path.

