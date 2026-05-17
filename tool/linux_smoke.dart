// Headless load smoke for libyse on platforms with no audio hardware
// (Docker containers, CI runners). Verifies the native library is found
// and its FFI symbols resolve; exercises initOffline → renderOffline so
// engine startup is touched but no audio device is opened.
//
// Run from the dart-yse package root:
//   dart run tool/linux_smoke.dart
//
// Honours YSE_DLL_PATH (set by the Docker / CI wrapper to point at the
// freshly built libyse.so).

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

void main() {
  print('Platform: ${Platform.operatingSystem} ${Platform.version}');
  print('YSE_DLL_PATH: ${Platform.environment['YSE_DLL_PATH'] ?? '(unset)'}');
  print('libYSE: ${System.version}');

  final sys = System.instance;
  sys.initOffline();
  sys.renderOffline(4);
  print('renderOffline OK — missed callbacks = ${sys.missedCallbacks}');
  sys.close();

  print('Smoke passed.');
}
