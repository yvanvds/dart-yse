# Changelog

## Unreleased

- **API reference site.** New `docs/` tree builds a Sphinx site that
  mirrors the upstream libYSE docs site (sphinx-book-theme, same
  intro / tutorials / API layout) so contributors who already know
  the C++ docs find their way. `tool/emit_api_rst.dart` walks the
  classes re-exported from `lib/yse.dart` and emits one RST page per
  class straight from each class's dartdoc comments — comments stay
  the canonical source of truth, no separate documentation prose to
  drift. The patcher object reference page is rendered at build time
  from the upstream `patcher_objects.json` snapshot via the same
  Jinja template the upstream docs use. A new
  `.github/workflows/docs.yml` builds the site on every push to
  `main` and publishes to `gh-pages`. (Closes #6.)


- **Android support.** `library.dart` resolves `libyse.so` on Android via
  the Android linker (no path lookup — the `.so` is bundled into the
  host APK / AAB under `lib/<abi>/`). A new sibling Flutter plugin
  `packages/yse_flutter_libs/` cross-compiles the engine for each ABI
  (default `arm64-v8a`, `x86_64`) by externalNativeBuild'ing the
  upstream CMakeLists with NDK 27 / minSdk 26. Consumers add both
  `yse` and `yse_flutter_libs` to their `pubspec.yaml`; Gradle picks up
  the resulting `libyse.so` automatically. Oboe is the audio backend
  (AAudio on API 26+ with OpenSL ES fallback). A minimal end-to-end
  sample lives at `example/android_sample/`. README has a parallel
  Android section covering the plugin model, ABI selection,
  permissions, and threading notes.
- **Linux support.** `library.dart` resolves `libyse.so` on Linux in
  addition to `libyse.dll` on Windows. RPATH is `$ORIGIN`, so sibling
  shared libs are discovered without `LD_LIBRARY_PATH`. Tested against
  Ubuntu 24.04 (the GitHub-Actions runner baseline).
- README has parallel Windows / Linux build sections.
- `tools/ci-linux/Dockerfile` builds an image with the engine deps
  plus the Dart SDK so Windows contributors can reproduce a Linux
  build locally without rebooting.
- `tool/linux_smoke.dart` exercises FFI load + `initOffline` /
  `renderOffline` for headless validation in Docker and CI.
- GitHub Actions CI job (Ubuntu 24.04) builds the engine and runs
  `dart analyze` / `dart test` / the headless smoke on every push and
  PR.

## 0.1.0 — initial Windows release

First public release. Wraps the YSE sound engine
([github.com/yvanvds/yse-soundengine](https://github.com/yvanvds/yse-soundengine))
via a hand-authored C ABI bridge that lives upstream (`YseEngine/c_api/`)
plus ffigen-generated low-level bindings + hand-written idiomatic Dart
wrappers in this package.

**Wrapped subsystems:**

- `System` — lifecycle, devices, MIDI device enumeration, global reverb,
  underwater FX, update loop, version, CPU load
- `Listener` — position, velocity, orientation
- `Sound` — file / buffer / patcher sources, transport, 3D, mixing,
  DSP-chain attachment
- `Channel` — pre-built singletons (ChannelMaster / FX / Music / Ambient /
  Voice / Gui), user-created channels, volume, reverb attach
- `Reverb` — positioned + global, 11 presets, full parameter surface
- `Device` + `DeviceSetup` — descriptor enumeration + open-device config
- `DspBuffer` — plain / drawable / file / wavetable subclasses, bulk
  Float32List I/O, draw_line, file load/save, band-limited wavetables
- `DspObject` — 11 effects (lowpass, highpass, bandpass, sweep,
  basicDelay + lp/hp variants, phaser, ringModulator, difference,
  granulator) plus the inherited bypass / impact / LFO surface
- `Patcher` + `PHandle` + `Obj` constants — Max/MSP-style graph with
  JSON round-trip
- `MidiFile`, `MidiOut` — file playback + device output
- `Note`, `PNote`, `Scale`, `Motif` — music-theory primitives
- `Log` — broadcast `Stream<String>` of engine messages via
  `NativeCallable.listener` with ownership-transfer marshalling
- `BufferIO` — register `Uint8List` assets under string IDs

**Known limitations:**

- Android (and Linux) landed in the next release — see Unreleased above.
- `Player` is wrapped but its upstream `player::create(synth&)` factory
  is commented out (synth subsystem deferred upstream) — every method
  call crashes the process. Don't use until YSE restores the synth.
- The callback-based `YSE::io` VFS isn't wrapped — `BufferIO` covers
  the common asset-pack use case.
- Custom `dspSourceObject` subclassing isn't wrapped — buffer-source
  sounds via `Sound.fromBuffer` are the procedural-audio path for now.
- No native-assets build hook yet: consumers point `YSE_DLL_PATH` at a
  locally-built `libyse.dll`. See README for the manual setup.
