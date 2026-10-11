// Source retention under garbage collection (issue #80, following #65).
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
}
