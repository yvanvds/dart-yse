// The build hook's download cache (hook/engine_cache.dart, #95), against a
// fake release served from localhost: download, sha256 check, unpack, reuse
// without network, and rejection of a tampered archive. Needs the system
// `tar` (Windows 10+ / Linux) but no engine and no internet.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:yse/src/engine_release.dart';

import '../hook/engine_cache.dart';

const _tag = 'v9.9.9';
const _platform = ReleasePlatform.linuxX64;

String _p(List<String> parts) => parts.join(Platform.pathSeparator);

void main() {
  late Directory tmp;
  late File archive;
  late String digest;
  late HttpServer server;
  late Uri url;
  var requests = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('yse_engine_cache_');
    // A release-shaped archive: libyse-<tag>-linux-x64/lib/libyse.so.
    final src = Directory(_p([tmp.path, 'src']));
    final top = archiveTopDir(_tag, _platform);
    Directory(_p([src.path, top, 'lib'])).createSync(recursive: true);
    File(_p([src.path, top, 'lib', 'libyse.so'])).writeAsStringSync('fake');
    archive = File(_p([tmp.path, assetName(_tag, _platform)]));
    final r = await Process.run(tarExecutable(), [
      '-czf',
      archive.path,
      '-C',
      src.path,
      top,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    digest = sha256.convert(archive.readAsBytesSync()).toString();

    requests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      requests++;
      await req.response.addStream(archive.openRead());
      await req.response.close();
    });
    url = Uri.http(
      '127.0.0.1:${server.port}',
      '/${archive.uri.pathSegments.last}',
    );
  });

  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });

  String cacheRoot() => _p([tmp.path, 'cache']);

  test('downloads, verifies and unpacks a release', () async {
    final lib = await ensureRelease(
      cacheRoot(),
      _platform,
      tag: _tag,
      sha256: digest,
      url: url,
    );
    expect(lib, _p([releaseDir(cacheRoot(), _tag, _platform), 'lib']));
    expect(File(_p([lib, 'libyse.so'])).readAsStringSync(), 'fake');
    expect(isCached(cacheRoot(), _tag, _platform, digest), isTrue);
    expect(requests, 1);
    // No download or staging leftovers next to the release.
    final names = Directory(_p([cacheRoot(), _tag]))
        .listSync()
        .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last)
        .toSet();
    expect(names, {
      archiveTopDir(_tag, _platform),
      '${archiveTopDir(_tag, _platform)}.sha256',
    });
  });

  test('a warm cache needs no network', () async {
    await ensureRelease(
      cacheRoot(),
      _platform,
      tag: _tag,
      sha256: digest,
      url: url,
    );
    await server.close(force: true);
    final lib = await ensureRelease(
      cacheRoot(),
      _platform,
      tag: _tag,
      sha256: digest,
      url: url,
    );
    expect(File(_p([lib, 'libyse.so'])).existsSync(), isTrue);
    expect(requests, 1);
  });

  test('rejects an archive whose sha256 differs and caches nothing', () async {
    await expectLater(
      ensureRelease(
        cacheRoot(),
        _platform,
        tag: _tag,
        sha256: '0' * 64,
        url: url,
      ),
      throwsA(
        isA<EngineFetchError>().having(
          (e) => e.message,
          'message',
          contains('sha256 mismatch'),
        ),
      ),
    );
    expect(isCached(cacheRoot(), _tag, _platform, '0' * 64), isFalse);
    expect(isCached(cacheRoot(), _tag, _platform, digest), isFalse);
    expect(
      Directory(_p([cacheRoot(), _tag])).listSync(),
      isEmpty,
      reason: 'the rejected download is deleted',
    );
  });

  test('a release unpacked from another digest is fetched again', () async {
    await ensureRelease(
      cacheRoot(),
      _platform,
      tag: _tag,
      sha256: digest,
      url: url,
    );
    expect(isCached(cacheRoot(), _tag, _platform, 'f' * 64), isFalse);
  });

  test(
    'an unreachable server explains that one online build is needed',
    () async {
      await server.close(force: true);
      await expectLater(
        ensureRelease(
          cacheRoot(),
          _platform,
          tag: _tag,
          sha256: digest,
          url: url,
        ),
        throwsA(
          isA<EngineFetchError>().having(
            (e) => e.message,
            'message',
            contains('needs network access once'),
          ),
        ),
      );
    },
  );

  test('on Windows every DLL in bin/ is bundled with libyse.dll', () {
    final bin = Directory(_p([tmp.path, 'bin']))..createSync();
    for (final f in ['libyse.dll', 'libc++.dll', 'libsndfile-1.dll', 'x.txt']) {
      File(_p([bin.path, f])).writeAsStringSync('');
    }
    final names = releaseLibraries(
      bin.path,
      ReleasePlatform.windowsX64,
    ).map((f) => f.uri.pathSegments.last).toList();
    expect(names, ['libc++.dll', 'libsndfile-1.dll', 'libyse.dll']);
  });

  test('on Linux only the engine library is bundled', () {
    expect(
      releaseLibraries('lib', ReleasePlatform.linuxX64).map((f) => f.path),
      [
        _p(['lib', 'libyse.so']),
      ],
    );
  });

  test('on Android only the target ABI\'s engine library is bundled', () {
    expect(
      releaseLibraries(
        'lib',
        ReleasePlatform.android,
        abi: 'x86_64',
      ).map((f) => f.path),
      [
        _p(['lib', 'x86_64', 'libyse.so']),
      ],
    );
    expect(
      () => releaseLibraries('lib', ReleasePlatform.android),
      throwsArgumentError,
    );
  });

  group('engine_dir', () {
    String androidEngine(List<String> abis) {
      final dir = _p([tmp.path, 'local-android']);
      for (final abi in abis) {
        Directory(_p([dir, 'lib', abi])).createSync(recursive: true);
        File(_p([dir, 'lib', abi, 'libyse.so'])).writeAsStringSync('');
      }
      return dir;
    }

    test('bundles the ABI\'s library from a release-shaped folder', () {
      final dir = androidEngine(['arm64-v8a', 'armeabi-v7a']);
      expect(
        localLibraries(
          dir,
          ReleasePlatform.android,
          abi: 'armeabi-v7a',
        ).map((f) => f.path),
        [
          _p([dir, 'lib', 'armeabi-v7a', 'libyse.so']),
        ],
      );
    });

    test('a missing required library is an error', () {
      final dir = androidEngine(['arm64-v8a']);
      expect(
        () => localLibraries(dir, ReleasePlatform.android, abi: 'x86_64'),
        throwsA(
          isA<EngineFetchError>().having(
            (e) => e.message,
            'message',
            contains(_p(['x86_64', 'libyse.so'])),
          ),
        ),
      );
    });

    test('a missing optional library bundles nothing', () {
      final dir = androidEngine(['arm64-v8a']);
      expect(
        localLibraries(
          dir,
          ReleasePlatform.android,
          abi: 'x86',
          optional: true,
        ),
        isEmpty,
      );
    });

    test('a folder without the release layout is an error', () {
      expect(
        () => localLibraries(tmp.path, ReleasePlatform.windowsX64),
        throwsA(
          isA<EngineFetchError>().having(
            (e) => e.message,
            'message',
            contains('no bin'),
          ),
        ),
      );
    });
  });
}
