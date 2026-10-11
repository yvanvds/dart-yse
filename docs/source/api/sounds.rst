Sound
=====

Sound playback. Construct one :class:`Sound` per voice in the scene
via one of its loaders:

- :py:meth:`Sound.fromFile` — an audio file, in memory or streamed.
- :py:meth:`Sound.fromBuffer` — a mono in-memory :class:`DspBuffer`.
- :py:meth:`Sound.fromMultiBuffer` — a stereo or surround in-memory
  :class:`DspMultiBuffer`, one buffer per channel. With a non-zero
  :py:attr:`Sound.spread` the source channels fan out around the sound's
  position; at the default spread of 0 they all pan to the same point.
- :py:meth:`Sound.fromPatcher` — the ``~dac`` output of a :class:`Patcher`.
- :py:meth:`Sound.fromSynth` — a :class:`Synth` voice pool.

A buffer or multi-buffer source must outlive the sound. The sound holds a
Dart reference to it, so garbage collection never frees it under a live
sound; call the source's ``dispose()`` only after disposing the sound.

Upstream: :yse-cpp:`api/sounds.html <YSE::sound>`.

Occlusion
---------

A sound with :py:attr:`Sound.occlusion` enabled is ducked by geometry
between it and the listener. The application supplies the amount through
one process-wide callback, :py:attr:`System.occlusion`, which receives the
sound and listener positions (already scaled by the distance factor) and
returns 0 (clear line of sight) to 1 (fully blocked):

.. code-block:: dart

   System.instance.occlusion = (src, lis) => world.raycast(src, lis);
   sound.occlusion = true;

The engine calls it once per occlusion-enabled sound during every
``System.update()``, synchronously on the calling isolate and never on the
audio thread, so the callback may query a physics engine or allocate. Keep
``update()`` on the isolate that installed it. Set ``null`` to remove it;
sounds then keep the last value they received. ``System.close()`` removes it
as well. An exception thrown by the callback counts as 0 for that update and
is reported to the zone the callback was installed in.

.. include:: _generated/sound.rst
