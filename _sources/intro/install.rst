Install
=======

``dart-yse`` is a pure Dart FFI package that depends on a locally-built
``libyse`` shared library. Until the Dart native-assets build hook
lands you build the native side yourself; the package looks up
``libyse`` at runtime via ``YSE_DLL_PATH`` or by walking the source
tree.

Requirements:

- Dart SDK ≥ 3.8
- CMake ≥ 3.20 + Ninja
- A C/C++ toolchain per platform (see below)

Windows (MSYS2 Clang64)
-----------------------

.. code-block:: powershell

   git clone --recurse-submodules https://github.com/yvanvds/dart-yse
   cd dart-yse

   cmake -S third_party/yse-soundengine -B third_party/yse-soundengine/build -G Ninja `
         -DCMAKE_BUILD_TYPE=Release `
         -DCMAKE_C_COMPILER=C:/msys64/clang64/bin/clang.exe `
         -DCMAKE_CXX_COMPILER=C:/msys64/clang64/bin/c++.exe
   cmake --build third_party/yse-soundengine/build --target yse

   dart pub get

Point ``YSE_DLL_PATH`` at the directory containing ``libyse.dll`` (the
loader walks up from the package root by default — so when running
from the repository the env var is optional):

.. code-block:: powershell

   $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
   dart run example/hello_sound.dart

Linux (Ubuntu 24.04)
--------------------

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

Android (via yse_flutter_libs)
------------------------------

Android consumers add a second package — the sibling Flutter plugin
``yse_flutter_libs`` — which cross-compiles ``libyse.so`` with the NDK
and bundles it into the APK / AAB:

.. code-block:: yaml

   dependencies:
     yse: ^0.1.0
     yse_flutter_libs: ^0.1.0

Requirements: Flutter ≥ 3.22, Android NDK 27.0.12077973 (must match
the engine's CMake config), AGP ≥ 8.5, ``minSdk`` 26 (so Oboe can
negotiate AAudio). Default ABIs are ``arm64-v8a`` and ``x86_64``.

See the project README for the end-to-end Flutter sample under
``example/android_sample/``.

Verifying the install
---------------------

The 11 demos under ``example/`` are ports of the C++ demos shipped
with libYSE. Each one exercises a different subsystem; start with the
simplest:

.. code-block:: sh

   dart run example/hello_sound.dart

If that prints ``Engine initialised`` and you hear a drone, you're set.

Next
----

- :doc:`hello_sound` — annotated walk-through of the first example.
- :doc:`/tutorials/index` — the full tutorial series.
