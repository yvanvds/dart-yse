# yse Android sample

Minimal Flutter app that loads `drone.ogg` through `package:yse` and plays
it on loop. Demonstrates that the engine, the `.so` bundling by the
`yse` build hook, and the FFI load path all work together end-to-end on an
Android device or emulator. The app depends on `yse` alone.

## One-time scaffold

The `android/`, `ios/`, `web/`, etc. Gradle / Xcode projects are not
checked in — `flutter create` regenerates them deterministically and they
add ~150 files of platform glue we'd rather not version. From this
directory, run:

```bash
flutter create --platforms=android --project-name=yse_android_sample .
```

That writes the missing `android/` Gradle project. The `lib/main.dart`,
`pubspec.yaml`, and `assets/` already present here are not overwritten.
It also adds a `.gitignore`, `analysis_options.yaml`, `test/`, `.idea/`
and `yse_android_sample.iml`, which this sample does not use; delete
them.

Raise the app's `minSdk` to 26, which the engine needs for Oboe's AAudio
backend (the template uses Flutter's lower default). In
`android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    minSdk = 26
}
```

Then copy the engine's test sound into `assets/`:

```bash
cp ../../third_party/yse-soundengine/TestResources/drone.ogg assets/
```

(or any other `.ogg` / `.wav` file — `libsndfile` handles both).

## Build + run

Plug in an arm64 device, or boot an `x86_64` emulator, then:

```bash
flutter pub get
flutter run
```

Flutter 3.38 or later runs `package:yse`'s build hook (`hook/build.dart`),
which downloads the engine release named in `lib/src/engine_release.dart`
(the submodule's pinned tag; ~56 MiB, once per project into
`.dart_tool/hooks_runner/shared/yse/`), checks its sha256 and hands Flutter
`lib/<abi>/libyse.so` for `arm64-v8a` and `x86_64`. The app shows the
loaded `System.version`, which should be the pinned tag without its `v`.

To run the sample against an unreleased engine or offline, point the
hook's `engine_dir` user-define at a folder laid out like an unpacked
`libyse-<tag>-android` release (see "Android" in the dart-yse README for
building one from engine sources), in this app's `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    yse:
      engine_dir: /path/to/libyse-android   # holds lib/<abi>/libyse.so
```

`dart run tool/fetch_engine.dart --platform android` in dart-yse unpacks
the pinned release into `.engine/<tag>/libyse-<tag>-android/`, which also
works as an `engine_dir`.

## Threading

The audio callback runs on a thread owned by Oboe. The `Timer.periodic`
in `lib/main.dart` drives `sys.update()` from the **UI isolate** (same
isolate that called `init()`), matching the threading rule documented in
the dart-yse README.

`lib/main.dart` sets `System.renderThreads = 0` before `init()`, so the
mix renders on the Oboe audio thread alone with no worker threads. The
engine's default (`-1`, auto) starts physical cores minus one workers,
which rarely pays off on low-end phones. The output is bit-identical
either way.

## Troubleshooting

- **`The libYSE engine is not in this app`** — the build hook bundled
  nothing for this ABI. The release covers `arm64-v8a` and `x86_64` only;
  a 32-bit device (`armeabi-v7a`) needs an `engine_dir` with that ABI.
  Also check that Flutter is 3.38 or later.
- **`package:yse build hook: could not download ...`** — the first build
  needs github.com. Offline, set `engine_dir` as above.
- **Engine silent on emulator** — the `x86_64` Android emulator routes
  audio through the host. Confirm host audio works first; some emulator
  graphics backends mute audio when the AVD window is unfocused.
