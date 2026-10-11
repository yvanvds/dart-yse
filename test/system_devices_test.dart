// Integration tests for `System.refreshDevices` (issue #51, libYSE #1026):
// enumerating the audio devices without opening a stream.
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test test/system_devices_test.dart
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test test/system_devices_test.dart
//
// Everything stays on the offline path and no stream is ever opened: CI has
// no audio device. A headless host may legitimately enumerate zero devices,
// or fail to start the backend at all, so every assertion here holds both on
// a dev box with hardware and on headless CI. What is checked is that the
// call never opens a stream or disturbs the session, and that the list it
// reports is self-consistent and stable.
//
// Not covered: hot-plug pickup (needs a device physically plugged in or
// removed between two refreshes), and openDevice after a refresh (opens a
// stream, which CI cannot do).
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yse/yse.dart';

import 'support/engine_pin.dart';

void main() {
  setUpAll(noticeUnpinnedEngine);

  final sys = System.instance;

  /// Snapshot of the list as (name, host, id) triples.
  List<(String, String, int)> snapshot() => [
    for (final d in sys.devices) (d.name, d.hostName, d.id),
  ];

  /// What a list must look like after a refresh that reported [ok].
  void expectConsistentList(bool ok) {
    final devices = sys.devices;
    if (!ok) {
      // The backend could not start: the engine reports an empty list.
      expect(devices, isEmpty);
      return;
    }
    for (final d in devices) {
      expect(d.id, greaterThanOrEqualTo(0), reason: 'device ${d.name}');
      expect(d.name, isNotEmpty);
      expect(d.hostName, isNotEmpty);
    }
    if (devices.isNotEmpty && sys.defaultDevice.isNotEmpty) {
      // The default device named by the engine is one of the listed ones.
      expect(devices.map((d) => d.name), contains(sys.defaultDevice));
    }
  }

  // Must stay the first test: it needs a process where nothing has started
  // the audio backend yet. No other suite calls refreshDevices() or init()
  // (CI has no device), so that holds under a full `dart test` run too.
  test('a cold offline session lists nothing until refreshDevices', () {
    sys.initOffline();
    addTearDown(sys.close);
    expect(sys.devices, isEmpty);
    expect(sys.defaultDevice, isEmpty);

    final ok = sys.refreshDevices();
    expectConsistentList(ok);
    expect(sys.activeSampleRate, 0);
  });

  test('works with no session at all', () {
    final ok = sys.refreshDevices();
    expectConsistentList(ok);
    expect(sys.activeSampleRate, 0);
  });

  group('on an offline session', () {
    setUp(() {
      sys.initOffline();
      addTearDown(sys.close);
    });

    test('lists devices without opening a stream', () {
      final rate = sys.sessionSampleRate;
      final ok = sys.refreshDevices();
      // ignore: avoid_print
      print(
        'refreshDevices -> $ok, ${sys.devices.length} devices, '
        'default "${sys.defaultDevice}" @ "${sys.defaultHost}"',
      );
      expectConsistentList(ok);

      // Still an offline session: no device opened, rate unchanged, and
      // offline rendering still works.
      expect(sys.activeSampleRate, 0);
      expect(sys.activeBufferSize, 0);
      expect(sys.sessionSampleRate, rate);
      sys.update();
      sys.renderOffline(2);
    });

    test('a second refresh reports the same list', () {
      final first = sys.refreshDevices();
      final before = snapshot();
      final second = sys.refreshDevices();
      expect(second, first);
      // Nothing was plugged in between, so the restarted backend enumerates
      // the same devices in the same order.
      expect(snapshot(), before);
      expect(sys.activeSampleRate, 0);
    });

    test('the list survives close and the next offline session', () {
      final ok = sys.refreshDevices();
      final before = snapshot();
      sys.close();
      sys.initOffline();
      // initOffline enumerates nothing itself; the refreshed list is kept.
      expect(snapshot(), before);
      expectConsistentList(ok);
    });
  });
}
