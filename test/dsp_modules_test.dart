// Integration smoke tests for the mix-grade DSP modules (issue #25):
// compressor, parametric EQ, chorus, plate reverb and feedback delay, plus
// the granulator getters completed alongside them.
//
// These drive the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test
//
// Threading (CLAUDE.md Boundaries): everything runs on the one isolate that
// calls `System.initOffline()`. The offline path is headless — it drives the
// engine via `renderOffline()` rather than an audio device.
@TestOn('vm')
library;

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

  group('Compressor', () {
    test('constructs and round-trips its parameters', () {
      final comp = Compressor();
      addTearDown(comp.dispose);

      comp.detector = CompressorDetector.rms;
      comp.threshold = -18.0;
      comp.ratio = 4.0;
      comp.attack = 5.0;
      comp.release = 120.0;
      comp.makeup = 3.0;

      expect(comp.detector, CompressorDetector.rms);
      expect(comp.threshold, closeTo(-18.0, 1e-3));
      expect(comp.ratio, closeTo(4.0, 1e-3));
      expect(comp.attack, closeTo(5.0, 1e-3));
      expect(comp.release, closeTo(120.0, 1e-3));
      expect(comp.makeup, closeTo(3.0, 1e-3));

      // Read-only meter is queryable; with no signal there is no reduction.
      expect(comp.gainReductionDb, isA<double>());
      expect(comp.gainReductionDb, lessThanOrEqualTo(1e-3));

      // Inherited dspObject surface still works on the subclass.
      comp.impact = 0.5;
      expect(comp.impact, closeTo(0.5, 1e-6));
    });
  });

  group('ParametricEq', () {
    test('constructs and round-trips per-band parameters', () {
      final eq = ParametricEq();
      addTearDown(eq.dispose);

      eq.setFrequency(EqBand.peak1, 1000.0);
      eq.setGain(EqBand.peak1, -6.0);
      eq.setQ(EqBand.peak1, 1.5);

      expect(eq.getFrequency(EqBand.peak1), closeTo(1000.0, 1e-2));
      expect(eq.getGain(EqBand.peak1), closeTo(-6.0, 1e-3));
      expect(eq.getQ(EqBand.peak1), closeTo(1.5, 1e-3));

      // Bands are independent — the untouched high shelf stays flat.
      expect(eq.getGain(EqBand.highShelf), closeTo(0.0, 1e-3));
    });
  });

  group('Chorus', () {
    test('constructs and round-trips its parameters', () {
      final chorus = Chorus();
      addTearDown(chorus.dispose);

      chorus.mode = ChorusMode.flanger;
      chorus.rate = 0.8;
      chorus.depth = 0.5;
      chorus.feedback = 0.3;
      chorus.spread = 0.7;

      expect(chorus.mode, ChorusMode.flanger);
      expect(chorus.rate, closeTo(0.8, 1e-3));
      expect(chorus.depth, closeTo(0.5, 1e-3));
      expect(chorus.feedback, closeTo(0.3, 1e-3));
      expect(chorus.spread, closeTo(0.7, 1e-3));
    });
  });

  group('PlateReverb', () {
    test('constructs and round-trips its parameters', () {
      final plate = PlateReverb();
      addTearDown(plate.dispose);

      plate.decay = 0.7;
      plate.damping = 4000.0;
      plate.predelay = 20.0;

      expect(plate.decay, closeTo(0.7, 1e-3));
      expect(plate.damping, closeTo(4000.0, 1e-1));
      expect(plate.predelay, closeTo(20.0, 1e-3));
    });
  });

  group('FeedbackDelay', () {
    test('constructs and round-trips its parameters', () {
      final delay = FeedbackDelay();
      addTearDown(delay.dispose);

      delay.time = 250.0;
      delay.feedback = 0.4;
      delay.damping = 3000.0;
      delay.crossfeed = 0.6;

      expect(delay.time, closeTo(250.0, 1e-2));
      expect(delay.feedback, closeTo(0.4, 1e-3));
      expect(delay.damping, closeTo(3000.0, 1e-1));
      expect(delay.crossfeed, closeTo(0.6, 1e-3));
    });
  });

  group('MorphingReverb (issue #38)', () {
    test('constructs, round-trips custom endpoint values and morph', () {
      final rev = MorphingReverb();
      addTearDown(rev.dispose);

      final a = ReverbPresetValues(
        roomSize: 0.8,
        damping: 0.3,
        dry: 0.0,
        wet: 1.0,
        modulationFrequency: 1.5,
        modulationWidth: 0.2,
        earlyTimes: [100, 200, 300, 400],
        earlyGains: [0.9, 0.7, 0.5, 0.3],
      );
      rev.presetAValues = a;

      final readback = rev.presetAValues;
      expect(readback.roomSize, closeTo(0.8, 1e-3));
      expect(readback.damping, closeTo(0.3, 1e-3));
      expect(readback.dry, closeTo(0.0, 1e-3));
      expect(readback.wet, closeTo(1.0, 1e-3));
      expect(readback.modulationFrequency, closeTo(1.5, 1e-3));
      expect(readback.modulationWidth, closeTo(0.2, 1e-3));
      expect(readback.earlyTimes[0], closeTo(100, 1e-1));
      expect(readback.earlyTimes[3], closeTo(400, 1e-1));
      expect(readback.earlyGains[0], closeTo(0.9, 1e-3));
      expect(readback.earlyGains[3], closeTo(0.3, 1e-3));

      // Named-preset setters take effect on both slots.
      rev.presetA = ReverbPreset.cave;
      rev.presetB = ReverbPreset.bathroom;

      // Morph control round-trips and clamps to [0, 1].
      rev.morph = 0.35;
      expect(rev.morph, closeTo(0.35, 1e-3));
      rev.morph = 2.0;
      expect(rev.morph, closeTo(1.0, 1e-3));
    });

    test('attaches to a channel and renders', () {
      final ch = Channel.create('morph-fx', parent: Channel.master);
      addTearDown(ch.dispose);
      final rev = MorphingReverb();
      addTearDown(rev.dispose);

      rev.presetB = ReverbPreset.hall;
      rev.morph = 0.5;

      ch.dsp = rev;
      expect(ch.dsp, same(rev));
      sys.renderOffline(128);
      ch.dsp = null;
      expect(ch.dsp, isNull);
    });
  });

  group('Patcher-insert DSP module (issue #38)', () {
    test('wraps a patcher graph, attaches to a channel and renders', () {
      final patcher = Patcher();
      addTearDown(patcher.dispose);
      // A minimal pass-through graph: host buffer → ~adc → ~dac → host buffer.
      final adc = patcher.createObject(Obj.dAdc);
      final dac = patcher.createObject(Obj.dDac);
      patcher.connect(adc, outlet: 0, to: dac, inlet: 0);

      // The insert borrows the patcher — registered first so it is disposed
      // last (teardown is LIFO), keeping the patcher alive under the insert.
      final insert = DspObject.patcherInsert(patcher);
      addTearDown(insert.dispose);

      final ch = Channel.create('patcher-fx', parent: Channel.master);
      addTearDown(ch.dispose);
      ch.dsp = insert;
      expect(ch.dsp, same(insert));
      sys.renderOffline(128);
      ch.dsp = null;
      expect(ch.dsp, isNull);
    });
  });

  group('DspObject.link(null) detach (issue #42)', () {
    test('link(null) / unlink() do not throw and let a chain re-order', () {
      final head = DspObject.lowpass();
      addTearDown(head.dispose);
      final mid = DspObject.highpass();
      addTearDown(mid.dispose);
      final tail = DspObject.bandpass();
      addTearDown(tail.dispose);

      // Original order: head → mid → tail.
      head.link(mid);
      mid.link(tail);

      // Detach the forward edges so no stale `next` survives the re-order.
      // Passing null (and the unlink() convenience) must not throw.
      expect(() => mid.link(null), returnsNormally);
      expect(() => tail.unlink(), returnsNormally);

      // Re-link into a new order: head → tail → mid, terminating at mid.
      head.link(tail);
      tail.link(mid);
      mid.link(null);

      // The engine walks the re-linked chain (no cycle from a stale edge).
      final ch = Channel.create('relink-fx', parent: Channel.master);
      addTearDown(ch.dispose);
      ch.dsp = head;
      expect(ch.dsp, same(head));
      sys.renderOffline(128);
      ch.dsp = null;
      expect(ch.dsp, isNull);
    });

    test(
      'link(null) on a standalone object is a no-op that does not throw',
      () {
        final fx = DspObject.lowpass();
        addTearDown(fx.dispose);
        expect(() => fx.link(null), returnsNormally);
        expect(() => fx.unlink(), returnsNormally);
      },
    );
  });

  group('Granulator getters (issue #25)', () {
    test('grainLength and grainTranspose round-trip', () {
      final gran = DspObject.granulator();
      addTearDown(gran.dispose);

      gran.setGrainLength(samples: 2048);
      gran.setGrainTranspose(pitch: 1.5);

      expect(gran.grainLength, 2048);
      expect(gran.grainTranspose, closeTo(1.5, 1e-3));
    });
  });

  group('Channel insert integration', () {
    test('a mixed chain of new modules attaches and renders on a channel', () {
      final ch = Channel.create('mix-fx', parent: Channel.master);
      addTearDown(ch.dispose);

      final comp = Compressor();
      addTearDown(comp.dispose);
      final eq = ParametricEq();
      addTearDown(eq.dispose);
      final chorus = Chorus();
      addTearDown(chorus.dispose);
      final plate = PlateReverb();
      addTearDown(plate.dispose);
      final delay = FeedbackDelay();
      addTearDown(delay.dispose);

      // Link all five as a single insert chain, subclasses treated as the
      // shared DspObject base type throughout.
      comp.link(eq);
      eq.link(chorus);
      chorus.link(plate);
      plate.link(delay);

      ch.dsp = comp;
      expect(ch.dsp, same(comp));

      // The engine processes the channel with the whole chain live.
      sys.renderOffline(128);

      ch.dsp = null;
      expect(ch.dsp, isNull);
    });

    test('a single module attaches by itself and detaches', () {
      final ch = Channel.create('single-fx', parent: Channel.master);
      addTearDown(ch.dispose);
      final plate = PlateReverb();
      addTearDown(plate.dispose);

      expect(ch.dsp, isNull);
      ch.dsp = plate;
      expect(ch.dsp, same(plate));
      sys.renderOffline(128);
      ch.dsp = null;
      expect(ch.dsp, isNull);
    });
  });
}
