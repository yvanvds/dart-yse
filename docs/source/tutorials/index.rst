Tutorials
=========

A guided tour of ``dart-yse``, organised in five progressive phases
that mirror the bundled demos under
`example/ <https://github.com/yvanvds/dart-yse/tree/main/example>`_.
Each demo is a runnable Dart program — work through them in order if
you are new to the wrapper, or jump straight to the one you need if
you are looking up a specific capability.

The Dart demos are ports of the C++ ``Demo.Windows.Native`` demos
shipped with libYSE upstream, so if you follow both worlds the source
shapes will look familiar.

Phase 1 — Fundamentals
----------------------

The minimum you need to put a sound on the speakers — covered in the
:doc:`/intro/hello_sound` walkthrough above.

Phase 2 — Spatial audio and mixing
----------------------------------

3D positioning, channels, audio devices. Demos:

- ``demo04_channels.dart`` — route sounds through pre-built channels.
- ``demo06_devices.dart`` — enumerate output devices and switch
  between them at runtime via :py:meth:`System.openDevice`.

Phase 3 — Effects
-----------------

Reverb zones and DSP effects on individual sounds:

- ``demo05_reverb.dart`` — multiple positioned :class:`Reverb` zones
  that blend into the listener mix as the listener moves through them.
- ``demo07_dsp_buffer.dart`` — load bytes into a :class:`DspBuffer`
  and play it as a sound source via :py:meth:`Sound.fromBuffer`.
- ``demo08_dsp_modules.dart`` — chain :class:`DspObject` effects
  (lowpass, sweep, granulator, ...) onto a sound.

Phase 4 — MIDI and music
------------------------

- ``demo16_midi.dart`` — enumerate MIDI output ports and send
  Note-On / Note-Off via :class:`MidiOut`.
- ``demo17_music.dart`` — build :class:`Note` / :class:`PNote` /
  :class:`Scale` / :class:`Motif` objects (the building blocks of the
  generative :class:`Player`; see the Status note in the README about
  Player itself).

Phase 5 — Modular synthesis
---------------------------

.. toctree::
   :maxdepth: 1

   05_patcher

The Phase-5 tutorial is the only one written as full prose in this
release — the patcher is the largest single API surface and benefits
from a guided introduction. Other tutorials are inline comments in
each demo file; refer to the source under ``example/``.

How to follow along
-------------------

Demos hard-code paths into the ``third_party/yse-soundengine/TestResources/``
directory of the engine submodule, so they should be launched from
the dart-yse repository root:

.. code-block:: sh

   dart run example/hello_sound.dart
   dart run example/demo13_patcher.dart
   # ...

The Windows-on-MSYS2 build leaves ``libyse.dll`` and its dependencies
in ``third_party/yse-soundengine/build/bin/``; the wrapper finds them
automatically when run from the repository root. From elsewhere set
``YSE_DLL_PATH`` to that directory before running.
