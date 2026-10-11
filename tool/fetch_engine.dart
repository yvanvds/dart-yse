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
// `--platform android` fetches the Android asset instead (#91): one
// `lib/<abi>/libyse.so` per ABI the yse_flutter_libs plugin packages. The
// plugin's Gradle build uses `.engine/<tag>/libyse-<tag>-android/` when it is
// there and otherwise downloads the same asset itself, so this is only needed
// to prepare an offline build.
//
// Usage (from the package root):
//   dart run tool/fetch_engine.dart           # fetch if missing, print path
//   dart run tool/fetch_engine.dart --force   # re-download and re-unpack
//   dart run tool/fetch_engine.dart --platform android
//
// On success the last line of output is the YSE_DLL_PATH to use (for
// android: the `lib/` folder holding the per-ABI libraries).

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'engine_pin.dart';

/// GitHub `owner/repo` the engine releases are published under.
const engineRepo = 'yvanvds/yse-soundengine';

/// Platforms the engine publishes release binaries for.
enum ReleasePlatform {
  /// Windows x86_64 — `libyse-<tag>-windows-x64.zip`, libraries in `bin/`.
  windowsX64('windows-x64', 'zip', 'bin', ['libyse.dll']),

  /// Linux x86_64 — `libyse-<tag>-linux-x64.tar.gz`, library in `lib/`.
  linuxX64('linux-x64', 'tar.gz', 'lib', ['libyse.so']),

  /// Android — `libyse-<tag>-android.tar.gz`, one `lib/<abi>/libyse.so` per
  /// ABI the yse_flutter_libs plugin packages (#91).
  android('android', 'tar.gz', 'lib', [
    'arm64-v8a/libyse.so',
    'x86_64/libyse.so',
  ]);

  const ReleasePlatform(
    this.slug,
    this.extension,
    this.libSubdir,
    this.libFiles,
  );

  /// Platform part of the asset name (`windows-x64`); also the value of
  /// `--platform`.
  final String slug;

  /// Archive extension of the asset (`zip`, `tar.gz`).
  final String extension;

  /// Directory inside the archive's top folder holding the engine library.
  final String libSubdir;

  /// The engine libraries, relative to [libSubdir] with `/` separators.
  final List<String> libFiles;

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

/// Parsed command line of the tool.
class FetchOptions {
  /// Creates options; [platform] null means the host platform.
  const FetchOptions({required this.force, this.platform});

  /// Re-download and re-unpack even when the tag is already there.
  final bool force;

  /// The platform asked for with `--platform`, or null for the host.
  final ReleasePlatform? platform;
}

/// Parses the tool's [args]: `--force` and `--platform <slug>` (or
/// `--platform=<slug>`).
///
/// Throws [FetchError] for an unknown argument or platform.
FetchOptions parseArgs(List<String> args) {
  var force = false;
  ReleasePlatform? platform;
  String slugs() => ReleasePlatform.values.map((p) => p.slug).join(', ');
  ReleasePlatform pick(String name) =>
      ReleasePlatform.fromSlug(name) ??
      (throw FetchError(
        'unknown platform "$name"; expected one of ${slugs()}',
      ));

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--force') {
      force = true;
    } else if (a == '--platform') {
      if (i + 1 >= args.length) {
        throw FetchError('--platform needs a value: ${slugs()}');
      }
      platform = pick(args[++i]);
    } else if (a.startsWith('--platform=')) {
      platform = pick(a.substring('--platform='.length));
    } else {
      throw FetchError(
        'unknown argument "$a"; usage: '
        'dart run tool/fetch_engine.dart [--force] [--platform <${slugs()}>]',
      );
    }
  }
  return FetchOptions(force: force, platform: platform);
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

/// GitHub API URL describing the release, including each asset's digest.
Uri releaseApiUrl(String tag) =>
    Uri.https('api.github.com', '/repos/$engineRepo/releases/tags/$tag');

/// Directory a tag is unpacked into: `<root>/.engine/<tag>`.
String tagDir(String root, String tag) => _join([root, engineCacheDir, tag]);

/// The directory to point `YSE_DLL_PATH` at for [tag] on [platform] (for
/// [ReleasePlatform.android], the `lib/` folder with one subfolder per ABI).
String dllPath(String root, String tag, ReleasePlatform platform) => _join([
  tagDir(root, tag),
  archiveTopDir(tag, platform),
  platform.libSubdir,
]);

/// Whether [tag] is already unpacked under [root] for [platform], i.e. every
/// one of its [ReleasePlatform.libFiles] is there.
bool isInstalled(String root, String tag, ReleasePlatform platform) {
  final dir = dllPath(root, tag, platform);
  return platform.libFiles.every(
    (f) => File(_join([dir, ...f.split('/')])).existsSync(),
  );
}

/// Reads `key=value` lines of a Java properties file such as the
/// yse_flutter_libs plugin's `android/engine.properties`. Blank lines and
/// `#` / `!` comments are skipped; keys and values are trimmed. Enough for
/// the plain `key=value` lines that file uses, not the full format.
Map<String, String> parseProperties(String text) {
  final out = <String, String>{};
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith('!')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    out[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  return out;
}

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
    await _run(parseArgs(args));
  } on FetchError catch (e) {
    stderr.writeln('fetch_engine: $e');
    exitCode = 1;
  }
}

Future<void> _run(FetchOptions options) async {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final platform = options.platform ?? ReleasePlatform.fromAbi(Abi.current());
  if (platform == null) {
    throw FetchError(
      'no prebuilt libyse for ${Abi.current()}; the engine releases '
      'Windows x64 and Linux x64. Build from source instead (see README.md).',
    );
  }

  final tag = await _pinnedTag(root);
  final target = dllPath(root, tag, platform);

  if (!options.force && isInstalled(root, tag, platform)) {
    print(
      'libyse $tag (${platform.slug}) already present in '
      '${tagDir(root, tag)}',
    );
  } else {
    await _install(root, tag, platform);
    if (!isInstalled(root, tag, platform)) {
      throw FetchError(
        'unpacked ${assetName(tag, platform)} but not all of '
        '${platform.libFiles.join(', ')} are in $target; the release layout '
        'may have changed',
      );
    }
    print('libyse $tag (${platform.slug}) unpacked into ${tagDir(root, tag)}');
  }

  print('');
  if (platform == ReleasePlatform.android) {
    print('The yse_flutter_libs Gradle build packages these per-ABI libraries');
    print('when the engine tag in packages/yse_flutter_libs/android/');
    print('engine.properties is $tag. Elsewhere, point it at them with the');
    print(
      'Gradle property yse.engineDir=${tagDir(root, tag)}'
      '${Platform.pathSeparator}${archiveTopDir(tag, platform)}',
    );
    print(target);
    return;
  }
  print('Point YSE_DLL_PATH at it before `dart test`:');
  if (platform == ReleasePlatform.windowsX64) {
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

Future<void> _install(String root, String tag, ReleasePlatform platform) async {
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
