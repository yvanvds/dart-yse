Install
=======

``dart-yse`` is a pure Dart FFI package that loads the ``libyse`` shared
library at runtime. On Windows x64 and Linux x64 the package brings that
library with it:

.. code-block:: sh

   dart pub add yse

The package's native-assets build hook downloads the prebuilt libYSE
release its bindings were generated from (**v3.1.0**), checks it against
the sha256 digest embedded in the package and bundles it into your app,
together with the engine's runtime DLLs on Windows. ``dart run``,
``dart test``, ``dart build cli`` and ``flutter run`` pick it up with no
further setup. Requirements and caveats:

- Dart SDK ≥ 3.10 (Flutter ≥ 3.38), where build hooks are stable.
- The first build of a project needs network access once; the download
  is cached under ``.dart_tool/`` and later builds work offline.
- Linux needs the runtime libraries the engine links:
  ``sudo apt-get install -y libportaudio2 libsndfile1 librtmidi6``.
- On Windows, a second ``dart run`` / ``dart test`` in the same project
  fails while a program using ``yse`` is still running there (the SDK
  re-copies the bundled DLLs, which Windows locks while loaded).
- Android uses the ``yse_flutter_libs`` plugin (below); macOS and iOS have
  no engine release yet.

The loader looks for the library in this order: the directory in
``YSE_DLL_PATH``, the release the build hook bundled, and
``third_party/yse-soundengine/build/bin/`` in a source tree.
``YSE_DLL_PATH`` is the way to run against another build, such as one of
the source builds below.

Prebuilt engine in a checkout (Windows x64, Linux x64)
------------------------------------------------------

In a clone of dart-yse, ``dart run`` and ``dart test`` use the bundled
release as well. To name the release explicitly with ``YSE_DLL_PATH``,
``tool/fetch_engine.dart`` reads the release tag the engine submodule
pins, downloads that release's binaries for your platform from the
yse-soundengine GitHub releases, checks the sha256 digest GitHub reports
for them, and unpacks them into the gitignored ``.engine/<tag>/``. It
needs the Dart SDK, ``git`` and ``tar`` (built into Windows 10+ and
Linux); no C++ toolchain. A tag already present is not downloaded
again.

.. code-block:: powershell

   # Windows
   git clone --recurse-submodules https://github.com/yvanvds/dart-yse
   cd dart-yse
   dart pub get
   dart run tool/fetch_engine.dart
   $env:YSE_DLL_PATH = "$PWD\.engine\v3.1.0\libyse-v3.1.0-windows-x64\bin"
   dart run example/hello_sound.dart

.. code-block:: sh

   # Linux: runtime libraries only
   sudo apt-get install -y libportaudio2 libsndfile1 librtmidi6

   git clone --recurse-submodules https://github.com/yvanvds/dart-yse
   cd dart-yse
   dart pub get
   dart run tool/fetch_engine.dart
   export YSE_DLL_PATH="$PWD/.engine/v3.1.0/libyse-v3.1.0-linux-x64/lib"
   dart run example/hello_sound.dart

The tool prints the ``YSE_DLL_PATH`` for the pinned tag as its last line.
The release binaries are built with the default options listed under
*Engine version and build options* below (MIDI device I/O on, Python off).

Building from source
--------------------

Build the engine yourself for another platform, or to change build
options. Requirements:

- Dart SDK ≥ 3.10
- CMake ≥ 3.20 + Ninja
- A C/C++ toolchain per platform (see below)

Windows (MSYS2 Clang64)
~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: powershell

   git clone --recurse-submodules https://github.com/yvanvds/dart-yse
   cd dart-yse

   cmake -S third_party/yse-soundengine -B third_party/yse-soundengine/build -G Ninja `
         -DCMAKE_BUILD_TYPE=Release `
         -DCMAKE_C_COMPILER=C:/msys64/clang64/bin/clang.exe `
         -DCMAKE_CXX_COMPILER=C:/msys64/clang64/bin/c++.exe
   cmake --build third_party/yse-soundengine/build --target yse

   dart pub get

Point ``YSE_DLL_PATH`` at the directory containing ``libyse.dll``; without
it the loader takes the release the build hook bundles:

.. code-block:: powershell

   $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
   dart run example/hello_sound.dart

Linux (Ubuntu 24.04)
~~~~~~~~~~~~~~~~~~~~

.. code-block:: sh

   sudo apt-get install -y \
     build-essential cmake ninja-build pkg-config \
     portaudio19-dev libsndfile1-dev librtmidi-dev

   git clone --recurse-submodules https://github.com/yvanvds/dart-yse
   cd dart-yse

   cmake -S third_party/yse-soundengine -B third_party/yse-soundengine/build -G Ninja \
         -DCMAKE_BUILD_TYPE=Release
   cmake --build third_party/yse-soundengine/build --target yse

   dart pub get

The upstream CMake build embeds ``$ORIGIN`` in the ``.so``'s RPATH, so
sibling shared libraries are discovered automatically — no
``LD_LIBRARY_PATH`` setup needed.

.. code-block:: sh

   export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
   dart run example/hello_sound.dart

Engine version and build options
--------------------------------

The submodule is pinned to the libYSE release this package binds
(**v3.1.0** for ``package:yse`` 0.2.0); :py:attr:`System.version` reports
the library you actually loaded. The bindings follow that pin, so fetch
or build the submodule's tag rather than another engine version. In a
clone made without ``--recurse-submodules``, run
``git submodule update --init`` first.

To try an engine change that has no release yet, point ``YSE_DLL_PATH``
at a build of your own yse-soundengine clone (not the submodule, which
stays on its tag). This is an opt-in mode for wrapper development: the
test suite then prints an ``UNRELEASED ENGINE`` banner in every engine
suite, and the bindings committed to the repository still come from the
pinned tag. See *Unreleased engine (opt-in)* in the project README.

Two upstream CMake options change what the wrapper can do:

- ``-DYSE_ENABLE_PYTHON=ON`` (default ``OFF``, desktop only) embeds the
  CPython interpreter behind :class:`LiveCoding`. Without it the API stays
  callable and reports the build through :py:attr:`LiveCoding.enabled`.
  Upstream's ``release-python`` CMake preset sets it.
- ``YSE_ENABLE_MIDI_DEVICE`` (default ``ON`` on Windows and Linux, ``OFF``
  elsewhere) builds the RtMidi device backend behind :class:`MidiIn` /
  :class:`MidiOut`. Without it the MIDI device counts are 0, and the
  patcher objects marked *MIDI device only* in the object reference do not
  exist.

Android (via yse_flutter_libs)
------------------------------

Android consumers add a second package — the sibling Flutter plugin
``yse_flutter_libs`` — which bundles ``libyse.so`` into the APK / AAB:

.. code-block:: yaml

   dependencies:
     yse: ^0.2.0
     yse_flutter_libs: ^0.2.0

The plugin packages the engine's prebuilt Android release
(``libyse-<tag>-android.tar.gz``). Gradle downloads it on the first
build, checks its sha256 and caches it under the Gradle user home, so no
NDK build of the engine is needed. For offline builds, set the Gradle
property ``yse.engineDir`` to an unpacked copy of the asset. Compiling
the engine with the NDK instead is opt-in (``yse.buildFromSource=true``,
NDK 27.0.12077973); the plugin's README describes both.

Requirements: Flutter ≥ 3.38, AGP ≥ 8.5, ``minSdk`` 26 (so Oboe can
negotiate AAudio). The ABIs are ``arm64-v8a`` and ``x86_64``, the ones
the engine's Android release ships.

See the project README for the end-to-end Flutter sample under
``example/android_sample/``.

Verifying the install
---------------------

The 13 demos under ``example/`` are mostly ports of the C++ demos
shipped with libYSE. Each one exercises a different subsystem; start with the
simplest:

.. code-block:: sh

   dart run example/hello_sound.dart

If that prints ``Engine initialised`` and you hear a drone, you're set.

Next
----

- :doc:`hello_sound` — annotated walk-through of the first example.
- :doc:`/tutorials/index` — the full tutorial series.
