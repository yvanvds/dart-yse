// M1 smoke test — port of yse-soundengine/Demo.Windows.Native/Demo00_PlaySound.cpp.
//
// Initialises the engine, loads drone.ogg from the YSE test resources on a
// loop, plays it for 3 seconds, then shuts down cleanly.
//
// Run from the dart-yse package root:
//   dart run example/hello_sound.dart
//
// Requires:
//   - third_party/yse-soundengine/build/bin/libyse.dll built locally, OR
//   - YSE_DLL_PATH env var pointing at a directory containing libyse.dll.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

Future<void> main() async {
  final sys = System.instance;
  print('libYSE ${System.version}');

  sys.init();
  print('Engine initialised (CPU load = ${sys.cpuLoad.toStringAsFixed(3)})');

  // Path to a sound file shipped with yse-soundengine for testing.
  // The submodule lives at third_party/yse-soundengine/.  YSE uses libsndfile
  // (which calls fopen internally on Windows) so absolute paths are the
  // safest bet — they sidestep any working-directory mismatch between Dart
  // and the audio thread.
  final resourceFile = File(
    [
      'third_party',
      'yse-soundengine',
      'TestResources',
      'drone.ogg',
    ].join(Platform.pathSeparator),
  ).absolute;

  if (!resourceFile.existsSync()) {
    print('Could not find test sound at ${resourceFile.path}');
    print(
      'Run from the dart-yse package root; ensure the submodule is initialised.',
    );
    sys.close();
    exitCode = 1;
    return;
  }
  final resourcePath = resourceFile.path;

  final sound = Sound.fromFile(resourcePath, loop: true, volume: 0.6);
  print(
    'Loaded ${File(resourcePath).path} '
    '(streaming=${sound.isStreaming})',
  );

  sound.play();
  print('Playing for 3 seconds...');

  // Drive the engine update loop while we wait. The YSE engine queues every
  // state change as a message; update() pumps them on the main thread.
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline)) {
    sys.update();
    sys.sleep(16);
  }

  print('Stopping (missed callbacks = ${sys.missedCallbacks})');
  sound.stop();
  sound.dispose();
  sys.close();
  print('Done.');
}
