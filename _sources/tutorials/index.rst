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
- ``demo06_devices.dart`` — list the output devices without opening a
  stream (:py:meth:`System.refreshDevices` on an offline session). Opening
  and switching devices is covered in :doc:`/intro/sessions_and_devices`.
- ``demo19_bus.dart`` — name a synth, a sound, a channel and a patcher,
  then drive them all through :py:meth:`Bus.publish` while a
  :py:meth:`Bus.tap` and a :py:meth:`Bus.subscribe` print what goes by.
  See :doc:`/api/bus`.

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
  :class:`Scale` / :class:`Motif` objects, then let a generative
  :class:`Player` improvise on a :class:`Synth` with them.
- ``demo20_clocks_clips.dart`` — loop a bar of notes into a
  :class:`Synth` with a :class:`ClipTransport` on a :class:`DomainClock`,
  glide the tempo and swap the notes while it plays. Written up as a full
  tutorial:

.. toctree::
   :maxdepth: 1

   06_clocks_and_clips

Phase 5 — Modular synthesis
---------------------------

.. toctree::
   :maxdepth: 1

   05_patcher

The patcher and clocks-and-clips tutorials are written as full prose —
they are the largest API surfaces and benefit from a guided introduction.
Other tutorials are inline comments in each demo file; refer to the
source under ``example/``.

How to follow along
-------------------

Demos hard-code paths into the ``third_party/yse-soundengine/TestResources/``
directory of the engine submodule, so they should be launched from
the dart-yse repository root:

.. code-block:: sh

   dart run example/hello_sound.dart
   dart run example/demo13_patcher.dart
   # ...

Set ``YSE_DLL_PATH`` to the directory holding ``libyse`` first. With the
prebuilt engine that is the path ``dart run tool/fetch_engine.dart``
prints (see :doc:`/intro/install`). An engine built from source lands in
``third_party/yse-soundengine/build/bin/``, which the wrapper also finds
without the variable when run from the repository root.
