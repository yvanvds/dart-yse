// Package layout rules pub.dev enforces at upload time but `dart pub publish
// --dry-run` does not (#101). pub.dev's archive check (pub-dev
// pkg/pub_package_reader, `checkHooks`) rejects every `.dart` file under
// hook/ other than the entry points hook/build.dart and hook/link.dart —
// subdirectories included — so helpers of the build hook live under
// lib/src/hook/ instead. No engine needed.

import 'dart:io';

import 'package:test/test.dart';

const _allowedHookFiles = {'hook/build.dart', 'hook/link.dart'};

String _rel(FileSystemEntity e) => e.path
    .substring(Directory.current.path.length + 1)
    .replaceAll(Platform.pathSeparator, '/');

void main() {
  test('hook/ holds only the hook entry points pub.dev accepts', () {
    final dartFiles = Directory('hook')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => _rel(f.absolute))
        .where((p) => p.endsWith('.dart'))
        .toSet();
    expect(dartFiles, contains('hook/build.dart'));
    expect(
      dartFiles.difference(_allowedHookFiles),
      isEmpty,
      reason:
          'pub.dev refuses any other .dart file under hook/ ("Hook files are '
          'experimental"). Move helpers to lib/src/hook/ and import them as '
          'package:yse/src/hook/...',
    );
  });

  test('only the hook imports lib/src/hook/', () {
    // The cache helper pulls in dart:io and package:crypto; the runtime
    // library must not depend on it.
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => _rel(f.absolute))
        .where((p) => !p.startsWith('lib/src/hook/'))
        .where(
          (p) => RegExp(
            r'''^\s*(import|export|part)\s+['"][^'"]*\bhook/''',
            multiLine: true,
          ).hasMatch(File(p).readAsStringSync()),
        )
        .toList();
    expect(offenders, isEmpty);
  });
}
