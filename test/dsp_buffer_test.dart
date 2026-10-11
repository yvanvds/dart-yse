// Tests for the DspBuffer family (issue #55).
//
// Engine 3.0 moved the subclass check out of the C API: the subclass entry
// points (draw_line, load_file, wavetable_create_*, ...) static_cast the
// handle and trust the caller, so calling one on a narrower buffer returns
// YSE_OK and writes through a mistyped pointer. The wrapper enforces the
// subclass through the Dart type hierarchy instead, which these tests pin.
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md).
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

void main() {
  late System sys;

  setUpAll(() {
    sys = System.instance;
    sys.initOffline();
  });

  tearDownAll(() {
    sys.close();
  });

  T owned<T extends DspBuffer>(T buffer) {
    addTearDown(buffer.dispose);
    return buffer;
  }

  group('subclass enforcement', () {
    test('a plain buffer has no drawLine: it throws without native access', () {
      final plain = owned(DspBuffer.plain(length: 16));
      plain.fill(0.25);

      // Dynamic dispatch is the only way to even attempt the call; it must
      // fail in Dart, before any FFI call writes through a mistyped pointer.
      expect(
        () => (plain as dynamic).drawLine(
          start: 0,
          stop: 15,
          startValue: -1.0,
          stopValue: 1.0,
        ),
        throwsNoSuchMethodError,
      );
      // Untouched.
      expect(plain.read(), everyElement(closeTo(0.25, 1e-6)));
    });

    test('narrower buffers lack the wider entry points', () {
      final plain = owned(DspBuffer.plain(length: 16));
      final drawable = owned(DrawableBuffer(length: 16));
      final file = owned(FileBuffer(length: 16));

      expect(plain, isNot(isA<DrawableBuffer>()));
      expect(drawable, isNot(isA<FileBuffer>()));
      expect(file, isNot(isA<Wavetable>()));
      expect(
        () => (drawable as dynamic).loadFile('x.wav'),
        throwsNoSuchMethodError,
      );
      expect(
        () => (file as dynamic).createSaw(harmonics: 4, length: 16),
        throwsNoSuchMethodError,
      );
    });

    test('the chain is linear: a wider buffer accepts every base entry', () {
      final table = owned(Wavetable(length: 64));
      expect(table, isA<FileBuffer>());
      expect(table, isA<DrawableBuffer>());
      expect(table, isA<DspBuffer>());

      table.createSaw(harmonics: 8, length: 64);
      expect(table.isSilent, isFalse);
      table.drawFlat(start: 0, stop: table.length - 1, value: 0.0);
      expect(table.maxValue, closeTo(0.0, 1e-6));
    });
  });

  group('subclass operations', () {
    test('DrawableBuffer draws a ramp', () {
      final buf = owned(DrawableBuffer(length: 101));
      buf.drawLine(start: 0, stop: 100, startValue: 0.0, stopValue: 1.0);
      final samples = buf.read();
      expect(samples.first, closeTo(0.0, 1e-3));
      expect(samples[50], closeTo(0.5, 2e-2));
      expect(buf.maxValue, closeTo(1.0, 2e-2));
    });

    test('FileBuffer saves and reloads a WAV', () {
      final dir = Directory.systemTemp.createTempSync('yse_dsp_buffer_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}ramp.wav';

      final out = owned(FileBuffer(length: 256));
      out.drawLine(start: 0, stop: 255, startValue: -0.5, stopValue: 0.5);
      out.saveFile(path);
      expect(File(path).existsSync(), isTrue);

      final back = owned(FileBuffer(length: 256));
      back.loadFile(path);
      expect(back.maxValue, closeTo(0.5, 1e-2));
    });

    test('FileBuffer.loadFile on a missing file throws YseException', () {
      final buf = owned(FileBuffer(length: 16));
      expect(
        () => buf.loadFile('definitely-not-here-$pid.wav'),
        throwsA(isA<YseException>()),
      );
    });
  });
}
