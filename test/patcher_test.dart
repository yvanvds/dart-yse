// Integration tests for the Patcher wrapper against the engine 3.x C ABI
// (issue #55): YseStatus-returning init / parseJson, the "nothing here"
// ID sentinels, and the registry category enum.
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md).
@TestOn('vm')
library;

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

  Patcher newPatcher({int mainOutputs = 2}) {
    final p = Patcher(mainOutputs: mainOutputs);
    addTearDown(p.dispose);
    return p;
  }

  group('Patcher construction', () {
    test('a valid configuration initialises without throwing', () {
      expect(newPatcher, returnsNormally);
    });

    test('a negative output count is rejected with YseException', () {
      expect(
        () => Patcher(mainOutputs: -1),
        throwsA(
          isA<YseException>().having((e) => e.status, 'status', isNotNull),
        ),
      );
    });
  });

  group('Patcher.parseJson', () {
    test('malformed JSON throws and leaves the patch unchanged', () {
      final p = newPatcher();
      final a = p.createObject(Obj.gInt);
      final b = p.createObject(Obj.gInt);
      p.connect(a, outlet: 0, to: b, inlet: 0);
      final before = p.dumpJson();
      final count = p.objects;

      expect(() => p.parseJson('not json'), throwsA(isA<YseException>()));
      expect(p.objects, count);
      expect(p.dumpJson(), before);
    });

    test('loading adds to the existing patch; clear() first replaces it', () {
      final src = newPatcher();
      src.createObject(Obj.gInt);
      src.createObject(Obj.gFloat);
      final json = src.dumpJson();

      final dst = newPatcher();
      dst.createObject(Obj.gInt);
      dst.parseJson(json);
      expect(dst.objects, 3);

      dst.clear();
      dst.parseJson(json);
      expect(dst.objects, 2);
    });
  });

  group('PHandle ID sentinels', () {
    test('the first object in a patcher has ID 0', () {
      final p = newPatcher();
      final first = p.createObject(Obj.gInt);
      final second = p.createObject(Obj.gInt);
      expect(first.id, 0);
      expect(second.id, 1);
      expect(p.getHandleById(0).id, 0);
    });

    test('an absent object reports a null ID', () {
      final p = newPatcher();
      p.createObject(Obj.gInt);
      expect(p.getHandleById(12345).id, isNull);
    });

    test('a real edge reports its target; an absent edge reports null', () {
      final p = newPatcher();
      final a = p.createObject(Obj.gInt);
      final b = p.createObject(Obj.gInt);
      p.connect(a, outlet: 0, to: b, inlet: 1);

      expect(a.connectionCount(0), 1);
      expect(a.connectionTargetId(0, 0), b.id);
      expect(a.connectionTargetInlet(0, 0), 1);

      // Connection index past the outlet's edge count.
      expect(a.connectionTargetId(0, 1), isNull);
      expect(a.connectionTargetInlet(0, 1), isNull);
      // Outlet index past the object's outlet count.
      expect(a.connectionTargetId(99, 0), isNull);
      expect(a.connectionTargetInlet(99, 0), isNull);
      // An object with no outgoing edges.
      expect(b.connectionTargetId(0, 0), isNull);
    });
  });

  group('PCategory', () {
    test('every registered type maps to a category without throwing', () {
      final cats = {for (final t in PatcherRegistry.types()) t.category};
      // The 3.0 registry files objects under the categories added after 2.4
      // (routing, list, io, ...); they must not all collapse to `unset`.
      expect(cats, contains(PCategory.io));
      expect(cats, contains(PCategory.routing));
      expect(cats.length, greaterThan(8));
    });

    test('every member carries a distinct native value', () {
      final natives = PCategory.values.map((c) => c.native).toSet();
      expect(natives.length, PCategory.values.length);
      expect(PCategory.values.length, 19);
    });
  });
}
