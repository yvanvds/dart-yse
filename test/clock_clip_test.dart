// Integration smoke tests for the DomainClock + ClipTransport wrappers
// (issue #21).
//
// These touch the real engine through `libyse.dll` / `libyse.so`, so they
// require the library to be resolvable — set `YSE_DLL_PATH` to the directory
// holding it (see README / CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test
//
// Threading (CLAUDE.md Boundaries): everything runs on the one isolate that
// calls `System.initOffline()`. The offline path is headless — it drives the
// engine (and therefore the beat clocks) via `renderOffline()` rather than an
// audio device, so the suite does not depend on an openable device or on MIDI
// hardware.
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

  // Unique clock names per test keep the shared engine's name registry from
  // colliding across cases (first registration of a name wins).
  var seq = 0;
  String freshName(String base) => '$base-${seq++}';

  group('ClipEvent', () {
    test('defaults to full velocity and no bend', () {
      const e = ClipEvent(
        startBeat: 1.5,
        durationBeats: 0.5,
        channel: 1,
        pitch: 60,
      );
      expect(e.velocity, 1.0);
      expect(e.pitchBend, 0.0);
      expect(e.startBeat, 1.5);
      expect(e.durationBeats, 0.5);
      expect(e.channel, 1);
      expect(e.pitch, 60);
    });
  });

  group('DomainClock', () {
    test('create, exists, and dispose round-trip', () {
      final name = freshName('rt');
      final clock = DomainClock(name, tempo: 120);
      expect(clock.exists, isTrue);
      expect(clock.currentTempo, closeTo(120, 0.001));

      clock.dispose();
      expect(clock.exists, isFalse);
      // Idempotent.
      clock.dispose();
    });

    test('duplicate name is rejected (first registration wins)', () {
      final name = freshName('dup');
      final a = DomainClock(name, tempo: 100);
      expect(
        () => DomainClock(name, tempo: 200),
        throwsA(isA<YseException>()),
      );
      a.dispose();
    });

    test('beat position advances while the engine renders', () {
      final clock = DomainClock(freshName('run'), tempo: 120);
      addTearDown(clock.dispose);

      final start = clock.beatPosition;
      sys.renderOffline(256);
      final after = clock.beatPosition;

      expect(
        after,
        greaterThan(start),
        reason: 'a positive-tempo clock must integrate forward as blocks render',
      );
    });

    test('a paused (tempo 0) clock holds its beat position', () {
      final clock = DomainClock(freshName('pause'), tempo: 120);
      addTearDown(clock.dispose);

      sys.renderOffline(64);
      // setTempo is queued to the audio thread and takes effect at the next
      // block boundary, so render a few blocks for it to settle before
      // sampling.
      clock.setTempo(0); // instant stop
      sys.renderOffline(16);
      expect(clock.currentTempo, closeTo(0, 0.001));

      final held = clock.beatPosition;
      sys.renderOffline(256);
      expect(
        clock.beatPosition,
        closeTo(held, 1e-6),
        reason: 'a tempo-0 clock must not advance',
      );
    });

    test('unknown clock reports zero, not a crash', () {
      final clock = DomainClock(freshName('gone'), tempo: 90);
      clock.dispose();
      expect(clock.exists, isFalse);
      expect(clock.beatPosition, 0.0);
      expect(clock.currentTempo, 0.0);
    });
  });

  group('ClipTransport', () {
    test('binds to a clock and toggles play/stop', () {
      final clock = DomainClock(freshName('clip'), tempo: 120);
      addTearDown(clock.dispose);
      final clip = ClipTransport(clock);
      addTearDown(clip.dispose);

      expect(clip.isPlaying, isFalse);

      clip.setEvents(
        const [
          ClipEvent(startBeat: 0, durationBeats: 1, channel: 1, pitch: 60),
          ClipEvent(
            startBeat: 1,
            durationBeats: 1,
            channel: 1,
            pitch: 64,
            velocity: 0.5,
            pitchBend: 0.25,
          ),
        ],
        loopBeats: 4,
      );

      clip.play();
      expect(clip.isPlaying, isTrue);
      sys.renderOffline(256); // let the audio thread pick the events up
      expect(clip.isPlaying, isTrue);

      clip.stop();
      expect(clip.isPlaying, isFalse);
    });

    test('event list is replaceable while playing', () {
      final clock = DomainClock(freshName('swap'), tempo: 140);
      addTearDown(clock.dispose);
      final clip = ClipTransport(clock);
      addTearDown(clip.dispose);

      clip.setEvents(
        const [ClipEvent(startBeat: 0, durationBeats: 2, channel: 1, pitch: 48)],
        loopBeats: 2,
      );
      clip.play();
      sys.renderOffline(128);

      // Swap the list mid-flight — must not throw and playback continues.
      clip.setEvents(
        const [
          ClipEvent(startBeat: 0, durationBeats: 1, channel: 2, pitch: 72),
          ClipEvent(startBeat: 1, durationBeats: 1, channel: 2, pitch: 76),
        ],
        loopBeats: 2,
      );
      sys.renderOffline(128);
      expect(clip.isPlaying, isTrue);

      // Clearing the list is also legal.
      clip.setEvents(const [], loopBeats: 0);
      sys.renderOffline(64);

      clip.stop();
      expect(clip.isPlaying, isFalse);
    });

    test('binding to a nonexistent clock throws', () {
      final clock = DomainClock(freshName('temp'), tempo: 120);
      clock.dispose(); // clock no longer live
      expect(
        () => ClipTransport(clock),
        throwsA(isA<YseException>()),
      );
    });

    test('dispose is idempotent', () {
      final clock = DomainClock(freshName('idem'), tempo: 120);
      addTearDown(clock.dispose);
      final clip = ClipTransport(clock);
      clip.dispose();
      clip.dispose(); // no throw
    });
  });
}
