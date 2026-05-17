import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';

/// Lazily-loaded singleton handle to the generated [YseBindings].
///
/// Resolves the path to `libyse.dll` in this order:
///   1. `YSE_DLL_PATH` env var — absolute path to a directory containing
///      `libyse.dll` (and its runtime dependencies).
///   2. `third_party/yse-soundengine/build/bin/libyse.dll` relative to the
///      current working directory — the canonical local-dev location.
///
/// On Windows the resolved directory is also passed to `SetDllDirectoryW`
/// so that `libyse.dll`'s own dependency DLLs (libstdc++, libsndfile,
/// libportaudio, etc.) sitting alongside it are discoverable by the loader.
YseBindings get bindings => _bindings ??= _load();
YseBindings? _bindings;

YseBindings _load() {
  if (!Platform.isWindows) {
    throw YseException(
      'yse v0.x is Windows-only. Other platforms land in a later milestone.',
    );
  }

  final dir = _resolveDllDirectory();
  final dllPath = '$dir${Platform.pathSeparator}libyse.dll';
  if (!File(dllPath).existsSync()) {
    throw YseException(
      'libyse.dll not found at $dllPath. '
      'Either set YSE_DLL_PATH to a directory containing it, or build '
      'yse-soundengine via `cmake --build third_party/yse-soundengine/build`.',
    );
  }

  _setDllDirectory(dir);
  return YseBindings(DynamicLibrary.open(dllPath));
}

String _resolveDllDirectory() {
  final envPath = Platform.environment['YSE_DLL_PATH'];
  if (envPath != null && envPath.isNotEmpty) return envPath;

  // Submodule build cache — works when the consumer ran cmake against the
  // pinned submodule from the package root.
  final cwdRelative = [
    'third_party',
    'yse-soundengine',
    'build',
    'bin',
  ].join(Platform.pathSeparator);
  return '${Directory.current.path}${Platform.pathSeparator}$cwdRelative';
}

void _setDllDirectory(String dir) {
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final setDllDirectoryW = kernel32
      .lookupFunction<Int32 Function(Pointer<Utf16>), int Function(Pointer<Utf16>)>(
    'SetDllDirectoryW',
  );
  final native = dir.toNativeUtf16();
  try {
    setDllDirectoryW(native);
  } finally {
    malloc.free(native);
  }
}
