import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'exception.dart';

/// Lazily-loaded singleton handle to the generated [YseBindings].
///
/// Resolution differs by platform:
///
/// * **Windows / Linux** — locates the engine library on disk in this order:
///   1. `YSE_DLL_PATH` env var — absolute path to a directory containing
///      `libyse.dll` (Windows) or `libyse.so` (Linux) and its runtime
///      dependencies.
///   2. `third_party/yse-soundengine/build/bin/` under the `yse` package's
///      own root, located via the consumer's
///      `.dart_tool/package_config.json`. Works for path, git, and
///      pub-hosted dependencies.
///   3. The same relative path under the current working directory — last
///      resort when no package config is available (e.g. running a loose
///      script).
///
///   On Windows the resolved directory is also passed to `SetDllDirectoryW`
///   so that `libyse.dll`'s own dependency DLLs (libstdc++, libsndfile,
///   libportaudio, etc.) sitting alongside it are discoverable by the
///   loader. On Linux the upstream CMake build embeds `$ORIGIN` in the
///   `.so`'s RPATH, so sibling shared libraries are found automatically
///   — no equivalent runtime call is needed.
///
/// * **Android** — calls `DynamicLibrary.open('libyse.so')` and relies on
///   the Android linker to resolve the per-ABI copy out of the APK's
///   `lib/<abi>/` directory. The `.so` is bundled into the host APK by
///   the sibling `yse_flutter_libs` plugin (see the Android section of
///   the package README). All transitive engine deps (Oboe, libsndfile)
///   are statically linked into `libyse.so`, so no other shared libraries
///   need to be loadable.
YseBindings get bindings => _bindings ??= _load();
YseBindings? _bindings;

YseBindings _load() {
  if (Platform.isAndroid) {
    return YseBindings(DynamicLibrary.open('libyse.so'));
  }

  if (!Platform.isWindows && !Platform.isLinux) {
    throw YseException(
      'yse v0.x supports Windows, Linux, and Android. macOS / iOS land in '
      'later milestones.',
    );
  }

  final dir = _resolveLibDirectory();
  final libName = Platform.isWindows ? 'libyse.dll' : 'libyse.so';
  final libPath = '$dir${Platform.pathSeparator}$libName';
  if (!File(libPath).existsSync()) {
    throw YseException(
      '$libName not found at $libPath. '
      'Either set YSE_DLL_PATH to a directory containing it, or build '
      'yse-soundengine via `cmake --build third_party/yse-soundengine/build`.',
    );
  }

  if (Platform.isWindows) _setDllDirectory(dir);
  return YseBindings(DynamicLibrary.open(libPath));
}

String _resolveLibDirectory() {
  final envPath = Platform.environment['YSE_DLL_PATH'];
  if (envPath != null && envPath.isNotEmpty) return envPath;

  final pkgRoot = _resolveYsePackageRoot();
  final base = pkgRoot ?? Directory.current.path;
  return [
    base,
    'third_party',
    'yse-soundengine',
    'build',
    'bin',
  ].join(Platform.pathSeparator);
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
        final packages = (json['packages'] as List)
            .cast<Map<String, dynamic>>();
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
      .lookupFunction<
        Int32 Function(Pointer<Utf16>),
        int Function(Pointer<Utf16>)
      >('SetDllDirectoryW');
  final native = dir.toNativeUtf16();
  try {
    setDllDirectoryW(native);
  } finally {
    malloc.free(native);
  }
}
