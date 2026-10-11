// The libYSE release this version of package:yse binds, and where its
// prebuilt binaries live (#88, #95).
//
// This file is the engine pin as it ships in the published package: a pub
// cache has no engine submodule to read the tag from, so the native-assets
// build hook (hook/build.dart) downloads the release named here and checks it
// against the digests below. test/engine_release_test.dart keeps [engineTag]
// equal to the submodule pin and the digests equal to the release's own.
//
// Pure Dart (dart:ffi only for the [Abi] type): the build hook,
// tool/fetch_engine.dart and the tests all read it.

import 'dart:ffi' show Abi;

/// GitHub `owner/repo` the engine releases are published under.
const engineRepo = 'yvanvds/yse-soundengine';

/// The engine release tag this package version binds and bundles.
///
/// Keep equal to the tag the `third_party/yse-soundengine` submodule is
/// checked out at; bump it together with [ReleasePlatform.sha256].
const engineTag = 'v3.1.0';

/// Asset id of the engine library the build hook bundles
/// (`package:yse/libyse`); the loader resolves it through an `@Native`
/// declaration with this id.
const libyseAssetId = 'package:yse/libyse';

/// Platforms the engine publishes release binaries for.
enum ReleasePlatform {
  /// Windows x86_64 — `libyse-<tag>-windows-x64.zip`, `libyse.dll` and its
  /// runtime DLLs in `bin/`.
  windowsX64(
    'windows-x64',
    'zip',
    'bin',
    ['libyse.dll'],
    sha256: '5d1c38f74d6c850757f97e8bb9f763665294c6701ccd21633d081e59b6c26faa',
  ),

  /// Linux x86_64 — `libyse-<tag>-linux-x64.tar.gz`, library in `lib/`.
  linuxX64(
    'linux-x64',
    'tar.gz',
    'lib',
    ['libyse.so'],
    sha256: 'd732cd20bd6f6513dd72ba01f321ad8c3debb3b3fc0defbd7e780fada3a5802d',
  ),

  /// Android — `libyse-<tag>-android.tar.gz`, one `lib/<abi>/libyse.so` per
  /// ABI the yse_flutter_libs plugin packages (#91).
  android(
    'android',
    'tar.gz',
    'lib',
    ['arm64-v8a/libyse.so', 'x86_64/libyse.so'],
    sha256: 'f30526c3a21ee6805445c51411b089e5f1f836e425b2ddca44c86511261d4d72',
  );

  const ReleasePlatform(
    this.slug,
    this.extension,
    this.libSubdir,
    this.libFiles, {
    required this.sha256,
  });

  /// Platform part of the asset name (`windows-x64`).
  final String slug;

  /// Archive extension of the asset (`zip`, `tar.gz`).
  final String extension;

  /// Directory inside the archive's top folder holding the engine library.
  final String libSubdir;

  /// The engine libraries, relative to [libSubdir] with `/` separators.
  final List<String> libFiles;

  /// Lower-case hex sha256 of this platform's asset of [engineTag], as GitHub
  /// reports it for the release.
  final String sha256;

  /// The desktop platform for a Dart [Abi], or null when no release asset
  /// exists for it.
  static ReleasePlatform? fromAbi(Abi abi) => switch (abi) {
    Abi.windowsX64 => windowsX64,
    Abi.linuxX64 => linuxX64,
    _ => null,
  };

  /// The platform whose [slug] is [name], or null.
  static ReleasePlatform? fromSlug(String name) {
    for (final p in values) {
      if (p.slug == name) return p;
    }
    return null;
  }
}

/// Name of the top folder inside the archive, e.g. `libyse-v3.1.0-windows-x64`.
String archiveTopDir(String tag, ReleasePlatform platform) =>
    'libyse-$tag-${platform.slug}';

/// File name of the release asset, e.g. `libyse-v3.1.0-windows-x64.zip`.
String assetName(String tag, ReleasePlatform platform) =>
    '${archiveTopDir(tag, platform)}.${platform.extension}';

/// Public download URL of the release asset (no `gh` or token needed).
Uri assetUrl(String tag, ReleasePlatform platform) => Uri.https(
  'github.com',
  '/$engineRepo/releases/download/$tag/${assetName(tag, platform)}',
);
