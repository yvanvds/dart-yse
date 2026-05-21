Hello, sound
============

The smallest ``dart-yse`` program — init the engine, play an audio
file, wait, shut down.

.. code-block:: dart

   import 'package:yse/yse.dart';

   void main() {
     final sys = System.instance;
     sys.init();

     final sound = Sound.fromFile('drone.ogg', loop: true);
     sound.play();

     // Pump the engine for 3 seconds.
     for (var i = 0; i < 180; i++) {
       sys.update();
       sys.sleep(16);
     }

     sound.dispose();
     sys.close();
   }

What just happened
------------------

- ``System.instance.init()`` opens the default audio device and starts
  the engine's worker threads. Throws :class:`YseException` when no
  audio device is available.
- ``Sound.fromFile('drone.ogg', loop: true)`` asynchronously loads
  ``drone.ogg`` and returns a :class:`Sound` handle. The file path is
  relative to the working directory; an absolute path is more
  predictable. :py:meth:`Sound.play` is safe to call before the load
  finishes — the start is queued.
- The ``update`` / ``sleep`` loop pumps engine state from Dart code.
  If you prefer event-driven scheduling, call
  :py:meth:`System.startUpdateTimer` instead — it runs ``update()``
  off a periodic ``Timer``.
- ``sound.dispose()`` releases the native sound. The DSP buffer it
  decoded survives in the engine's cache until the next
  ``System.close()``.
- ``System.instance.close()`` stops the engine and releases the audio
  device.

What's not here
---------------

Every call you would make in a real application — but that this
minimal example skips — is covered in the tutorials:

- 3D positioning of sounds and the listener
- Volume, pitch, looping
- Routing sounds through :class:`Channel` subtrees
- :class:`Reverb` zones
- The modular :class:`Patcher` graph

See :doc:`/tutorials/index` for the full walk-through.
