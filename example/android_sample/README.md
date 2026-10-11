# yse Android sample

Minimal Flutter app that loads `drone.ogg` through `package:yse` and plays
it on loop. Demonstrates that the engine, `yse_flutter_libs` `.so`
bundling, and the FFI load path all work together end-to-end on an Android
device or emulator.

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

Raise the app's `minSdk` to 26, which `yse_flutter_libs` requires (the
template uses Flutter's lower default). In
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

`yse_flutter_libs` packages the engine release named in
`packages/yse_flutter_libs/android/engine.properties` (the submodule's
pinned tag) for `arm64-v8a` and `x86_64`. It uses
`.engine/<tag>/libyse-<tag>-android/` from
`dart run tool/fetch_engine.dart --platform android` when that exists,
and otherwise downloads the release asset (~56 MiB) once into the Gradle
user home. The app shows the loaded `System.version`, which should be
the pinned tag without its `v`.

To run the sample against an unreleased engine instead, compile it from
source by adding to `android/gradle.properties`:

```properties
yse.buildFromSource=true
yse.engineSourceDir=/path/to/yse-soundengine
```

That needs NDK 27.0.12077973, and the first build is slow (~5–10 min per
ABI — fetches Oboe and libsndfile sources, compiles the engine cold).

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

- **`libyse.so not found`** — confirm `yse_flutter_libs` is in
  `pubspec.yaml` *and* `flutter clean` has been run since adding it.
  Gradle caches the merged `lib/<abi>/` set per build configuration.
- **`yse_flutter_libs: could not download ...`** — the first build needs
  github.com. Offline, run `dart run tool/fetch_engine.dart --platform
  android` while you still have a connection, or set `yse.engineDir` to
  an unpacked `libyse-<tag>-android` folder.
- **`CMake error: Could not find a configuration file for package "..."`**
  (source builds only) — the NDK version in
  `packages/yse_flutter_libs/android/build.gradle` (`27.0.12077973`) must
  be installed via the Android SDK Manager.
- **Engine silent on emulator** — the `x86_64` Android emulator routes
  audio through the host. Confirm host audio works first; some emulator
  graphics backends mute audio when the AVD window is unfocused.
