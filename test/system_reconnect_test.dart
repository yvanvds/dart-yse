// Tests for the auto-reconnect watchdog and its outcome reporting (issue #54,
// libYSE #1027): `System.setAutoReconnect`, `reconnectState`,
// `reconnectCount`, `activeDevice` / `activeHost`.
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test test/system_reconnect_test.dart
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test test/system_reconnect_test.dart
//
// Everything stays on the offline path: CI has no audio device. An offline
// session has no device for the watchdog to reopen, so every attempt there
// fails without opening anything — which is exactly what exercises the
// state machine (reconnecting, the attempt limit, re-arming) headlessly.
//
// Not covered: RS_RESTORED / RS_FELL_BACK_TO_DEFAULT and which device a
// reopen lands on. Both need a real device that stops and comes back.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yse/yse.dart';

void main() {
  // ── Pure-Dart unit coverage (no engine required) ───────────────────────────

  group('ReconnectState (unit)', () {
    test('every value carries a distinct native code and round-trips', () {
      final natives = ReconnectState.values.map((s) => s.native).toSet();
      expect(natives.length, ReconnectState.values.length);
      for (final s in ReconnectState.values) {
        expect(ReconnectState.fromNative(s.native), s);
      }
    });

    test('maps to the YSE_RS_* C values', () {
      expect(ReconnectState.none.native.value, 0);
      expect(ReconnectState.reconnecting.native.value, 1);
      expect(ReconnectState.restored.native.value, 2);
      expect(ReconnectState.fellBackToDefault.native.value, 3);
      expect(ReconnectState.failed.native.value, 4);
    });
  });

  group('on an offline session', () {
    final sys = System.instance;

    setUp(() {
      sys.initOffline();
      addTearDown(() {
        sys.setAutoReconnect(on: false);
        sys.close();
      });
    });

    test('starts with no attempt and no active device', () {
      expect(sys.reconnectState, ReconnectState.none);
      expect(sys.reconnectCount, 0);
      expect(sys.activeDevice, isEmpty);
      expect(sys.activeHost, isEmpty);
    });

    test('the watchdog stays idle while auto-reconnect is off', () {
      for (var i = 0; i < 5; i++) {
        sys.update();
      }
      expect(sys.reconnectState, ReconnectState.none);
      expect(sys.reconnectCount, 0);
    });

    test('a failed attempt reads reconnecting and opens nothing', () {
      sys.setAutoReconnect(on: true, delayMs: 0);
      sys.update();
      expect(sys.reconnectCount, greaterThan(0));
      expect(sys.reconnectState, ReconnectState.reconnecting);
      // An offline session never gets a device from the watchdog, not even
      // with the fallback to the default device.
      expect(sys.activeSampleRate, 0);
      expect(sys.activeDevice, isEmpty);
    });

    test('fallbackToDefault does not graft a device onto an offline '
        'session', () {
      sys.setAutoReconnect(on: true, delayMs: 0, fallbackToDefault: true);
      for (var i = 0; i < 3; i++) {
        sys.update();
      }
      expect(sys.reconnectState, ReconnectState.reconnecting);
      expect(sys.activeSampleRate, 0);
      expect(sys.activeDevice, isEmpty);
      sys.renderOffline(1);
    });

    test('the delay is honoured in milliseconds', () {
      sys.setAutoReconnect(on: true, delayMs: 60000);
      for (var i = 0; i < 10; i++) {
        sys.update();
      }
      expect(sys.reconnectCount, 0);
      expect(sys.reconnectState, ReconnectState.none);
    });

    test('maxAttempts stops the watchdog with failed', () {
      sys.setAutoReconnect(on: true, delayMs: 0, maxAttempts: 2);
      for (var i = 0; i < 10; i++) {
        sys.update();
      }
      expect(sys.reconnectState, ReconnectState.failed);
      expect(sys.reconnectCount, 2);
    });

    test('setAutoReconnect resets the state and re-arms a watchdog that '
        'gave up', () {
      sys.setAutoReconnect(on: true, delayMs: 0, maxAttempts: 1);
      for (var i = 0; i < 5; i++) {
        sys.update();
      }
      expect(sys.reconnectState, ReconnectState.failed);
      expect(sys.reconnectCount, 1);

      sys.setAutoReconnect(on: true, delayMs: 0, maxAttempts: 1);
      expect(sys.reconnectState, ReconnectState.none);
      // The count is per session, not per configuration.
      expect(sys.reconnectCount, 1);
      for (var i = 0; i < 5; i++) {
        sys.update();
      }
      expect(sys.reconnectState, ReconnectState.failed);
      expect(sys.reconnectCount, 2);
    });

    test('a new session resets the state and the count', () {
      sys.setAutoReconnect(on: true, delayMs: 0, maxAttempts: 1);
      sys.update();
      expect(sys.reconnectState, ReconnectState.failed);
      sys.close();
      sys.initOffline();
      expect(sys.reconnectState, ReconnectState.none);
      expect(sys.reconnectCount, 0);
    });
  });
}
