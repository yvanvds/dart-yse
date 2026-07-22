// M3 example — in-memory buffer playback.
//
// Allocates a DspBuffer.file, loads piano.wav into it, then plays the
// buffer through a Sound (Sound.fromBuffer). Demonstrates the in-memory
// audio source path — the same buffer can back multiple sounds.
//
// The C++ Demo07_DspSource subclasses dspSourceObject for the
// Shepard-tones example; that path needs audio-thread callbacks and
// isn't wrapped yet, so this Dart port covers the buffer-source overload
// instead (which is the more common use case).
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo07_dsp_buffer.dart

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:yse/yse.dart';

String _resource(String name) => File(
  [
    'third_party',
    'yse-soundengine',
    'TestResources',
    name,
  ].join(Platform.pathSeparator),
).absolute.path;

Future<void> main() async {
  final sys = System.instance;
  sys.init();

  // Load piano.wav into a fileBuffer; allocate large enough for the full file.
  final buffer = DspBuffer.file(length: 48000 * 5); // up to ~5s @ 48kHz
  buffer.loadFile(_resource('piano.wav'));
  print(
    'Loaded piano.wav: ${buffer.length} samples '
    '(${buffer.lengthSec.toStringAsFixed(2)}s), peak=${buffer.maxValue.toStringAsFixed(3)}',
  );

  // Inspect the first 8 samples via the read API (round-trip FFI).
  final head = buffer.read(offset: 0, count: 8);
  print('First 8 samples: ${head.map((s) => s.toStringAsFixed(4)).toList()}');

  // Play the buffer-backed sound twice in sequence at different volumes.
  final s1 = Sound.fromBuffer(buffer, loop: false, volume: 0.7);
  s1.play();
  print('Playing piano (volume 0.7)...');
  for (var i = 0; i < 100; i++) {
    sys.update();
    sys.sleep(16);
  }

  // Demonstrate writing a synthetic ramp into a drawable buffer and playing it.
  final drawable = DspBuffer.drawable(length: 48000); // 1 second @ 48kHz
  drawable.drawLine(start: 0, stop: 24000, startValue: -0.5, stopValue: 0.5);
  drawable.drawLine(
    start: 24000,
    stop: 47999,
    startValue: 0.5,
    stopValue: -0.5,
  );
  print('Drew triangle ramp: peak=${drawable.maxValue.toStringAsFixed(3)}');

  // Round-trip via the bulk-write API: overwrite the middle with a small sine
  // burst, just to exercise the write path.
  final burst = Float32List(1000);
  for (var i = 0; i < burst.length; i++) {
    burst[i] =
        0.4 * (i % 2 == 0 ? 1.0 : -1.0); // square at Nyquist/2 — quiet click
  }
  drawable.write(burst, offset: 12000);

  final s2 = Sound.fromBuffer(drawable, loop: false, volume: 0.3);
  s2.play();
  print('Playing triangle ramp (volume 0.3)...');
  for (var i = 0; i < 80; i++) {
    sys.update();
    sys.sleep(16);
  }

  print('Done. (missed callbacks=${sys.missedCallbacks})');
  s1.dispose();
  s2.dispose();
  buffer.dispose();
  drawable.dispose();
  sys.close();
}
