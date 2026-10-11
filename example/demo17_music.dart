// M7 example — music-theory primitives (note, scale, motif) and the
// generative Player.
//
// Builds a 4-note motif, constructs a C-pentatonic Scale, asks the
// Scale for the nearest in-key pitch to a chromatic input, and
// inspects the motif's length / size after auto-set. Then a Player
// improvises on a sine Synth for a few seconds, kept in key by the
// scale and drawing on the motif.
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo17_music.dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

Future<void> main() async {
  final sys = System.instance;
  sys.init();

  // Build a small motif: an arpeggio of C-E-G-C across one second.
  final motif = Motif();
  motif.add(PNote(position: 0.0, pitch: 60, length: 0.2));
  motif.add(PNote(position: 0.25, pitch: 64, length: 0.2));
  motif.add(PNote(position: 0.5, pitch: 67, length: 0.2));
  motif.add(PNote(position: 0.75, pitch: 72, length: 0.2));
  motif.autoSetLength();
  print(
    'Motif: ${motif.size} notes, length=${motif.length.toStringAsFixed(2)}s',
  );

  // C-pentatonic scale across all octaves (octaveStep=12 replicates).
  final scale = Scale()
    ..add(60) // C
    ..add(62) // D
    ..add(64) // E
    ..add(67) // G
    ..add(69); // A
  print(
    'Scale: ${scale.size} pitches in MIDI range; '
    'nearest to 63 (Eb) = ${scale.nearest(63)} (E)',
  );
  print('Has 60 (C)?  ${scale.has(60)}');
  print('Has 61 (C#)? ${scale.has(61)}');

  // Transpose the motif up an octave.
  motif.transpose(12);
  // Walking the motif via PNote is not yet exposed (motif::operator[]
  // returns a reference into the internal vector, which is awkward to
  // cross the ABI safely). For now: trust the count + length.

  // Plain Note arithmetic is fine without the player.
  final root = Note(pitch: 60, volume: 0.8, length: 0.5);
  print(
    'Root note: pitch=${root.pitch}, volume=${root.volume}, '
    'length=${root.length}s, channel=${root.channel}',
  );

  // Restrict the motif's legal start pitches to the scale.
  motif.setFirstPitch(scale);

  // A player plays its notes on a synth; a sound renders that synth.
  // Add the voices right after creating the synth.
  final synth = Synth()..addSineVoices(8, attack: 0.01, release: 0.3);
  final sound = Sound.fromSynth(synth, volume: 0.5)
    ..position = const Pos(0, 0, 1)
    ..play();

  final player = Player(synth)
    ..setMinimumPitch(55)
    ..setMaximumPitch(84)
    ..setMinimumVelocity(0.4)
    ..setMaximumVelocity(0.8)
    ..setMinimumGap(0.05)
    ..setMaximumGap(0.3)
    ..setMinimumLength(0.1)
    ..setMaximumLength(0.5)
    ..setVoices(2)
    ..setScale(scale)
    ..addMotif(motif)
    ..playMotifs(0.3)
    ..play();
  print('Player improvising for 6 seconds...');
  for (var i = 0; i < 120; i++) {
    sys.update();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  player.stop();

  print('Done. (missed callbacks=${sys.missedCallbacks})');

  // Dispose the player before what it borrows, and give the engine a block
  // to retire it before its synth goes away.
  player.dispose();
  for (var i = 0; i < 10; i++) {
    sys.update();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  sound.dispose();
  synth.dispose();
  motif.dispose();
  scale.dispose();
  root.dispose();
  sys.close();
  exit(0);
}
