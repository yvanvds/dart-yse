// Native-assets build hook (#95): bundles the prebuilt libYSE release this
// package version pins, so `dart run`, `dart test`, `dart build cli` and
// `flutter run` / `flutter build` on Windows and Linux find the engine with no
// manual setup.
//
// For a Windows x64 or Linux x64 target the hook downloads
// `libyse-<tag>-<platform>` from the engine's GitHub release (tag and sha256
// embedded in lib/src/engine_release.dart), checks the digest, unpacks it
// under the hook's shared output directory (`.dart_tool/hooks_runner/shared/
// yse/`), and reports the engine library as the code asset
// `package:yse/libyse`. On Windows every runtime DLL from the release `bin/`
// is reported as well, so the SDK copies them next to `libyse.dll` and the
// loader finds them there.
//
// Later builds reuse the unpacked release without network access. Other
// targets get no asset: Android is served by the yse_flutter_libs plugin
// (#91), and macOS / iOS / arm64 desktops have no engine release yet. The
// runtime loader (lib/src/library.dart) explains what to do in that case.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:yse/src/engine_release.dart';

import 'engine_cache.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final platform = hookPlatform(code.targetOS, code.targetArchitecture);
    if (platform == null) return;

    final libDir = await ensureRelease(
      Directory.fromUri(input.outputDirectoryShared).path,
      platform,
      log: stderr.writeln,
    );
    for (final lib in releaseLibraries(libDir, platform)) {
      final name = lib.uri.pathSegments.last;
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: assetNameFor(name),
          linkMode: DynamicLoadingBundled(),
          file: lib.absolute.uri,
        ),
      );
    }
  });
}

/// The release platform the hook bundles for a target, or null when it
/// bundles nothing there.
///
/// Android is deliberately left to the yse_flutter_libs plugin, which already
/// packages `libyse.so` as jniLibs: a second copy from this hook would clash
/// with it in the APK.
ReleasePlatform? hookPlatform(OS os, Architecture arch) => switch ((os, arch)) {
  (OS.windows, Architecture.x64) => ReleasePlatform.windowsX64,
  (OS.linux, Architecture.x64) => ReleasePlatform.linuxX64,
  _ => null,
};

/// Asset name (the part after `package:yse/`) for the library file [file]:
/// `libyse` for the engine, `deps/<file>` for its runtime dependencies.
String assetNameFor(String file) {
  final lower = file.toLowerCase();
  if (lower == 'libyse.dll' || lower == 'libyse.so') {
    return libyseAssetId.substring('package:yse/'.length);
  }
  return 'deps/$file';
}
