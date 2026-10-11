// Probe for test/library_load_test.dart (#92, #95): loads libyse the way a
// user's script does, from whatever YSE_DLL_PATH the spawning test sets (or,
// with none, the engine the build hook bundles), and prints the engine
// version. Run in a fresh process because the loader is a process-wide
// singleton.
// ignore_for_file: avoid_print

import 'package:yse/src/library.dart'
    show loadedFromBundledAsset, loadedLibraryDirectory;
import 'package:yse/yse.dart';

void main() {
  print('version=${System.version}');
  print('dir=$loadedLibraryDirectory');
  print('bundled=$loadedFromBundledAsset');
}
