// M4 example — chainable DSP effects on a sound.
//
// Plays drone.ogg with an LFO-modulated lowpass on top, then swaps it
// for a basicDelay + phaser cascade. Demonstrates Sound.dsp setter, the
// inherited LFO control surface, and DspObject.link to build a chain.
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo08_dsp_modules.dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

String _resource(String name) => File([
      'third_party',
      'yse-soundengine',
      'TestResources',
      name,
    ].join(Platform.pathSeparator)).absolute.path;

Future<void> main() async {
  final sys = System.instance;
  sys.init();

  final sound = Sound.fromFile(_resource('drone.ogg'), loop: true, volume: 0.6);

  // 1) LFO-modulated lowpass.
  final lp = DspObject.lowpass()
    ..frequency = 800
    ..lfoType = LfoType.sine
    ..lfoFrequency = 0.5;
  sound.dsp = lp;
  sound.play();
  print('Playing through LFO-modulated lowpass (cutoff=800Hz, 0.5Hz sine LFO)...');
  for (var i = 0; i < 200; i++) { sys.update(); sys.sleep(16); }

  // 2) Swap to a 3-tap delay → phaser chain.
  final delay = DspObject.basicDelay()
    ..setDelayTap(DelayTap.first,  timeMs: 250, gain: 0.5)
    ..setDelayTap(DelayTap.second, timeMs: 500, gain: 0.3)
    ..setDelayTap(DelayTap.third,  timeMs: 750, gain: 0.2);
  final phaser = DspObject.phaser()
    ..frequency = 0.3
    ..phaserRange = 0.1;
  delay.link(phaser);

  sound.dsp = delay;
  print('Swapped to basicDelay → phaser chain...');
  for (var i = 0; i < 200; i++) { sys.update(); sys.sleep(16); }

  // 3) Granulator on the same sound.
  final gran = DspObject.granulator(poolSize: 44100, maxGrains: 24)
    ..grainFrequency = 30
    ..setGrainLength(samples: 4000, random: 1000)
    ..setGrainTranspose(pitch: 1.0, random: 0.2)
    ..grainGain = 0.8;
  sound.dsp = gran;
  print('Swapped to granulator (30 grains/s)...');
  for (var i = 0; i < 200; i++) { sys.update(); sys.sleep(16); }

  print('Done. (missed callbacks=${sys.missedCallbacks})');

  // YSE lifetime contract: a DSP object attached via Sound.dsp must
  // outlive both the sound *and* the engine's slow-pool delete tick.
  // For a CLI demo the simplest correct shutdown is: detach the DSP
  // chain, drain, close the engine, then let the OS reclaim the native
  // allocations at process exit — explicit dispose() in the wrong order
  // can race the audio thread's last reads.
  sound.dsp = null;
  for (var i = 0; i < 30; i++) { sys.update(); sys.sleep(16); }
  sound.stop();
  sys.close();

  // For a CLI demo the cleanest exit is Process.exit(0): the OS
  // reclaims everything in one shot, sidestepping the
  // Dart-finalizers-vs-engine-shutdown race. Long-running applications
  // should keep the DSP-effect wrappers alive for the full session
  // (don't dispose mid-flight) and let the engine's slow-pool drain
  // them after sys.close() returns.
  exit(0);
}
