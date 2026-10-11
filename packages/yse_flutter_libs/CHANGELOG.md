# Changelog

## 0.2.0

- Builds **libYSE v3.1.0** (the engine submodule's pinned tag; was 2.x),
  the engine `package:yse` 0.2.0 binds. The libYSE 3 C ABI is not
  compatible with 2.4, so use this release with `yse` 0.2.x and 0.1.0
  with `yse` 0.1.x.
- No change to the Gradle setup: NDK 27.0.12077973, `minSdk` 26, default
  ABIs `arm64-v8a` and `x86_64`, tests and benchmarks off. Python live
  coding is not available on Android (`YSE_ENABLE_PYTHON` is desktop only),
  and neither is MIDI device I/O.

## 0.1.0

- Initial release. Cross-compiles the YSE sound engine for Android via the
  NDK (arm64-v8a, x86_64 by default) so `package:yse` resolves
  `libyse.so` at runtime on Flutter Android.
