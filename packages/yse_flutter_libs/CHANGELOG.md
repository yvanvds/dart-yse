# Changelog

## 0.2.0

- Builds **libYSE v3.1.0** (the engine submodule's pinned tag; was 2.x),
  the engine `package:yse` 0.2.0 binds. The libYSE 3 C ABI is not
  compatible with 2.4, so use this release with `yse` 0.2.x and 0.1.0
  with `yse` 0.1.x.
- **Packages the engine's prebuilt Android release instead of compiling
  it** (#91). `android/engine.properties` names the libYSE tag and the
  sha256 of its `libyse-<tag>-android.tar.gz` asset; the Gradle build
  downloads that asset once into `<gradle user home>/caches/yse-engine/`,
  checks the digest, and adds `lib/arm64-v8a` and `lib/x86_64` as
  `jniLibs`. Consumers no longer need the NDK or CMake, nor the engine
  sources, which is what lets the plugin work as a pub.dev or git
  dependency. `yse.engineDir` points the build at an unpacked asset for
  offline builds; inside dart-yse,
  `dart run tool/fetch_engine.dart --platform android` provides one.
- Building from source is opt-in: `yse.buildFromSource=true` compiles the
  engine's CMakeLists per ABI with NDK 27.0.12077973 as before (tests and
  benchmarks off), from the dart-yse submodule or `yse.engineSourceDir`,
  for the ABIs in `yse.abis`. Use it to test an unreleased engine or to
  build `armeabi-v7a`, which the release does not ship.
- **No longer applies the Kotlin Gradle Plugin** (#93). The plugin is
  now declared as an `ffiPlugin`, so the empty `YseFlutterLibsPlugin`
  Kotlin class, `kotlin-android` and the KGP classpath entry are gone.
  This clears Flutter's "plugins that apply Kotlin Gradle Plugin"
  warning (future Flutter versions fail that build) and works with
  built-in Kotlin on AGP 9. `android/build.gradle` also uses
  `prop = value` assignments throughout, ahead of Gradle 10 removing
  the Groovy space-assignment syntax. The minimum Flutter version
  (3.22) is unchanged.
- `minSdk` 26 and the default ABIs `arm64-v8a` and `x86_64` are unchanged.
  Python live coding is not available on Android (`YSE_ENABLE_PYTHON` is
  desktop only), and neither is MIDI device I/O.

## 0.1.0

- Initial release. Cross-compiles the YSE sound engine for Android via the
  NDK (arm64-v8a, x86_64 by default) so `package:yse` resolves
  `libyse.so` at runtime on Flutter Android.
