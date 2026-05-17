# yse

Dart bindings for the [YSE sound engine](https://github.com/yvanvds/yse-soundengine)
— 3D audio playback, mixing, DSP, MIDI, and generative music.

## Status

**Pre-release.** v0.x supports **Windows and Linux**; Android is next.
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
`third_party/yse-soundengine/build-linux/` (kept separate from the
Windows `build/` so the two toolchains never collide), runs
`dart analyze`, and exercises the FFI surface via
`tool/linux_smoke.dart` (initOffline → renderOffline; no audio
device required).

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

- [yse-soundengine](https://github.com/yvanvds/yse-soundengine) — the C++ engine this package wraps.
- [Issue tracker](https://github.com/yvanvds/dart-yse/issues)
