// The yse_flutter_libs plugin packages the engine release named in
// packages/yse_flutter_libs/android/engine.properties (#91). These checks keep
// that file in step with the submodule pin, so a bump of the pin cannot ship
// a plugin that packages a different libYSE than package:yse binds.
// No engine and no network needed.

import 'dart:io';

import 'package:test/test.dart';

import '../tool/engine_pin.dart';
import '../tool/fetch_engine.dart';

const _propsPath = 'packages/yse_flutter_libs/android/engine.properties';

Map<String, String> _props() => parseProperties(
  File(_propsPath.replaceAll('/', Platform.pathSeparator)).readAsStringSync(),
);

void main() {
  test('engine.properties names a release tag and a sha256', () {
    final p = _props();
    expect(() => parseReleaseTag(p['engineTag'] ?? ''), returnsNormally);
    expect(p['engineSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('engine.properties matches the submodule pin', () async {
    final String tag;
    try {
      tag = await readPinnedTag(Directory.current.path);
    } on PinError catch (e) {
      // CI's shallow submodule checkout carries no tags.
      markTestSkipped('pinned tag unreadable: $e');
      return;
    }
    expect(
      _props()['engineTag'],
      tag,
      reason:
          'bump engineTag (and engineSha256) in $_propsPath along with the '
          'engine submodule',
    );
  });
}
