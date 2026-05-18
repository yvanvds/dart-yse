# yse_flutter_libs

Native binaries for the [YSE sound engine](https://github.com/yvanvds/yse-soundengine)
on Flutter Android. **No Dart API** — adding this package alongside
[`package:yse`](https://pub.dev/packages/yse) causes Gradle to cross-compile
`libyse.so` per ABI and bundle it into your APK / AAB, so the engine loads
at runtime via `DynamicLibrary.open('libyse.so')`.

This mirrors the
[`sqlite3`](https://pub.dev/packages/sqlite3) /
[`sqlite3_flutter_libs`](https://pub.dev/packages/sqlite3_flutter_libs)
split: keep the wrapper pure Dart so it works in CLI / server contexts,
and let a sibling Flutter plugin handle the platform-specific binary
delivery.

## Usage

```yaml
dependencies:
  yse: ^0.1.0
  yse_flutter_libs: ^0.1.0
```

Then build your Flutter app as normal. The plugin's Gradle module runs the
engine's CMake build with the Android NDK, producing one `libyse.so` per
configured ABI, which the merged APK then carries under
`lib/<abi>/libyse.so`.

## Requirements

- **Flutter** ≥ 3.22
- **Android NDK** 27.0.12077973 (matches the engine's own CMake config)
- **Android Gradle Plugin** ≥ 8.5
- **minSdk** 26 — required so Oboe negotiates the AAudio backend instead
  of falling back to OpenSL ES on every device

## ABIs

Default: `arm64-v8a`, `x86_64` (modern phones + Intel/AMD emulator).

To add 32-bit ARM, override `ndk.abiFilters` in your consumer app's
`android/app/build.gradle`:

```groovy
android {
  defaultConfig {
    ndk {
      abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64'
    }
  }
}
```

Note that the engine itself has not been routinely tested on
`armeabi-v7a`.

## Permissions

The engine uses Oboe for audio output, which does **not** need any runtime
permission on its own. Add `RECORD_AUDIO` to your app's manifest only if
you exercise an input-capture code path (none is exposed today by
`package:yse`).

## Threading

The audio callback runs on a thread owned by Oboe / AAudio. As with desktop
builds, **never** call into `package:yse` from inside a callback you didn't
install, and keep all `yse.*` calls on the same isolate that called
`System.init()`. On Flutter, that is typically the UI isolate.

## License

Eclipse Public License 2.0 — matches the upstream engine and
`package:yse`.
