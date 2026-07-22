// M8 example — Log stream + BufferIO asset bundling.
//
// 1) Subscribes to the engine log stream, prints every message to
//    stdout, then deliberately fires an application-level log message
//    via Log.sendMessage.
// 2) Reads drone.ogg into a Uint8List, registers it under the ID
//    "drone-asset", and loads a Sound by passing that ID as the
//    filename. Proves the BufferIO → Sound path works.
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo_io_log.dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

Future<void> main() async {
  final sys = System.instance;
  final log = Log.instance;

  // Subscribe to the log stream BEFORE init so we capture init messages.
  final sub = log.messages.listen((line) => print('[YSE] $line'));

  sys.init();
  print('Engine init complete. Log file would have been: ${log.logfile}');

  log.sendMessage('Hello from the Dart side');
  // Give the engine update loop a chance to process the message queue.
  for (var i = 0; i < 10; i++) {
    sys.update();
    sys.sleep(16);
  }

  // BufferIO: read drone.ogg as bytes, register, then play by ID.
  final resourceFile = File(
    [
      'third_party',
      'yse-soundengine',
      'TestResources',
      'drone.ogg',
    ].join(Platform.pathSeparator),
  ).absolute;
  final bytes = await resourceFile.readAsBytes();
  print('Loaded ${bytes.length} bytes of drone.ogg into Dart memory');

  final io = BufferIO()..active = true;
  io.addAsset('drone-asset', bytes);
  print('Registered as "drone-asset"; exists=${io.exists("drone-asset")}');

  final sound = Sound.fromFile('drone-asset', loop: true, volume: 0.5);
  sound.play();
  print('Playing buffer-IO-backed sound for 3 s...');
  for (var i = 0; i < 180; i++) {
    sys.update();
    sys.sleep(16);
  }

  print('Done. (missed callbacks=${sys.missedCallbacks})');
  sound.stop();
  sound.dispose();

  // Detach log subscription before shutting down the engine so the
  // bridge callback uninstalls cleanly.
  await sub.cancel();

  sys.close();
  io.dispose();
  exit(0);
}
