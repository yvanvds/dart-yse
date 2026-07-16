// Pure-Dart unit tests for the [ReverbPresetValues] value class (issue #38).
//
// These exercise only Dart-side logic — defaults, length validation, equality
// and immutability — so they need neither the engine nor `libyse.dll`.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yse/yse.dart';

void main() {
  group('ReverbPresetValues', () {
    test('defaults every field to zero with length-4 reflection lists', () {
      final v = ReverbPresetValues();
      expect(v.roomSize, 0);
      expect(v.damping, 0);
      expect(v.dry, 0);
      expect(v.wet, 0);
      expect(v.modulationFrequency, 0);
      expect(v.modulationWidth, 0);
      expect(v.earlyTimes, [0, 0, 0, 0]);
      expect(v.earlyGains, [0, 0, 0, 0]);
    });

    test('rejects reflection lists that are not exactly length 4', () {
      expect(
        () => ReverbPresetValues(earlyTimes: [1, 2, 3]),
        throwsArgumentError,
      );
      expect(
        () => ReverbPresetValues(earlyGains: [1, 2, 3, 4, 5]),
        throwsArgumentError,
      );
    });

    test('exposes unmodifiable reflection lists', () {
      final v = ReverbPresetValues(earlyTimes: [1, 2, 3, 4]);
      expect(() => v.earlyTimes[0] = 9, throwsUnsupportedError);
    });

    test('implements value equality and hashCode', () {
      final a = ReverbPresetValues(
        roomSize: 0.5,
        wet: 1.0,
        earlyTimes: [1, 2, 3, 4],
        earlyGains: [0.1, 0.2, 0.3, 0.4],
      );
      final b = ReverbPresetValues(
        roomSize: 0.5,
        wet: 1.0,
        earlyTimes: [1, 2, 3, 4],
        earlyGains: [0.1, 0.2, 0.3, 0.4],
      );
      final c = ReverbPresetValues(roomSize: 0.6);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
