# yse

Dart bindings for the [YSE sound engine](https://github.com/yvanvds/yse-soundengine)
— 3D audio playback, mixing, DSP, MIDI, and generative music.

## Status

**Pre-release.** v0.x supports **Windows, Linux, and Android**; iOS / macOS are next.
The full C++ API is wrapped except for two upstream-deferred areas:

- **Player + synth**: the `Player` class is wrapped but every method
  crashes because YSE's own `player::create(synth&)` factory is
  commented out (synth subsystem is awaiting a rewrite). The wrapper
  is in place so it becomes usable as soon as the engine restores
  the factory; for now treat `Player` as a placeholder.
- **Custom DSP sources** (`dspSourceObject` subclassing) and the
  **callback-based `YSE::io` VFS** — these need audio-thread-safe
  callback plumbing that lands in a later release. `BufferIO` covers
  the common asset-pack use case in the meantime.

## Install

This package consumes YSE through a git submodule and currently
relies on a locally-built engine shared library
(`libyse.dll` on Windows, `libyse.so` on Linux). Until the
native-assets build hook lands you need a manual setup.

### Windows

Requires MSYS2 Clang64 (the same toolchain YSE itself uses) and CMake.

```powershell
# Clone with the submodule.
git clone --recurse-submodules https://github.com/yvanvds/dart-yse
cd dart-yse

# Build libyse.dll once.
cmake -S third_party/yse-soundengine -B third_party/yse-soundengine/build -G Ninja `
      -DCMAKE_BUILD_TYPE=Release `
      -DCMAKE_C_COMPILER=C:/msys64/clang64/bin/clang.exe `
      -DCMAKE_CXX_COMPILER=C:/msys64/clang64/bin/c++.exe
cmake --build third_party/yse-soundengine/build --target yse

# Install the Dart dependencies.
dart pub get
```

At runtime point `YSE_DLL_PATH` at the directory containing
`libyse.dll` (or leave it unset — the loader walks up to find the
`yse` package root):

```powershell
$env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
dart run example/hello_sound.dart
```

(Or copy that directory's contents next to your Dart executable.)

### Linux

Tested on Ubuntu 24.04. Requires CMake ≥ 3.20, Ninja, GCC or Clang,
and the system development packages that YSE links against.

```bash
sudo apt-get install -y \
  build-essential cmake ninja-build pkg-config \
  portaudio19-dev libsndfile1-dev librtmidi-dev

git clone --recurse-submodules https://github.com/yvanvds/dart-yse
cd dart-yse

# Build libyse.so once.
cmake -S third_party/yse-soundengine -B third_party/yse-soundengine/build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release
cmake --build third_party/yse-soundengine/build --target yse

dart pub get
```

At runtime the loader picks `libyse.so` automatically when run from the
package root. Otherwise point `YSE_DLL_PATH` at the build output:

```bash
export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
dart run example/hello_sound.dart
```

The upstream CMake build embeds `$ORIGIN` in the `.so`'s RPATH, so
sibling shared libraries are discovered automatically — no
`LD_LIBRARY_PATH` setup needed.

### Linux validation from Windows (optional)

`tools/ci-linux/Dockerfile` builds an image with the engine deps and
the Dart SDK so you can reproduce the Linux build from a Windows dev
box without rebooting:

```powershell
docker build -t dart-yse-ci -f tools/ci-linux/Dockerfile .
docker run --rm -v ${PWD}:/workspace dart-yse-ci
```

The default command configures + builds `libyse.so` into
`.docker-build/yse/bin/` (a `.gitignore`d directory inside dart-yse —
keeps Docker artefacts out of the Windows `build/` tree and out of
the submodule, so neither toolchain trips on stale CMakeCache
entries left by the other), runs `dart analyze`, and exercises the
FFI surface via `tool/linux_smoke.dart` (initOffline → renderOffline;
no audio device required).

If the submodule is a Windows junction to a separate engine-dev
workspace, bind-mount the junction target into the container at the
submodule path so the container can see the sources:

```powershell
docker run --rm `
  -v "${PWD}:/workspace" `
  -v "D:/yse-soundengine:/workspace/third_party/yse-soundengine" `
  dart-yse-ci
```

### Android

Android consumers add a second package — the sibling Flutter plugin
[`yse_flutter_libs`](packages/yse_flutter_libs/) — which is responsible
for cross-compiling `libyse.so` with the NDK and bundling it into the
APK / AAB. `package:yse` itself stays pure Dart and works unchanged on
CLI / server hosts.

```yaml
dependencies:
  yse: ^0.1.0
  yse_flutter_libs: ^0.1.0
```

Requirements:

- Flutter ≥ 3.22
- Android NDK **27.0.12077973** (matches the engine's CMake config) —
  install via the Android SDK Manager.
- Android Gradle Plugin ≥ 8.5
- `minSdk` 26 so Oboe negotiates the AAudio backend (older devices fall
  back to OpenSL ES, which the engine still supports through Oboe but
  has fewer guarantees on latency).
- Default ABIs: `arm64-v8a`, `x86_64`. Add `armeabi-v7a` via
  `ndk.abiFilters` in your app's `build.gradle` if you target older
  32-bit devices (the engine builds for it but is not routinely tested
  there).

The first Gradle build pulls Oboe and libsndfile sources via
FetchContent and compiles the engine cold — expect 5–10 minutes per
ABI. Subsequent incremental builds are fast.

A minimal end-to-end Flutter sample lives at
[`example/android_sample/`](example/android_sample/) — see the README
there for the one-time `flutter create` scaffold and run instructions.

**Permissions.** Oboe playback needs no runtime permission. Add
`RECORD_AUDIO` to your manifest only if you exercise an input-capture
code path (none is exposed by `package:yse` today).

**Threading.** The audio callback runs on a thread owned by Oboe /
AAudio. As with desktop builds, never call into `yse` from a callback
you didn't install, and keep all `yse.*` calls on the same isolate that
called `System.init()`. On Flutter, that is typically the UI isolate.

## Hello, sound

```dart
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
```

`System.startUpdateTimer()` wraps the update loop in a `Timer.periodic`
if you prefer event-driven code.

## What's wrapped

| Subsystem | Coverage | Notes |
|-----------|----------|-------|
| `System`     | Lifecycle, devices, MIDI device enumeration, global reverb, underwater FX, update loop, version/cpu_load | full |
| `Listener`   | Position, velocity, orientation | full |
| `Sound`      | File / buffer / patcher sources, transport, 3D, mixing, DSP-chain attachment | full |
| `Channel`    | Pre-built singletons, user channels, volume, reverb attach | full |
| `Reverb`     | Positioned + global, presets, full parameter surface | full |
| `Device`     | Read-only descriptors + owned `DeviceSetup` builder | full |
| `DspBuffer`  | Plain / drawable / file / wavetable subclasses, bulk Float32List I/O, draw_line, load/save, band-limited wavetable generators | full |
| `DspObject`  | 11 effects (lowpass, highpass, bandpass, sweep, basicDelay + lp/hp variants, phaser, ringMod, difference, granulator) under one handle with the inherited bypass/impact/LFO surface | full |
| `Patcher`    | Max/MSP-style graph: createObject, connect, JSON round-trip, named-receiver message passing, full `PHandle` introspection | full minus `oscHandler` outbound callback |
| `MidiFile`   | Load / play / pause / stop | full |
| `MidiOut`    | Note / pressure / control / program / raw + reset / all-notes-off | full (Windows/Linux) |
| `Note`/`PNote`/`Scale`/`Motif` | Pitch/volume/length, position, has/nearest/clear, transpose, setFirstPitch | full |
| `Player`     | Wrapped but unusable — see Status above | deferred upstream |
| `Log`        | sendMessage, level, logfile, broadcast `messages` Stream | full |
| `BufferIO`   | Register `Uint8List` bytes under an ID; load by ID | full |

11 example demos under [`example/`](example/) — ports of the C++
demos shipped with yse-soundengine, plus a few extras.

## Threading

- All Dart calls must come from the **same isolate** that called
  `System.init()`. The engine maintains internal queues per-thread.
- The audio callback runs on a private thread the wrapper never
  exposes — never call into `yse` from a callback you didn't
  install.
- `System.update()` must be called from that isolate every frame
  (or use `startUpdateTimer`). It drives message delivery and
  listener-velocity computation.

## License

Eclipse Public License 2.0 — matches the upstream YSE license.

## Links

- [API reference site](https://yvanvds.github.io/dart-yse/) — Sphinx
  docs with tutorials, mental model, and the full Dart API. Built
  from the dartdoc comments in `lib/`; see [docs/README.md](docs/README.md)
  for the local build recipe.
- [yse-soundengine](https://github.com/yvanvds/yse-soundengine) — the C++ engine this package wraps.
- [Issue tracker](https://github.com/yvanvds/dart-yse/issues)
