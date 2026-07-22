// M7 example — music-theory primitives (note, scale, motif).
//
// Builds a 4-note motif, constructs a C-pentatonic Scale, asks the
// Scale for the nearest in-key pitch to a chromatic input, and
// inspects the motif's length / size after auto-set.
//
// The Player class is wrapped but its upstream factory
// (`YSE::player::create(synth&)`) is commented out in YSE — the
// synth subsystem is deferred per the project plan. Calling methods
// on a freshly-constructed Player crashes (null pimpl deref). When
// the synth subsystem returns, the Player surface in lib/src/music.dart
// becomes usable without any wrapper changes.
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

  print('Done. (missed callbacks=${sys.missedCallbacks})');

  motif.dispose();
  scale.dispose();
  root.dispose();
  sys.close();
  exit(0);
}
