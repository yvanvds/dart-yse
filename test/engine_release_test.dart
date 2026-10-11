// The engine pin as it ships in the published package
// (lib/src/engine_release.dart, #95): the tag and per-asset sha256 digests the
// native-assets build hook downloads and checks. A pub cache has no engine
// submodule, so these tests keep the embedded copy equal to the submodule pin,
// to the yse_flutter_libs plugin's pin and to the digests of the release
// itself. The last check needs the network and skips cleanly without it.

import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';
import 'package:yse/src/engine_release.dart';

import '../hook/build.dart';
import '../tool/engine_pin.dart';
import '../tool/fetch_engine.dart'
    show parseAssetDigest, parseProperties, releaseApiUrl;

const _propsPath = 'packages/yse_flutter_libs/android/engine.properties';

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

  test('the Android digest equals the yse_flutter_libs pin', () {
    final props = parseProperties(
      File(
        _propsPath.replaceAll('/', Platform.pathSeparator),
      ).readAsStringSync(),
    );
    expect(props['engineTag'], engineTag);
    expect(props['engineSha256'], ReleasePlatform.android.sha256);
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

    test('leaves Android to yse_flutter_libs and skips unreleased ones', () {
      expect(hookPlatform(OS.android, Architecture.arm64), isNull);
      expect(hookPlatform(OS.android, Architecture.x64), isNull);
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
