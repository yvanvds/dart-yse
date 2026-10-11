// Pure-Dart tests for the docs generator (tool/emit_api_rst.dart). No
// engine needed: the generator is lexical.

import 'dart:io';

import 'package:test/test.dart';

import '../tool/emit_api_rst.dart';

void main() {
  group('collectApiPages', () {
    test('emits record and function typedefs (#75)', () {
      const source = '''
/// A frame.
typedef Frame = ({String address, int value});

/// A callback.
typedef Cb = double Function(int a, int b);

/// Legacy form.
typedef int Legacy(String s);

typedef Hidden = int;
''';
      final pages = collectApiPages(source, {'Frame', 'Cb', 'Legacy'});
      expect(pages.keys, unorderedEquals(['Frame', 'Cb', 'Legacy']));
      expect(pages['Frame'], startsWith('typedef Frame\n============='));
      expect(
        pages['Frame'],
        contains('typedef Frame = ({String address, int value});'),
      );
      expect(pages['Frame'], contains('A frame.'));
      expect(
        pages['Cb'],
        contains('typedef Cb = double Function(int a, int b);'),
      );
      expect(pages['Legacy'], contains('typedef int Legacy(String s);'));
    });
  });

  group('coverageErrors', () {
    test('reports re-exported names with no page', () {
      final errors = coverageErrors(
        exports: (names: {'A', 'B', 'C'}, withoutShow: const []),
        emitted: {'A'},
      );
      expect(errors, hasLength(1));
      expect(errors.single, contains('2 re-exported name(s)'));
      expect(errors.single, contains('B, C'));
    });

    test('reports exports without a show clause', () {
      final exports = parseReExports(
        "export 'src/a.dart' show A;\nexport 'src/b.dart';\n",
      );
      expect(exports.names, {'A'});
      expect(exports.withoutShow, ['src/b.dart']);
      final errors = coverageErrors(exports: exports, emitted: {'A'});
      expect(errors.single, contains("export 'src/b.dart'"));
    });

    test('is empty when everything is covered', () {
      expect(
        coverageErrors(
          exports: (names: {'A'}, withoutShow: const []),
          emitted: {'A'},
        ),
        isEmpty,
      );
    });
  });

  group('the real public surface', () {
    final exports = parseReExports(File('lib/yse.dart').readAsStringSync());
    final pages = <String, String>{};
    for (final f in Directory('lib/src').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      pages.addAll(collectApiPages(f.readAsStringSync(), exports.names));
    }

    test('every lib/yse.dart export gets an API page', () {
      expect(
        coverageErrors(exports: exports, emitted: pages.keys.toSet()),
        isEmpty,
      );
    });

    test('every generated page is included from docs/source/api', () {
      final included = <String>{};
      final include = RegExp(r'^\.\. include:: _generated/(\S+)\.rst\s*$');
      for (final f in Directory(
        'docs/source/api',
      ).listSync().whereType<File>()) {
        if (!f.path.endsWith('.rst')) continue;
        for (final line in f.readAsLinesSync()) {
          final m = include.firstMatch(line);
          if (m != null) included.add(m.group(1)!);
        }
      }
      final orphans = pages.keys
          .where((name) => !included.contains(apiPageSlug(name)))
          .toList();
      expect(orphans, isEmpty, reason: 'pages no .rst includes');
    });
  });
}
