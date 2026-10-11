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
        assetName('v3.1.0', HostPlatform.windowsX64),
        'libyse-v3.1.0-windows-x64.zip',
      );
      expect(
        assetName('v3.1.0', HostPlatform.linuxX64),
        'libyse-v3.1.0-linux-x64.tar.gz',
      );
    });

    test('downloads from the public release URL', () {
      expect(
        assetUrl('v3.1.0', HostPlatform.windowsX64).toString(),
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
      expect(HostPlatform.fromAbi(Abi.windowsX64), HostPlatform.windowsX64);
      expect(HostPlatform.fromAbi(Abi.linuxX64), HostPlatform.linuxX64);
      expect(HostPlatform.fromAbi(Abi.linuxArm64), isNull);
      expect(HostPlatform.fromAbi(Abi.macosArm64), isNull);
      expect(HostPlatform.fromAbi(Abi.windowsArm64), isNull);
    });
  });

  group('layout', () {
    test('YSE_DLL_PATH is bin/ on Windows and lib/ on Linux', () {
      expect(
        dllPath('root', 'v3.1.0', HostPlatform.windowsX64),
        _p(['root', '.engine', 'v3.1.0', 'libyse-v3.1.0-windows-x64', 'bin']),
      );
      expect(
        dllPath('root', 'v3.1.0', HostPlatform.linuxX64),
        _p(['root', '.engine', 'v3.1.0', 'libyse-v3.1.0-linux-x64', 'lib']),
      );
    });

    test('isInstalled looks for the library under the tag dir', () {
      final root = Directory.systemTemp.createTempSync('fetch_engine_test');
      addTearDown(() => root.deleteSync(recursive: true));
      const platform = HostPlatform.linuxX64;

      expect(isInstalled(root.path, 'v3.1.0', platform), isFalse);

      final dir = Directory(dllPath(root.path, 'v3.1.0', platform))
        ..createSync(recursive: true);
      expect(isInstalled(root.path, 'v3.1.0', platform), isFalse);

      File(_p([dir.path, platform.libName])).writeAsStringSync('');
      expect(isInstalled(root.path, 'v3.1.0', platform), isTrue);
      expect(isInstalled(root.path, 'v3.2.0', platform), isFalse);
    });
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
