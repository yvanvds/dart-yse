// M2 example — port of Demo04_Channels.cpp.
//
// Demonstrates the channel tree: a custom channel and the pre-built music
// channel each hosting a sound; per-channel volume control; channel
// disposal hands its sounds to the parent.
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo04_channels.dart

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

  // Custom channel attached under the master.
  final custom = Channel.create('myChannel', parent: Channel.master);

  final kick = Sound.fromFile(_resource('kick.ogg'),
      channel: custom, loop: true, volume: 0.7);
  final pulse = Sound.fromFile(_resource('pulse1.ogg'),
      channel: Channel.music, loop: true, volume: 0.7);

  kick.play();
  pulse.play();

  print('Playing kick (custom channel) + pulse (music channel) for 2 s...');
  for (var i = 0; i < 125; i++) { sys.update(); sys.sleep(16); }

  print('Halving custom-channel volume...');
  custom.volume = custom.volume * 0.3;
  for (var i = 0; i < 125; i++) { sys.update(); sys.sleep(16); }

  print('Disposing custom channel → kick auto-moves to master...');
  // First detach the sound's wrapper from this Dart-side channel reference so
  // we don't carry a dangling channel handle, then destroy the channel.
  custom.dispose();
  for (var i = 0; i < 125; i++) { sys.update(); sys.sleep(16); }

  print('Done. (missed callbacks=${sys.missedCallbacks})');
  kick.dispose();
  pulse.dispose();
  sys.close();
}
