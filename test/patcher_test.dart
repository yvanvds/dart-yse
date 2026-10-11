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

import 'support/engine_pin.dart';
import 'support/sound_ready.dart';

void main() {
  setUpAll(noticeUnpinnedEngine);

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

  group('subpatchers (#61)', () {
    /// `[patcher: ~inlet 0 -> ~* 0.5 -> ~outlet 0]`, built inside [p].
    ({PHandle sub, PHandle inlet, PHandle gain, PHandle outlet}) halfGain(
      Patcher p,
    ) {
      final sub = p.createObject(Obj.patcher);
      final inlet = p.createObject(Obj.dInlet, args: '0');
      final gain = p.createObject(Obj.dMultiply, args: '0.5');
      final outlet = p.createObject(Obj.dOutlet, args: '0');
      for (final h in [inlet, gain, outlet]) {
        p.setContainer(h, sub);
      }
      p.connect(inlet, outlet: 0, to: gain, inlet: 0);
      p.connect(gain, outlet: 0, to: outlet, inlet: 0);
      return (sub: sub, inlet: inlet, gain: gain, outlet: outlet);
    }

    /// Master post-fader peak over a few update + render cycles.
    double renderPeak() {
      var peak = 0.0;
      for (var i = 0; i < 20; i++) {
        sys.update();
        sys.renderOffline(4);
        final level = Channel.master.peakLinearPost();
        if (level > peak) peak = level;
      }
      return peak;
    }

    test('~sine -> [~inlet -> ~* 0.5 -> ~outlet] -> ~dac is audible', () {
      final p = newPatcher();
      final sine = p.createObject(Obj.dSine, args: '440');
      final sub = halfGain(p).sub;
      final dac = p.createObject(Obj.dDac);
      // Wired by the subpatcher's pin numbers only.
      p.connect(sine, outlet: 0, to: sub, inlet: 0);
      p.connect(sub, outlet: 0, to: dac, inlet: 0);
      p.connect(sub, outlet: 0, to: dac, inlet: 1);

      final sound = Sound.fromPatcher(p)
        ..position = const Pos(0, 0, 1)
        ..play();
      addTearDown(sound.dispose);
      pumpUntilReady(sys, sound);

      expect(renderPeak(), greaterThan(0.01), reason: 'signal crosses');

      // Disconnecting by pin number resolves to the same boundary edge.
      p.disconnect(sine, outlet: 0, to: sub, inlet: 0);
      renderPeak(); // let the release settle
      expect(renderPeak(), lessThan(1e-4), reason: 'silent once cut');
    });

    test('connect to a subpatcher pin lands on its boundary object', () {
      final p = newPatcher();
      final parts = halfGain(p);
      final src = p.createObject(Obj.dSine);
      final dst = p.createObject(Obj.dDac);
      p.connect(src, outlet: 0, to: parts.sub, inlet: 0);
      p.connect(parts.sub, outlet: 0, to: dst, inlet: 0);

      expect(src.connectionTargetId(0, 0), parts.inlet.id);
      expect(parts.outlet.connectionTargetId(0, 0), dst.id);
    });

    test('message and signal boundaries share one index space', () {
      final p = newPatcher();
      final sub = p.createObject(Obj.patcher);
      p.setContainer(p.createObject(Obj.gInlet, args: '0'), sub);
      p.setContainer(p.createObject(Obj.dInlet, args: '1'), sub);
      p.setContainer(p.createObject(Obj.gOutlet, args: '2'), sub);

      expect(sub.subpatcherInlets, 2);
      expect(sub.subpatcherOutlets, 3, reason: 'one past the highest index');
      expect(sub.inputs, 0, reason: 'a patcher object owns no pins');
      expect(sub.outputs, 0);
      expect(p.createObject(Obj.gInt).subpatcherInlets, 0);
    });

    test('container reads back, nests, and returns to the top level', () {
      final p = newPatcher();
      final outer = p.createObject(Obj.patcher);
      final inner = p.createObject(Obj.patcher);
      final obj = p.createObject(Obj.gInt);
      expect(obj.container, isNull);

      p.setContainer(inner, outer);
      p.setContainer(obj, inner);
      expect(obj.container, inner);
      expect(inner.container, outer);
      expect(outer.container, isNull);

      p.setContainer(obj, null);
      expect(obj.container, isNull);
    });

    test('a cycle is refused and changes nothing', () {
      final p = newPatcher();
      final a = p.createObject(Obj.patcher);
      final b = p.createObject(Obj.patcher);
      p.setContainer(a, b);
      expect(() => p.setContainer(b, a), throwsA(isA<YseException>()));
      expect(() => p.setContainer(a, a), throwsA(isA<YseException>()));
      expect(a.container, b);
      expect(b.container, isNull);
    });

    test('a non-patcher container is refused', () {
      final p = newPatcher();
      final notASub = p.createObject(Obj.gInt);
      final obj = p.createObject(Obj.gInt);
      expect(() => p.setContainer(obj, notASub), throwsA(isA<YseException>()));
      expect(obj.container, isNull);
    });

    test('a handle from another patcher is an ArgumentError', () {
      final p = newPatcher();
      final other = newPatcher();
      final sub = p.createObject(Obj.patcher);
      final foreign = other.createObject(Obj.gInt);
      final foreignSub = other.createObject(Obj.patcher);
      expect(() => p.setContainer(foreign, sub), throwsArgumentError);
      expect(
        () => p.setContainer(p.createObject(Obj.gInt), foreignSub),
        throwsArgumentError,
      );
      expect(foreign.container, isNull);
    });

    test('deleting a subpatcher deletes its contents transitively', () {
      final p = newPatcher();
      final outer = halfGain(p).sub;
      final inner = halfGain(p).sub;
      p.setContainer(inner, outer);
      final kept = p.createObject(Obj.gInt);
      expect(p.objects, 9);

      p.deleteObject(outer);
      expect(p.objects, 1);
      expect(p.getHandleAt(0), kept);
    });

    test('dumpJson -> clear -> parseJson round-trips containment', () {
      final p = newPatcher();
      final outer = p.createObject(Obj.patcher);
      final parts = halfGain(p);
      p.setContainer(parts.sub, outer);
      final json = p.dumpJson();

      p.clear();
      expect(p.objects, 0);
      p.parseJson(json);
      expect(p.dumpJson(), json);

      // Find the reloaded objects by type and check the nesting.
      final byType = <String, PHandle>{
        for (var i = 0; i < p.objects; i++)
          p.getHandleAt(i).type: p.getHandleAt(i),
      };
      final subs = [
        for (var i = 0; i < p.objects; i++)
          if (p.getHandleAt(i).type == Obj.patcher) p.getHandleAt(i),
      ];
      expect(subs, hasLength(2));
      final reInner = byType[Obj.dInlet]!.container!;
      expect(byType[Obj.dMultiply]!.container, reInner);
      expect(byType[Obj.dOutlet]!.container, reInner);
      expect(reInner.container, isNotNull);
      expect(reInner.container!.container, isNull);
      expect(reInner.subpatcherInlets, 1);
      expect(reInner.subpatcherOutlets, 1);
    });
  });

  group('GUI value protocol (#63)', () {
    test('.multislider: cell count, per-cell write and read', () {
      final p = newPatcher();
      final ms = p.createObject(Obj.gMultislider, args: '4 0 1');
      expect(ms.guiValueIsSettable, isTrue);
      expect(ms.guiValueCount, 4);

      // Cells are engine-formatted strings ('0.' for zero), so compare them
      // as numbers.
      double cell(int i) => double.parse(ms.guiValueAt(i));

      ms.setGuiValueAt(2, '0.5');
      expect(cell(2), 0.5);
      expect(cell(0), 0);
      expect(ms.guiValue.split(' ').map(double.parse), [0, 0, 0.5, 0]);

      // The raw message form the convenience wraps.
      ms.sendList(0, 'set 1 0.25');
      expect(cell(1), 0.25);

      // Past the end reads empty; a negative index is a caller error.
      expect(ms.guiValueAt(4), '');
      expect(() => ms.guiValueAt(-1), throwsRangeError);
      expect(() => ms.setGuiValueAt(4, '1'), throwsRangeError);
    });

    test('.multislider: restoring the whole state resizes the bank', () {
      final p = newPatcher();
      final ms = p.createObject(Obj.gMultislider, args: '4 0 1');
      ms.restoreGuiValue('0.1 0.2 0.3 0.4 0.5 0.6');
      expect(ms.guiValueCount, 6);
      expect(double.parse(ms.guiValueAt(5)), closeTo(0.6, 1e-6));
    });

    test('.slider round trip: read, change, restore', () {
      final p = newPatcher();
      final slider = p.createObject(Obj.gSlider);
      expect(slider.guiValueIsSettable, isTrue);
      expect(slider.guiValueCount, 1);

      slider.sendFloat(0, 0.75);
      final saved = slider.guiValue;
      expect(double.parse(saved), 0.75);
      expect(slider.guiValueAt(0), saved, reason: 'cell 0 is the scalar');

      slider.sendFloat(0, 0.2);
      expect(slider.guiValue, isNot(saved));

      slider.restoreGuiValue(saved);
      expect(slider.guiValue, saved);

      slider.setGuiValueAt(0, '0.4');
      expect(double.parse(slider.guiValue), closeTo(0.4, 1e-6));
    });

    test('.textedit takes a cell write as the whole state', () {
      final p = newPatcher();
      final text = p.createObject(Obj.gTextedit);
      expect(text.guiValueIsSettable, isTrue);
      text.setGuiValueAt(0, 'set 0 hello');
      expect(text.guiValue, 'set 0 hello');
    });

    test('.b is not settable and the conveniences refuse it', () {
      final p = newPatcher();
      final b = p.createObject(Obj.gButton);
      expect(b.guiValueIsSettable, isFalse);
      expect(() => b.restoreGuiValue('on'), throwsStateError);
      expect(() => b.setGuiValueAt(0, 'on'), throwsStateError);
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
