Music
=====

Musical primitives — :class:`Note`, :class:`PNote`, :class:`Scale`,
:class:`Motif` — and the generative :class:`Player` that builds on them.
The primitives are usable on their own.

A player plays its notes on the :class:`Synth` it is constructed with;
attach that synth to a playing sound (:py:meth:`Sound.fromSynth`) to hear
it:

.. code-block:: dart

   final synth = Synth()..addSineVoices(8);
   final sound = Sound.fromSynth(synth)..play();
   final player = Player(synth)
     ..setScale(Scale()..add(60)..add(64)..add(67))
     ..play();

The engine borrows the synth, the active scales and every added motif.
The player holds Dart references to them, so garbage collection never
frees one while the player can still read it, and they are released only
after the player's native destroy. Dispose the player before any of them,
and let one audio block run before disposing the synth: the engine retires
a destroyed player on its next block and still sends note-offs to the
synth then.

Upstream: :yse-cpp:`api/music.html <YSE::note>`.

.. include:: _generated/note.rst

.. include:: _generated/p_note.rst

.. include:: _generated/scale.rst

.. include:: _generated/motif.rst

.. include:: _generated/player.rst
