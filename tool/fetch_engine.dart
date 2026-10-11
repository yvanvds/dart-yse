// Downloads the prebuilt libyse for the engine tag the submodule pins (#88),
// so running the tests and examples needs no MSYS2 / CMake build.
//
// The pinned tag comes from the submodule gitlink (tool/engine_pin.dart,
// shared with the test suite's unreleased-engine notice, #89):
//   git -C third_party/yse-soundengine describe --tags --exact-match
// The tool fails when the pin is not a tagged release (the engine only
// publishes binaries for tags). The host platform's asset is downloaded from
// the public release URL, so `gh` is not required:
//   https://github.com/yvanvds/yse-soundengine/releases/download/<tag>/<asset>
// and unpacked into the gitignored `.engine/<tag>/` with the system `tar`
// (built into Windows 10+ and Linux; Windows' bsdtar also reads the .zip).
// A tag that is already unpacked is not downloaded again.
//
// Integrity: the release has no checksum file, but the GitHub API reports a
// sha256 digest for every asset. The download is checked against it; when the
// API cannot be reached (offline, rate-limited) the tool says so and goes on.
//
// The C headers ffigen reads still come from the submodule — the release
// archives only carry the C++ headers (upstream yvanvds/yse-soundengine#1184).
//
// Usage (from the package root):
//   dart run tool/fetch_engine.dart           # fetch if missing, print path
//   dart run tool/fetch_engine.dart --force   # re-download and re-unpack
//
// On success the last line of output is the YSE_DLL_PATH to use.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'engine_pin.dart';

/// GitHub `owner/repo` the engine releases are published under.
const engineRepo = 'yvanvds/yse-soundengine';

/// Host platforms the engine publishes desktop binaries for.
enum HostPlatform {
  /// Windows x86_64 — `libyse-<tag>-windows-x64.zip`, libraries in `bin/`.
  windowsX64('windows-x64', 'zip', 'bin', 'libyse.dll'),

  /// Linux x86_64 — `libyse-<tag>-linux-x64.tar.gz`, library in `lib/`.
  linuxX64('linux-x64', 'tar.gz', 'lib', 'libyse.so');

  const HostPlatform(this.slug, this.extension, this.libSubdir, this.libName);

  /// Platform part of the asset name (`windows-x64`).
  final String slug;

  /// Archive extension of the asset (`zip`, `tar.gz`).
  final String extension;

  /// Directory inside the archive's top folder holding the engine library.
  final String libSubdir;

  /// File name of the engine library.
  final String libName;

  /// The platform for a Dart [Abi], or null when no release asset exists.
  static HostPlatform? fromAbi(Abi abi) => switch (abi) {
    Abi.windowsX64 => windowsX64,
    Abi.linuxX64 => linuxX64,
    _ => null,
  };
}

/// Name of the top folder inside the archive, e.g. `libyse-v3.1.0-windows-x64`.
String archiveTopDir(String tag, HostPlatform platform) =>
    'libyse-$tag-${platform.slug}';

/// File name of the release asset, e.g. `libyse-v3.1.0-windows-x64.zip`.
String assetName(String tag, HostPlatform platform) =>
    '${archiveTopDir(tag, platform)}.${platform.extension}';

/// Public download URL of the release asset (no `gh` or token needed).
Uri assetUrl(String tag, HostPlatform platform) => Uri.https(
  'github.com',
  '/$engineRepo/releases/download/$tag/${assetName(tag, platform)}',
);

/// GitHub API URL describing the release, including each asset's digest.
Uri releaseApiUrl(String tag) =>
    Uri.https('api.github.com', '/repos/$engineRepo/releases/tags/$tag');

/// Directory a tag is unpacked into: `<root>/.engine/<tag>`.
String tagDir(String root, String tag) => _join([root, engineCacheDir, tag]);

/// The directory to point `YSE_DLL_PATH` at for [tag] on [platform].
String dllPath(String root, String tag, HostPlatform platform) => _join([
  tagDir(root, tag),
  archiveTopDir(tag, platform),
  platform.libSubdir,
]);

/// Whether [tag] is already unpacked under [root] for [platform].
bool isInstalled(String root, String tag, HostPlatform platform) =>
    File(_join([dllPath(root, tag, platform), platform.libName])).existsSync();

/// Reads the sha256 hex digest of [asset] from a GitHub release API [json]
/// body, or null when the release does not list one.
String? parseAssetDigest(String json, String asset) {
  final release = jsonDecode(json);
  if (release is! Map<String, dynamic>) return null;
  final assets = release['assets'];
  if (assets is! List) return null;
  for (final a in assets) {
    if (a is Map<String, dynamic> && a['name'] == asset) {
      final digest = a['digest'];
      if (digest is String && digest.startsWith('sha256:')) {
        return digest.substring('sha256:'.length).toLowerCase();
      }
      return null;
    }
  }
  return null;
}

String _join(List<String> parts) => parts.join(Platform.pathSeparator);

/// Thrown for a failure the user can act on; printed without a stack trace.
class FetchError implements Exception {
  /// Creates an error carrying [message].
  FetchError(this.message);

  /// What went wrong and what to do about it.
  final String message;

  @override
  String toString() => message;
}

Future<void> main(List<String> args) async {
  try {
    await _run(force: args.contains('--force'));
  } on FetchError catch (e) {
    stderr.writeln('fetch_engine: $e');
    exitCode = 1;
  }
}

Future<void> _run({required bool force}) async {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final platform = HostPlatform.fromAbi(Abi.current());
  if (platform == null) {
    throw FetchError(
      'no prebuilt libyse for ${Abi.current()}; the engine releases '
      'Windows x64 and Linux x64. Build from source instead (see README.md).',
    );
  }

  final tag = await _pinnedTag(root);
  final target = dllPath(root, tag, platform);

  if (!force && isInstalled(root, tag, platform)) {
    print('libyse $tag already present in ${tagDir(root, tag)}');
  } else {
    await _install(root, tag, platform);
    if (!isInstalled(root, tag, platform)) {
      throw FetchError(
        'unpacked ${assetName(tag, platform)} but ${platform.libName} is not '
        'in $target; the release layout may have changed',
      );
    }
    print('libyse $tag unpacked into ${tagDir(root, tag)}');
  }

  print('');
  print('Point YSE_DLL_PATH at it before `dart test`:');
  if (platform == HostPlatform.windowsX64) {
    print('  \$env:YSE_DLL_PATH = "$target"');
  } else {
    print('  export YSE_DLL_PATH="$target"');
  }
  print(target);
}

Future<String> _pinnedTag(String root) async {
  try {
    return await readPinnedTag(root);
  } on PinError catch (e) {
    final git = e.gitOutput;
    if (git == null) throw FetchError(e.message);
    throw FetchError(
      '${e.message}, so there are no prebuilt binaries for it.\n'
      '  git: $git\n'
      'Run `git submodule update --init` for the pinned release (in a '
      'shallow clone, also `git -C $submodulePath fetch --tags`), or build '
      'the engine from source (see README.md).',
    );
  }
}

Future<void> _install(String root, String tag, HostPlatform platform) async {
  final cache = Directory(_join([root, engineCacheDir]))
    ..createSync(recursive: true);
  final asset = assetName(tag, platform);
  final archive = File(_join([cache.path, asset]));
  final top = archiveTopDir(tag, platform);
  final staging = Directory(_join([cache.path, '.staging-$top']));
  // Each platform's archive has its own top folder, so a checkout shared
  // between Windows and Linux (WSL, a Docker mount) keeps both side by side
  // under `.engine/<tag>/`.
  final dest = Directory(_join([tagDir(root, tag), top]));

  try {
    final url = assetUrl(tag, platform);
    print('Downloading $url');
    final bytes = await _download(url, archive);
    print('  ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB');

    await _verify(tag, asset, archive);

    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync(recursive: true);
    final r = await Process.run('tar', [
      '-xf',
      archive.path,
      '-C',
      staging.path,
    ]);
    if (r.exitCode != 0) {
      throw FetchError(
        'tar could not unpack $asset (exit ${r.exitCode}): '
        '${(r.stderr as String).trim()}',
      );
    }

    final unpacked = Directory(_join([staging.path, top]));
    if (!unpacked.existsSync()) {
      throw FetchError(
        '$asset has no top folder $top/; the release layout may have changed',
      );
    }

    // Move the complete tree in only after a successful unpack, so an
    // interrupted run never leaves a half-filled folder that the "already
    // present" check would accept.
    if (dest.existsSync()) dest.deleteSync(recursive: true);
    dest.parent.createSync(recursive: true);
    unpacked.renameSync(dest.path);
  } on ProcessException catch (e) {
    throw FetchError('could not run tar: ${e.message}');
  } finally {
    if (archive.existsSync()) archive.deleteSync();
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  }
}

Future<int> _download(Uri url, File to) async {
  final client = HttpClient()..userAgent = 'dart-yse-fetch-engine';
  try {
    final req = await client.getUrl(url);
    final res = await req.close();
    if (res.statusCode != HttpStatus.ok) {
      await res.drain<void>();
      throw FetchError(
        'download failed: HTTP ${res.statusCode} for $url\n'
        'Check that the release exists and has an asset for this platform.',
      );
    }
    final sink = to.openWrite();
    var n = 0;
    await res
        .map((chunk) {
          n += chunk.length;
          return chunk;
        })
        .pipe(sink);
    return n;
  } on SocketException catch (e) {
    throw FetchError('download failed: ${e.message} ($url)');
  } on HttpException catch (e) {
    throw FetchError('download failed: ${e.message} ($url)');
  } finally {
    client.close();
  }
}

Future<void> _verify(String tag, String asset, File archive) async {
  final expected = await _expectedDigest(tag, asset);
  if (expected == null) {
    print(
      '  sha256 not checked: the GitHub API did not report a digest for '
      '$asset',
    );
    return;
  }
  final actual = sha256.convert(await archive.readAsBytes()).toString();
  if (actual != expected) {
    throw FetchError(
      'sha256 mismatch for $asset: expected $expected, got $actual',
    );
  }
  print('  sha256 OK ($actual)');
}

Future<String?> _expectedDigest(String tag, String asset) async {
  final client = HttpClient()..userAgent = 'dart-yse-fetch-engine';
  try {
    final req = await client.getUrl(releaseApiUrl(tag));
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != HttpStatus.ok) return null;
    return parseAssetDigest(body, asset);
  } on Exception {
    return null;
  } finally {
    client.close();
  }
}
