// M2 example — port of Demo05_Reverb.cpp.
//
// Sets up the global reverb plus four positioned reverb zones (bathroom,
// hall, sewer-pipe, custom), then walks the listener through them so each
// preset becomes audible in turn on a looping snare.
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo05_reverb.dart

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

  final snare = Sound.fromFile(_resource('snare.ogg'), loop: true);
  snare.play();

  // Global fallback reverb on the master channel.
  sys.globalReverb
    ..active = true
    ..preset = ReverbPreset.generic;
  Channel.master.attachReverb();

  // Four positioned reverb zones along the Z axis.
  final bathroom = Reverb()
    ..position = const Pos(0, 0, 5)
    ..size = 1.0
    ..rollOff = 1.0
    ..preset = ReverbPreset.bathroom;

  final hall = Reverb()
    ..position = const Pos(0, 0, 10)
    ..size = 1.0
    ..rollOff = 1.0
    ..preset = ReverbPreset.hall;

  final sewer = Reverb()
    ..position = const Pos(0, 0, 15)
    ..size = 1.0
    ..rollOff = 1.0
    ..preset = ReverbPreset.sewerpipe;

  final custom = Reverb()
    ..position = const Pos(0, 0, 20)
    ..size = 1.0
    ..rollOff = 1.0
    ..roomSize = 1.0
    ..damping = 0.1;
  custom.setDryWetBalance(dry: 0.0, wet: 1.0);
  custom.setModulation(frequency: 6.5, width: 0.7);
  custom.setReflection(0, time: 1000, gain: 0.5);
  custom.setReflection(1, time: 1500, gain: 0.6);
  custom.setReflection(2, time: 2100, gain: 0.8);
  custom.setReflection(3, time: 2999, gain: 0.9);

  // Walk the listener+sound from 0..22 m along z so each zone gets focus.
  final listener = Listener.instance;
  print('Walking listener through reverb zones (0 → 22 m)...');
  for (var z = 0.0; z <= 22.0; z += 0.05) {
    final p = Pos(0, 0, z);
    listener.position = p;
    snare.position = p;
    sys.update();
    sys.sleep(16);
  }

  print('Done. (missed callbacks=${sys.missedCallbacks})');
  bathroom.dispose();
  hall.dispose();
  sewer.dispose();
  custom.dispose();
  snare.dispose();
  sys.close();
}
