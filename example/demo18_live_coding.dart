// M18 example — embedded-Python live coding.
//
// Subscribes to the LiveCoding error stream, submits a script to the
// embedded CPython interpreter, then pumps the engine update loop so any
// traceback is delivered. On a YSE_ENABLE_PYTHON=OFF build the run still
// succeeds — the engine surfaces a "compiled without" sentinel through the
// same error stream.
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo18_live_coding.dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

Future<void> main() async {
  final sys = System.instance;

  // Subscribe before submitting so we catch every traceback, including the
  // OFF-build sentinel which fires synchronously inside run().
  final sub = LiveCoding.errors.listen((tb) => print('[script error] $tb'));

  sys.init();
  print('Engine initialised. Python live-coding enabled: ${LiveCoding.enabled}');

  // A deliberately broken script: on an ON build this produces a real
  // Python traceback; on an OFF build it is a no-op beyond the sentinel
  // already delivered by the engine.
  print('Submitting a script...');
  LiveCoding.run('raise RuntimeError("hello from Dart-driven Python")');

  // Drive the update loop so the engine dispatches the error callback on
  // this (main) isolate thread. Yield with `await` (not a blocking sleep)
  // between frames so the broadcast stream can deliver queued tracebacks —
  // including the OFF-build sentinel fired synchronously inside run().
  for (var i = 0; i < 60; i++) {
    sys.update();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }

  print('Done. (missed callbacks=${sys.missedCallbacks})');

  // Detach before shutting down so the error-callback bridge uninstalls
  // cleanly.
  await sub.cancel();

  sys.close();
  exit(0);
}
