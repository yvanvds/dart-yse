// Native-assets build hook (#95, #96): bundles the prebuilt libYSE release
// this package version pins, so `dart run`, `dart test`, `dart build cli` and
// `flutter run` / `flutter build` on Windows, Linux and Android find the
// engine with no manual setup.
//
// For a Windows x64, Linux x64 or Android arm64 / x86_64 target the hook
// downloads `libyse-<tag>-<platform>` from the engine's GitHub release (tag
// and sha256 embedded in lib/src/engine_release.dart), checks the digest,
// unpacks it under the hook's shared output directory (`.dart_tool/
// hooks_runner/shared/yse/`), and reports the engine library as the code
// asset `package:yse/libyse`. On Windows every runtime DLL from the release
// `bin/` is reported as well, so the SDK copies them next to `libyse.dll` and
// the loader finds them there. On Android the target ABI's
// `lib/<abi>/libyse.so` is reported; Flutter packages it into the APK / AAB
// under `lib/<abi>/`. It links Oboe, libsndfile and the C++ runtime
// statically and needs only system libraries, so nothing else is bundled.
//
// Later builds reuse the unpacked release without network access (one
// download per project and platform, not per build). Other targets get no
// asset: macOS / iOS / arm64 desktops / 32-bit Android have no engine release
// yet. The runtime loader (lib/src/library.dart) explains what to do there.
//
// The user-define `engine_dir` replaces the download with a local engine
// folder laid out like an unpacked release (`bin/` or `lib/` inside it; on
// Android `lib/<abi>/libyse.so`, 32-bit ABIs included), for offline builds
// and for testing an unreleased engine on Android:
//
//   hooks:
//     user_defines:
//       yse:
//         engine_dir: path/to/libyse-v3.1.0-android
//
// in the application's pubspec.yaml (relative paths resolve against it).

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:yse/src/engine_release.dart';
// The cache helper lives under lib/src/ because pub.dev accepts only the hook
// entry points (build.dart, link.dart) in hook/ (#101).
import 'package:yse/src/hook/engine_cache.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final platform = hookPlatform(code.targetOS, code.targetArchitecture);
    if (platform == null) return;

    final abi = platform == ReleasePlatform.android
        ? androidAbi(code.targetArchitecture)
        : null;
    final local = input.userDefines.path(engineDirDefine);
    final List<File> libs;
    // The release ships 64-bit Android ABIs only; a 32-bit one gets an
    // engine only from an engine_dir that has it.
    final optionalAbi = abi != null && !releaseShipsAbi(abi);
    if (local != null) {
      libs = localLibraries(
        Directory.fromUri(local).path,
        platform,
        abi: abi,
        optional: optionalAbi,
      );
      output.dependencies.addAll([local, for (final l in libs) l.absolute.uri]);
    } else {
      if (optionalAbi) return;
      final libDir = await ensureRelease(
        Directory.fromUri(input.outputDirectoryShared).path,
        platform,
        log: stderr.writeln,
      );
      libs = releaseLibraries(libDir, platform, abi: abi);
    }
    for (final lib in libs) {
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

/// The user-define naming a local engine folder to bundle instead of the
/// downloaded release (`hooks: user_defines: yse: engine_dir: ...`).
const engineDirDefine = 'engine_dir';

/// The release platform whose layout the hook bundles from for a target, or
/// null when it bundles nothing there. Every Android ABI maps to
/// [ReleasePlatform.android]; see [releaseShipsAbi] for which ones the
/// downloaded release covers.
ReleasePlatform? hookPlatform(OS os, Architecture arch) => switch ((os, arch)) {
  (OS.windows, Architecture.x64) => ReleasePlatform.windowsX64,
  (OS.linux, Architecture.x64) => ReleasePlatform.linuxX64,
  (OS.android, _) when androidAbi(arch) != null => ReleasePlatform.android,
  _ => null,
};

/// The Android ABI folder name (`lib/<abi>/`) for [arch], or null when
/// Android has no such ABI.
String? androidAbi(Architecture arch) => switch (arch) {
  Architecture.arm64 => 'arm64-v8a',
  Architecture.x64 => 'x86_64',
  Architecture.arm => 'armeabi-v7a',
  Architecture.ia32 => 'x86',
  _ => null,
};

/// Whether the engine's Android release has a library for [abi]
/// (arm64-v8a and x86_64).
bool releaseShipsAbi(String abi) =>
    ReleasePlatform.android.libFiles.contains('$abi/libyse.so');

/// Asset name (the part after `package:yse/`) for the library file [file]:
/// `libyse` for the engine, `deps/<file>` for its runtime dependencies.
String assetNameFor(String file) {
  final lower = file.toLowerCase();
  if (lower == 'libyse.dll' || lower == 'libyse.so') {
    return libyseAssetId.substring('package:yse/'.length);
  }
  return 'deps/$file';
}
