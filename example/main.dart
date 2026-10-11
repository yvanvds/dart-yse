// Hello, sound: the smallest complete package:yse program.
//
// After `dart pub add yse`, run it with `dart run example/main.dart`. The
// package's build hook downloads and bundles the engine (Windows x64,
// Linux x64, Android); no environment variable or native build is needed.
//
// It plays a one-second 440 Hz sine tone generated in memory, so it needs no
// sound file. Pass a file path to play that file instead:
//   dart run example/main.dart path/to/sound.ogg

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:yse/yse.dart';

void main(List<String> args) {
  final sys = System.instance;
  try {
    sys.init(); // throws YseException when no audio device opens
  } on YseException catch (e) {
    print('Could not open an audio device: $e');
    exitCode = 1;
    return;
  }
  print('libYSE ${System.version}');

  DspBuffer? tone;
  final Sound sound;
  if (args.isNotEmpty) {
    sound = Sound.fromFile(File(args.first).absolute.path);
  } else {
    // One second of a 440 Hz sine at the session rate: a whole number of
    // cycles, so the loop is seamless.
    final rate = sys.sessionSampleRate.round();
    final samples = Float32List(rate);
    for (var i = 0; i < rate; i++) {
      samples[i] = 0.3 * math.sin(2 * math.pi * 440 * i / rate);
    }
    tone = DspBuffer.plain(length: rate)..write(samples);
    sound = Sound.fromBuffer(tone, loop: true);
  }
  sound.play();

  // Pump the engine for 3 seconds: update() delivers queued changes.
  for (var i = 0; i < 180; i++) {
    sys.update();
    sys.sleep(16);
  }

  sound.dispose();
  tone?.dispose();
  sys.close();
}
