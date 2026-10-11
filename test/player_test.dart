// Player: construction against a synth, and audible output through it
// (issue #85).
//
// Since engine v2.3.0 `yse_player_create` takes the synth the player plays
// on; a NULL synth makes it return NULL. Before #85 the Dart `Player()`
// constructor passed `nullptr`, so it always threw and nothing exercised the
// player end to end. The audible test here is the user-visible check: a player
// driving a synth that a playing sound renders must lift the master level.
//
// Requires `libyse.dll` / `libyse.so` — set `YSE_DLL_PATH` (see README).
// Threading (CLAUDE.md): everything runs on the isolate that called
// `System.initOffline()`; the session is headless.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yse/yse.dart';

import 'support/sound_ready.dart';
import 'support/synth_ready.dart';

void main() {
  final sys = System.instance;

  setUpAll(sys.initOffline);
  tearDownAll(sys.close);

  /// Highest master post-fader peak over [cycles] update + render cycles.
  double renderPeak({int cycles = 20}) {
    var peak = 0.0;
    for (var i = 0; i < cycles; i++) {
      sys.update();
      sys.renderOffline(4);
      final level = Channel.master.peakLinearPost();
      if (level > peak) peak = level;
    }
    return peak;
  }

  test('Player(synth) constructs and reports its synth', () {
    // Voice-less: destroying a never-attached synth is only unsafe once it
    // has a voice group (upstream yvanvds/yse-soundengine#1175).
    final synth = Synth();
    addTearDown(synth.dispose);
    final player = Player(synth);
    addTearDown(player.dispose);

    expect(identical(player.synth, synth), isTrue);
    expect(player.isPlaying, isFalse);
    player.play();
    expect(player.isPlaying, isTrue);
    player.stop();
    expect(player.isPlaying, isFalse);
  });

  test('Player on a disposed synth throws YseException', () {
    final synth = Synth()..dispose();
    expect(() => Player(synth), throwsA(isA<YseException>()));
  });

  test('a playing player is heard through its synth', () {
    final synth = newSynth(sys)..addSineVoices(4, attack: 0.001, release: 0.01);
    final sound = Sound.fromSynth(synth)
      ..position = const Pos(0, 0, 1)
      ..play();
    addTearDown(sound.dispose);
    pumpUntilReady(sys, sound);
    expect(pumpVoices(sys, synth, 4), 4, reason: 'voices should clone');

    final scale = Scale()
      ..add(60)
      ..add(64)
      ..add(67);
    final player = Player(synth)
      ..setMinimumPitch(60)
      ..setMaximumPitch(72)
      ..setMinimumVelocity(0.8)
      ..setMaximumVelocity(1)
      ..setMinimumGap(0)
      ..setMaximumGap(0)
      ..setMinimumLength(0.2)
      ..setMaximumLength(0.4)
      ..setScale(scale);
    // Teardown runs last-in first-out: dispose the player, then render a few
    // blocks so the engine retires it before the synth goes. A destroyed
    // player still sends note-offs to its synth on its next block; if the
    // synth is gone by then, or the session is closed first and a later
    // session in this process renders, that is a use-after-free (upstream
    // yvanvds/yse-soundengine#1181).
    addTearDown(() => renderPeak(cycles: 4));
    addTearDown(player.dispose);

    expect(renderPeak(), lessThan(0.001), reason: 'silent before play()');

    player.play();
    var peak = 0.0;
    for (var i = 0; i < 20 && peak <= 0.01; i++) {
      peak = renderPeak();
    }
    expect(peak, greaterThan(0.01), reason: 'the player must drive the synth');

    player.stop();
    synth.allNotesOff();
  });
}
