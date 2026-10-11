// Runs one of this package's Dart scripts in a fresh process, for the tests
// that check a tool's output or the loader's behaviour from outside (#95).
//
// `dart run` is avoided on purpose: it copies the build hook's bundled
// engine into `.dart_tool/lib/` on every start, deleting the old copies
// first, and on Windows that fails while the test runner itself has those
// DLLs loaded (any engine suite of the same `dart test` run loads them). The
// standalone VM (`dartvm`, next to `dart` in the SDK) runs the script with
// the native assets the test runner already bundled
// (`.dart_tool/native_assets.yaml`) and copies nothing. Without a `dartvm`
// in the SDK it falls back to `dart run`.

import 'dart:io';

/// Runs [script] (relative to the package root, the working directory of
/// `dart test`) with [args]. [environment] is added to this process's
/// environment.
Future<ProcessResult> runDartScript(
  String script, {
  List<String> args = const [],
  Map<String, String>? environment,
}) {
  final dart = File(Platform.resolvedExecutable);
  final vm = File(
    '${dart.parent.path}${Platform.pathSeparator}'
    'dartvm${Platform.isWindows ? '.exe' : ''}',
  );
  final root = Directory.current.path;
  final sep = Platform.pathSeparator;
  return vm.existsSync()
      ? Process.run(vm.path, [
          '--packages=$root$sep.dart_tool${sep}package_config.json',
          script,
          ...args,
        ], environment: environment)
      : Process.run(dart.path, [
          'run',
          script,
          ...args,
        ], environment: environment);
}
