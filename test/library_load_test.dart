// Loader smoke tests (#92, #95): YSE_DLL_PATH as a user sets it, and the engine
// the native-assets build hook bundles when it is unset, in a fresh process per
// case (the loaded library is a process-wide singleton, and the environment
// can't change inside the test process).
//
// The bundled-engine case needs the hook's download (cached under .dart_tool/
// after the first run). The YSE_DLL_PATH cases need YSE_DLL_PATH to point at
// an engine (e.g. the path `dart run tool/fetch_engine.dart` prints), inside
// this checkout so that a relative form of it exists.
@TestOn('windows || linux')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:yse/src/engine_release.dart' show engineTag;

import '../tool/engine_pin.dart';
import 'support/dart_script.dart';

const _probe = 'test/support/relative_load_probe.dart';

String get _libName => Platform.isWindows ? 'libyse.dll' : 'libyse.so';

/// Runs the probe with [dllPath] as YSE_DLL_PATH from the repo root. A
/// non-null [path] replaces PATH.
Future<ProcessResult> _runProbe(String dllPath, {String? path}) =>
    runDartScript(
      _probe,
      environment: {'YSE_DLL_PATH': dllPath, 'PATH': ?path},
    );

/// [path] relative to the current directory, or null when it is not below it.
String? _relativeToCwd(String path) {
  final sep = Platform.pathSeparator;
  final cwd = Directory.current.absolute.path;
  final prefix = cwd.endsWith(sep) ? cwd : '$cwd$sep';
  final abs = Directory(path).absolute.path;
  final matches = Platform.isWindows
      ? abs.toLowerCase().startsWith(prefix.toLowerCase())
      : abs.startsWith(prefix);
  return matches ? abs.substring(prefix.length) : null;
}

void main() {
  final envPath = Platform.environment['YSE_DLL_PATH'];
  final absDir = (envPath == null || envPath.isEmpty)
      ? null
      : Directory(envPath).absolute.path;
  final relDir = absDir == null ? null : _relativeToCwd(absDir);
  final hasEngine =
      absDir != null &&
      File('$absDir${Platform.pathSeparator}$_libName').existsSync();
  final skipNoEngine = hasEngine
      ? false
      : 'YSE_DLL_PATH does not point at a directory with $_libName';

  test(
    'a relative YSE_DLL_PATH loads the engine and reports its version',
    () async {
      final result = await _runProbe(relDir!);
      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
      final out = (result.stdout as String).split(RegExp(r'\r?\n'));
      final version = out
          .firstWhere((l) => l.startsWith('version='))
          .substring('version='.length);
      final dir = out
          .firstWhere((l) => l.startsWith('dir='))
          .substring('dir='.length);
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+')));
      // The loader reports the resolved, absolute directory.
      expect(Directory(dir).isAbsolute, isTrue, reason: dir);
      expect(
        Platform.isWindows ? dir.toLowerCase() : dir,
        Platform.isWindows ? absDir!.toLowerCase() : absDir,
      );

      // The unreleased-engine check (#89) treats the relative form exactly
      // like the absolute one: silent for the pinned `.engine/<tag>/` tree.
      final root = Directory.current.path;
      String? tag;
      String? problem;
      try {
        tag = await readPinnedTag(root);
      } on PinError catch (e) {
        problem = e.message;
      }
      String? notice(String libDir) => unpinnedEngineNotice(
        version: version,
        libDir: libDir,
        root: root,
        tag: tag,
        pinProblem: problem,
        caseSensitive: !Platform.isWindows,
      );
      expect(notice(dir), notice(absDir!));
    },
    skip: skipNoEngine is String
        ? skipNoEngine
        : (relDir == null
              ? 'YSE_DLL_PATH ($absDir) is not inside the working directory'
              : false),
  );

  test(
    'without YSE_DLL_PATH the engine the build hook bundles is loaded',
    () async {
      // An empty YSE_DLL_PATH counts as unset. On Windows the PATH is cut
      // down to the system directories and the Dart SDK, so the runtime DLLs
      // can only come from the bundle, not from a toolchain such as MSYS2.
      // The probe resolves the asset the hook bundled for this `dart test`
      // run, wherever the SDK put it (see support/dart_script.dart).
      final sysRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      final result = await _runProbe(
        '',
        path: Platform.isWindows
            ? [
                '$sysRoot\\System32',
                sysRoot,
                File(Platform.resolvedExecutable).parent.path,
              ].join(';')
            : null,
      );
      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
      final out = (result.stdout as String).split(RegExp(r'\r?\n'));
      String field(String key) => out
          .firstWhere((l) => l.startsWith('$key='))
          .substring(key.length + 1);
      expect(field('bundled'), 'true');
      expect(versionMatchesTag(field('version'), engineTag), isTrue);
      final dir = field('dir');
      expect(Directory(dir).isAbsolute, isTrue, reason: dir);
      expect(
        File('$dir${Platform.pathSeparator}$_libName').existsSync(),
        isTrue,
      );

      // The unreleased-engine check (#89) is silent for the bundled release.
      String? tag;
      try {
        tag = await readPinnedTag(Directory.current.path);
      } on PinError {
        tag = null;
      }
      expect(
        unpinnedEngineNotice(
          version: field('version'),
          libDir: dir,
          root: Directory.current.path,
          tag: tag,
          bundledTag: engineTag,
          caseSensitive: !Platform.isWindows,
        ),
        isNull,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('a missing relative YSE_DLL_PATH names the resolved path', () async {
    final result = await _runProbe('no-such-engine-dir');
    expect(result.exitCode, isNot(0));
    final expected = Directory('no-such-engine-dir').absolute.path;
    expect('${result.stdout}${result.stderr}', contains(expected));
  });

  test(
    'a library whose dependencies are missing gets a clear error',
    () async {
      // libyse alone, without the dependency libraries that ship next to it.
      final lonely = await Directory.systemTemp.createTemp('yse_lonely_');
      addTearDown(() => lonely.delete(recursive: true));
      await File(
        '$absDir${Platform.pathSeparator}$_libName',
      ).copy('${lonely.path}${Platform.pathSeparator}$_libName');

      // A PATH with only the system directories and the Dart SDK, so that a
      // toolchain on the developer's PATH (e.g. MSYS2 clang64/bin) can't
      // supply the missing DLLs.
      final sysRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      final result = await _runProbe(
        lonely.path,
        path: [
          '$sysRoot\\System32',
          sysRoot,
          File(Platform.resolvedExecutable).parent.path,
        ].join(';'),
      );
      expect(result.exitCode, isNot(0));
      final output = '${result.stdout}${result.stderr}';
      expect(output, contains('Failed to load $_libName from'));
      expect(output, contains(lonely.path));
      expect(output, contains('libyse.dll depends on'));
    },
    // On Linux the release .so's dependencies are system packages, so a lone
    // copy may still load; the missing-sibling case is a Windows one.
    skip: !Platform.isWindows
        ? 'Windows-only: dependency DLLs ship next to libyse.dll'
        : skipNoEngine,
  );
}
