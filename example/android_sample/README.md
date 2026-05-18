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

The Gradle build invokes the engine's CMake project under
`packages/yse_flutter_libs` for each configured ABI (default
`arm64-v8a` + `x86_64`). First build is slow (~5–10 min — fetches Oboe
and libsndfile sources, compiles the engine cold); subsequent builds are
incremental.

## Threading

The audio callback runs on a thread owned by Oboe. The `Timer.periodic`
in `lib/main.dart` drives `sys.update()` from the **UI isolate** (same
isolate that called `init()`), matching the threading rule documented in
the dart-yse README.

## Troubleshooting

- **`libyse.so not found`** — confirm `yse_flutter_libs` is in
  `pubspec.yaml` *and* `flutter clean` has been run since adding it.
  Gradle caches the merged `lib/<abi>/` set per build configuration.
- **`CMake error: Could not find a configuration file for package "..."`** —
  the NDK version in `packages/yse_flutter_libs/android/build.gradle`
  (`27.0.12077973`) must be installed via the Android SDK Manager.
- **Engine silent on emulator** — the `x86_64` Android emulator routes
  audio through the host. Confirm host audio works first; some emulator
  graphics backends mute audio when the AVD window is unfocused.
