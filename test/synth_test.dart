// Integration + unit tests for the synth subsystem wrappers (issue #23):
// Synth, SfzInstrument, Dx7Bank, PositionHandler, the VaWaveform enum and the
// Sound.fromSynth attachment.
//
// The engine-touching cases drive the real `libyse.dll` / `libyse.so`, so they
// require the library to be resolvable — set `YSE_DLL_PATH` to the directory
// holding it (see README / CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test
//
// Threading (CLAUDE.md Boundaries): everything runs on the one isolate that
// calls `System.initOffline()`. The offline path is headless — it drives the
// engine via `renderOffline()` rather than an audio device. Voice cloning runs
// on the engine's background setup pool, so the tests pump `update()` +
// `renderOffline()` (with short sleeps) until `voiceCount` reflects the cloned
// pool, exactly as an app would poll a file-backed sound for readiness.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

/// Drive the engine until [synth] has cloned at least [want] voices, or a
/// bounded timeout elapses. Returns the final voice count.
int pumpVoices(System sys, Synth synth, int want) {
  var vc = synth.voiceCount;
  for (var i = 0; i < 60 && vc < want; i++) {
    sys.update();
    sys.renderOffline(128);
    vc = synth.voiceCount;
    if (vc >= want) break;
    sleep(const Duration(milliseconds: 10));
  }
  return vc;
}

/// Write a tiny valid 16-bit mono PCM WAV so libsndfile has a real sample to
/// decode for the sampler tests. Returns the file path.
String writeSampleWav(String dir) {
  const sampleRate = 8000;
  const numSamples = 800;
  const dataSize = numSamples * 2;
  final b = BytesBuilder();
  void ascii(String v) => b.add(v.codeUnits);
  void u32(int v) =>
      b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) =>
      b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  ascii('RIFF');
  u32(36 + dataSize);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(sampleRate);
  u32(sampleRate * 2); // byte rate
  u16(2); // block align
  u16(16); // bits per sample
  ascii('data');
  u32(dataSize);
  final samples = ByteData(dataSize);
  for (var i = 0; i < numSamples; i++) {
    samples.setInt16(i * 2, i.isEven ? 3000 : -3000, Endian.little);
  }
  b.add(samples.buffer.asUint8List());

  final path = '$dir${Platform.pathSeparator}sample.wav';
  File(path).writeAsBytesSync(b.toBytes());
  return path;
}

void main() {
  // ── Pure-Dart unit coverage (no engine required) ───────────────────────────

  group('VaWaveform (unit)', () {
    test('every value carries a distinct native code', () {
      final natives = VaWaveform.values.map((w) => w.native).toSet();
      expect(natives.length, VaWaveform.values.length);
    });
  });

  group('PositionHandler (unit)', () {
    test('the three built-in handler factories are const-constructible', () {
      const handlers = [
        PositionHandler.fixed(1, 2, 3),
        PositionHandler.randomSpread(radius: 2, seed: 7),
        PositionHandler.orbit(radius: 3, rate: 1.5),
      ];
      expect(handlers, hasLength(3));
    });
  });

  // ── Engine-touching integration coverage ───────────────────────────────────

  late System sys;
  late Directory tmpDir;
  late String samplePath;

  setUpAll(() {
    sys = System.instance;
    sys.initOffline();
    tmpDir = Directory.systemTemp.createTempSync('yse_synth_test');
    samplePath = writeSampleWav(tmpDir.path);
  });

  tearDownAll(() {
    sys.close();
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  group('Synth lifecycle', () {
    test('create, isValid, and dispose round-trip', () {
      final synth = Synth();
      expect(synth.isValid, isTrue);
      expect(synth.voiceCount, 0, reason: 'no voices added yet');

      synth.dispose();
      expect(synth.isValid, isFalse);
      // Idempotent.
      synth.dispose();
    });
  });

  group('Sine voices + playback', () {
    test('voices clone, a sound wraps the synth, and notes play', () {
      final synth = Synth();
      addTearDown(synth.dispose);
      synth.addSineVoices(6, channel: 0, attack: 0.005, release: 0.05);

      // Cloning is async on the setup pool; it starts once a sound renders the
      // synth. The wrapping sound is the user-visible readiness path.
      final sound = Sound.fromSynth(synth, volume: 0.7);
      addTearDown(sound.dispose);
      expect(sound.isValid, isTrue);

      final cloned = pumpVoices(sys, synth, 6);
      expect(cloned, 6, reason: 'the full requested pool should clone');

      // Drive notes, pedals and controllers — none of these should throw while
      // the engine renders.
      synth.noteOn(60, channel: 1, velocity: 0.8);
      synth.noteOn(64, channel: 1);
      synth.aftertouch(0.5, channel: 1, noteNumber: 60);
      synth.controller(1, 0.3, channel: 1); // mod wheel
      synth.pitchWheel(0.25, channel: 1);
      synth.sustain(true, channel: 1);
      sys.renderOffline(256);
      synth.sustain(false, channel: 1);
      synth.noteOff(60, channel: 1);
      synth.noteOff(64, channel: 1);
      synth.allNotesOff();
      sys.renderOffline(64);

      expect(synth.voiceCount, 6, reason: 'the pool size is stable');
    });
  });

  group('Virtual-analog voices', () {
    test('VA voices clone and every VA setter is a safe no-throw', () {
      final synth = Synth();
      addTearDown(synth.dispose);
      synth.addVaVoices(4);
      final sound = Sound.fromSynth(synth);
      addTearDown(sound.dispose);

      expect(pumpVoices(sys, synth, 4), 4);

      // Exercise the glitch-free atomic setters while a note sounds.
      synth.noteOn(48);
      synth
        ..setVaOscWave(0, VaWaveform.saw)
        ..setVaOscWave(1, VaWaveform.pulse)
        ..setVaOscDetune(1, 0.1)
        ..setVaOscLevel(0, 0.8)
        ..setVaOscPulseWidth(1, 0.4)
        ..setVaWavetablePosition(0.5)
        ..setVaCutoff(1800)
        ..setVaResonance(0.3)
        ..setVaKeyTracking(0.5)
        ..setVaFilterEnvAmount(2)
        ..setVaFilterVelAmount(1)
        ..setVaAmpAttack(0.01)
        ..setVaAmpDecay(0.2)
        ..setVaAmpSustain(0.7)
        ..setVaAmpRelease(0.3)
        ..setVaAmpVelAmount(0.5)
        ..setVaFilterAttack(0.01)
        ..setVaFilterDecay(0.2)
        ..setVaFilterSustain(0.6)
        ..setVaFilterRelease(0.3)
        ..setVaLfoType(LfoType.sine)
        ..setVaLfoRate(4)
        ..setVaLfoToPitch(0.5)
        ..setVaLfoToCutoff(1)
        ..setVaLfoToWavetable(0.2)
        ..setVaGain(0.9)
        ..loadVaWavetable(0, List<double>.filled(64, 0.0));
      sys.renderOffline(256);
      synth.noteOff(48);

      expect(synth.voiceCount, 4);
    });
  });

  group('FM voices', () {
    test('FM voices clone and every headline FM setter is a safe no-throw', () {
      final synth = Synth();
      addTearDown(synth.dispose);
      synth.addFmVoices(4);
      final sound = Sound.fromSynth(synth);
      addTearDown(sound.dispose);

      expect(pumpVoices(sys, synth, 4), 4);

      synth
        ..setFmAlgorithm(5)
        ..setFmFeedback(4)
        ..setFmTranspose(24)
        ..setFmLfoSpeed(35)
        ..setFmLfoDelay(0)
        ..setFmLfoWaveform(0)
        ..setFmLfoPitchModDepth(10)
        ..setFmLfoAmpModDepth(0)
        ..setFmPitchModSens(3);
      for (var op = 0; op < 6; op++) {
        synth
          ..setFmOpOutputLevel(op, 90)
          ..setFmOpFreqCoarse(op, 1)
          ..setFmOpFreqFine(op, 0)
          ..setFmOpDetune(op, 7)
          ..setFmOpOscMode(op, 0)
          ..setFmOpEnabled(op, true);
      }

      synth.noteOn(60);
      sys.renderOffline(256);
      synth.noteOff(60);
      expect(synth.voiceCount, 4);
    });
  });

  group('SFZ sampler voices', () {
    test('a one-region instrument loads and clones sampler voices', () {
      final inst = SfzInstrument.fromSample(
        samplePath,
        name: 'probe',
        root: 60,
        low: 48,
        high: 72,
      );
      expect(inst.isValid, isTrue);

      final synth = Synth();
      addTearDown(synth.dispose);
      synth.addSamplerVoices(inst, 3);
      // The voice group retains its own share, so disposing the instrument
      // right after add-voices is safe.
      inst.dispose();

      final sound = Sound.fromSynth(synth);
      addTearDown(sound.dispose);
      expect(pumpVoices(sys, synth, 3), 3);

      synth.noteOn(60);
      sys.renderOffline(256);
      synth.noteOff(60);
    });
  });

  group('Per-channel voice pools (#41)', () {
    // The channel + key-range arguments thread straight through the C ABI to
    // the engine's voice filter. These are smoke-level: they confirm each pool
    // kind accepts a non-omni channel and still clones + plays. Whether the
    // filter actually gates notes by channel is validated by the engine's own
    // tests, not here (CLAUDE.md: don't re-test engine-only behaviour).
    test('VA / FM / sampler pools build on a specific channel and clone', () {
      final inst = SfzInstrument.fromSample(
        samplePath,
        name: 'probe',
        root: 60,
        low: 48,
        high: 72,
      );

      final synth = Synth();
      addTearDown(synth.dispose);

      // Split three pools across three channels + key ranges — the point of
      // #41 is that each non-sine pool can register on its own MIDI channel.
      synth.addVaVoices(2, channel: 1, lowestNote: 0, highestNote: 59);
      synth.addFmVoices(2, channel: 2, lowestNote: 60, highestNote: 71);
      synth.addSamplerVoices(
        inst,
        2,
        channel: 3,
        lowestNote: 72,
        highestNote: 127,
      );
      // The sampler group retains its own share, so disposing here is safe.
      inst.dispose();

      final sound = Sound.fromSynth(synth);
      addTearDown(sound.dispose);

      // Six voices across the three channel-scoped pools.
      expect(pumpVoices(sys, synth, 6), 6);

      // A note on each pool's channel renders without throwing.
      synth.noteOn(48, channel: 1);
      synth.noteOn(64, channel: 2);
      synth.noteOn(80, channel: 3);
      sys.renderOffline(256);
      synth.noteOff(48, channel: 1);
      synth.noteOff(64, channel: 2);
      synth.noteOff(80, channel: 3);

      expect(synth.voiceCount, 6);
    });
  });

  group('Per-note position handlers', () {
    test('attaching handlers and steering positions never throws', () {
      final synth = Synth();
      addTearDown(synth.dispose);
      synth.addSineVoices(4, channel: 0);
      synth.setPositionHandler(const PositionHandler.orbit(radius: 2, rate: 1));

      final sound = Sound.fromSynth(synth);
      addTearDown(sound.dispose);
      expect(pumpVoices(sys, synth, 4), 4);

      synth.noteOn(60);
      synth.setHandlerCenter(1, 2, 3);
      synth.setNotePosition(60, 4, 5, 6, channel: 1);
      sys.renderOffline(256);
      synth.noteOff(60);
    });

    test(
      'getVoicePosition returns the origin for a note that is not sounding',
      () {
        final synth = Synth();
        addTearDown(synth.dispose);
        synth.addSineVoices(2, channel: 0);
        final sound = Sound.fromSynth(synth);
        addTearDown(sound.dispose);
        pumpVoices(sys, synth, 2);

        // Never played note 99 → best-effort snapshot is the origin.
        expect(synth.getVoicePosition(99), const Pos.zero());
      },
    );
  });

  group('Instrument loader error paths', () {
    test('loading a missing SFZ file throws', () {
      expect(
        () => SfzInstrument.load('does-not-exist.sfz'),
        throwsA(isA<YseException>()),
      );
    });

    test('loading a missing DX7 bank throws', () {
      expect(
        () => Dx7Bank.load('does-not-exist.syx'),
        throwsA(isA<YseException>()),
      );
    });
  });

  group('ClipTransport → Synth sink', () {
    test('a clip connects and disconnects an internal synth', () {
      final clock = DomainClock('synth-clip', tempo: 120);
      addTearDown(clock.dispose);
      final synth = Synth();
      addTearDown(synth.dispose);
      synth.addSineVoices(4, channel: 0);
      final sound = Sound.fromSynth(synth);
      addTearDown(sound.dispose);
      pumpVoices(sys, synth, 4);

      final clip = ClipTransport(clock);
      addTearDown(clip.dispose);
      clip.connectSynth(synth);
      clip.setEvents(const [
        ClipEvent(startBeat: 0, durationBeats: 1, channel: 1, pitch: 60),
        ClipEvent(startBeat: 1, durationBeats: 1, channel: 1, pitch: 64),
      ], loopBeats: 2);
      clip.play();
      sys.renderOffline(512);
      expect(clip.isPlaying, isTrue);

      clip.disconnectSynth(synth);
      clip.stop();
      expect(clip.isPlaying, isFalse);
    });
  });
}
