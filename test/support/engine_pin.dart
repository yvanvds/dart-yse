// Shared test helper: say loudly when the suite runs against an engine that
// is not the pinned release (#89).
//
// Testing against an unreleased engine is opt-in: point YSE_DLL_PATH at a dev
// build. It is legitimate, but its results can differ from CI's, so every
// engine-touching suite calls [noticeUnpinnedEngine] from a top-level
// `setUpAll`. With the pinned release (the fetched `.engine/<tag>/` tree or
// the submodule's source build) it prints nothing. Otherwise it prints a
// banner in each suite, next to whatever that suite reports. It never fails a
// test: CI always runs the pin, and a dev engine is a valid local setup.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/src/library.dart' show loadedLibraryDirectory;
import 'package:yse/yse.dart';

import '../../tool/engine_pin.dart';

/// Prints a prominent notice when the loaded libyse is not the pinned
/// engine release. Use as `setUpAll(noticeUnpinnedEngine);`.
Future<void> noticeUnpinnedEngine() async {
  final String version;
  final String? libDir;
  try {
    version = System.version;
    libDir = loadedLibraryDirectory;
  } on Object {
    // No engine library: the suite's own tests report that. This helper
    // never turns a setup problem into a failure of its own.
    return;
  }
  if (libDir == null) return; // Android: the APK's copy, nothing to compare.

  final root = Directory.current.path;
  String? tag;
  String? problem;
  try {
    tag = await readPinnedTag(root);
  } on PinError catch (e) {
    problem = e.message;
  }

  final notice = unpinnedEngineNotice(
    version: version,
    libDir: Directory(libDir).absolute.path, // YSE_DLL_PATH may be relative
    root: root,
    tag: tag,
    pinProblem: problem,
    caseSensitive: !Platform.isWindows,
  );
  if (notice != null) print(notice);
}
