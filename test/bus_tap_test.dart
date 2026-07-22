// Tests for the host bus tap wrapper (issue #43).
//
// Two layers:
//
//   * `BusValue` — pure-Dart value types (tagged union + record frame). These
//     need no engine and run anywhere.
//   * `LiveCoding.bus` — engine-touching delivery, prefix filtering, and the
//     install/teardown lifecycle. These touch the real engine through
//     `libyse.dll` / `libyse.so`, so the library must be resolvable — set
//     `YSE_DLL_PATH` to the directory holding it (see README / CLAUDE.md):
//
//       Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//       Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//
// A Dart-side publish path exists: a patcher `.s` (gSend) object broadcasts its
// inlet value onto the global bus as "<patcherName>.<dataName>". Driving that
// inlet on the control thread publishes inline, so the tap fires and the frame
// is asserted with its reconstructed type. gSend carries its list inlet as a
// string, so it can produce BANG / INT / FLOAT / STRING frames but not a
// genuine float-LIST; the LIST kind's native decode is covered by the engine's
// own `test_c_api_bus` (CLAUDE.md: don't re-test engine-only behaviour), and
// the [BusList] value type itself is unit-tested below.
//
// Threading (CLAUDE.md Boundaries): everything runs on the one isolate that
// calls `System.initOffline()` — the same isolate the engine dispatches the tap
// callback on. The offline path keeps the suite headless.
@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

void main() {
  group('BusValue', () {
    test('leaves carry their payload and reconstruct value equality', () {
      expect(const BusInt(42).value, 42);
      expect(const BusFloat(1.5).value, 1.5);
      expect(const BusString('hi').value, 'hi');
      expect(const BusList([3, 4, 5]).values, [3, 4, 5]);

      expect(const BusInt(42), const BusInt(42));
      expect(const BusInt(42), isNot(const BusInt(7)));
      expect(const BusFloat(1.5), const BusFloat(1.5));
      expect(const BusString('hi'), const BusString('hi'));
      expect(const BusString('hi'), isNot(const BusString('ho')));
      expect(const BusBang(), const BusBang());
      expect(const BusList([3, 4, 5]), const BusList([3, 4, 5]));
      expect(const BusList([3, 4]), isNot(const BusList([3, 4, 5])));
      expect(const BusList([3, 4, 5]), isNot(const BusList([3, 9, 5])));
    });

    test('leaves hash consistently with equality', () {
      expect(const BusInt(42).hashCode, const BusInt(42).hashCode);
      expect(const BusBang().hashCode, const BusBang().hashCode);
      expect(
        const BusList([3, 4, 5]).hashCode,
        const BusList([3, 4, 5]).hashCode,
      );
      // A set collapses equal values.
      final ints = [const BusInt(1), const BusInt(1), const BusInt(2)];
      expect(ints.toSet(), hasLength(2));
    });

    test('toString is descriptive per kind', () {
      expect(const BusBang().toString(), 'BusBang()');
      expect(const BusInt(42).toString(), 'BusInt(42)');
      expect(const BusFloat(1.5).toString(), 'BusFloat(1.5)');
      expect(const BusString('hi').toString(), 'BusString(hi)');
      expect(const BusList([3, 4]).toString(), 'BusList([3.0, 4.0])');
    });

    test('a frame destructures into (address, value)', () {
      const BusFrame frame = (address: 'phi.ctl.play', value: BusInt(1));
      final (:address, :value) = frame;
      expect(address, 'phi.ctl.play');
      expect(value, const BusInt(1));
      // Named record fields are also reachable.
      expect(frame.address, 'phi.ctl.play');
      expect(frame.value, const BusInt(1));
    });

    test('is a sealed union — an exhaustive switch needs no default', () {
      String label(BusValue v) => switch (v) {
        BusBang() => 'bang',
        BusInt() => 'int',
        BusFloat() => 'float',
        BusString() => 'string',
        BusList() => 'list',
      };
      expect(label(const BusBang()), 'bang');
      expect(label(const BusList([1])), 'list');
    });
  });

  group('LiveCoding.bus (engine)', () {
    late System sys;

    setUpAll(() {
      sys = System.instance;
      sys.initOffline();
    });

    tearDownAll(() {
      sys.close();
    });

    // Pump the engine and the Dart event loop until [done] or the budget runs
    // out. We yield with `await` (not a blocking sleep) so the broadcast
    // stream's microtask delivery runs. A control-thread gSend publish is
    // delivered inline, so the budget is short.
    Future<void> pumpUntil(
      bool Function() done, {
      int maxFrames = 40,
      int frameMs = 5,
    }) async {
      for (var i = 0; i < maxFrames && !done(); i++) {
        sys.update();
        await Future<void>.delayed(Duration(milliseconds: frameMs));
      }
    }

    // A gSend publishing under "<patcher>.<dataName>". Returns the patcher (so
    // the caller can dispose it) and the send handle to drive.
    (Patcher, PHandle) makeSender(String dataName) {
      final patcher = Patcher();
      final send = patcher.createObject(Obj.gSend, args: dataName);
      return (patcher, send);
    }

    test('delivers a gSend int publish as a BusInt frame', () async {
      final (patcher, send) = makeSender('ping');
      final frames = <BusFrame>[];
      // Empty prefix matches every address.
      final sub = LiveCoding.bus('').listen(frames.add);
      await Future<void>.delayed(Duration.zero);

      send.sendInt(0, 42);
      await pumpUntil(() => frames.isNotEmpty);

      expect(
        frames,
        isNotEmpty,
        reason: 'expected a bus frame after gSend int',
      );
      final (:address, :value) = frames.first;
      expect(address, endsWith('.ping'));
      expect(value, const BusInt(42));

      await sub.cancel();
      patcher.dispose();
    });

    test('reconstructs float, string, and bang kinds from gSend', () async {
      final (patcher, send) = makeSender('multi');
      final frames = <BusFrame>[];
      final sub = LiveCoding.bus('').listen(frames.add);
      await Future<void>.delayed(Duration.zero);

      send.sendFloat(0, 1.5);
      await pumpUntil(() => frames.isNotEmpty);
      send.sendList(0, 'hello'); // gSend carries a list inlet as a string
      await pumpUntil(() => frames.length >= 2);
      send.sendBang(0);
      await pumpUntil(() => frames.length >= 3);

      final values = frames.map((f) => f.value).toList();
      expect(values, contains(const BusFloat(1.5)));
      expect(values, contains(const BusString('hello')));
      expect(values, contains(const BusBang()));
      // Every frame was published under this sender's dataName.
      expect(frames.every((f) => f.address.endsWith('.multi')), isTrue);

      await sub.cancel();
      patcher.dispose();
    });

    test(
      'prefix match is byte-wise: a non-matching tap sees nothing',
      () async {
        final (patcher, send) = makeSender('ping');
        // Default patcher names are "patcher_<N>", so this prefix matches; the
        // other never can.
        final matched = <BusFrame>[];
        final missed = <BusFrame>[];
        final subM = LiveCoding.bus('patcher_').listen(matched.add);
        final subX = LiveCoding.bus('phi.ctl.').listen(missed.add);
        await Future<void>.delayed(Duration.zero);

        send.sendInt(0, 7);
        await pumpUntil(() => matched.isNotEmpty);

        expect(matched, isNotEmpty);
        expect(matched.first.value, const BusInt(7));
        expect(
          missed,
          isEmpty,
          reason: 'phi.ctl. prefix must not match patcher_*',
        );

        await subM.cancel();
        await subX.cancel();
        patcher.dispose();
      },
    );

    test(
      'shares one bridge across listeners and reinstalls after teardown',
      () async {
        final stream = LiveCoding.bus('patcher_');
        expect(stream.isBroadcast, isTrue);

        final (patcher, send) = makeSender('life');

        // Two concurrent listeners share the single installed tap.
        final a = <BusFrame>[];
        final b = <BusFrame>[];
        final subA = stream.listen(a.add);
        final subB = stream.listen(b.add);
        await Future<void>.delayed(Duration.zero);

        send.sendInt(0, 1);
        await pumpUntil(() => a.isNotEmpty && b.isNotEmpty);
        expect(a.single.value, const BusInt(1));
        expect(b.single.value, const BusInt(1));

        // Cancelling the last listener tears the native tap down.
        await subA.cancel();
        await subB.cancel();

        // Re-subscribing reinstalls a working tap: delivery here proves
        // teardown left the façade reusable rather than closed/leaked.
        final c = <BusFrame>[];
        final subC = LiveCoding.bus('patcher_').listen(c.add);
        await Future<void>.delayed(Duration.zero);

        send.sendInt(0, 2);
        await pumpUntil(() => c.isNotEmpty);
        expect(c.single.value, const BusInt(2));

        await subC.cancel();
        patcher.dispose();
      },
    );
  });
}
