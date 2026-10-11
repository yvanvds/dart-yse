// Pure-Dart tests for the pin helpers (tool/engine_pin.dart, #88/#89): tag
// parsing, the System.version-vs-tag comparison, the pinned-location check
// and when the unreleased-engine notice is raised. No git, no engine.

import 'package:test/test.dart';

import '../tool/engine_pin.dart';

void main() {
  group('parseReleaseTag', () {
    test('accepts release tags', () {
      expect(parseReleaseTag('v3.1.0\n'), 'v3.1.0');
      expect(parseReleaseTag('  v10.20.30  '), 'v10.20.30');
      expect(parseReleaseTag('v2.4.0-3'), 'v2.4.0-3');
      expect(parseReleaseTag('v3.2.0-rc.1'), 'v3.2.0-rc.1');
    });

    test('rejects output that is not a release tag', () {
      for (final bad in [
        '',
        '\n',
        '3.1.0',
        'v3.1',
        'dev',
        'v3.1.0-5-gda8ce99', // `git describe` without --exact-match
        'v3.1.0\nv3.1.1', // two tags on the commit
      ]) {
        expect(() => parseReleaseTag(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('versionMatchesTag', () {
    test('System.version matches its tag with the v prefix', () {
      expect(versionMatchesTag('3.1.0', 'v3.1.0'), isTrue);
      expect(versionMatchesTag(' 3.1.0\n', 'v3.1.0'), isTrue);
      expect(versionMatchesTag('10.0.12', 'v10.0.12'), isTrue);
    });

    test('a different release does not match', () {
      expect(versionMatchesTag('3.1.0', 'v3.1.1'), isFalse);
      expect(versionMatchesTag('3.2.0', 'v3.1.0'), isFalse);
      expect(versionMatchesTag('3.1.0', 'v3.1.0-rc.1'), isFalse);
      expect(versionMatchesTag('3.1', 'v3.1.0'), isFalse);
      expect(versionMatchesTag('3.1.0.1', 'v3.1.0'), isFalse);
    });

    test('the bare version or an empty string is not a tag', () {
      expect(versionMatchesTag('3.1.0', '3.1.0'), isFalse);
      expect(versionMatchesTag('v3.1.0', 'v3.1.0'), isFalse);
      expect(versionMatchesTag('', 'v'), isFalse);
    });
  });

  group('normalizeDir', () {
    test('unifies separators, dot segments and trailing slashes', () {
      expect(
        normalizeDir(r'D:\repo\.\a\..\b\', caseSensitive: true),
        'D:/repo/b',
      );
      expect(
        normalizeDir('/home/u//repo/', caseSensitive: true),
        '/home/u/repo',
      );
    });

    test('folds case only on case-insensitive file systems', () {
      expect(normalizeDir(r'D:\Repo', caseSensitive: false), 'd:/repo');
      expect(normalizeDir('/Repo', caseSensitive: true), '/Repo');
    });
  });

  group('isPinnedLocation', () {
    bool pinned(String dir, {String? tag = 'v3.1.0', bool cs = false}) =>
        isPinnedLocation(
          libDir: dir,
          root: r'D:\dart-yse',
          tag: tag,
          caseSensitive: cs,
        );

    test('accepts the fetched release of the pinned tag', () {
      expect(
        pinned(r'D:\dart-yse\.engine\v3.1.0\libyse-v3.1.0-windows-x64\bin'),
        isTrue,
      );
      expect(
        pinned(r'd:/DART-YSE/.engine/v3.1.0/libyse-v3.1.0-windows-x64/bin/'),
        isTrue,
      );
    });

    test('accepts the submodule source build, with or without a tag', () {
      const src = r'D:\dart-yse\third_party\yse-soundengine\build\bin';
      expect(pinned(src), isTrue);
      expect(pinned(src, tag: null), isTrue);
    });

    test('rejects a dev clone, another tag and an unknown pin', () {
      expect(pinned(r'D:\yse-soundengine\build\bin'), isFalse);
      expect(
        pinned(r'D:\dart-yse\.engine\v3.0.0\libyse-v3.0.0-windows-x64\bin'),
        isFalse,
      );
      expect(
        pinned(
          r'D:\dart-yse\.engine\v3.1.0\libyse-v3.1.0-windows-x64\bin',
          tag: null,
        ),
        isFalse,
      );
      // A sibling folder that merely shares the prefix is not the cache.
      expect(pinned(r'D:\dart-yse\.engine\v3.1.0-old\bin'), isFalse);
    });

    test('compares case-sensitively on Linux', () {
      expect(
        isPinnedLocation(
          libDir: '/home/u/Dart-yse/third_party/yse-soundengine/build/bin',
          root: '/home/u/dart-yse',
          tag: 'v3.1.0',
          caseSensitive: true,
        ),
        isFalse,
      );
    });
  });

  group('unpinnedEngineNotice', () {
    const root = r'D:\dart-yse';
    const fetched = r'D:\dart-yse\.engine\v3.1.0\libyse-v3.1.0-windows-x64\bin';
    const source = r'D:\dart-yse\third_party\yse-soundengine\build\bin';
    const devClone = r'D:\yse-soundengine\build\bin';

    String? notice({
      String version = '3.1.0',
      String libDir = fetched,
      String? tag = 'v3.1.0',
      String? problem,
    }) => unpinnedEngineNotice(
      version: version,
      libDir: libDir,
      root: root,
      tag: tag,
      pinProblem: problem,
      caseSensitive: false,
    );

    test('is silent for the pinned release, fetched or built', () {
      expect(notice(), isNull);
      expect(notice(libDir: source), isNull);
    });

    test(
      'is silent for CI: source build, pin unreadable in a shallow clone',
      () {
        expect(notice(libDir: source, tag: null, problem: 'no tag'), isNull);
      },
    );

    test('flags a version that differs from the pin', () {
      final n = notice(version: '3.2.0', libDir: source)!;
      expect(n, contains('UNRELEASED ENGINE'));
      expect(n, contains('libYSE reports version "3.2.0", the pin is v3.1.0'));
      expect(n, isNot(contains('outside the pinned locations')));
      expect(n, contains('must not be committed'));
    });

    test('flags a dev build that still reports the pinned version', () {
      // libYSE's VERSION constant only moves at release time, so a dev clone
      // built just after v3.1.0 still says "3.1.0"; its location gives it
      // away.
      final n = notice(libDir: devClone)!;
      expect(n, contains('UNRELEASED ENGINE'));
      expect(n, contains(devClone));
      expect(n, contains('outside the pinned locations'));
      expect(n, isNot(contains('reports version')));
    });

    test('flags both reasons at once', () {
      final n = notice(version: '3.2.0', libDir: devClone)!;
      expect(n, contains('reports version "3.2.0"'));
      expect(n, contains('outside the pinned locations'));
    });

    test('flags an unreadable pin when the build is not the submodule', () {
      final n = notice(
        libDir: devClone,
        tag: null,
        problem: 'the engine submodule is not checked out at a release tag',
      )!;
      expect(n, contains('pinned tag : (unknown)'));
      expect(n, contains('not checked out at a release tag'));
    });

    test('every line is marked so the banner stands out', () {
      final lines = notice(libDir: devClone)!.split('\n');
      expect(lines.every((l) => l.startsWith('!!')), isTrue);
    });
  });
}
