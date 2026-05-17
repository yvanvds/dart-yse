import 'dart:convert';
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
///   2. `third_party/yse-soundengine/build/bin/libyse.dll` under the `yse`
///      package's own root, located via the consumer's
///      `.dart_tool/package_config.json`. Works for path, git, and
///      pub-hosted dependencies.
///   3. The same relative path under the current working directory — last
///      resort when no package config is available (e.g. running a loose
///      script).
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

  final pkgRoot = _resolveYsePackageRoot();
  final base = pkgRoot ?? Directory.current.path;
  return [base, 'third_party', 'yse-soundengine', 'build', 'bin']
      .join(Platform.pathSeparator);
}

/// Finds the on-disk root of the `yse` package by reading the consumer's
/// `.dart_tool/package_config.json`. Walks up from the current working
/// directory so it works whether the consumer ran `dart run` from their
/// project root or a subdirectory. Returns null if the config can't be
/// located or parsed — callers fall back to CWD-relative resolution.
String? _resolveYsePackageRoot() {
  var dir = Directory.current;
  while (true) {
    final cfg = File(
      '${dir.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}package_config.json',
    );
    if (cfg.existsSync()) {
      try {
        final json = jsonDecode(cfg.readAsStringSync()) as Map<String, dynamic>;
        final packages = (json['packages'] as List).cast<Map<String, dynamic>>();
        for (final pkg in packages) {
          if (pkg['name'] == 'yse') {
            final rootUri = pkg['rootUri'] as String?;
            if (rootUri == null) return null;
            return cfg.uri.resolve(rootUri).toFilePath();
          }
        }
      } catch (_) {
        // fall through to null
      }
      return null;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
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
