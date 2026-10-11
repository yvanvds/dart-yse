// Integration tests for the sound-occlusion callback (issue #58):
// `System.occlusion` drives the gain duck of every sound with
// `Sound.occlusion` enabled.
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
// Everything stays on the offline path — CI has no audio device, and
// `init()` throws without one. The callback is process-global; every test
// closes its session, and close() removes the callback.
@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

void main() {
  final sys = System.instance;

  /// Bring up an offline session at a known rate and close it when the test
  /// ends.
  void offlineSession() {
    sys.requestedSampleRate = 48000;
    sys.initOffline();
    addTearDown(() {
      sys.close();
      sys.requestedSampleRate = 0;
    });
  }

  /// A looping, audible DC sound at [at] with occlusion enabled.
  Sound occludedSound(Pos at) {
    final buffer = DspBuffer.plain(length: 1024)..fill(0.5);
    final sound = Sound.fromBuffer(buffer, loop: true);
    addTearDown(() {
      sound.dispose();
      buffer.dispose();
    });
    sound
      ..position = at
      ..occlusion = true
      ..play();
    return sound;
  }

  /// Master post-fader peak after a few update + render cycles.
  double renderPeak() {
    for (var i = 0; i < 20; i++) {
      sys.update();
      sys.renderOffline(1);
    }
    return Channel.master.peakLinearPost();
  }

  test('the callback runs during update with the sound and listener '
      'positions', () {
    offlineSession();
    Listener.instance.position = const Pos(0, 0, 0);
    final sound = occludedSound(const Pos(1, 2, 3));
    expect(sound.occlusion, isTrue);

    final calls = <(Pos, Pos)>[];
    sys.occlusion = (src, lis) {
      calls.add((src, lis));
      return 1.0;
    };
    expect(sys.occlusion, isNotNull);

    sys.update();
    expect(calls, isNotEmpty);
    expect(calls.last.$1, const Pos(1, 2, 3));
    expect(calls.last.$2, const Pos(0, 0, 0));
  });

  test('null stops invocations', () {
    offlineSession();
    occludedSound(const Pos(1, 0, 0));

    var calls = 0;
    sys.occlusion = (_, _) {
      calls++;
      return 0.0;
    };
    sys.update();
    expect(calls, greaterThan(0));

    sys.occlusion = null;
    expect(sys.occlusion, isNull);
    final before = calls;
    sys.update();
    sys.update();
    expect(calls, before);
  });

  test('full occlusion silences the sound, none leaves it audible', () {
    offlineSession();
    occludedSound(const Pos(0, 0, 1));

    sys.occlusion = (_, _) => 0.0;
    final clear = renderPeak();
    expect(clear, greaterThan(0.01));

    sys.occlusion = (_, _) => 1.0;
    final blocked = renderPeak();
    expect(blocked, lessThan(clear * 0.01));

    // Removing the callback keeps the last value: still silent.
    sys.occlusion = null;
    expect(renderPeak(), lessThan(clear * 0.01));
  });

  test('close removes the callback', () {
    offlineSession();
    sys.occlusion = (_, _) => 0.5;
    sys.close();
    expect(sys.occlusion, isNull);
    sys.initOffline();
  });

  test('an exception in the callback reaches the installing zone and counts '
      'as unoccluded', () {
    offlineSession();
    occludedSound(const Pos(0, 0, 1));

    final errors = <Object>[];
    runZonedGuarded(() {
      sys.occlusion = (_, _) => throw StateError('raycast failed');
    }, (e, _) => errors.add(e));

    final peak = renderPeak();
    expect(errors, isNotEmpty);
    expect(errors.first, isA<StateError>());
    expect(peak, greaterThan(0.01));
  });

  test('the callback may replace itself from inside', () async {
    offlineSession();
    occludedSound(const Pos(0, 0, 1));

    var second = 0;
    sys.occlusion = (_, _) {
      sys.occlusion = (_, _) {
        second++;
        return 0.0;
      };
      return 0.0;
    };
    sys.update();
    // The replaced callable closes in a microtask; let it run.
    await Future<void>.delayed(Duration.zero);
    sys.update();
    expect(second, greaterThan(0));
  });
}
