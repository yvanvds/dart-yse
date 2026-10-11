// Loader smoke tests (#92): YSE_DLL_PATH as a user sets it, in a fresh
// process per case (the loaded library is a process-wide singleton, and the
// environment can't change inside the test process).
//
// Needs an engine: YSE_DLL_PATH must point at one (e.g. the path
// `dart run tool/fetch_engine.dart` prints), inside this checkout so that a
// relative form of it exists.
@TestOn('windows || linux')
library;

import 'dart:io';

import 'package:test/test.dart';

import '../tool/engine_pin.dart';

const _probe = 'test/support/relative_load_probe.dart';

String get _libName => Platform.isWindows ? 'libyse.dll' : 'libyse.so';

/// Runs the probe with [dllPath] as YSE_DLL_PATH from the repo root. A
/// non-null [path] replaces PATH.
Future<ProcessResult> _runProbe(String dllPath, {String? path}) => Process.run(
  Platform.resolvedExecutable,
  ['run', _probe],
  workingDirectory: Directory.current.path,
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
