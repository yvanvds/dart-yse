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

  group('Patcher.name (#50)', () {
    // Matched by name: the public surface does not re-export YseStatus.
    final invalidArgument = isA<YseException>().having(
      (e) => e.status?.name,
      'status',
      'YSE_ERR_INVALID_ARGUMENT',
    );

    test('an unnamed patcher gets an auto-generated patcher_<N> name', () {
      expect(newPatcher().name, matches(RegExp(r'^patcher_\d+$')));
    });

    test('the factory name: parameter names the patcher', () {
      final p = Patcher(name: 'lead');
      addTearDown(p.dispose);
      expect(p.name, 'lead');
    });

    test('set and read back; null and empty restore the auto-name', () {
      final p = newPatcher();
      p.name = 'pad';
      expect(p.name, 'pad');
      p.name = null;
      expect(p.name, matches(RegExp(r'^patcher_\d+$')));
      p.name = 'pad';
      p.name = '';
      expect(p.name, matches(RegExp(r'^patcher_\d+$')));
    });

    test('a name over 55 characters is refused and the old name kept', () {
      final p = newPatcher();
      p.name = 'keep';
      expect(() => p.name = 'x' * 56, throwsA(invalidArgument));
      expect(p.name, 'keep');
      p.name = 'y' * Patcher.maxNameLength;
      expect(p.name, 'y' * Patcher.maxNameLength);
    });

    test('a too-long factory name throws', () {
      expect(() => Patcher(name: 'x' * 56), throwsA(invalidArgument));
    });

    test('the name round-trips through dumpJson / parseJson', () {
      final src = newPatcher();
      src.name = 'saved';
      src.createObject(Obj.gInt);
      final dst = newPatcher();
      dst.parseJson(src.dumpJson());
      expect(dst.name, 'saved');
    });

    Future<void> flush() => Future<void>.delayed(Duration.zero);

    test('a gSend publishes under patcher.<name>.<slot>', () async {
      final p = Patcher(name: 'lead');
      addTearDown(p.dispose);
      final send = p.createObject(Obj.gSend, args: 'cutoff');

      final frames = <BusFrame>[];
      final sub = Bus.subscribe('patcher.lead.cutoff').listen(frames.add);
      addTearDown(sub.cancel);

      send.sendFloat(0, 0.25);
      await flush();
      expect(frames.map((f) => f.value), [const BusFloat(0.25)]);
    });

    test('renaming re-anchors the slot under the new name', () async {
      final p = newPatcher();
      p.name = 'before';
      final send = p.createObject(Obj.gSend, args: 'gate');

      final seen = <String>[];
      final sub = Bus.tap('patcher.').listen((f) => seen.add(f.address));
      addTearDown(sub.cancel);

      send.sendBang(0);
      await flush();
      p.name = 'after';
      send.sendBang(0);
      await flush();

      expect(seen, ['patcher.before.gate', 'patcher.after.gate']);
    });

    test('a Bus.publish to patcher.<name>.<slot> reaches a gReceive', () {
      final p = newPatcher();
      p.name = 'synth1';
      final recv = p.createObject(Obj.gReceive, args: 'note');
      final store = p.createObject(Obj.gInt);
      p.connect(recv, outlet: 0, to: store, inlet: 0);

      Bus.publish('patcher.synth1.note', const BusInt(64));
      sys.update();
      expect(store.guiValue, '64');
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
