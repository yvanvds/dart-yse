// Tests for the patcher metadata snapshot that feeds the docs' object
// reference (tool/gen_patcher_snapshot.dart, #69).
//
// The snapshot (docs/source/_data/patcher_objects.json) is committed so the
// docs build needs no engine. The engine-backed tests here keep it from
// drifting from the registry of the bound libyse: before #69 a hand-copied
// snapshot listed 42 objects while the engine had 305.
//
// These drive the real `libyse.dll` / `libyse.so`; set `YSE_DLL_PATH` to the
// directory holding it (see README / CLAUDE.md).
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

import '../tool/gen_patcher_snapshot.dart';
import 'support/engine_pin.dart';

const _snapshotPath = 'docs/source/_data/patcher_objects.json';

Map<String, dynamic> _snapshot() =>
    jsonDecode(File(_snapshotPath).readAsStringSync()) as Map<String, dynamic>;

void main() {
  setUpAll(noticeUnpinnedEngine);

  group('renderPatcherSnapshot', () {
    test('sorts every map key, keeps list order, ends with a newline', () {
      final out = renderPatcherSnapshot({
        '~sine': {
          'name': '~sine',
          'category': 'OSC',
          'inlets': [
            {'index': 1, 'doc': 'b'},
            {'index': 0, 'doc': 'a'},
          ],
        },
        '.b': {'name': '.b', 'category': 'GENERIC'},
      });
      expect(
        out,
        '{\n'
        '  ".b": {\n'
        '    "category": "GENERIC",\n'
        '    "name": ".b"\n'
        '  },\n'
        '  "~sine": {\n'
        '    "category": "OSC",\n'
        '    "inlets": [\n'
        '      {\n'
        '        "doc": "b",\n'
        '        "index": 1\n'
        '      },\n'
        '      {\n'
        '        "doc": "a",\n'
        '        "index": 0\n'
        '      }\n'
        '    ],\n'
        '    "name": "~sine"\n'
        '  }\n'
        '}\n',
      );
    });

    test('is independent of the input key order', () {
      expect(
        renderPatcherSnapshot({'b': 1, 'a': 2}),
        renderPatcherSnapshot({'a': 2, 'b': 1}),
      );
    });
  });

  test('docs/source/conf.py has a page for every PCategory', () {
    // `("OSC", "signal_generators", ...` rows of _PATCHER_CATEGORIES.
    final conf = File('docs/source/conf.py').readAsStringSync();
    final table = RegExp(
      r'_PATCHER_CATEGORIES = \[(.*?)\n\]',
      dotAll: true,
    ).firstMatch(conf);
    expect(table, isNotNull, reason: '_PATCHER_CATEGORIES not found');
    final keys = RegExp(
      r'\(\s*"(\w+)",\s*"\w+",',
    ).allMatches(table!.group(1)!).map((m) => m.group(1)!).toList();
    expect(keys.toSet(), hasLength(keys.length), reason: 'duplicate keys');
    expect(
      keys.map((k) => 'YSE_PCAT_$k').toSet(),
      PCategory.values.map((c) => c.native.name).toSet(),
    );
  });

  group('against the bound registry', () {
    late System sys;

    setUpAll(() {
      sys = System.instance;
      sys.initOffline();
    });

    tearDownAll(() {
      sys.close();
    });

    test('the snapshot lists exactly the registry\'s object types', () {
      final snapshot = _snapshot();
      expect(snapshot, hasLength(PatcherRegistry.typeCount));
      expect(snapshot.keys.toSet(), PatcherRegistry.typeNames().toSet());
    });

    test('every snapshot category is a PCategory', () {
      for (final MapEntry(key: type, value: meta) in _snapshot().entries) {
        final cat = (meta as Map<String, dynamic>)['category'] as String;
        expect(
          PCategory.values.map((c) => c.native.name),
          contains('YSE_PCAT_$cat'),
          reason: type,
        );
        expect(cat, isNot('UNSET'), reason: '$type has no category');
      }
    });

    test('the snapshot matches the registry byte for byte', () {
      final current = File(_snapshotPath).readAsStringSync();
      expect(
        current.replaceAll('\r\n', '\n'),
        renderPatcherSnapshot(
          jsonDecode(PatcherRegistry.metadataJson()) as Map<String, dynamic>,
        ),
        reason:
            '$_snapshotPath is stale; run '
            'dart run tool/gen_patcher_snapshot.dart',
      );
    });

    test('tool --check agrees', () async {
      final r = await Process.run(Platform.resolvedExecutable, [
        'run',
        'tool/gen_patcher_snapshot.dart',
        '--check',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
