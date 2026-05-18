/// Native binaries for [package:yse](https://pub.dev/packages/yse) on
/// Flutter Android. This package has no Dart API — adding it to your
/// `pubspec.yaml` alongside `yse` causes Gradle to build `libyse.so` per
/// ABI and bundle it into your APK / AAB so the engine loads on device.
///
/// ```yaml
/// dependencies:
///   yse: ^0.1.0
///   yse_flutter_libs: ^0.1.0
/// ```
///
/// See the dart-yse README for ABI selection and required `minSdk`.
library;
