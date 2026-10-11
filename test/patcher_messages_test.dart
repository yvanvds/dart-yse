// Integration tests for Patcher.messages, the outbound send callback
// (issue #62): `.s` and unreceived `pass*` messages reach the host, the
// callback is installed per listener, and every native message block is
// freed — including those still in flight at dispose / System.close().
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md).
@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:yse/src/patcher.dart' show patcherMessagesFreed;
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

  Patcher newPatcher() {
    final p = Patcher();
    addTearDown(p.dispose);
    return p;
  }

  /// Lets the listener port deliver what is queued.
  Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 5));

  /// Polls [condition] until it holds or [timeout] passes.
  Future<void> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('condition not met within $timeout');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  test('PatcherMessage has value equality', () {
    expect(
      const PatcherMessage('a', BusFloat(1)),
      const PatcherMessage('a', BusFloat(1)),
    );
    expect(
      const PatcherMessage('a', BusFloat(1)),
      isNot(const PatcherMessage('b', BusFloat(1))),
    );
    expect(
      const PatcherMessage('a', BusBang()).hashCode,
      const PatcherMessage('a', BusBang()).hashCode,
    );
  });

  test('a .b poked into a .s out arrives as one bang', () async {
    final p = newPatcher();
    final button = p.createObject(Obj.gButton);
    final send = p.createObject(Obj.gSend, args: 'out');
    p.connect(button, outlet: 0, to: send, inlet: 0);

    final got = <PatcherMessage>[];
    final sub = p.messages.listen(got.add);
    addTearDown(sub.cancel);

    button.sendBang(0);
    await flush();
    expect(got, [const PatcherMessage('out', BusBang())]);
  });

  test('a .s carries int, float and list payloads', () async {
    final p = newPatcher();
    final send = p.createObject(Obj.gSend, args: 'val');

    final got = <PatcherMessage>[];
    final sub = p.messages.listen(got.add);
    addTearDown(sub.cancel);

    send.sendInt(0, 7);
    send.sendFloat(0, 0.25);
    send.sendList(0, '1 2 three');
    await flush();
    expect(got, [
      const PatcherMessage('val', BusInt(7)),
      const PatcherMessage('val', BusFloat(0.25)),
      const PatcherMessage('val', BusString('1 2 three')),
    ]);
  });

  test('pass* to a name nothing receives: true while listened', () async {
    final p = newPatcher();
    expect(p.passFloat(0.5, 'nobody'), isFalse, reason: 'no callback yet');

    final got = <PatcherMessage>[];
    final sub = p.messages.listen(got.add);
    expect(p.passFloat(0.5, 'nobody'), isTrue);
    expect(p.passString('hi there', 'nobody'), isTrue);
    expect(got, isEmpty, reason: 'delivery is asynchronous');
    await flush();
    expect(got, [
      const PatcherMessage('nobody', BusFloat(0.5)),
      const PatcherMessage('nobody', BusString('hi there')),
    ]);

    await sub.cancel();
    expect(
      p.passFloat(0.5, 'nobody'),
      isFalse,
      reason: 'the last cancel clears the callback',
    );
  });

  test('a message a .r receives does not reach the host', () async {
    final p = newPatcher();
    p.createObject(Obj.gReceive, args: 'here');
    final got = <PatcherMessage>[];
    final sub = p.messages.listen(got.add);
    addTearDown(sub.cancel);

    expect(p.passBang('here'), isTrue);
    await flush();
    expect(got, isEmpty);
  });

  test('a listener may call back into the patcher', () async {
    final p = newPatcher();
    final echoed = <PatcherMessage>[];
    final sub = p.messages.listen((m) {
      echoed.add(m);
      if (m.address == 'ping') p.passBang('pong');
    });
    addTearDown(sub.cancel);

    p.passBang('ping');
    await waitFor(() => echoed.length == 2);
    expect(echoed.map((m) => m.address), ['ping', 'pong']);
  });

  test('a timer-driven .metro -> .s tick delivers from the worker thread, '
      'and every block is freed', () async {
    final p = newPatcher();
    final metro = p.createObject(Obj.gMetro, args: '10');
    final send = p.createObject(Obj.gSend, args: 'tick');
    p.connect(metro, outlet: 0, to: send, inlet: 0);

    final before = patcherMessagesFreed;
    var ticks = 0;
    final sub = p.messages.listen((m) {
      expect(m, const PatcherMessage('tick', BusBang()));
      ticks++;
    });

    metro.sendInt(0, 1); // start
    // Keep the offline engine rendering while the timer runs.
    await waitFor(() {
      sys.update();
      sys.renderOffline(4);
      return ticks >= 5;
    });
    metro.sendInt(0, 0); // stop
    await sub.cancel();

    // After the drain every native block the engine handed over is freed,
    // delivered or dropped, and nothing is freed twice.
    await flush();
    final freed = patcherMessagesFreed - before;
    expect(freed, greaterThanOrEqualTo(ticks));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(patcherMessagesFreed - before, freed, reason: 'callback cleared');
  });

  test(
    'dispose frees messages still in flight and closes the stream',
    () async {
      final p = Patcher();
      final got = <PatcherMessage>[];
      final done = Completer<void>();
      p.messages.listen(got.add, onDone: done.complete);

      final before = patcherMessagesFreed;
      const n = 50;
      for (var i = 0; i < n; i++) {
        expect(p.passInt(i, 'nobody'), isTrue);
      }
      p.dispose(); // all n are still queued on the listener port

      await done.future;
      await waitFor(() => patcherMessagesFreed - before == n);
      expect(got, isEmpty, reason: 'nothing is delivered after dispose');
      expect(() => p.messages, throwsStateError);
    },
  );

  test('System.close() clears the callback and closes the stream', () async {
    final p = newPatcher();
    final done = Completer<void>();
    p.messages.listen((_) {}, onDone: done.complete);
    expect(p.passBang('nobody'), isTrue);

    sys.close();
    await done.future.timeout(const Duration(seconds: 3));
    sys.initOffline();

    expect(p.passBang('nobody'), isFalse, reason: 'callback cleared');
    // A fresh read gives a fresh, working stream.
    final got = <PatcherMessage>[];
    final sub = p.messages.listen(got.add);
    addTearDown(sub.cancel);
    p.passBang('nobody');
    await flush();
    expect(got, [const PatcherMessage('nobody', BusBang())]);
  });
}
