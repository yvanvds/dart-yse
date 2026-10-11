// The engine pin as it ships in the published package
// (lib/src/engine_release.dart, #95): the tag and per-asset sha256 digests the
// native-assets build hook downloads and checks. A pub cache has no engine
// submodule, so these tests keep the embedded copy equal to the submodule pin
// and to the digests of the release itself. The last check needs the network
// and skips cleanly without it.

import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';
import 'package:yse/src/engine_release.dart';

import '../hook/build.dart';
import '../tool/engine_pin.dart';
import '../tool/fetch_engine.dart' show parseAssetDigest, releaseApiUrl;

void main() {
  test('the embedded tag is a release tag', () {
    expect(parseReleaseTag(engineTag), engineTag);
  });

  test('every platform has a sha256 digest', () {
    for (final p in ReleasePlatform.values) {
      expect(p.sha256, matches(RegExp(r'^[0-9a-f]{64}$')), reason: p.slug);
    }
  });

  test('the embedded tag equals the submodule pin', () async {
    final String tag;
    try {
      tag = await readPinnedTag(Directory.current.path);
    } on PinError catch (e) {
      // CI's shallow submodule checkout carries no tags.
      markTestSkipped('pinned tag unreadable: $e');
      return;
    }
    expect(
      engineTag,
      tag,
      reason:
          'bump engineTag and the digests in lib/src/engine_release.dart '
          'along with the engine submodule',
    );
  });

  test('the embedded digests equal the release assets on GitHub', () async {
    final String body;
    try {
      body = await _get(releaseApiUrl(engineTag));
    } on Exception catch (e) {
      markTestSkipped('GitHub API unreachable: $e');
      return;
    }
    for (final p in ReleasePlatform.values) {
      final name = assetName(engineTag, p);
      expect(
        parseAssetDigest(body, name),
        p.sha256,
        reason: '$name in the $engineTag release',
      );
    }
  }, timeout: const Timeout(Duration(seconds: 60)));

  group('build hook targets', () {
    test('bundles the desktop x64 releases', () {
      expect(
        hookPlatform(OS.windows, Architecture.x64),
        ReleasePlatform.windowsX64,
      );
      expect(
        hookPlatform(OS.linux, Architecture.x64),
        ReleasePlatform.linuxX64,
      );
    });

    test('bundles the Android release for its 64-bit ABIs (#96)', () {
      for (final arch in [
        Architecture.arm64,
        Architecture.x64,
        Architecture.arm,
        Architecture.ia32,
      ]) {
        expect(
          hookPlatform(OS.android, arch),
          ReleasePlatform.android,
          reason: '$arch',
        );
      }
      expect(androidAbi(Architecture.arm64), 'arm64-v8a');
      expect(androidAbi(Architecture.x64), 'x86_64');
      expect(androidAbi(Architecture.arm), 'armeabi-v7a');
      expect(androidAbi(Architecture.ia32), 'x86');
      expect(androidAbi(Architecture.riscv64), isNull);
      // 32-bit ABIs get an engine only from an engine_dir.
      expect(releaseShipsAbi('arm64-v8a'), isTrue);
      expect(releaseShipsAbi('x86_64'), isTrue);
      expect(releaseShipsAbi('armeabi-v7a'), isFalse);
      expect(releaseShipsAbi('x86'), isFalse);
    });

    test('skips targets without an engine release', () {
      expect(hookPlatform(OS.android, Architecture.riscv64), isNull);
      expect(hookPlatform(OS.linux, Architecture.arm64), isNull);
      expect(hookPlatform(OS.windows, Architecture.arm64), isNull);
      expect(hookPlatform(OS.macOS, Architecture.arm64), isNull);
      expect(hookPlatform(OS.iOS, Architecture.arm64), isNull);
    });

    test('names the engine asset as the loader expects', () {
      expect('package:yse/${assetNameFor('libyse.dll')}', libyseAssetId);
      expect('package:yse/${assetNameFor('libyse.so')}', libyseAssetId);
      expect(assetNameFor('libc++.dll'), 'deps/libc++.dll');
      expect(assetNameFor('libsndfile-1.dll'), 'deps/libsndfile-1.dll');
    });
  });
}

/// GETs [url] as text; throws on a network error or a non-200 answer (an
/// API rate limit included).
Future<String> _get(Uri url) async {
  final client = HttpClient()..userAgent = 'dart-yse-tests';
  try {
    final req = await client.getUrl(url).timeout(const Duration(seconds: 20));
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    return body;
  } finally {
    client.close();
  }
}
