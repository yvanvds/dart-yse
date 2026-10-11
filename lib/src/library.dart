import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'bindings/yse_bindings.g.dart';
import 'engine_release.dart';
import 'exception.dart';

/// Lazily-loaded singleton handle to the generated [YseBindings].
///
/// Resolution differs by platform:
///
/// * **Windows / Linux** — locates the engine library in this order:
///   1. `YSE_DLL_PATH` env var — path to a directory containing
///      `libyse.dll` (Windows) or `libyse.so` (Linux) and its runtime
///      dependencies. An explicit override: a source build, a fetched
///      release or an unreleased dev engine (#89). A relative path is
///      resolved against the current working directory before anything is
///      loaded (#92).
///   2. The engine bundled by the package's native-assets build hook
///      (`hook/build.dart`, #95): the prebuilt release named in
///      `engine_release.dart`, which `dart run`, `dart test`, `dart build`
///      and `flutter run` copy into the application (on Windows together with
///      its runtime DLLs). It is resolved through the code asset id
///      [libyseAssetId], so it is found wherever the SDK put it.
///   3. `third_party/yse-soundengine/build/bin/` under the `yse` package's
///      own root (located via the consumer's `.dart_tool/package_config.json`)
///      or, without a package config, under the current working directory —
///      a source build in a dart-yse checkout, for targets the hook bundles
///      nothing for.
///
///   With `YSE_DLL_PATH` on Windows the resolved directory is also passed to
///   `SetDllDirectoryW` so that `libyse.dll`'s own dependency DLLs (libc++,
///   libsndfile, libportaudio, etc.) sitting alongside it are discoverable by
///   the loader. The bundled asset needs no such call: the SDK places the
///   DLLs side by side and loads them from there. On Linux the upstream CMake
///   build embeds `$ORIGIN` in the `.so`'s RPATH, so sibling shared libraries
///   are found automatically.
///
/// * **Android** — loads the engine the build hook bundled (#96): Flutter
///   packages the hook's `libyse.so` for the target ABI (arm64-v8a or x86_64)
///   into the APK / AAB under `lib/<abi>/`. The loader resolves it through
///   the code asset id [libyseAssetId] and then opens it by its soname. All
///   transitive engine deps (Oboe, libsndfile, the C++ runtime) are
///   statically linked into `libyse.so`, so no other shared libraries need
///   to be loadable. `YSE_DLL_PATH` does not apply; the hook's `engine_dir`
///   user-define bundles a local engine instead.
YseBindings get bindings => _bindings ??= _load();
YseBindings? _bindings;

/// The directory the engine library was loaded from, or null before the
/// first [bindings] access and on Android (where the system linker loads the
/// APK's copy). Internal: the test suite uses it to tell whether it runs
/// against the pinned engine release (#89).
String? get loadedLibraryDirectory => _loadedDirectory;
String? _loadedDirectory;

/// Whether the engine library is the one the build hook bundled (resolution
/// step 2 of [bindings]), i.e. the release [engineTag] names. Internal, for
/// the test suite's unreleased-engine notice (#89).
bool get loadedFromBundledAsset => _fromBundledAsset;
bool _fromBundledAsset = false;

String get _libName => Platform.isWindows ? 'libyse.dll' : 'libyse.so';

YseBindings _load() {
  if (Platform.isAndroid) return _loadAndroid();

  if (!Platform.isWindows && !Platform.isLinux) {
    throw YseException(
      'yse v0.x supports Windows, Linux, and Android. macOS / iOS land in '
      'later milestones.',
    );
  }

  final envPath = Platform.environment['YSE_DLL_PATH'];
  if (envPath != null && envPath.isNotEmpty) {
    // A relative YSE_DLL_PATH is made absolute here (#92): on Windows,
    // `SetDllDirectoryW` takes the working directory out of the DLL search
    // order, and `LoadLibrary` looks a relative path up along that search
    // order rather than from the working directory, so a relative path made
    // even `libyse.dll` itself unfindable (error 126).
    return _openDirectory(
      Directory(envPath).absolute.path,
      missingHint: 'YSE_DLL_PATH must name a directory containing it.',
    );
  }

  final String bundledProblem;
  try {
    final path = _bundledLibraryPath();
    final native = DynamicLibrary.open(path);
    _loadedDirectory = File(path).parent.absolute.path;
    _fromBundledAsset = true;
    return YseBindings(native);
  } on ArgumentError catch (e) {
    bundledProblem = '${e.message}'.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  return _openDirectory(
    _sourceBuildDirectory(),
    missingHint:
        'No engine was bundled by the package:yse build hook either '
        '($bundledProblem). The hook bundles the prebuilt libYSE $engineTag '
        'for Windows x64 and Linux x64 when you use `dart run`, `dart test`, '
        '`dart build` or `flutter run`; elsewhere set YSE_DLL_PATH to a '
        'directory containing $_libName.',
  );
}

/// Android: the engine the build hook bundled into the APK / AAB
/// (`lib/<abi>/libyse.so`), loaded through its code asset id.
YseBindings _loadAndroid() {
  try {
    // Loads the asset from wherever Flutter packaged it. The library is then
    // reopened by its soname rather than by the path dladdr reports: with
    // uncompressed native libraries that path points into the APK
    // (`base.apk!/lib/<abi>/libyse.so`).
    _bundledYseVersion();
    final native = DynamicLibrary.open('libyse.so');
    _fromBundledAsset = true;
    return YseBindings(native);
  } on ArgumentError catch (e) {
    final reason = '${e.message}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    throw YseException(
      'The libYSE engine is not in this app ($reason). The package:yse build '
      'hook bundles libYSE $engineTag for the arm64-v8a and x86_64 ABIs when '
      'the app is built with `flutter build` / `flutter run` (Flutter 3.38 or '
      'later); 32-bit ABIs (armeabi-v7a, x86) have no engine release.',
    );
  }
}

/// Opens `libyse` from [dir], an absolute directory; [missingHint] says what
/// to do when the library is not there.
YseBindings _openDirectory(String dir, {required String missingHint}) {
  final libPath = '$dir${Platform.pathSeparator}$_libName';
  if (!File(libPath).existsSync()) {
    throw YseException('$_libName not found at $libPath. $missingHint');
  }

  if (Platform.isWindows) _setDllDirectory(dir);
  final DynamicLibrary native;
  try {
    native = DynamicLibrary.open(libPath);
  } on ArgumentError catch (e) {
    final hint = Platform.isWindows
        ? 'Error code 126 here usually means a DLL libyse.dll depends on '
              '(libc++, libsndfile, libportaudio, ...) is missing: they ship '
              'next to it in the release bin/ folder and must stay in the '
              'same directory.'
        : 'This usually means a shared library libyse.so depends on is '
              'missing; run `ldd $libPath` to see which.';
    final reason = '${e.message}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    throw YseException('Failed to load $_libName from $libPath: $reason $hint');
  }
  _loadedDirectory = dir;
  return YseBindings(native);
}

/// Anchor into the bundled engine asset: calling it makes the Dart runtime
/// load the asset with id [libyseAssetId] from wherever the SDK bundled it,
/// after which the library's path is read back from the loaded module.
/// `yse_version` has no side effects.
@Native<Pointer<Char> Function()>(symbol: 'yse_version', assetId: libyseAssetId)
external Pointer<Char> _bundledYseVersion();

/// The absolute path of the hook-bundled engine library, loading it.
///
/// Throws [ArgumentError] when the application has no such asset (the hook
/// bundled nothing for this target) or it cannot be loaded.
String _bundledLibraryPath() {
  // Call before taking the address: in an AOT `dart build cli` bundle,
  // `Native.addressOf` on a native function that is never called failed to
  // resolve the asset (Dart 3.13).
  _bundledYseVersion();
  final address = Native.addressOf<NativeFunction<Pointer<Char> Function()>>(
    _bundledYseVersion,
  );
  final path = Platform.isWindows
      ? _windowsModulePath(address)
      : _linuxModulePath(address);
  if (path == null) {
    throw ArgumentError(
      'the bundled $libyseAssetId was loaded but its file could not be '
      'determined',
    );
  }
  return File(path).absolute.path;
}

/// The file of the loaded module containing [address], via
/// `GetModuleHandleExW` + `GetModuleFileNameW`.
String? _windowsModulePath(Pointer<NativeType> address) {
  const fromAddress = 0x4; // GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS
  const unchangedRefCount = 0x2; // GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT
  const capacity = 32768; // longest extended-length path, in UTF-16 units
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getModuleHandleEx = kernel32
      .lookupFunction<
        Int32 Function(Uint32, Pointer<NativeType>, Pointer<Pointer<Void>>),
        int Function(int, Pointer<NativeType>, Pointer<Pointer<Void>>)
      >('GetModuleHandleExW');
  final getModuleFileName = kernel32
      .lookupFunction<
        Uint32 Function(Pointer<Void>, Pointer<Utf16>, Uint32),
        int Function(Pointer<Void>, Pointer<Utf16>, int)
      >('GetModuleFileNameW');
  final module = calloc<Pointer<Void>>();
  final buffer = calloc<Uint16>(capacity).cast<Utf16>();
  try {
    if (getModuleHandleEx(fromAddress | unchangedRefCount, address, module) ==
        0) {
      return null;
    }
    final n = getModuleFileName(module.value, buffer, capacity);
    if (n == 0 || n >= capacity) return null;
    var path = buffer.toDartString(length: n);
    if (path.startsWith(r'\\?\')) path = path.substring(4);
    return path;
  } finally {
    calloc.free(module);
    calloc.free(buffer);
  }
}

/// `Dl_info` from `<dlfcn.h>`.
final class _DlInfo extends Struct {
  external Pointer<Utf8> fileName;
  external Pointer<Void> fileBase;
  external Pointer<Utf8> symbolName;
  external Pointer<Void> symbolAddress;
}

/// The file of the loaded shared object containing [address], via `dladdr`.
String? _linuxModulePath(Pointer<NativeType> address) {
  final dladdr = DynamicLibrary.process()
      .lookupFunction<
        Int32 Function(Pointer<NativeType>, Pointer<_DlInfo>),
        int Function(Pointer<NativeType>, Pointer<_DlInfo>)
      >('dladdr');
  final info = calloc<_DlInfo>();
  try {
    if (dladdr(address, info) == 0 || info.ref.fileName == nullptr) {
      return null;
    }
    return info.ref.fileName.toDartString();
  } finally {
    calloc.free(info);
  }
}

/// The submodule's source-build directory: `third_party/yse-soundengine/
/// build/bin` under the `yse` package root, or under the working directory
/// when the package root cannot be found. Always absolute.
String _sourceBuildDirectory() {
  final pkgRoot = _resolveYsePackageRoot();
  final base = pkgRoot ?? Directory.current.absolute.path;
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
