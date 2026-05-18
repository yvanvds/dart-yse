# CLAUDE.md

Workflow rules for Claude Code sessions on the dart-yse project. Read at
session start. Pair with [README.md](README.md) for the install / build
recipe and the wrap table.

## How we work

1. **Issues first.** Every bug, feature, or enhancement is filed as a
   labelled GitHub issue *before* code is written. Branch from `main` as
   `<issue-number>-<short-slug>`. PR through review. The only exception
   is a trivial doc fix.
2. **Tests where sensible** (not dogmatically). Pure Dart logic
   (`music.dart` primitives, FFI helpers, enum mappings) gets unit tests.
   Engine-touching paths get smoke-level integration tests that require
   `libyse.dll`. Don't write tests for wrapper plumbing that only the
   engine can validate (audio output, device callbacks).
3. **Related classes from one subsystem live together.** Files under
   `lib/src/` are organised per wrapped subsystem
   (`music.dart` for Note/PNote/Scale/Motif, `midi.dart` for
   MidiFile/MidiOut, etc.). Keep this pattern when adding new wrappers
   rather than splitting one-class-per-file.
4. **Wrapper layering.** Generated bindings
   (`lib/src/bindings/yse_bindings.g.dart`) are the lowest layer.
   `ffi_helpers.dart` + `library.dart` sit above. Subsystem wrappers
   (`sound.dart`, `system.dart`, etc.) consume those helpers and never
   reach into raw FFI from outside `lib/src/`. The public surface
   (`lib/yse.dart`) re-exports the wrappers.
5. **Don't hand-edit generated bindings.** `yse_bindings.g.dart` is
   produced by `ffigen` — regenerate via the ffigen config rather than
   patching the output.

## Label taxonomy

Applied to every issue.

- **type:** `type:bug`, `type:feature`, `type:enhancement`, `type:task`,
  `type:docs`
- **layer:** `layer:system`, `layer:listener`, `layer:sound`,
  `layer:channel`, `layer:reverb`, `layer:device`, `layer:dsp-buffer`,
  `layer:dsp-object`, `layer:patcher`, `layer:midi`, `layer:music`,
  `layer:log`, `layer:buffer-io`, `layer:bindings`, `layer:infra`
- **priority:** `priority:p0-now`, `priority:p1-soon`, `priority:p2-later`,
  `priority:p3-maybe`
- **status:** `status:triaged`, `status:blocked`, `status:in-progress`

Pick at least one `type:` and one `layer:`. Priority and status are
maintainer-applied.

## Running locally

Requires Dart SDK ≥ 3.8, CMake ≥ 3.20, and one of:

- **Windows** — MSYS2 Clang64 (to build `libyse.dll`).
- **Linux** — GCC or Clang, plus `portaudio19-dev`, `libsndfile1-dev`,
  `librtmidi-dev` (Ubuntu 24.04 is the tested baseline).
- **Android** — NDK 27 via Flutter / Gradle, driven by the sibling
  `yse_flutter_libs` plugin under `packages/`. The plugin's Gradle
  module externalNativeBuild's the engine CMakeLists for each ABI.

See [README.md](README.md) for the per-platform build recipe.

```powershell
# Windows. After building libyse.dll into the submodule's build/ dir:
$env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"

dart pub get
dart analyze
dart test
dart run example/hello_sound.dart
```

```bash
# Linux. After building libyse.so into the submodule's build/ dir:
export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"

dart pub get
dart analyze
dart test
dart run example/hello_sound.dart
```

For Windows-only Linux validation without rebooting, see
`tools/ci-linux/Dockerfile` in the README.

## Boundaries

- **Don't** push to `main` without confirmation.
- **Don't** skip hooks (`--no-verify`) or bypass signing.
- **Don't** hand-edit `lib/src/bindings/yse_bindings.g.dart` — regenerate
  via ffigen.
- **Don't** import `lib/src/bindings/` outside `lib/src/`. Consumers of
  the package use the public surface in `lib/yse.dart`; internal
  wrappers go through `ffi_helpers.dart` + `library.dart`.
- **Don't** call into `yse` from an isolate other than the one that
  called `System.init()`, or from the audio callback thread. The engine
  maintains internal queues per-thread; threading violations show up as
  silent corruption.
- **Do** file an upstream issue on `yvanvds/yse-soundengine` when the
  C++ API itself needs to change, rather than working around it in the
  wrapper.

## Memory

There is a Claude Code memory store for this project under
`~/.claude/projects/d--dart-yse/memory/`. It captures durable
preferences and project facts that survive between sessions.
