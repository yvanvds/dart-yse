// Source retention under garbage collection (issue #80, following #65;
// extended by #84 to linked chains, channel inserts, connected sinks and the
// order in which an owner and its borrowed objects are finalized).
//
// The engine borrows a sound's Patcher / Synth source, a sound's DSP chain
// head and a patcher insert's Patcher: it reads them on the audio thread but
// never owns them. Each of those Dart wrappers carries a NativeFinalizer, so
// if nothing on the Dart side keeps the wrapper reachable, garbage collection
// frees the native object under a live consumer. These tests drop the
// caller's only reference, force collections until an identical *unattached*
// control object has been collected (proving the GC really ran), and then
// check that the attached source was not collected and still renders.
//
// Requires `libyse.dll` / `libyse.so` — set `YSE_DLL_PATH` (see README).
// Threading (CLAUDE.md): everything runs on the isolate that called
// `System.initOffline()`; the session is headless.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

import 'support/sound_ready.dart';

/// Allocate until [control] has been collected (or a generous bound runs
/// out), then report whether it was. Short-lived garbage drives the
/// scavenger; the larger chunks push old-space collections too.
bool collectUntilCleared(WeakReference<Object> control) {
  var sink = <Object>[];
  for (var round = 0; round < 400 && control.target != null; round++) {
    sink = List<Object>.generate(20000, (i) => List<int>.filled(8, i));
    if (round.isEven) sink.add(List<int>.filled(1 << 20, round));
  }
  sink.clear();
  return control.target == null;
}

/// A patcher whose `~sine 440` feeds both `~dac` inputs.
@pragma('vm:never-inline')
Patcher sinePatcher() {
  final p = Patcher();
  final sine = p.createObject(Obj.dSine, args: '440');
  final dac = p.createObject(Obj.dDac);
  p.connect(sine, outlet: 0, to: dac, inlet: 0);
  p.connect(sine, outlet: 0, to: dac, inlet: 1);
  return p;
}

/// A playing sound over a fresh patcher, plus weak handles on that patcher
/// and on an unattached control patcher. No strong reference to either
/// patcher survives this frame.
@pragma('vm:never-inline')
(Sound, WeakReference<Patcher>, WeakReference<Patcher>) patcherSound() {
  final p = sinePatcher();
  final sound = Sound.fromPatcher(p)
    ..position = const Pos(0, 0, 1)
    ..play();
  return (sound, WeakReference(p), WeakReference(sinePatcher()));
}

/// A playing sound over a sine synth whose four voices have cloned, plus weak
/// handles on that synth and on an unattached control synth. The voice pump
/// runs here, on the strong local, so no temporary in the caller's frame can
/// keep the synth reachable.
@pragma('vm:never-inline')
(Sound, WeakReference<Synth>, WeakReference<Synth>) synthSound(System sys) {
  final synth = Synth()..addSineVoices(4, attack: 0.001, release: 0.01);
  final sound = Sound.fromSynth(synth)
    ..position = const Pos(0, 0, 1)
    ..play();
  for (var i = 0; i < 100 && synth.voiceCount < 4; i++) {
    sys.update();
    sys.renderOffline(4);
    sleep(const Duration(milliseconds: 5));
  }
  expect(synth.voiceCount, 4, reason: 'voices should clone');
  // No voices on the control: destroying a never-attached synth that has a
  // voice group crashes the engine on the next update (upstream
  // yvanvds/yse-soundengine#1175).
  final control = Synth();
  return (sound, WeakReference(synth), WeakReference(control));
}

@pragma('vm:never-inline')
(WeakReference<DspObject>, WeakReference<DspObject>) assignDsp(Sound sound) {
  final fx = DspObject.lowpass()..frequency = 8000;
  sound.dsp = fx;
  return (WeakReference(fx), WeakReference(DspObject.lowpass()));
}

@pragma('vm:never-inline')
(DspObject, WeakReference<Patcher>, WeakReference<Patcher>) patcherInsert() {
  final p = sinePatcher();
  return (
    DspObject.patcherInsert(p),
    WeakReference(p),
    WeakReference(sinePatcher()),
  );
}

// ─── #84: linked chains, sinks, channel inserts, finalizer order ──────────

/// A port index no host enumerates (CI has no MIDI devices).
const _noSuchPort = 65535;

/// Collect garbage *and* let the event loop run between rounds, so Dart
/// `Finalizer` callbacks are delivered, until [target] has been collected.
Future<bool> collectAsyncUntilCleared(WeakReference<Object> target) async {
  for (var round = 0; round < 50 && target.target != null; round++) {
    collectUntilCleared(target);
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  return target.target == null;
}

/// Links a fresh lowpass after [head]. Returns weak handles on it and on an
/// unlinked control.
@pragma('vm:never-inline')
(WeakReference<DspObject>, WeakReference<DspObject>) linkTail(DspObject head) {
  final tail = DspObject.lowpass()..frequency = 8000;
  head.link(tail);
  return (WeakReference(tail), WeakReference(DspObject.lowpass()));
}

/// `head.link(c)` then `head.link(b)`: the engine inserts `b` between `head`
/// and `c`. Returns weak handles on `b`, `c` and an unlinked control.
@pragma('vm:never-inline')
(WeakReference<DspObject>, WeakReference<DspObject>, WeakReference<DspObject>)
insertBetween(DspObject head) {
  final c = DspObject.highpass()..frequency = 20;
  head.link(c);
  final b = DspObject.lowpass()..frequency = 8000;
  head.link(b);
  return (
    WeakReference(b),
    WeakReference(c),
    WeakReference(DspObject.lowpass()),
  );
}

@pragma('vm:never-inline')
void disposeTarget(WeakReference<DspObject> fx) => fx.target!.dispose();

@pragma('vm:never-inline')
(WeakReference<DspObject>, WeakReference<DspObject>) insertOn(Channel ch) {
  final fx = DspObject.lowpass()..frequency = 8000;
  ch.dsp = fx;
  return (WeakReference(fx), WeakReference(DspObject.lowpass()));
}

/// A voice-less synth: destroying a never-attached synth is only unsafe once
/// it has a voice group (upstream yvanvds/yse-soundengine#1175).
@pragma('vm:never-inline')
(WeakReference<Synth>, WeakReference<MidiOut>, WeakReference<Synth>)
connectClipSinks(ClipTransport clip) {
  final synth = Synth();
  final out = MidiOut.open(_noSuchPort);
  clip.connectSynth(synth);
  clip.connectMidiOut(out);
  return (WeakReference(synth), WeakReference(out), WeakReference(Synth()));
}

@pragma('vm:never-inline')
void disconnectClipSinks(
  ClipTransport clip,
  WeakReference<Synth> synth,
  WeakReference<MidiOut> out,
) {
  clip.disconnectSynth(synth.target!);
  clip.disconnectMidiOut(out.target!);
}

@pragma('vm:never-inline')
(WeakReference<Synth>, WeakReference<Synth>) connectSynthTo(
  void Function(Synth) connect,
) {
  final synth = Synth();
  connect(synth);
  return (WeakReference(synth), WeakReference(Synth()));
}

/// A minimal type-0 Standard MIDI File: one track holding only end-of-track.
List<int> get emptyMidiFile => [
  ...'MThd'.codeUnits, 0, 0, 0, 6, 0, 0, 0, 1, 0, 96, //
  ...'MTrk'.codeUnits, 0, 0, 0, 4, 0, 0xFF, 0x2F, 0,
];

@pragma('vm:never-inline')
(WeakReference<Scale>, WeakReference<Scale>) setFirstPitch(Motif motif) {
  final scale = Scale()..add(60);
  motif.setFirstPitch(scale);
  return (WeakReference(scale), WeakReference(Scale()));
}

/// A sound over a buffer, with every strong reference to both dropped.
@pragma('vm:never-inline')
(WeakReference<Sound>, WeakReference<DspBuffer>) abandonedBufferSound() {
  final buffer = DspBuffer.plain(length: 4800);
  final sound = Sound.fromBuffer(buffer, loop: true)..play();
  return (WeakReference(sound), WeakReference(buffer));
}

/// A sound with an effect chain, with every strong reference dropped.
@pragma('vm:never-inline')
(WeakReference<Sound>, WeakReference<DspObject>) abandonedSoundWithDsp() {
  final head = DspObject.lowpass();
  final sound = Sound.fromPatcher(sinePatcher())..dsp = head;
  final (tail, _) = linkTail(head);
  return (WeakReference(sound), tail);
}

/// A clip connected to a voice-less synth, both references dropped.
@pragma('vm:never-inline')
(WeakReference<ClipTransport>, WeakReference<Synth>) abandonedClip(
  DomainClock clock,
) {
  final clip = ClipTransport(clock);
  final synth = Synth();
  clip.connectSynth(synth);
  return (WeakReference(clip), WeakReference(synth));
}

void main() {
  final sys = System.instance;

  setUpAll(sys.initOffline);
  tearDownAll(sys.close);

  /// Master post-fader peak over a few update + render cycles.
  double renderPeak() {
    var peak = 0.0;
    for (var i = 0; i < 20; i++) {
      sys.update();
      sys.renderOffline(4);
      final level = Channel.master.peakLinearPost();
      if (level > peak) peak = level;
    }
    return peak;
  }

  test('Sound.fromPatcher keeps its patcher alive', () {
    final (sound, source, control) = patcherSound();
    addTearDown(sound.dispose);
    pumpUntilReady(sys, sound);

    expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
    expect(source.target, isNotNull, reason: 'the sound must hold its source');
    expect(renderPeak(), greaterThan(0.01));
  });

  test('Sound.fromSynth keeps its synth alive', () {
    final (sound, source, control) = synthSound(sys);
    addTearDown(sound.dispose);

    expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
    final synth = source.target;
    expect(synth, isNotNull, reason: 'the sound must hold its source');
    expect(synth!.voiceCount, 4);
    synth.noteOn(69, channel: 1, velocity: 1);
    expect(renderPeak(), greaterThan(0.01));
    synth.allNotesOff();
  });

  test('Sound.dsp keeps the assigned chain head alive', () {
    final (sound, _, _) = patcherSound();
    addTearDown(sound.dispose);
    final (fx, control) = assignDsp(sound);
    pumpUntilReady(sys, sound);

    expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
    expect(fx.target, isNotNull, reason: 'the sound must hold its effect');
    expect(renderPeak(), greaterThan(0.01));
  });

  test('DspObject.patcherInsert keeps its patcher alive', () {
    final (insert, source, control) = patcherInsert();
    addTearDown(insert.dispose);

    expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
    expect(
      source.target,
      isNotNull,
      reason: 'the insert must hold its patcher',
    );
  });

  group('linked DSP chains (#84)', () {
    test('DspObject.link keeps the linked successor alive', () {
      final (sound, _, _) = patcherSound();
      addTearDown(sound.dispose);
      final head = DspObject.lowpass()..frequency = 8000;
      addTearDown(head.dispose);
      sound.dsp = head;
      final (tail, control) = linkTail(head);
      pumpUntilReady(sys, sound);

      expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
      expect(tail.target, isNotNull, reason: 'the head must hold its tail');
      expect(identical(head.next, tail.target), isTrue);
      expect(renderPeak(), greaterThan(0.01));
    });

    test('an inserted-between object and the old successor both stay held, '
        'and dispose splices', () {
      final head = DspObject.lowpass();
      addTearDown(head.dispose);
      final (b, c, control) = insertBetween(head);

      expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
      expect(b.target, isNotNull, reason: 'head must hold b');
      expect(c.target, isNotNull, reason: 'b must hold the old successor c');
      expect(identical(head.next, b.target), isTrue);
      expect(identical(b.target!.next, c.target), isTrue);

      // Disposing b splices it out natively; head must now hold c itself.
      disposeTarget(b);
      final control2 = WeakReference(DspObject.lowpass());
      expect(collectUntilCleared(control2), isTrue, reason: 'GC never ran');
      expect(c.target, isNotNull, reason: 'head must take over c');
      expect(identical(head.next, c.target), isTrue);
      expect(c.target!.next, isNull);
    });

    test('unlink releases the detached successor', () {
      final head = DspObject.lowpass();
      addTearDown(head.dispose);
      final (tail, _) = linkTail(head);
      head.unlink();
      expect(head.next, isNull);
      expect(
        collectUntilCleared(tail),
        isTrue,
        reason: 'an unlinked object must not stay held',
      );
    });
  });

  group('Channel.dsp (#84)', () {
    test('Channel.master.dsp keeps the insert alive across fresh wrappers', () {
      addTearDown(() => Channel.master.dsp = null);
      final (sound, _, _) = patcherSound();
      addTearDown(sound.dispose);
      final (fx, control) = insertOn(Channel.master);
      pumpUntilReady(sys, sound);

      expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
      expect(fx.target, isNotNull, reason: 'the channel must hold its insert');
      expect(identical(Channel.master.dsp, fx.target), isTrue);
      expect(renderPeak(), greaterThan(0.01));
    });

    test('a disposed channel releases its insert', () {
      final ch = Channel.create('retention', parent: Channel.master);
      final (fx, _) = insertOn(ch);
      ch.dispose();
      expect(collectUntilCleared(fx), isTrue);
    });
  });

  group('connectSynth / connectMidiOut sinks (#84)', () {
    test('ClipTransport holds its sinks until they are disconnected', () {
      final clock = DomainClock('retention-clip', tempo: 120);
      addTearDown(clock.dispose);
      final clip = ClipTransport(clock);
      addTearDown(clip.dispose);
      final (synth, out, control) = connectClipSinks(clip);

      expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
      expect(synth.target, isNotNull, reason: 'the clip must hold its synth');
      expect(out.target, isNotNull, reason: 'the clip must hold its port');

      disconnectClipSinks(clip, synth, out);
      expect(collectUntilCleared(synth), isTrue);
      expect(collectUntilCleared(out), isTrue);
    });

    test('MidiFile holds a connected synth', () {
      final dir = Directory.systemTemp.createTempSync('yse_retention');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}empty.mid';
      File(path).writeAsBytesSync(emptyMidiFile);
      final file = MidiFile(path);
      addTearDown(file.dispose);
      final (synth, control) = connectSynthTo(file.connectSynth);

      expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
      expect(synth.target, isNotNull, reason: 'the file must hold its synth');
    });

    test('MidiIn holds a connected synth', () {
      final port = MidiIn.open(_noSuchPort);
      addTearDown(port.dispose);
      final (synth, control) = connectSynthTo(port.connectSynth);

      expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
      expect(synth.target, isNotNull, reason: 'the port must hold its synth');
    });

    test('Motif.setFirstPitch holds its scale', () {
      final motif = Motif();
      addTearDown(motif.dispose);
      final (scale, control) = setFirstPitch(motif);

      expect(collectUntilCleared(control), isTrue, reason: 'GC never ran');
      expect(scale.target, isNotNull, reason: 'the motif must hold its scale');
    });
  });

  // When an owner and what it borrows become unreachable in the same
  // collection, their NativeFinalizers run in unspecified order. Borrowed
  // objects must still be destroyed strictly after the owner: they stay held
  // until the owner's own collection has run its native destroy, and are
  // released only once the event loop delivers the owner's Dart finalizer.
  group('finalizer order (#84)', () {
    test('a sound is destroyed before its buffer', () async {
      final (sound, buffer) = abandonedBufferSound();
      sys.update();

      expect(collectUntilCleared(sound), isTrue, reason: 'GC never ran');
      expect(
        buffer.target,
        isNotNull,
        reason: 'the buffer must outlive the collected sound',
      );
      expect(await collectAsyncUntilCleared(buffer), isTrue);
    });

    test('a sound is destroyed before its effect chain', () async {
      final (sound, tail) = abandonedSoundWithDsp();
      sys.update();

      expect(collectUntilCleared(sound), isTrue, reason: 'GC never ran');
      expect(tail.target, isNotNull, reason: 'the chain must outlive it');
      expect(await collectAsyncUntilCleared(tail), isTrue);
    });

    test('a clip is destroyed before its synth', () async {
      final clock = DomainClock('retention-order', tempo: 120);
      addTearDown(clock.dispose);
      final (clip, synth) = abandonedClip(clock);

      expect(collectUntilCleared(clip), isTrue, reason: 'GC never ran');
      expect(synth.target, isNotNull, reason: 'the synth must outlive it');
      expect(await collectAsyncUntilCleared(synth), isTrue);
    });
  });
}
