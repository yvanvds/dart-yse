What is dart-yse?
=================

``dart-yse`` is the Dart binding for `libYSE
<https://github.com/yvanvds/yse-soundengine>`_, a cross-platform C++
sound engine for games and interactive applications. The wrapper sits
on top of the engine's flat ``extern "C"`` ABI (``yse_c/yse_*.h``) and
exposes every C++ subsystem through idiomatic Dart classes —
:class:`Sound`, :class:`Channel`, :class:`Reverb`, :class:`Patcher`,
:class:`Player`, :class:`MidiOut`, ...

What dart-yse is
----------------

- A **runtime sound engine for Dart applications**. Load audio files
  (wav, ogg, flac), generate audio procedurally from a custom DSP
  source, or build modular Max/MSP-style graphs with the
  :doc:`patcher </tutorials/05_patcher>`.
- **3D positional**. Every :class:`Sound` carries a :class:`Pos`; the
  :class:`Listener` carries position and orientation. Distance
  attenuation, panning, and doppler are computed automatically by the
  engine.
- **Mixable**. :class:`Channel` groups sounds for shared volume control
  and effects. Pre-built channels for music, ambient, voice, GUI, and
  SFX are available out of the box.
- **Embeddable**. Pure Dart FFI — no Flutter dependency. Runs on
  desktop, server-side Dart, and Flutter (Android via the sibling
  ``yse_flutter_libs`` plugin).

What dart-yse is not
--------------------

- Not a Flutter widget library. There is no audio-player widget; the
  package is the engine, not the UI.
- Not a digital audio workstation. There is no timeline editor, no
  plug-in host, no automation lanes.
- Not a stand-alone implementation. Every call ultimately runs through
  the upstream C++ engine — the Dart layer is a thin handle / lifetime
  / type-safety wrapper.

Supported platforms
-------------------

- **Windows** (MSYS2 Clang64)
- **Linux** (Clang or GCC, x64; tested on Ubuntu 24.04)
- **Android** (NDK 27+, API 26+, ``arm64-v8a`` and ``x86_64`` via the
  ``yse_flutter_libs`` Flutter plugin)

The audio backends are PortAudio on desktop and Oboe (AAudio with
OpenSL ES fallback) on Android — chosen by the engine, not the wrapper.
MIDI device I/O uses RtMidi on Windows and Linux; Android has no MIDI
device support.

Pre-release status
------------------

``dart-yse`` is at ``v0.x``. The full C++ API is wrapped except for two
upstream-deferred areas:

- :class:`Player` (the generative note sequencer) is wrapped but every
  method crashes because the upstream ``player::create(synth&)``
  factory is currently commented out. Treat as a placeholder.
- Custom DSP-source subclassing and the callback-based ``YSE::io`` VFS
  are deferred to a later release. :class:`BufferIO` covers the common
  asset-pack use case in the meantime.

Where next
----------

- :doc:`mental_model` — the six concepts you need to know.
- :doc:`install` — get the package and the native library on disk.
- :doc:`hello_sound` — a 25-line program that plays a sound.
