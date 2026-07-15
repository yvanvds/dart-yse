// Integration smoke tests for the channel routing wrappers (issue #24):
// aux sends, return buses and channel insert DSP, layered onto the existing
// Channel wrapper.
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
// Threading (CLAUDE.md Boundaries): everything runs on the one isolate that
// calls `System.initOffline()`. The offline path is headless — it drives the
// engine via `renderOffline()` rather than an audio device.
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

  group('Return buses', () {
    test('createReturn produces a return; an ordinary channel is not', () {
      final ret = Channel.createReturn('reverb-return');
      addTearDown(ret.dispose);
      final ch = Channel.create('dry', parent: Channel.master);
      addTearDown(ch.dispose);

      expect(ret.isReturn, isTrue);
      expect(ret.isValid, isTrue);
      expect(ch.isReturn, isFalse);
      // A return keeps the ordinary channel surface (volume, metering).
      ret.volume = 0.5;
      expect(ret.volume, closeTo(0.5, 1e-6));
    });
  });

  group('Aux sends', () {
    test('wire, read back, retarget and clear a send slot', () {
      final ret = Channel.createReturn('delay-return');
      addTearDown(ret.dispose);
      final ch = Channel.createWithSends(
        'source',
        parent: Channel.master,
        sendSlots: 6,
      );
      addTearDown(ch.dispose);

      // Unwired slot reads back as silence.
      expect(ch.getSendLevel(0), 0.0);

      // Wire slot 0 to the return at a set level.
      ch.send(0, ret, level: 0.5);
      expect(ch.getSendLevel(0), closeTo(0.5, 1e-6));

      // Retarget the level (ramped/click-free setter).
      ch.setSendLevel(0, 0.25);
      expect(ch.getSendLevel(0), closeTo(0.25, 1e-6));

      // Render with the send live — must not throw.
      sys.renderOffline(128);

      // Clear the slot: fully disconnected, level back to 0.
      ch.clearSend(0);
      expect(ch.getSendLevel(0), 0.0);
    });

    test('a return may send onward to another return', () {
      final delay = Channel.createReturn('delay', sendSlots: 2);
      addTearDown(delay.dispose);
      final reverb = Channel.createReturn('reverb');
      addTearDown(reverb.dispose);

      // Acyclic delay → reverb edge is accepted.
      delay.send(0, reverb, level: 0.8);
      expect(delay.getSendLevel(0), closeTo(0.8, 1e-6));
      sys.renderOffline(64);
    });

    test('sending to a non-return channel is rejected, not fatal', () {
      final ch = Channel.createWithSends(
        'src',
        parent: Channel.master,
        sendSlots: 2,
      );
      addTearDown(ch.dispose);
      final notAReturn = Channel.create('plain', parent: Channel.master);
      addTearDown(notAReturn.dispose);

      // The engine rejects the illegal wiring on the calling thread and logs
      // it; the slot stays disconnected rather than crashing.
      ch.send(0, notAReturn, level: 0.5);
      expect(ch.getSendLevel(0), 0.0);
      sys.renderOffline(64);
    });
  });

  group('Channel insert DSP', () {
    test('attach, read back the same wrapper, and detach an insert', () {
      final ch = Channel.create('insert-ch', parent: Channel.master);
      addTearDown(ch.dispose);
      final fx = DspObject.lowpass();
      addTearDown(fx.dispose);

      // No insert to start.
      expect(ch.dsp, isNull);

      // Attach: the getter round-trips through the engine and hands back the
      // exact wrapper we assigned.
      ch.dsp = fx;
      expect(ch.dsp, same(fx));

      // The engine processes the channel with the insert live.
      sys.renderOffline(128);

      // Detach.
      ch.dsp = null;
      expect(ch.dsp, isNull);
    });

    test('a linked insert chain attaches by its head', () {
      final ch = Channel.create('chain-ch', parent: Channel.master);
      addTearDown(ch.dispose);
      final head = DspObject.lowpass();
      addTearDown(head.dispose);
      final tail = DspObject.highpass();
      addTearDown(tail.dispose);

      head.link(tail);
      ch.dsp = head;
      expect(ch.dsp, same(head));
      sys.renderOffline(128);

      ch.dsp = null;
      expect(ch.dsp, isNull);
    });
  });
}
