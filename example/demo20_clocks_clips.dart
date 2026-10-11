// Clocks and clips — engine-timed playback into a synth.
//
// Mirrors libYSE tutorial 15 (clocks and clips): a named DomainClock counts
// beats, and a ClipTransport loops one bar of notes against it on the
// audio thread, into a Synth playing behind a Sound. The Dart side never
// times a single note: it edits the event list and steers the tempo.
//
// Walk-through: docs/source/tutorials/06_clocks_and_clips.rst.
//
// Run from the dart-yse package root:
//   dart run example/demo20_clocks_clips.dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

/// Pump the engine for [ms] milliseconds, printing the playhead once per
/// [printEveryMs].
Future<void> pump(
  System sys,
  DomainClock clock,
  int ms, {
  int printEveryMs = 500,
}) async {
  final start = DateTime.now();
  var nextPrint = 0;
  while (true) {
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    if (elapsed >= ms) break;
    if (elapsed >= nextPrint) {
      print(
        '  beat ${clock.beatPosition.toStringAsFixed(2)} '
        '@ ${clock.currentTempo.toStringAsFixed(1)} BPM',
      );
      nextPrint += printEveryMs;
    }
    sys.update();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}

Future<void> main() async {
  final sys = System.instance;
  sys.init();

  // A clock starts at beat 0. The first registration of a name wins, so a
  // second DomainClock('main') would throw while this one lives.
  final clock = DomainClock('main', tempo: 120);

  // The clip plays into a synth behind a sound. Add the voices right after
  // Synth().
  final synth = Synth()..addSineVoices(8, attack: 0.01, release: 0.2);
  final sound = Sound.fromSynth(synth, volume: 0.5)..play();

  // One bar of four quarter notes. Channels are 1-based, like the synth's.
  final bar = [
    for (final (i, pitch) in [60, 64, 67, 72].indexed)
      ClipEvent(
        startBeat: i.toDouble(),
        durationBeats: 0.5,
        channel: 1,
        pitch: pitch,
        velocity: 0.8,
      ),
  ];

  final clip = ClipTransport(clock)
    ..connectSynth(synth)
    ..setEvents(bar, loopBeats: 4)
    ..play();

  print('Looping one bar at 120 BPM ...');
  await pump(sys, clock, 4000);

  // Glide the tempo: every clip on the clock bends with it.
  print('Gliding to 80 BPM over 3 s ...');
  clock.setTempo(80, ramp: const Duration(seconds: 3));
  await pump(sys, clock, 4000);

  // Swap the list while playing: the engine applies it at the next block,
  // and a note sounding across the swap still gets its note-off.
  print('Swapping in a minor arpeggio ...');
  clip.setEvents([
    for (final (i, pitch) in [57, 60, 64, 69].indexed)
      ClipEvent(
        startBeat: i.toDouble(),
        durationBeats: 0.75,
        channel: 1,
        pitch: pitch,
        velocity: 0.7,
      ),
  ], loopBeats: 4);
  await pump(sys, clock, 4000);

  // Tempo 0 pauses the clock (and its clips); the beat position holds.
  print('Pausing the clock (tempo 0) ...');
  clock.setTempo(0);
  await pump(sys, clock, 1500);
  clock.setTempo(120);
  await pump(sys, clock, 2000);

  // stop() releases exactly the notes this clip still has sounding.
  clip.stop();
  await pump(sys, clock, 500);
  print('Done. (missed callbacks=${sys.missedCallbacks})');

  // A clip and its clock may be disposed in either order; disposing the
  // clip first also releases its notes. Then the sound, then the synth.
  clip.dispose();
  clock.dispose();
  sound.dispose();
  synth.dispose();
  sys.close();
  exit(0);
}
