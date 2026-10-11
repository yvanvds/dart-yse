// Unit tests for the [ReverbPresetValues] value class (issues #38, #66).
//
// The value-class tests exercise only Dart-side logic — defaults, length
// validation, equality and immutability. The preset-table / morph tests
// (#66) call the engine's pure functions, so they need `libyse.dll`
// resolvable via `YSE_DLL_PATH`, but no engine session and no device.
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

  group('ReverbPresetValues preset table + lerp (issue #66)', () {
    test('fromPreset(off) matches the engine OFF values', () {
      expect(
        ReverbPresetValues.fromPreset(ReverbPreset.off),
        ReverbPresetValues(dry: 1.0),
      );
    });

    test('fromPreset(bathroom) carries its early reflections', () {
      final v = ReverbPresetValues.fromPreset(ReverbPreset.bathroom);
      expect(v.roomSize, closeTo(0.2, 1e-6));
      expect(v.damping, closeTo(0.1, 1e-6));
      expect(v.dry, closeTo(0.3, 1e-6));
      expect(v.wet, closeTo(0.7, 1e-6));
      expect(v.earlyTimes, [0, 20, 50, 85]);
      expect(v.earlyGains[0], 1.0);
      expect(v.earlyGains[3], closeTo(0.3, 1e-6));
    });

    test('lerp is exact at both endpoints and clamps t', () {
      final a = ReverbPresetValues.fromPreset(ReverbPreset.bathroom);
      final b = ReverbPresetValues.fromPreset(ReverbPreset.stoneroom);
      expect(ReverbPresetValues.lerp(a, b, 0), a);
      expect(ReverbPresetValues.lerp(a, b, 1), b);
      expect(ReverbPresetValues.lerp(a, b, -3), a);
      expect(ReverbPresetValues.lerp(a, b, 7), b);
    });

    test('lerp blends every field linearly', () {
      final a = ReverbPresetValues(
        roomSize: 0,
        wet: 1,
        earlyTimes: [0, 0, 0, 0],
        earlyGains: [0, 0, 0, 0],
      );
      final b = ReverbPresetValues(
        roomSize: 1,
        wet: 0,
        modulationFrequency: 2,
        earlyTimes: [100, 200, 300, 400],
        earlyGains: [1, 1, 1, 1],
      );
      final m = ReverbPresetValues.lerp(a, b, 0.5);
      expect(m.roomSize, closeTo(0.5, 1e-6));
      expect(m.wet, closeTo(0.5, 1e-6));
      expect(m.modulationFrequency, closeTo(1.0, 1e-6));
      expect(m.earlyTimes, [50, 100, 150, 200]);
      expect(m.earlyGains, [0.5, 0.5, 0.5, 0.5]);
    });
  });
}
