// Download, verification and caching of the prebuilt libYSE release for the
// native-assets build hook (hook/build.dart, #95, #96).
//
// Kept apart from the hook's `main` so the cache logic is unit-tested without
// a hooks runner (test/engine_cache_test.dart). Only dart:io and
// package:crypto: no git, no `gh`, no GitHub API call at build time — the
// expected digests are embedded in lib/src/engine_release.dart.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:yse/src/engine_release.dart';

/// A failure the package user can act on.
class EngineFetchError implements Exception {
  /// Creates an error carrying [message].
  EngineFetchError(this.message);

  /// What went wrong and what to do about it.
  final String message;

  @override
  String toString() => 'package:yse build hook: $message';
}

String _join(List<String> parts) => parts.join(Platform.pathSeparator);

/// Where [platform]'s release of [tag] is unpacked under [cacheRoot]:
/// `<cacheRoot>/<tag>/libyse-<tag>-<slug>`.
String releaseDir(String cacheRoot, String tag, ReleasePlatform platform) =>
    _join([cacheRoot, tag, archiveTopDir(tag, platform)]);

/// The marker written once a release is completely unpacked. It holds the
/// sha256 of the archive the tree came from.
File _marker(String cacheRoot, String tag, ReleasePlatform platform) =>
    File('${releaseDir(cacheRoot, tag, platform)}.sha256');

/// Whether [platform]'s release of [tag] is unpacked under [cacheRoot] from an
/// archive whose sha256 is [sha256], with every library it should hold.
bool isCached(
  String cacheRoot,
  String tag,
  ReleasePlatform platform,
  String sha256,
) {
  final marker = _marker(cacheRoot, tag, platform);
  if (!marker.existsSync() || marker.readAsStringSync().trim() != sha256) {
    return false;
  }
  final lib = _join([releaseDir(cacheRoot, tag, platform), platform.libSubdir]);
  return platform.libFiles.every(
    (f) => File(_join([lib, ...f.split('/')])).existsSync(),
  );
}

/// The shared libraries a release ships for [platform] in [libDir]: on
/// Windows `libyse.dll` plus every runtime DLL next to it (libc++, PortAudio,
/// RtMidi, libsndfile and its codecs, libwinpthread), which must be bundled
/// together; on Android the engine library of the ABI [abi]
/// (`<abi>/libyse.so`, which needs only system libraries); elsewhere the
/// engine library alone.
List<File> releaseLibraries(
  String libDir,
  ReleasePlatform platform, {
  String? abi,
}) {
  if (platform == ReleasePlatform.android) {
    if (abi == null) {
      throw ArgumentError.notNull('abi');
    }
    return [
      File(_join([libDir, abi, 'libyse.so'])),
    ];
  }
  if (platform == ReleasePlatform.windowsX64) {
    final dlls =
        Directory(libDir)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.dll'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return dlls;
  }
  return [
    for (final f in platform.libFiles) File(_join([libDir, ...f.split('/')])),
  ];
}

/// The libraries to bundle for [platform] (and Android [abi]) from
/// [engineDir], a local folder laid out like an unpacked release: the
/// `engine_dir` user-define of the build hook. Throws [EngineFetchError] when
/// one of them is missing, except that an [optional] library that is
/// missing yields an empty list (a 32-bit Android ABI the folder does not
/// cover gets no engine, as with the release).
List<File> localLibraries(
  String engineDir,
  ReleasePlatform platform, {
  String? abi,
  bool optional = false,
}) {
  final libDir = _join([engineDir, platform.libSubdir]);
  if (!Directory(libDir).existsSync()) {
    throw EngineFetchError(
      'the engine_dir user-define names $engineDir, which has no '
      '${platform.libSubdir}${Platform.pathSeparator} folder. It must be laid '
      'out like an unpacked ${archiveTopDir(engineTag, platform)} release.',
    );
  }
  final libs = releaseLibraries(libDir, platform, abi: abi);
  final missing = [
    for (final l in libs)
      if (!l.existsSync()) l.path,
  ];
  if (optional && missing.isNotEmpty) return const [];
  if (libs.isEmpty || missing.isNotEmpty) {
    throw EngineFetchError(
      'the engine_dir user-define names $engineDir, but '
      '${missing.isEmpty ? 'it holds no engine library' : '${missing.join(', ')} is missing'}. '
      'It must be laid out like an unpacked '
      '${archiveTopDir(engineTag, platform)} release.',
    );
  }
  return libs;
}

/// Makes sure [platform]'s release of [engineTag] is unpacked under
/// [cacheRoot] and returns its library directory.
///
/// A release that is already there (see [isCached]) is reused without any
/// network access, so a warm cache works offline. Otherwise the asset is
/// downloaded from the public release URL, checked against
/// [ReleasePlatform.sha256] and unpacked with the system `tar`; an archive
/// with any other digest is rejected. [log] receives progress lines.
Future<String> ensureRelease(
  String cacheRoot,
  ReleasePlatform platform, {
  void Function(String) log = _noLog,
  String tag = engineTag,
  String? sha256,
  Uri? url,
}) async {
  final digest = sha256 ?? platform.sha256;
  final dest = releaseDir(cacheRoot, tag, platform);
  final libDir = _join([dest, platform.libSubdir]);
  if (isCached(cacheRoot, tag, platform, digest)) return libDir;

  final from = url ?? assetUrl(tag, platform);
  final tagRoot = Directory(_join([cacheRoot, tag]))
    ..createSync(recursive: true);
  // Unique per process, so concurrent hook runs never share a staging area.
  final stamp = '$pid-${DateTime.now().microsecondsSinceEpoch}';
  final archive = File(
    _join([tagRoot.path, '.download-$stamp.${platform.extension}']),
  );
  final staging = Directory(_join([tagRoot.path, '.staging-$stamp']));
  try {
    log('Downloading $from');
    await _download(from, archive);
    final actual = (await _sha256Of(archive)).toString();
    if (actual != digest) {
      throw EngineFetchError(
        'sha256 mismatch for ${assetName(tag, platform)}: expected $digest, '
        'got $actual. The download was discarded.',
      );
    }
    log('sha256 OK ($actual)');

    staging.createSync(recursive: true);
    await _untar(archive, staging);
    final top = Directory(_join([staging.path, archiveTopDir(tag, platform)]));
    if (!top.existsSync()) {
      throw EngineFetchError(
        '${assetName(tag, platform)} has no top folder '
        '${archiveTopDir(tag, platform)}/; the release layout may have changed',
      );
    }

    // Move the complete tree in only after a successful unpack, and write the
    // marker last, so an interrupted run never leaves a tree that [isCached]
    // accepts.
    final destDir = Directory(dest);
    final marker = _marker(cacheRoot, tag, platform);
    if (marker.existsSync()) marker.deleteSync();
    if (destDir.existsSync()) destDir.deleteSync(recursive: true);
    try {
      top.renameSync(dest);
    } on FileSystemException {
      // Another hook run finished the same release first.
      if (!destDir.existsSync()) rethrow;
    }
    marker.writeAsStringSync(digest);
    if (!isCached(cacheRoot, tag, platform, digest)) {
      throw EngineFetchError(
        'unpacked ${assetName(tag, platform)} but not all of '
        '${platform.libFiles.join(', ')} are in $libDir; the release layout '
        'may have changed',
      );
    }
    return libDir;
  } finally {
    if (archive.existsSync()) archive.deleteSync();
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  }
}

void _noLog(String _) {}

Future<Digest> _sha256Of(File file) => sha256.bind(file.openRead()).single;

Future<void> _download(Uri url, File to) async {
  final client = HttpClient()
    ..userAgent = 'dart-yse-build-hook'
    // The hooks runner passes the http(s)_proxy / no_proxy variables through.
    ..findProxy = HttpClient.findProxyFromEnvironment;
  try {
    final req = await client.getUrl(url);
    final res = await req.close();
    if (res.statusCode != HttpStatus.ok) {
      await res.drain<void>();
      throw EngineFetchError(
        'downloading the prebuilt engine failed: HTTP ${res.statusCode} for '
        '$url',
      );
    }
    await res.pipe(to.openWrite());
  } on SocketException catch (e) {
    throw EngineFetchError(_offline(url, e.message));
  } on HttpException catch (e) {
    throw EngineFetchError(_offline(url, e.message));
  } on HandshakeException catch (e) {
    throw EngineFetchError(_offline(url, e.message));
  } finally {
    client.close();
  }
}

String _offline(Uri url, String reason) =>
    'could not download the prebuilt engine from $url ($reason). The first '
    'build of a project that uses package:yse needs network access once; '
    'later builds reuse the copy under .dart_tool/.';

/// The `tar` to unpack with. On Windows this is the bsdtar that ships in
/// System32 (Windows 10 1803+), which also reads .zip; a Git or MSYS2 `tar`
/// earlier on PATH cannot.
String tarExecutable() {
  if (!Platform.isWindows) return 'tar';
  final root =
      Platform.environment['SYSTEMROOT'] ??
      Platform.environment['SystemRoot'] ??
      r'C:\Windows';
  return _join([root, 'System32', 'tar.exe']);
}

Future<void> _untar(File archive, Directory into) async {
  final tar = tarExecutable();
  final ProcessResult r;
  try {
    r = await Process.run(tar, ['-xf', archive.path, '-C', into.path]);
  } on ProcessException catch (e) {
    throw EngineFetchError('could not run $tar to unpack the engine: $e');
  }
  if (r.exitCode != 0) {
    throw EngineFetchError(
      '$tar could not unpack ${archive.path} (exit ${r.exitCode}): '
      '${(r.stderr as String).trim()}',
    );
  }
}
