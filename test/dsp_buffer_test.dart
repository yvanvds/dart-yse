// Tests for the DspBuffer family (issue #55), the buffer operations and
// multichannel buffers libYSE 3.0 added (issue #65).
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
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

import 'support/engine_pin.dart';

void main() {
  setUpAll(noticeUnpinnedEngine);

  late System sys;

  setUpAll(() {
    sys = System.instance;
    sys.requestedSampleRate = 48000;
    sys.initOffline();
  });

  tearDownAll(() {
    sys.close();
    sys.requestedSampleRate = 0;
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

  // Issue #65: the buffer operations libYSE 3.0 added to the C API.
  group('buffer math', () {
    DspBuffer filled(List<double> values) {
      final buf = owned(DspBuffer.plain(length: values.length));
      buf.write(Float32List.fromList(values));
      return buf;
    }

    test('add / sub / mul / div work sample by sample', () {
      final a = filled([1, 2, 3, 4]);
      final b = filled([4, 3, 2, 1]);

      a.addBuffer(b);
      expect(a.read(), [5, 5, 5, 5]);
      a.subBuffer(b);
      expect(a.read(), [1, 2, 3, 4]);
      a.mulBuffer(b);
      expect(a.read(), [4, 6, 6, 4]);
      a.divBuffer(b);
      expect(a.read(), [1, 2, 3, 4]);
    });

    test('operations cover the shorter length only', () {
      final long = filled([1, 1, 1, 1]);
      final short = filled([2, 2]);
      long.addBuffer(short);
      expect(long.read(), [3, 3, 1, 1]);
      short.mulBuffer(long);
      expect(short.read(), [6, 6]);
    });

    test('division by a zero sample gives 0', () {
      final a = filled([1, 2, 3]);
      final b = filled([1, 0, 3]);
      a.divBuffer(b);
      expect(a.read(), [1, 0, 1]);
    });

    test('a buffer may operate on itself', () {
      final a = filled([1, 2, 3]);
      a.addBuffer(a);
      expect(a.read(), [2, 4, 6]);
    });
  });

  group('copyFrom', () {
    test('copies a span between buffers', () {
      final src = owned(DspBuffer.plain(length: 8));
      src.write(Float32List.fromList([0, 1, 2, 3, 4, 5, 6, 7]));
      final dst = owned(DrawableBuffer(length: 6));
      dst.copyFrom(src, srcPos: 2, dstPos: 1, count: 4);
      expect(dst.read(), [0, 2, 3, 4, 5, 0]);
    });

    test('an out-of-range span throws and copies nothing', () {
      final src = owned(DspBuffer.plain(length: 8));
      src.fill(1.0);
      final dst = owned(DspBuffer.plain(length: 4));
      expect(
        () => dst.copyFrom(src, srcPos: 6, count: 3),
        throwsA(isA<YseException>()),
      );
      expect(
        () => dst.copyFrom(src, dstPos: 2, count: 3),
        throwsA(isA<YseException>()),
      );
      expect(() => dst.copyFrom(src, count: -1), throwsRangeError);
      expect(dst.isSilent, isTrue);
    });

    test('within one buffer: disjoint ranges copy, overlapping ones throw', () {
      final buf = owned(DspBuffer.plain(length: 6));
      buf.write(Float32List.fromList([1, 2, 3, 0, 0, 0]));
      buf.copyFrom(buf, srcPos: 0, dstPos: 3, count: 3);
      expect(buf.read(), [1, 2, 3, 1, 2, 3]);
      expect(
        () => buf.copyFrom(buf, srcPos: 0, dstPos: 2, count: 3),
        throwsArgumentError,
      );
      expect(buf.read(), [1, 2, 3, 1, 2, 3]);
    });
  });

  group('swap', () {
    test('exchanges samples; each buffer keeps its class and rate', () {
      final a = owned(DspBuffer.plain(length: 3));
      a.write(Float32List.fromList([1, 2, 3]));
      a.sampleRateAdjustment = 0.5;
      final b = owned(FileBuffer(length: 3));
      b.write(Float32List.fromList([7, 8, 9]));

      a.swap(b);
      expect(a.read(), [7, 8, 9]);
      expect(b.read(), [1, 2, 3]);
      expect(a.sampleRateAdjustment, closeTo(0.5, 1e-6));
      expect(b.sampleRateAdjustment, closeTo(1.0, 1e-6));
      expect(b, isA<FileBuffer>());
    });

    test('a length mismatch throws and swaps nothing', () {
      final a = owned(DspBuffer.plain(length: 3));
      a.fill(1.0);
      final b = owned(DspBuffer.plain(length: 4));
      b.fill(2.0);
      expect(() => a.swap(b), throwsA(isA<YseException>()));
      expect(a.read(), everyElement(1.0));
      expect(b.read(), everyElement(2.0));
    });
  });

  group('FileBuffer.fileSampleRate', () {
    test('is 0 before a load', () {
      expect(owned(FileBuffer(length: 16)).fileSampleRate, 0.0);
    });

    test('reports a 44.1 kHz file in a 48 kHz session, across re-init', () {
      final dir = Directory.systemTemp.createTempSync('yse_file_rate_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}tone44k.wav';
      _writeMonoWav16(path, sampleRate: 44100, frames: 441);

      expect(sys.sessionSampleRate, 48000);
      final buf = owned(FileBuffer(length: 441));
      buf.loadFile(path);
      expect(buf.fileSampleRate, 44100);
      expect(buf.sampleRateAdjustment, closeTo(44100 / 48000, 1e-6));

      // The native rate survives a re-init at another rate, so the playback
      // speed can be re-derived against the live session.
      try {
        sys.close();
        sys.requestedSampleRate = 96000;
        sys.initOffline();
        expect(buf.fileSampleRate, 44100);
        expect(
          buf.fileSampleRate / sys.sessionSampleRate,
          closeTo(44100 / 96000, 1e-6),
        );
      } finally {
        sys.close();
        sys.requestedSampleRate = 48000;
        sys.initOffline();
      }
    });
  });

  group('DspMultiBuffer', () {
    DspMultiBuffer ownedMulti(DspMultiBuffer mb) {
      addTearDown(mb.dispose);
      return mb;
    }

    test('copies its channels: the sources can be disposed', () {
      final left = DspBuffer.plain(length: 8)..fill(0.5);
      final right = DrawableBuffer(length: 4)..fill(0.25);
      final mb = ownedMulti(DspMultiBuffer([left, right]));
      left.dispose();
      right.dispose();
      expect(mb.channelCount, 2);
    });

    test('an empty channel list throws', () {
      expect(() => DspMultiBuffer([]), throwsArgumentError);
    });

    test('a disposed channel buffer throws YseException', () {
      final gone = DspBuffer.plain(length: 4)..dispose();
      expect(() => DspMultiBuffer([gone]), throwsA(isA<YseException>()));
    });

    test('dispose is idempotent and zeroes the channel count', () {
      final mb = DspMultiBuffer([owned(DspBuffer.plain(length: 4))]);
      mb.dispose();
      mb.dispose();
      expect(mb.channelCount, 0);
    });
  });

  group('Sound.fromMultiBuffer', () {
    // A 64-sample period puts whole cycles in every 128-sample meter block,
    // so the channel's per-block peak reads the tone's amplitude whatever
    // the playhead phase (upstream #925).
    Float32List tone(int length, double amp) => Float32List.fromList([
      for (var i = 0; i < length; i++) amp * math.sin(2 * math.pi * i / 64),
    ]);

    /// Plays a two-channel buffer whose channels are [left] and [right]
    /// (shorter one first, to check the length rule), and returns the
    /// channel's peak on outputs 0 and 1.
    Future<(double, double)> playStereo({
      required DspBuffer left,
      required DspBuffer right,
      required int expectLength,
    }) async {
      final mb = DspMultiBuffer([left, right]);
      // The multi-buffer holds copies; the sources can go right away.
      left.dispose();
      right.dispose();

      final ch = Channel.create('multibuffer65', parent: Channel.master);
      addTearDown(ch.dispose);
      final sound = Sound.fromMultiBuffer(mb, channel: ch, loop: true);
      addTearDown(() {
        sound.dispose();
        sys.update();
        sys.renderOffline(4);
        mb.dispose();
      });
      // Straight ahead with full spread: source channel 0 pans hard to the
      // first speaker, channel 1 to the second.
      sound.relative = true;
      sound.position = const Pos(0, 0, 1);
      sound.spread = 1.0;
      // The engine finishes the load on a worker; pump until it reports.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!sound.isReady && DateTime.now().isBefore(deadline)) {
        sys.update();
        sys.renderOffline(1);
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(sound.isReady, isTrue);
      expect(sound.length, expectLength);

      sound.play();
      var peak0 = 0.0, peak1 = 0.0;
      for (var i = 0; i < 20; i++) {
        sys.update();
        sys.renderOffline(1);
        peak0 = math.max(peak0, ch.peakLinearPost(output: 0));
        peak1 = math.max(peak1, ch.peakLinearPost(output: 1));
      }
      expect(sound.isPlaying, isTrue);
      return (peak0, peak1);
    }

    test(
      'a two-channel buffer plays as stereo, left and right as built',
      () async {
        final (l0, l1) = await playStereo(
          left: DspBuffer.plain(length: 24000)..write(tone(24000, 0.5)),
          right: DspBuffer.plain(length: 48000),
          expectLength: 24000,
        );
        expect(l0, greaterThan(0.25), reason: 'tone on the left channel');
        expect(l1, lessThan(l0 * 0.1), reason: 'right channel silent');

        final (r0, r1) = await playStereo(
          left: DrawableBuffer(length: 48000),
          right: FileBuffer(length: 48000)..write(tone(48000, 0.5)),
          expectLength: 48000,
        );
        expect(r1, greaterThan(0.25), reason: 'tone on the right channel');
        expect(r0, lessThan(r1 * 0.1), reason: 'left channel silent');
      },
    );
  });
}

/// Writes a 16-bit PCM mono WAV of a quiet 1 kHz-ish tone.
void _writeMonoWav16(
  String path, {
  required int sampleRate,
  required int frames,
}) {
  final data = ByteData(44 + frames * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + frames * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  for (var i = 0; i < frames; i++) {
    final v = (8000 * math.sin(2 * math.pi * i / 44)).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  File(path).writeAsBytesSync(data.buffer.asUint8List());
}
