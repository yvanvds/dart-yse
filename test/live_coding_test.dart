// Integration smoke tests for the LiveCoding wrapper (issue #16).
//
// These touch the real engine through `libyse.dll` / `libyse.so`, so they
// require the library to be resolvable — set `YSE_DLL_PATH` to the directory
// holding it (see README / CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "D:\yse-soundengine\build\bin"; dart test
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test
//
// The suite passes against either library configuration: build-specific
// expectations are gated on [LiveCoding.enabled] so the OFF-only sentinel and
// the ON-only traceback each `skip` on the other build.
//
// Threading (CLAUDE.md Boundaries): everything runs on the one isolate that
// calls `System.initOffline()` — the same isolate the engine dispatches the
// error callback on. We use the offline path so the suite is headless and does
// not depend on an openable audio device.
@TestOn('vm')
library;

import 'dart:async';

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

  // Pump the engine and the Dart event loop until [done] is satisfied, or the
  // budget runs out. We yield with `await` (not a blocking sleep) between
  // frames so the broadcast stream's microtask delivery runs. The script
  // worker is asynchronous and booting CPython on the first eval takes a
  // noticeable moment, so we poll rather than assume a fixed frame count
  // suffices (mirrors the engine's own pumpUntil in test_c_api_python.cpp).
  Future<void> pumpUntil(
    bool Function() done, {
    int maxFrames = 300,
    int frameMs = 10,
  }) async {
    for (var i = 0; i < maxFrames && !done(); i++) {
      sys.update();
      await Future<void>.delayed(Duration(milliseconds: frameMs));
    }
  }

  group('enabled', () {
    test('is a stable boolean for the build under test', () {
      final first = LiveCoding.enabled;
      // A compile-time feature query must not vary call-to-call.
      expect(LiveCoding.enabled, equals(first));
      expect(first, isA<bool>());
    });
  });

  group('OFF build', () {
    test(
      'run() emits the "compiled without" sentinel through errors',
      () async {
        final errors = <String>[];
        final sub = LiveCoding.errors.listen(errors.add);
        // Let the broadcast listener attach before submitting.
        await Future<void>.delayed(Duration.zero);

        // On an OFF build the engine invokes the error callback synchronously
        // inside run(); pumping just flushes the broadcast delivery.
        LiveCoding.run('anything');
        await pumpUntil(() => errors.isNotEmpty);

        expect(errors, contains('YSE compiled without YSE_ENABLE_PYTHON'));

        await sub.cancel();
      },
      skip: LiveCoding.enabled
          ? 'ON build — the OFF-only sentinel does not apply'
          : false,
    );
  });

  group('ON build', () {
    test(
      'a broken script yields a traceback through errors after update()',
      () async {
        final errors = <String>[];
        final sub = LiveCoding.errors.listen(errors.add);
        await Future<void>.delayed(Duration.zero);

        // Division by zero: the interpreter raises, and the formatted
        // traceback is drained on the update thread.
        LiveCoding.run('1 / 0');
        await pumpUntil(() => errors.isNotEmpty);

        expect(
          errors,
          isNotEmpty,
          reason: 'expected a Python traceback after pumping update()',
        );
        expect(
          errors.join('\n'),
          anyOf(contains('ZeroDivisionError'), contains('Traceback')),
        );

        await sub.cancel();
      },
      skip: LiveCoding.enabled
          ? false
          : 'OFF build — no interpreter to produce a traceback',
    );
  });

  group('stream lifecycle', () {
    // The bridge installs on first access and tears down on last cancel. The
    // installed controller is a *broadcast* controller — `.stream` returns a
    // fresh wrapper on every access, so identity can't track it. We instead
    // assert the observable contract: one bridge fans a run() out to all live
    // listeners, and after a full teardown a fresh subscription still works
    // (which only holds if teardown closed-and-dropped the controller and the
    // next access reinstalled a clean one — a leaked/closed controller would
    // deliver nothing). Delivery is gated on an OFF build, where run() yields
    // the sentinel; the structural checks run on either build.
    test(
      'shares one bridge across listeners and reinstalls after teardown',
      () async {
        final stream = LiveCoding.errors;
        expect(stream.isBroadcast, isTrue);

        // Two concurrent listeners share the single installed bridge.
        final a = <String>[];
        final b = <String>[];
        final subA = stream.listen(a.add);
        final subB = stream.listen(b.add);
        await Future<void>.delayed(Duration.zero);
        LiveCoding.run('anything');
        // The OFF sentinel lands within a frame or two; on an ON build
        // 'anything' is a clean script that delivers nothing, so keep the
        // budget short rather than waiting out the full poll.
        await pumpUntil(() => a.isNotEmpty && b.isNotEmpty, maxFrames: 20);
        if (!LiveCoding.enabled) {
          expect(a, contains('YSE compiled without YSE_ENABLE_PYTHON'));
          expect(b, contains('YSE compiled without YSE_ENABLE_PYTHON'));
        }

        // Cancelling the last listener tears the bridge down.
        await subA.cancel();
        await subB.cancel();

        // Re-subscribing reinstalls a working bridge: a clean delivery here
        // proves teardown left the façade reusable rather than closed/leaked.
        final c = <String>[];
        final subC = LiveCoding.errors.listen(c.add);
        await Future<void>.delayed(Duration.zero);
        LiveCoding.run('anything');
        await pumpUntil(() => c.isNotEmpty, maxFrames: 20);
        if (!LiveCoding.enabled) {
          expect(
            c,
            contains('YSE compiled without YSE_ENABLE_PYTHON'),
            reason: 'the reinstalled bridge should deliver the OFF sentinel',
          );
        }
        await subC.cancel();
      },
    );
  });
}
