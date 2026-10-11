# yse

Dart bindings for the [YSE sound engine](https://github.com/yvanvds/yse-soundengine)
— 3D audio playback, mixing, DSP, MIDI, and generative music.

## Status

**Pre-release.** v0.x supports **Windows, Linux, and Android**; iOS / macOS are next.

**0.2.0 binds libYSE v3.1.0** (0.1.0 bound libYSE 2.4). This is a breaking
upgrade: `System.init()` now throws when no audio device opens, the
default session rate is 48 kHz, `DspBuffer` subclasses are real classes,
patcher IDs are `int?` and the patcher's bus slots moved under
`patcher.`. The [upgrade guide](https://yvanvds.github.io/dart-yse/intro/upgrading.html)
lists every change with before / after code, and
[CHANGELOG.md](CHANGELOG.md) has the full release notes.

The full C++ API is wrapped except for one upstream-deferred area:

- **Custom DSP sources** (`dspSourceObject` subclassing) and the
  **callback-based `YSE::io` VFS** — these need audio-thread-safe
  callback plumbing that lands in a later release. `BufferIO` covers
  the common asset-pack use case in the meantime.

## Install

This package consumes YSE through a git submodule, pinned to the engine
release the bindings were generated from (libYSE **v3.1.0**), and
currently relies on a locally-built engine shared library
(`libyse.dll` on Windows, `libyse.so` on Linux). Until the
native-assets build hook lands you need a manual setup. Build the
submodule as checked out; `System.version` reports the library actually
loaded.

### The engine submodule

`third_party/yse-soundengine` is an ordinary git submodule pinned to an
engine release tag. The C headers `ffigen` reads, the patcher metadata
the drift tests compare against, and the docs data all come from that
pinned tree, so a local checkout sees exactly what CI sees.

- **Get it:** clone with `--recurse-submodules` (as below), or run
  `git submodule update --init` in an existing clone.
- **Bump it:** check out the new release tag inside the submodule and
  commit the gitlink:

  ```bash
  git -C third_party/yse-soundengine fetch --tags
  git -C third_party/yse-soundengine checkout v3.2.0   # the new tag
  git add third_party/yse-soundengine
  git commit -m "chore(infra): bump libYSE to v3.2.0"
  ```

  Then regenerate the bindings (`dart run ffigen --config ffigen.yaml`),
  fetch the new release (`dart run tool/fetch_engine.dart`) and rerun the
  drift tests. Committed bindings always come from the pinned tag's
  headers; never commit bindings generated against an unreleased engine
  (see [Unreleased engine](#unreleased-engine-opt-in)).
- **Engine development** happens in a separate clone of
  yse-soundengine, not through the submodule. Keep the submodule on its
  release tag; `git status` should show it clean.

Two upstream CMake options matter to the wrapper:
`-DYSE_ENABLE_PYTHON=ON` (default `OFF`, desktop only) embeds the
interpreter behind `LiveCoding`, and `YSE_ENABLE_MIDI_DEVICE` (default
`ON` on Windows / Linux) builds the RtMidi backend behind `MidiIn` /
`MidiOut` and the MIDI-device patcher objects.

### Prebuilt engine (default)

The engine publishes `libyse` binaries for every release tag.
`tool/fetch_engine.dart` reads the tag the submodule pins
(`git describe --tags --exact-match`), downloads that release's asset
for your platform from
`https://github.com/yvanvds/yse-soundengine/releases`, checks it
against the sha256 digest GitHub reports for it, and unpacks it into
the gitignored `.engine/<tag>/`. A tag that is already there is not
downloaded again (`--force` re-fetches). It needs only the Dart SDK,
`git` and `tar` (built into Windows 10+ and Linux); no `gh`, MSYS2 or
CMake. It fails if the pin is not a release tag.

```powershell
# Windows
git clone --recurse-submodules https://github.com/yvanvds/dart-yse
cd dart-yse
dart pub get
dart run tool/fetch_engine.dart
$env:YSE_DLL_PATH = "$PWD\.engine\v3.1.0\libyse-v3.1.0-windows-x64\bin"
dart test
```

```bash
# Linux (x86_64). Runtime libraries only, no build toolchain:
sudo apt-get install -y libportaudio2 libsndfile1 librtmidi6

git clone --recurse-submodules https://github.com/yvanvds/dart-yse
cd dart-yse
dart pub get
dart run tool/fetch_engine.dart
export YSE_DLL_PATH="$PWD/.engine/v3.1.0/libyse-v3.1.0-linux-x64/lib"
dart test
```

The tool prints the exact `YSE_DLL_PATH` for the pinned tag as its last
line. The Windows `bin/` holds `libyse.dll` and all its runtime DLLs. The
release builds use the default options: MIDI device I/O on, Python
(`LiveCoding`) off. The C headers `ffigen` reads still come from the
submodule.

The loader does not look in `.engine/` by itself: that folder exists only
in a dart-yse checkout, never in a published package, so you always say
which engine you run by setting `YSE_DLL_PATH`. To try an engine that has
no release yet, see [Unreleased engine](#unreleased-engine-opt-in).

### Building the engine from source

Use this for a platform without a prebuilt asset, or to change build
options such as `-DYSE_ENABLE_PYTHON=ON`.

#### Windows

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

#### Linux

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

### Unreleased engine (opt-in)

dart-yse is also where engine changes get tried before they are tagged.
To do that, build your own clone of yse-soundengine (not the submodule,
which stays on its release tag) and point `YSE_DLL_PATH` at its output:

```powershell
# Windows, with the dev clone built at D:\yse-soundengine\build
$env:YSE_DLL_PATH = "D:\yse-soundengine\build\bin"
dart test
```

```bash
# Linux
export YSE_DLL_PATH="$HOME/src/yse-soundengine/build/bin"
dart test
```

This mode is only ever entered on purpose; nothing in the default flow
reads or builds a dev clone. While it is active, every engine test suite
prints an `UNRELEASED ENGINE` banner in its setup output, naming the
pinned tag and the library actually loaded. The banner appears when
`System.version` differs from the pinned tag (`3.1.0` for `v3.1.0`) or
when the library comes from anywhere other than `.engine/<tag>/` or
the submodule's own `build/bin` (libYSE's version string only changes
at release time, so a dev build just after a tag still reports that
tag). It never fails a test. Expect snapshot and drift tests to fail
when the dev engine has changed what they check; CI always runs the pin.

To try new C API functions you can regenerate the bindings against the
dev clone's headers (point the `headers.entry-points` path in
`ffigen.yaml` at the clone's `yse_all.h`), but only locally: committed
bindings, and `ffigen.yaml` itself, must stay on the pinned tag's
headers in the submodule. When the
engine change is released, bump the pin to the new tag, regenerate,
and run `dart run tool/fetch_engine.dart`.

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

### Android

Android consumers add a second package — the sibling Flutter plugin
[`yse_flutter_libs`](packages/yse_flutter_libs/) — which is responsible
for cross-compiling `libyse.so` with the NDK and bundling it into the
APK / AAB. `package:yse` itself stays pure Dart and works unchanged on
CLI / server hosts.

```yaml
dependencies:
  yse: ^0.2.0
  yse_flutter_libs: ^0.2.0
```

Keep the two at the same minor version: `yse_flutter_libs` builds the
engine from this repository's submodule, and `yse` 0.2.0 needs the
libYSE 3.1 C ABI it ships.

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

**Render threads.** The engine renders with `physical cores - 1` worker
threads (at most 8) by default. On low-end devices set `System.instance.renderThreads
= 0` before `init()` to render on the audio thread alone (the output is
bit-identical); the Android sample does this.

## Hello, sound

```dart
import 'package:yse/yse.dart';

void main() {
  final sys = System.instance;
  sys.init(); // throws YseException when no audio device opens

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
| `System`     | Device and offline sessions, `requestedSampleRate`, headless speaker layout, device listing without a stream (`refreshDevices`), auto-reconnect with outcome (`reconnectState`, `activeDevice`), render threads, block size, RNG seeding, occlusion callback, MIDI device enumeration, global reverb, underwater FX, update loop, version / CPU load | full |
| `DomainClock` / `ClipTransport` | Named, rampable beat clocks; beat-timed clips played on the audio thread into synths and MIDI ports | full |
| `Listener`   | Position, velocity, orientation | full |
| `Sound`      | File / buffer / multichannel buffer / patcher / synth sources, transport, 3D, occlusion, mixing, DSP-chain attachment, `busName` | full |
| `Channel`    | Pre-built singletons, user channels, aux sends and return buses, insert DSP, peak metering, virtualisation, reverb attach, `busName` | full |
| `Reverb`     | Positioned + global, presets, full parameter surface, preset values + morph (`ReverbPresetValues`) | full |
| `Device`     | Read-only descriptors + owned `DeviceSetup` builder | full |
| `DspBuffer`  | `DspBuffer` / `DrawableBuffer` / `FileBuffer` / `Wavetable` subclasses, bulk Float32List I/O, drawing, load/save, buffer math, copy/swap, band-limited wavetable generators; `DspMultiBuffer` for multichannel sources | full |
| `DspObject`  | 11 base effects (lowpass, highpass, bandpass, sweep, basicDelay + lp/hp variants, phaser, ringMod, difference, granulator) with the inherited bypass/impact/LFO surface, chain walking; mix-grade `Compressor`, `ParametricEq`, `Chorus`, `PlateReverb`, `FeedbackDelay`, `MorphingReverb`, `Underwater`; patcher inserts | full |
| `Patcher`    | Max/MSP-style graph: all 305 objects as `Obj` constants, connect, names and `patcher.<name>.<slot>` bus slots, subpatchers, `messages` stream (the C++ `oscHandler`), GUI value protocol, JSON round-trip, full `PHandle` and registry introspection | full |
| `Synth`      | Sine / virtual-analog / FM (DX7 banks from file or memory) / SFZ sampler voice pools, per-note 3D positions, `busName` | full minus audio-thread hooks (note-rewrite callback, custom voices) |
| `Bus`        | Host publish, exact-address subscribe, prefix tap | full |
| `MidiFile`   | Load / play / pause / stop, synth sink | full |
| `MidiOut`    | Note / pressure / control / program / `raw3` + `raw` (any length, SysEx) / reset / all-notes-off | full (Windows/Linux) |
| `MidiIn`     | Raw and parsed message streams, synth sink | full (Windows/Linux) |
| `Note`/`PNote`/`Scale`/`Motif` | Pitch/volume/length/channel, position, has/nearest/clear, transpose, setFirstPitch | full |
| `Player`     | Generative sequencer on a `Synth`: pitch / velocity / gap / length ranges, voices, scale (with cross-fade), weighted motifs | full |
| `LiveCoding` | Submit scripts to the embedded Python interpreter, error stream | full (needs `YSE_ENABLE_PYTHON=ON`) |
| `Log`        | sendMessage, level, logfile, broadcast `messages` Stream | full |
| `BufferIO`   | Register `Uint8List` bytes under an ID; load by ID | full |

13 example demos under [`example/`](example/) — ports of the C++
demos shipped with yse-soundengine, plus a few extras (`demo19_bus.dart`,
`demo20_clocks_clips.dart`, live coding, log + buffer I/O).

## Threading

- All Dart calls must come from the **same isolate** that called
  `System.init()`. The engine maintains internal queues per-thread.
- The audio callback runs on a private thread the wrapper never
  exposes — never call into `yse` from a callback you didn't
  install.
- `System.update()` must be called from that isolate every frame
  (or use `startUpdateTimer`). It drives message delivery,
  listener-velocity computation, the occlusion callback, bus delivery
  and the auto-reconnect watchdog.
- Engine callbacks reach Dart either synchronously inside `update()`
  (occlusion) or as stream events (`Bus`, `Patcher.messages`,
  `Log.messages`, `MidiIn`). The docs'
  [mental model](https://yvanvds.github.io/dart-yse/intro/mental_model.html)
  page has the per-callback table.

## License

Eclipse Public License 2.0 — matches the upstream YSE license.

## Links

- [API reference site](https://yvanvds.github.io/dart-yse/) — Sphinx
  docs with tutorials, mental model, and the full Dart API. Built
  from the dartdoc comments in `lib/`; see [docs/README.md](docs/README.md)
  for the local build recipe.
- [yse-soundengine](https://github.com/yvanvds/yse-soundengine) — the C++ engine this package wraps.
- [Issue tracker](https://github.com/yvanvds/dart-yse/issues)
