Sound
=====

Sound playback. Construct one :class:`Sound` per voice in the scene
via :py:meth:`Sound.fromFile`, :py:meth:`Sound.fromBuffer`, or
:py:meth:`Sound.fromPatcher`.

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
