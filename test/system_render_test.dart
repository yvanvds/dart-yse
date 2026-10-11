// Integration tests for the libYSE 3 render scheduler, engine block size and
// random generator controls on System (issue #57).
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
// `init()` throws without one. The render-thread setting survives close and
// is process-global, as is the random seed; suites share one process, so
// tearDownAll puts both back on their defaults (auto workers, a fixed seed).
@TestOn('vm')
library;

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

  tearDownAll(() {
    sys.renderThreads = -1;
    System.randomSeed(0);
  });

  group('render threads', () {
    test('0 renders on the calling thread alone', () {
      sys.renderThreads = 0;
      expect(sys.renderThreads, 0);
      offlineSession();
      expect(sys.activeRenderThreads, 0);
      sys.renderOffline(4);
    });

    test('n starts exactly n workers', () {
      sys.renderThreads = 2;
      expect(sys.renderThreads, 2);
      offlineSession();
      expect(sys.activeRenderThreads, 2);
      sys.renderOffline(4);
    });

    test('the setting survives close', () {
      sys.renderThreads = 1;
      sys.initOffline();
      sys.close();
      expect(sys.renderThreads, 1);
      offlineSession();
      expect(sys.activeRenderThreads, 1);
    });

    test('a negative count reads back as auto', () {
      sys.renderThreads = -5;
      expect(sys.renderThreads, -1);
      offlineSession();
      expect(sys.activeRenderThreads, inInclusiveRange(0, 8));
    });
  });

  test('blockSize is the 128-frame engine block', () {
    expect(System.blockSize, 128);
  });

  group('random seed', () {
    /// Draw [count] values from a `.random` object into a `.i` number box
    /// in a fresh offline session seeded with [seed].
    List<String> draw(int seed, {int count = 16}) {
      System.randomSeed(seed);
      sys.requestedSampleRate = 48000;
      sys.initOffline();
      try {
        final p = Patcher(mainOutputs: 2);
        try {
          final rnd = p.createObject(Obj.gRandom, args: '1000000');
          final box = p.createObject(Obj.gInt);
          p.connect(rnd, outlet: 0, to: box, inlet: 0);
          final out = <String>[];
          for (var i = 0; i < count; i++) {
            rnd.sendBang(0);
            sys.renderOffline(1);
            out.add(box.guiValue);
          }
          return out;
        } finally {
          p.dispose();
        }
      } finally {
        sys.close();
        sys.requestedSampleRate = 0;
      }
    }

    test('the same seed replays the same sequence across sessions', () {
      final a = draw(1234);
      final b = draw(1234);
      expect(a.toSet().length, greaterThan(1));
      expect(b, a);
    });

    test('a different seed gives a different sequence', () {
      expect(draw(99), isNot(draw(1234)));
    });

    test('a seed outside 32 bits is rejected', () {
      expect(() => System.randomSeed(-1), throwsArgumentError);
      expect(() => System.randomSeed(0x100000000), throwsArgumentError);
    });
  });
}
