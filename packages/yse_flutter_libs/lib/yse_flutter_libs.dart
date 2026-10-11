/// Native binaries for [package:yse](https://pub.dev/packages/yse) on
/// Flutter Android. This package has no Dart API — adding it to your
/// `pubspec.yaml` alongside `yse` makes Gradle bundle the engine's prebuilt
/// `libyse.so` per ABI into your APK / AAB so the engine loads on device.
///
/// ```yaml
/// dependencies:
///   yse: ^0.2.0
///   yse_flutter_libs: ^0.2.0
/// ```
///
/// See this package's README for where the binaries come from, offline
/// builds, building from source, and the required `minSdk`.
library;
