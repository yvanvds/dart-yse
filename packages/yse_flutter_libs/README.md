# yse_flutter_libs

Native binaries for the [YSE sound engine](https://github.com/yvanvds/yse-soundengine)
on Flutter Android. **No Dart API** — adding this package alongside
[`package:yse`](https://pub.dev/packages/yse) bundles the engine's prebuilt
`libyse.so` for each ABI into your APK / AAB, so the engine loads at
runtime via `DynamicLibrary.open('libyse.so')`.

This mirrors the
[`sqlite3`](https://pub.dev/packages/sqlite3) /
[`sqlite3_flutter_libs`](https://pub.dev/packages/sqlite3_flutter_libs)
split: keep the wrapper pure Dart so it works in CLI / server contexts,
and let a sibling Flutter plugin handle the platform-specific binary
delivery.

## Usage

```yaml
dependencies:
  yse: ^0.2.0
  yse_flutter_libs: ^0.2.0
```

Keep both packages on the same minor version: `yse_flutter_libs` 0.2.x
packages libYSE v3.1.0, the engine whose C ABI `yse` 0.2.x binds.

Then build your Flutter app as normal. Your app's `minSdk` must be at
least 26 (see below); Flutter's template defaults lower, so set it in
`android/app/build.gradle(.kts)`.

## Where `libyse.so` comes from

The engine publishes an Android build with every release:
`libyse-<tag>-android.tar.gz` on
[yvanvds/yse-soundengine releases](https://github.com/yvanvds/yse-soundengine/releases),
holding `lib/arm64-v8a/libyse.so` and `lib/x86_64/libyse.so` with Oboe and
libsndfile linked in statically. `android/engine.properties` names the
tag this plugin version packages and the asset's sha256.

On the first build the plugin's Gradle module downloads that asset
(~56 MiB) into `<gradle user home>/caches/yse-engine/<tag>/`, checks the
sha256 and unpacks it; later builds, including after `flutter clean`,
reuse it. The libraries are added as `jniLibs`, so the merged APK carries
them under `lib/<abi>/libyse.so` and the app's Android build strips their
debug symbols (about 6 MiB per ABI in a release APK). No NDK or CMake
build of the engine is involved.

### Offline builds

Unpack the asset yourself and point the Gradle property `yse.engineDir`
at the `libyse-<tag>-android` folder, e.g. in your app's
`android/gradle.properties`:

```properties
yse.engineDir=/opt/yse/libyse-v3.1.0-android
```

A relative path is resolved against your app's `android/` folder. Inside
a dart-yse checkout, `dart run tool/fetch_engine.dart --platform android`
fills `.engine/<tag>/libyse-<tag>-android/`, which the plugin uses
without any property.

### Building the engine from source (opt-in)

To test an engine that has no release yet, set `yse.buildFromSource=true`.
The plugin then compiles the engine's `CMakeLists.txt` with the Android
NDK for each ABI, as versions before 0.2.0 always did. By default it
builds the dart-yse engine submodule (so this only works from a dart-yse
checkout); `yse.engineSourceDir` points it at another yse-soundengine
clone:

```properties
yse.buildFromSource=true
yse.engineSourceDir=/path/to/yse-soundengine
```

This needs **Android NDK 27.0.12077973** and CMake 3.22.1 from the
Android SDK Manager, and the first build fetches Oboe and libsndfile and
compiles the engine cold (5–10 minutes per ABI).

## Requirements

- **Flutter** ≥ 3.22
- **Android Gradle Plugin** ≥ 8.5
- **minSdk** 26 — required so Oboe negotiates the AAudio backend instead
  of falling back to OpenSL ES on every device
- Network access to github.com on the first build, unless you set
  `yse.engineDir`

## ABIs

`arm64-v8a` and `x86_64` (modern phones + Intel/AMD emulator) — the ABIs
the engine's Android release ships.

32-bit ARM (`armeabi-v7a`) has no prebuilt library. It needs a source
build with the ABI list in `yse.abis`:

```properties
yse.buildFromSource=true
yse.abis=arm64-v8a,armeabi-v7a,x86_64
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

On low-end devices, set `System.instance.renderThreads = 0` before
`init()` so the engine renders on the audio thread alone instead of
starting worker threads; the output is identical.

## License

Eclipse Public License 2.0 — matches the upstream engine and
`package:yse`.
