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

Requires Dart SDK ≥ 3.8, `git` and `tar`. The default is the engine's
prebuilt release for the pinned tag: `dart run tool/fetch_engine.dart`
downloads it into the gitignored `.engine/<tag>/` (skipped when already
there) and prints the `YSE_DLL_PATH` to use, `.engine/<tag>/libyse-<tag>-windows-x64/bin`
on Windows and `.engine/<tag>/libyse-<tag>-linux-x64/lib` on Linux.
Linux also needs the runtime packages `libportaudio2`, `libsndfile1`,
`librtmidi6`. It fails if the submodule pin is not a release tag.

Building the engine from source is the alternative (and what CI does),
needing CMake ≥ 3.20 and:

- **Windows** — MSYS2 Clang64 (to build `libyse.dll`).
- **Linux** — GCC or Clang, plus `portaudio19-dev`, `libsndfile1-dev`,
  `librtmidi-dev` (Ubuntu 24.04 is the tested baseline).
- **Android** — NDK 27 via Flutter / Gradle, driven by the sibling
  `yse_flutter_libs` plugin under `packages/`. The plugin's Gradle
  module externalNativeBuild's the engine CMakeLists for each ABI
  (#91 tracks using the android release tarball instead).

See [README.md](README.md) for both recipes.

`third_party/yse-soundengine` is a normal git submodule pinned to an
engine release tag. Clone with `--recurse-submodules`, or run
`git submodule update --init` in an existing clone. `ffigen`, the drift
tests (`gen_obj_constants_test`, `gen_patcher_snapshot_test`,
`port_patcher_notes_test`, `patcher_objects_test`) and the docs data all
read that pinned tree, so `git status` should show it clean. Bump it by
checking out a new release tag inside the submodule and committing the
gitlink, then regenerate the bindings. Engine development happens in a
separate clone of yse-soundengine, never through the submodule.

```powershell
# Windows.
dart pub get
dart run tool/fetch_engine.dart
$env:YSE_DLL_PATH = "$PWD\.engine\v3.1.0\libyse-v3.1.0-windows-x64\bin"

dart analyze
dart test
dart run example/hello_sound.dart
```

```bash
# Linux.
dart pub get
dart run tool/fetch_engine.dart
export YSE_DLL_PATH="$PWD/.engine/v3.1.0/libyse-v3.1.0-linux-x64/lib"

dart analyze
dart test
dart run example/hello_sound.dart
```

For Windows-only Linux validation without rebooting, see
`tools/ci-linux/Dockerfile` in the README.

**Unreleased engine (opt-in).** To validate an engine change before it
is tagged, build the separate dev clone and point `YSE_DLL_PATH` at its
output (e.g. `D:\yse-soundengine\build\bin`). Only do this when asked;
the default flow never reads or builds the dev clone. Every engine test
suite then prints an `UNRELEASED ENGINE` banner (from
`test/support/engine_pin.dart`) when `System.version` differs from the
pinned tag or the library is loaded from outside `.engine/<tag>/` and the
submodule's `build/bin`. It never fails a test; drift-test failures under
that banner are expected and must not be "fixed" against the dev engine.
Report which engine a result came from. Bindings regenerated against
unreleased headers are for local experiments only — committed bindings
come from the pinned tag. Once the engine change is released: bump the
pin to the new tag, regenerate the bindings, `dart run
tool/fetch_engine.dart`.

## Boundaries

- **Don't** push to `main` without confirmation.
- **Don't** skip hooks (`--no-verify`) or bypass signing.
- **Don't** hand-edit `lib/src/bindings/yse_bindings.g.dart` — regenerate
  via ffigen, from the pinned tag's headers only (never commit bindings
  generated against an unreleased engine).
- **Don't** point the submodule at an untagged engine commit or develop
  the engine inside it; bump the gitlink only to a release tag.
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
