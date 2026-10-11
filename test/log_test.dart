// Integration tests for Log.messages (issue #76): every log line the engine
// hands to the stream bridge is freed exactly once, including lines still
// queued on the listener port when the last subscription is cancelled.
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test test/log_test.dart
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test test/log_test.dart
@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:yse/src/log.dart' show logMessagesFreed;
import 'package:yse/yse.dart';

import 'support/engine_pin.dart';

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

  test(
    'messages delivers lines sent while subscribed and frees each',
    () async {
      final log = Log.instance;
      final got = <String>[];
      final before = logMessagesFreed;
      final sub = log.messages.listen(got.add);

      for (var i = 0; i < 5; i++) {
        log.sendMessage('log_test delivered $i');
      }
      await waitFor(
        () => got.where((m) => m.contains('log_test delivered')).length == 5,
      );
      await sub.cancel();

      await waitFor(() => logMessagesFreed - before >= 5);
      for (var i = 0; i < 5; i++) {
        expect(got, contains(contains('log_test delivered $i')));
      }
    },
  );

  test('cancelling the last listener frees lines still in flight', () async {
    final log = Log.instance;
    final got = <String>[];
    final sub = log.messages.listen(got.add);

    final before = logMessagesFreed;
    const n = 50;
    for (var i = 0; i < n; i++) {
      log.sendMessage('log_test in flight $i');
    }
    // All n calls are still queued on the listener port: the bridge has not
    // had a turn of the event loop yet. Cancel without awaiting first.
    final cancelled = sub.cancel();
    expect(logMessagesFreed - before, 0, reason: 'nothing handled yet');
    await cancelled;

    // Closing the listener outright would drop the queued calls and leak
    // their strings; the drain marker makes the bridge free every one.
    await waitFor(() => logMessagesFreed - before >= n);
    expect(
      got.where((m) => m.contains('log_test in flight')),
      isEmpty,
      reason: 'nothing is delivered after the last listener cancels',
    );
  });

  test('a new subscription works while the previous bridge drains', () async {
    final log = Log.instance;

    final first = log.messages.listen((_) {});
    for (var i = 0; i < 10; i++) {
      log.sendMessage('log_test old bridge $i');
    }
    unawaited(first.cancel());

    final got = <String>[];
    final second = log.messages.listen(got.add);
    addTearDown(second.cancel);
    log.sendMessage('log_test new bridge');

    await waitFor(() => got.any((m) => m.contains('log_test new bridge')));
    expect(got.where((m) => m.contains('log_test old bridge')), isEmpty);
  });
}
