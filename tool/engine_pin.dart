// The engine release the submodule pins, and how to tell whether a loaded
// libyse is that release (#88, #89).
//
// Shared by tool/fetch_engine.dart (which downloads the pinned release) and
// the test suite's unreleased-engine notice (test/support/engine_pin.dart).
// The pinned tag is read from the submodule checkout:
//   git -C third_party/yse-soundengine describe --tags --exact-match
//
// Everything except [readPinnedTag] is pure, so it is unit-tested without git
// or an engine (test/engine_pin_test.dart).

import 'dart:io';

/// Submodule path of the engine, relative to the package root.
const submodulePath = 'third_party/yse-soundengine';

/// Gitignored folder the releases are unpacked into, relative to the root.
const engineCacheDir = '.engine';

/// A release tag the engine publishes binaries for: `v<major>.<minor>.<patch>`
/// with an optional pre-release / build suffix (`v3.1.0`, `v2.4.0-3`), but not
/// a `git describe` distance suffix (`v3.1.0-5-gda8ce99`), which names an
/// untagged commit.
final _tagPattern = RegExp(
  r'^v\d+\.\d+\.\d+(?:[-+.][0-9A-Za-z.+-]+)?$(?<!-\d+-g[0-9a-f]{7,40})',
);

/// Returns the release tag in `git describe --tags --exact-match` [output].
///
/// Throws [FormatException] when the output is empty or not a release tag.
String parseReleaseTag(String output) {
  final tag = output.trim();
  if (!_tagPattern.hasMatch(tag)) {
    throw FormatException(
      'the engine pin is not a release tag (got "$tag"); expected vX.Y.Z',
    );
  }
  return tag;
}

/// Why the pinned tag could not be read.
class PinError implements Exception {
  /// Creates an error carrying [message] and, for a failed `git describe`,
  /// git's own [gitOutput].
  PinError(this.message, {this.gitOutput});

  /// What went wrong.
  final String message;

  /// The trimmed stderr of `git describe`, when git ran but failed.
  final String? gitOutput;

  @override
  String toString() => message;
}

/// Reads the release tag the engine submodule under [root] is checked out at.
///
/// Throws [PinError] when git cannot run, the submodule is not at a tag, or
/// the tag is not a release tag.
Future<String> readPinnedTag(String root) async {
  final sub = [root, ...submodulePath.split('/')].join(Platform.pathSeparator);
  final ProcessResult r;
  try {
    r = await Process.run('git', [
      '-C',
      sub,
      'describe',
      '--tags',
      '--exact-match',
    ]);
  } on ProcessException catch (e) {
    throw PinError('could not run git: ${e.message}');
  }
  if (r.exitCode != 0) {
    throw PinError(
      'the engine submodule ($submodulePath) is not checked out at a release '
      'tag',
      gitOutput: (r.stderr as String).trim(),
    );
  }
  try {
    return parseReleaseTag(r.stdout as String);
  } on FormatException catch (e) {
    throw PinError(e.message);
  }
}

/// Whether libYSE's `System.version` string ([version], e.g. `3.1.0`) is the
/// release named by [tag] (e.g. `v3.1.0`).
///
/// The tag is the version with a `v` prefix, so the comparison is exact after
/// stripping it: `3.1.0` matches `v3.1.0` but not `v3.1.1` or `v3.1.0-rc.1`.
bool versionMatchesTag(String version, String tag) {
  final v = version.trim();
  final t = tag.trim();
  if (v.isEmpty || !t.startsWith('v')) return false;
  return t.substring(1) == v;
}

/// Normalises a directory path for comparison: forward slashes, `.` / `..`
/// segments resolved, no trailing slash, and lower case when the file system
/// is case-insensitive ([caseSensitive] false, as on Windows).
String normalizeDir(String path, {required bool caseSensitive}) {
  var p = path.replaceAll(r'\', '/');
  final absolute = p.startsWith('/');
  final out = <String>[];
  for (final seg in p.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (out.isNotEmpty) out.removeLast();
      continue;
    }
    out.add(seg);
  }
  p = (absolute ? '/' : '') + out.join('/');
  return caseSensitive ? p : p.toLowerCase();
}

/// Whether [libDir] (the directory libyse was loaded from) is one of the two
/// places a build of the pinned engine lives in a checkout at [root]:
///
/// * the fetched release, anywhere under `<root>/.engine/<tag>/`; [tag] null
///   (the pin could not be read) never matches here, since the cache may hold
///   other tags;
/// * the source build of the submodule,
///   `<root>/third_party/yse-soundengine/build/bin`, which the loader also
///   uses when `YSE_DLL_PATH` is unset.
bool isPinnedLocation({
  required String libDir,
  required String root,
  required String? tag,
  required bool caseSensitive,
}) {
  String n(String p) => normalizeDir(p, caseSensitive: caseSensitive);
  final dir = n(libDir);
  final base = n(root);
  if (dir == '$base/$submodulePath/build/bin') return true;
  if (tag == null) return false;
  return dir.startsWith('$base/$engineCacheDir/${n(tag)}/');
}

/// The notice to print when the loaded engine may not be the pinned release,
/// or null when it is.
///
/// [version] is the loaded library's `System.version`, [libDir] the directory
/// it was loaded from, [tag] the pinned tag (null when it could not be read;
/// [pinProblem] then says why). The library counts as the pinned release when
/// its version matches the tag *and* it was loaded from a pinned location:
/// libYSE's version string is a constant that only changes at release time,
/// so a dev build made right after a tag still reports that tag's version and
/// only its location gives it away.
///
/// An unreadable pin is tolerated without a notice when the library is the
/// submodule's own source build — that is how CI runs (its shallow submodule
/// checkout carries no tags), and that build is the pin by construction.
String? unpinnedEngineNotice({
  required String version,
  required String libDir,
  required String root,
  required String? tag,
  String? pinProblem,
  required bool caseSensitive,
}) {
  final pinnedPlace = isPinnedLocation(
    libDir: libDir,
    root: root,
    tag: tag,
    caseSensitive: caseSensitive,
  );
  final reasons = <String>[];
  if (tag == null) {
    if (pinnedPlace) return null;
    reasons.add(
      'the pinned tag could not be read'
      '${pinProblem == null ? '' : ' ($pinProblem)'}, so the engine cannot '
      'be checked against it',
    );
  } else if (!versionMatchesTag(version, tag)) {
    reasons.add('libYSE reports version "$version", the pin is $tag');
  }
  if (!pinnedPlace) {
    reasons.add(
      'it was loaded from outside the pinned locations '
      '($engineCacheDir/${tag ?? '<tag>'}/ and $submodulePath/build/bin)',
    );
  }
  if (reasons.isEmpty) return null;

  const rule =
      '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
  return [
    rule,
    '!!  UNRELEASED ENGINE: these tests may not run against the pinned libyse',
    '!!',
    '!!  pinned tag : ${tag ?? '(unknown)'}',
    '!!  loaded     : libYSE $version from $libDir',
    for (final r in reasons) '!!  - $r',
    '!!',
    '!!  Results can differ from CI, which always uses the pin; snapshot and',
    '!!  drift tests may fail for that reason alone. Bindings regenerated',
    '!!  against this engine must not be committed. For the pinned release:',
    '!!    dart run tool/fetch_engine.dart   (and set YSE_DLL_PATH to it)',
    rule,
  ].join('\n');
}
