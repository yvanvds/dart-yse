// Integration smoke tests for the patcher object metadata introspection
// API (issue #26): the read-only `PatcherRegistry` surface that enumerates
// registered patcher object types and exposes their description, category
// and inlet / outlet / parameter schema.
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test
//
// Self-contained: the suite owns the engine for its whole lifecycle via
// `initOffline()` / `close()` so it passes both in isolation and in the
// full concurrency:1 run.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

void main() {
  late System sys;

  setUpAll(() {
    sys = System.instance;
    sys.initOffline();
  });

  tearDownAll(() {
    sys.close();
  });

  group('PatcherRegistry enumeration', () {
    test('reports a non-empty, self-consistent type list', () {
      final count = PatcherRegistry.typeCount;
      expect(count, greaterThan(0));

      final names = PatcherRegistry.typeNames();
      expect(names, hasLength(count));
      // No blanks, no duplicates.
      expect(names.where((n) => n.isEmpty), isEmpty);
      expect(names.toSet(), hasLength(count));

      // The catalogue includes the well-known objects the wrapper ships
      // constants for.
      expect(names, contains(Obj.dSine));
      expect(names, contains(Obj.gAdd));
    });

    test('types() mirrors typeNames()', () {
      final types = PatcherRegistry.types();
      expect(types.map((t) => t.name).toList(), PatcherRegistry.typeNames());
    });

    test('unknown type resolves to null', () {
      expect(PatcherRegistry.type('~definitely-not-a-real-object'), isNull);
    });
  });

  group('PatcherObjectType metadata', () {
    test('~sine exposes its full schema', () {
      final sine = PatcherRegistry.type(Obj.dSine);
      expect(sine, isNotNull);

      expect(sine!.name, Obj.dSine);
      expect(sine.description, isNotEmpty);
      expect(sine.category, PCategory.oscillator);
      expect(sine.isDsp, isTrue);

      // One frequency inlet accepting a DSP buffer (FM) or a float.
      expect(sine.inletCount, 1);
      final inlets = sine.inlets();
      expect(inlets, hasLength(1));
      expect(inlets.first.label, 'freq');
      expect(inlets.first.accepts, contains(InletAccepts.buffer));
      expect(inlets.first.accepts, contains(InletAccepts.float));

      // One audio-buffer outlet.
      expect(sine.outletCount, 1);
      final outlets = sine.outlets();
      expect(outlets, hasLength(1));
      expect(outlets.first.type, OutType.buffer);

      // One creation parameter.
      expect(sine.paramCount, 1);
      final params = sine.params();
      expect(params, hasLength(1));
      expect(params.first.name, 'frequency');
      expect(params.first.defaultValue, isNotEmpty);
    });

    test('a control-rate object reports isDsp false', () {
      final add = PatcherRegistry.type(Obj.gAdd);
      expect(add, isNotNull);
      expect(add!.isDsp, isFalse);
      expect(add.category, PCategory.math);
    });
  });

  group('metadata JSON snapshot', () {
    test('parses and covers every registered type; repeat calls are safe', () {
      // Called repeatedly to exercise the allocate/free round-trip — the
      // wrapper must release each engine-allocated buffer via
      // yse_free_string (no native string leak per the issue's acceptance).
      late Map<String, dynamic> decoded;
      for (var i = 0; i < 3; i++) {
        final json = PatcherRegistry.metadataJson();
        expect(json, isNotEmpty);
        decoded = jsonDecode(json) as Map<String, dynamic>;
      }

      // Every enumerated type appears in the bulk snapshot.
      for (final name in PatcherRegistry.typeNames()) {
        expect(decoded, contains(name));
      }
    });
  });
}
