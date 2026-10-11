// Pure-Dart tests for the release fetcher (tool/fetch_engine.dart, #88).
// No engine and no network: these cover asset naming per platform, the
// `.engine/<tag>/` layout and the digest lookup. Tag parsing moved with the
// pin helpers to tool/engine_pin.dart (test/engine_pin_test.dart).

import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:test/test.dart';

import '../tool/fetch_engine.dart';

String _p(List<String> parts) => parts.join(Platform.pathSeparator);

void main() {
  group('asset naming', () {
    test('matches the v3.1.0 release assets', () {
      expect(
        assetName('v3.1.0', ReleasePlatform.windowsX64),
        'libyse-v3.1.0-windows-x64.zip',
      );
      expect(
        assetName('v3.1.0', ReleasePlatform.linuxX64),
        'libyse-v3.1.0-linux-x64.tar.gz',
      );
    });

    test('downloads from the public release URL', () {
      expect(
        assetUrl('v3.1.0', ReleasePlatform.windowsX64).toString(),
        'https://github.com/yvanvds/yse-soundengine/releases/download/'
        'v3.1.0/libyse-v3.1.0-windows-x64.zip',
      );
      expect(
        releaseApiUrl('v3.1.0').toString(),
        'https://api.github.com/repos/yvanvds/yse-soundengine/releases/'
        'tags/v3.1.0',
      );
    });

    test('maps only the desktop ABIs the engine releases', () {
      expect(
        ReleasePlatform.fromAbi(Abi.windowsX64),
        ReleasePlatform.windowsX64,
      );
      expect(ReleasePlatform.fromAbi(Abi.linuxX64), ReleasePlatform.linuxX64);
      expect(ReleasePlatform.fromAbi(Abi.linuxArm64), isNull);
      expect(ReleasePlatform.fromAbi(Abi.macosArm64), isNull);
      expect(ReleasePlatform.fromAbi(Abi.windowsArm64), isNull);
    });
  });

  group('layout', () {
    test('YSE_DLL_PATH is bin/ on Windows and lib/ on Linux', () {
      expect(
        dllPath('root', 'v3.1.0', ReleasePlatform.windowsX64),
        _p(['root', '.engine', 'v3.1.0', 'libyse-v3.1.0-windows-x64', 'bin']),
      );
      expect(
        dllPath('root', 'v3.1.0', ReleasePlatform.linuxX64),
        _p(['root', '.engine', 'v3.1.0', 'libyse-v3.1.0-linux-x64', 'lib']),
      );
    });

    test('isInstalled looks for the library under the tag dir', () {
      final root = Directory.systemTemp.createTempSync('fetch_engine_test');
      addTearDown(() => root.deleteSync(recursive: true));
      const platform = ReleasePlatform.linuxX64;

      expect(isInstalled(root.path, 'v3.1.0', platform), isFalse);

      final dir = Directory(dllPath(root.path, 'v3.1.0', platform))
        ..createSync(recursive: true);
      expect(isInstalled(root.path, 'v3.1.0', platform), isFalse);

      File(_p([dir.path, 'libyse.so'])).writeAsStringSync('');
      expect(isInstalled(root.path, 'v3.1.0', platform), isTrue);
      expect(isInstalled(root.path, 'v3.2.0', platform), isFalse);
    });

    test('android unpacks to lib/<abi>/libyse.so for both ABIs', () {
      expect(
        dllPath('root', 'v3.1.0', ReleasePlatform.android),
        _p(['root', '.engine', 'v3.1.0', 'libyse-v3.1.0-android', 'lib']),
      );
      expect(ReleasePlatform.android.libFiles, [
        'arm64-v8a/libyse.so',
        'x86_64/libyse.so',
      ]);
    });

    test('android counts as installed only with every ABI present', () {
      final root = Directory.systemTemp.createTempSync('fetch_engine_test');
      addTearDown(() => root.deleteSync(recursive: true));
      const platform = ReleasePlatform.android;
      final lib = dllPath(root.path, 'v3.1.0', platform);

      Directory(_p([lib, 'arm64-v8a'])).createSync(recursive: true);
      File(_p([lib, 'arm64-v8a', 'libyse.so'])).writeAsStringSync('');
      expect(isInstalled(root.path, 'v3.1.0', platform), isFalse);

      Directory(_p([lib, 'x86_64'])).createSync(recursive: true);
      File(_p([lib, 'x86_64', 'libyse.so'])).writeAsStringSync('');
      expect(isInstalled(root.path, 'v3.1.0', platform), isTrue);
    });
  });

  group('parseArgs', () {
    test('defaults to the host platform without --force', () {
      final o = parseArgs([]);
      expect(o.force, isFalse);
      expect(o.platform, isNull);
    });

    test('reads --force and --platform in both spellings', () {
      final a = parseArgs(['--platform', 'android', '--force']);
      expect(a.force, isTrue);
      expect(a.platform, ReleasePlatform.android);
      expect(
        parseArgs(['--platform=linux-x64']).platform,
        ReleasePlatform.linuxX64,
      );
      expect(
        parseArgs(['--platform', 'windows-x64']).platform,
        ReleasePlatform.windowsX64,
      );
    });

    test('rejects unknown platforms and arguments', () {
      expect(
        () => parseArgs(['--platform', 'ios']),
        throwsA(isA<FetchError>()),
      );
      expect(() => parseArgs(['--platform']), throwsA(isA<FetchError>()));
      expect(() => parseArgs(['--nope']), throwsA(isA<FetchError>()));
    });
  });

  group('parseProperties', () {
    test('reads key=value lines and skips comments and blanks', () {
      expect(parseProperties('# c\n! c\n\n a = 1 \nb=x=y\r\nnot a pair\n'), {
        'a': '1',
        'b': 'x=y',
      });
    });
  });

  test('android asset is named like the v3.1.0 release', () {
    expect(
      assetName('v3.1.0', ReleasePlatform.android),
      'libyse-v3.1.0-android.tar.gz',
    );
  });

  group('parseAssetDigest', () {
    const release = '''
{"tag_name": "v3.1.0", "assets": [
  {"name": "libyse-v3.1.0-linux-x64.tar.gz",
   "digest": "sha256:D732CD20bd6f6513dd72ba01f321ad8c3debb3b3fc0defbd7e780fada3a5802d"},
  {"name": "libyse-v3.1.0-windows-x64.zip", "digest": null}
]}''';

    test('returns the lower-case sha256 of the named asset', () {
      expect(
        parseAssetDigest(release, 'libyse-v3.1.0-linux-x64.tar.gz'),
        'd732cd20bd6f6513dd72ba01f321ad8c3debb3b3fc0defbd7e780fada3a5802d',
      );
    });

    test('returns null when there is no digest to check against', () {
      expect(parseAssetDigest(release, 'libyse-v3.1.0-windows-x64.zip'), null);
      expect(parseAssetDigest(release, 'libyse-v3.1.0-android.tar.gz'), null);
      expect(parseAssetDigest('{}', 'x'), null);
      expect(parseAssetDigest('[]', 'x'), null);
    });
  });
}
