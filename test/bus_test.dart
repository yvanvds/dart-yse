// Tests for the host-side global named bus (issue #59): `Bus.publish`,
// `Bus.subscribe` (exact address), `Bus.tap` (prefix) and the session
// lifecycle. Tap delivery from engine-side producers (patcher gSend) and the
// BusValue types are covered in bus_tap_test.dart.
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//
// Threading (CLAUDE.md Boundaries): everything runs on the one isolate that
// calls `System.initOffline()`, which is the control thread the engine
// dispatches bus callbacks on. Each test opens and closes its own offline
// session, restoring the requested sample rate so later files are unaffected.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

import 'support/sound_ready.dart';

void main() {
  final sys = System.instance;

  void offlineSession() {
    sys.requestedSampleRate = 48000;
    sys.initOffline();
    addTearDown(() {
      sys.close();
      sys.requestedSampleRate = 0;
    });
  }

  /// Let queued broadcast-stream events reach their listeners. Deliberately
  /// does NOT call `update()`: a control-thread publish dispatches inline.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  // Matched by name: tests stay on the public surface, which does not
  // re-export the generated YseStatus enum.
  Matcher yseError(String status) =>
      isA<YseException>().having((e) => e.status?.name, 'status', status);

  group('Bus.publish / Bus.subscribe', () {
    test(
      'an exact subscription receives its address only, without update()',
      () async {
        offlineSession();
        final x = <BusFrame>[];
        final sub = Bus.subscribe('test.x').listen(x.add);
        addTearDown(sub.cancel);

        Bus.publish('test.x', const BusFloat(0.5));
        Bus.publish('test.x2', const BusFloat(0.75));
        await flush();

        expect(x, hasLength(1));
        expect(x.single.address, 'test.x');
        expect(x.single.value, const BusFloat(0.5));
      },
    );

    test('a prefix tap sees both addresses', () async {
      offlineSession();
      final seen = <BusFrame>[];
      final sub = Bus.tap('test.').listen(seen.add);
      addTearDown(sub.cancel);

      Bus.publish('test.x', const BusFloat(0.5));
      Bus.publish('test.x2', const BusFloat(0.75));
      Bus.publish('other.x', const BusFloat(1));
      await flush();

      expect(seen.map((f) => f.address), ['test.x', 'test.x2']);
      expect(seen.map((f) => f.value), [
        const BusFloat(0.5),
        const BusFloat(0.75),
      ]);
    });

    test('every value kind round-trips', () async {
      offlineSession();
      final got = <BusValue>[];
      final sub = Bus.subscribe('test.kinds').listen((f) => got.add(f.value));
      addTearDown(sub.cancel);

      const sent = <BusValue>[
        BusBang(),
        BusInt(-7),
        BusFloat(0.25),
        BusString('héllo'),
        BusList([1, 60, 0.5]),
        BusList([]),
      ];
      for (final v in sent) {
        Bus.publish('test.kinds', v);
      }
      await flush();
      expect(got, sent);
    });

    test(
      'listeners share one subscription; it reinstalls after cancel',
      () async {
        offlineSession();
        final stream = Bus.subscribe('test.share');
        expect(stream.isBroadcast, isTrue);
        expect(Bus.subscribe('test.share'), stream);

        final a = <BusFrame>[];
        final b = <BusFrame>[];
        final subA = stream.listen(a.add);
        final subB = stream.listen(b.add);
        Bus.publish('test.share', const BusInt(1));
        await flush();
        expect(a, hasLength(1));
        expect(b, hasLength(1));

        await subA.cancel();
        await subB.cancel();
        // Torn down: a publish now reaches nobody (and is not an error).
        Bus.publish('test.share', const BusInt(2));

        final c = <BusFrame>[];
        final subC = Bus.subscribe('test.share').listen(c.add);
        addTearDown(subC.cancel);
        Bus.publish('test.share', const BusInt(3));
        await flush();
        expect(c.map((f) => f.value), [const BusInt(3)]);
      },
    );

    test('a publish nobody hears is not an error', () {
      offlineSession();
      expect(
        () => Bus.publish('nobody.home', const BusBang()),
        returnsNormally,
      );
    });
  });

  group('errors', () {
    test('publish before init throws NOT_INITIALIZED', () {
      expect(
        () => Bus.publish('test.x', const BusFloat(0.5)),
        throwsA(yseError('YSE_ERR_NOT_INITIALIZED')),
      );
    });

    test('subscribe and tap before init throw StateError', () {
      expect(() => Bus.subscribe('test.x'), throwsStateError);
      expect(() => Bus.tap('test.'), throwsStateError);
    });

    test('an empty address is rejected', () {
      offlineSession();
      expect(
        () => Bus.publish('', const BusBang()),
        throwsA(yseError('YSE_ERR_INVALID_ARGUMENT')),
      );
      expect(() => Bus.subscribe(''), throwsArgumentError);
    });

    test('a BusInt outside 32 bits is rejected', () {
      offlineSession();
      expect(
        () => Bus.publish('test.x', const BusInt(1 << 40)),
        throwsArgumentError,
      );
    });
  });

  group('lifecycle', () {
    test('System.close() closes bus streams; re-subscribing after re-init '
        'works', () async {
      sys.requestedSampleRate = 48000;
      sys.initOffline();
      var subDone = false;
      var tapDone = false;
      Bus.subscribe('test.life').listen((_) {}, onDone: () => subDone = true);
      Bus.tap('test.').listen((_) {}, onDone: () => tapDone = true);

      sys.close();
      await flush();
      expect(subDone, isTrue);
      expect(tapDone, isTrue);

      offlineSession();
      final sub = <BusFrame>[];
      final tap = <BusFrame>[];
      final s1 = Bus.subscribe('test.life').listen(sub.add);
      final s2 = Bus.tap('test.').listen(tap.add);
      addTearDown(s1.cancel);
      addTearDown(s2.cancel);
      Bus.publish('test.life', const BusInt(1));
      await flush();
      expect(sub, hasLength(1));
      expect(tap, hasLength(1));
    });

    test('the deprecated LiveCoding.bus forwards to Bus.tap', () async {
      offlineSession();
      final seen = <BusFrame>[];
      // ignore: deprecated_member_use_from_same_package
      final sub = LiveCoding.bus('test.').listen(seen.add);
      addTearDown(sub.cancel);
      Bus.publish('test.fwd', const BusBang());
      await flush();
      expect(seen.single.address, 'test.fwd');
    });
  });

  group('engine listeners', () {
    /// Master post-fader peak after a few update + render cycles.
    double renderPeak() {
      var peak = 0.0;
      for (var i = 0; i < 20; i++) {
        sys.update();
        sys.renderOffline(4);
        final p = Channel.master.peakLinearPost();
        if (p > peak) peak = p;
      }
      return peak;
    }

    /// A sine synth, wrapped in a playing sound, with its voices cloned.
    Synth playableSynth() {
      final synth = Synth();
      synth.addSineVoices(4, attack: 0.001, release: 0.01);
      final sound = Sound.fromSynth(synth)
        ..position = const Pos(0, 0, 1)
        ..play();
      // LIFO: the sound is disposed before the synth it renders.
      addTearDown(synth.dispose);
      addTearDown(sound.dispose);
      for (var i = 0; i < 100 && synth.voiceCount < 4; i++) {
        sys.update();
        sys.renderOffline(4);
        sleep(const Duration(milliseconds: 5));
      }
      expect(synth.voiceCount, 4, reason: 'voices should clone');
      return synth;
    }

    test('publishing synth.<name>.note plays a named Synth', () {
      offlineSession();
      final synth = playableSynth()..busName = 'bustest';
      expect(synth.busName, 'bustest');

      expect(renderPeak(), lessThan(1e-4), reason: 'silent before the note');

      Bus.publish('synth.bustest.note', const BusList([1, 69, 1]));
      expect(renderPeak(), greaterThan(0.01));
    });

    test('clearing the name stops delivery', () {
      offlineSession();
      final synth = playableSynth()..busName = 'bustest';
      synth.busName = '';
      expect(synth.busName, isNull);

      Bus.publish('synth.bustest.note', const BusList([1, 69, 1]));
      expect(renderPeak(), lessThan(1e-4));
    });
  });

  group('named sounds and channels', () {
    /// A looping DC sound whose load has succeeded (the engine drops bus
    /// values that reach a sound that is not yet valid).
    Sound loadedSound({Channel? channel}) {
      final buffer = DspBuffer.plain(length: 1024)..fill(0.5);
      final sound = Sound.fromBuffer(buffer, loop: true, channel: channel);
      addTearDown(() {
        sound.dispose();
        buffer.dispose();
      });
      expect(sound.isValid, isTrue);
      return sound;
    }

    test('sound.<name>.volume / .speed / .position drive a named Sound', () {
      offlineSession();
      final sound = loadedSound()..busName = 'bussound';
      expect(sound.busName, 'bussound');

      Bus.publish('sound.bussound.volume', const BusFloat(0.25));
      Bus.publish('sound.bussound.speed', const BusInt(2));
      Bus.publish('sound.bussound.position', const BusList([1, 2, 3]));
      sys.update();

      expect(sound.volume, closeTo(0.25, 1e-6));
      expect(sound.speed, closeTo(2, 1e-6));
      expect(sound.position, const Pos(1, 2, 3));
    });

    test('clearing a sound name stops delivery', () {
      offlineSession();
      final sound = loadedSound()
        ..volume = 1
        ..busName = 'bussound';
      sound.busName = null;
      expect(sound.busName, isNull);

      Bus.publish('sound.bussound.volume', const BusFloat(0.25));
      sys.update();
      expect(sound.volume, closeTo(1, 1e-6));
    });

    test('channel.<name>.volume drives a named Channel', () {
      offlineSession();
      final ch = Channel.create('log-name', parent: Channel.master);
      addTearDown(ch.dispose);
      ch.busName = 'buschan';
      expect(ch.busName, 'buschan');
      // The log name and the bus name are independent.
      expect(ch.name, 'log-name');

      Bus.publish('channel.buschan.volume', const BusFloat(0.25));
      sys.update();
      expect(ch.volume, closeTo(0.25, 1e-6));

      Bus.publish('channel.buschan.volume', const BusInt(1));
      sys.update();
      expect(ch.volume, closeTo(1, 1e-6));
    });

    test('a named channel is audibly attenuated through the bus', () {
      offlineSession();
      final ch = Channel.create('lvl', parent: Channel.master);
      addTearDown(ch.dispose);
      final sound = loadedSound(channel: ch)
        ..position = const Pos(0, 0, 1)
        ..play();
      pumpUntilReady(sys, sound);
      ch.busName = 'buslvl';

      double peak() {
        for (var i = 0; i < 20; i++) {
          sys.update();
          sys.renderOffline(1);
        }
        return ch.peakLinearPost();
      }

      final full = peak();
      expect(full, greaterThan(0.01));
      Bus.publish('channel.buslvl.volume', const BusFloat(0));
      expect(peak(), lessThan(full * 0.01));
    });

    test('clearing a channel name stops delivery', () {
      offlineSession();
      final ch = Channel.create('log-name', parent: Channel.master)..volume = 1;
      addTearDown(ch.dispose);
      ch.busName = 'buschan';
      ch.busName = '';
      expect(ch.busName, isNull);

      Bus.publish('channel.buschan.volume', const BusFloat(0.25));
      sys.update();
      expect(ch.volume, closeTo(1, 1e-6));
    });

    test('a singleton channel remembers its bus name across wrappers, and '
        'close() forgets it', () {
      offlineSession();
      Channel.music.busName = 'busmusic';
      addTearDown(() => Channel.music.busName = null);
      expect(Channel.music.busName, 'busmusic');

      sys.close();
      expect(Channel.music.busName, isNull);
      sys.initOffline();
    });
  });
}
