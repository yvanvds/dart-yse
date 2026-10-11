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

Methods
-------

.. code-block:: dart

   void loadFile(String filename, {int channel = 0})

Load one channel from an audio file.

Throws [YseException] on failure (file missing, wrong channel, etc.).

.. code-block:: dart

   void saveFile(String filename)

Save the contents to a mono WAV file.

