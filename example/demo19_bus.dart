// Global bus example — publish, subscribe and tap.
//
// The engine's bus is one message plane shared by the host, patchers,
// synths, sounds, channels and live-coding scripts. This demo:
//
//   1. taps everything under "synth.lead." and subscribes to one exact
//      host address,
//   2. names a synth, a sound, a channel and a patcher so they answer on
//      the bus (synth.<name>.*, sound.<name>.*, channel.<name>.*,
//      patcher.<name>.<slot>),
//   3. plays a short phrase and moves the mix purely through
//      Bus.publish — no direct method calls on the objects.
//
// Run from the dart-yse package root:
//   dart run example/demo19_bus.dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

String _resource(String name) => File(
  [
    'third_party',
    'yse-soundengine',
    'TestResources',
    name,
  ].join(Platform.pathSeparator),
).absolute.path;

/// Pump the engine for [ms] milliseconds. Awaiting between ticks lets the
/// bus streams deliver their events.
Future<void> pump(System sys, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    sys.update();
    await Future<void>.delayed(const Duration(milliseconds: 16));
  }
}

Future<void> main() async {
  final sys = System.instance;
  sys.init();

  // 1) Listen. A tap matches an address prefix, a subscription one exact
  //    address. Both see host publishes as well as engine ones.
  final tap = Bus.tap(
    'synth.lead.',
  ).listen((f) => print('[tap] ${f.address} = ${f.value}'));
  final status = Bus.subscribe(
    'demo.status',
  ).listen((f) => print('[demo.status] ${f.value}'));

  // 2) Name things. Bus names only take effect between init and close.
  //    Add a synth's voices right after Synth().
  final synth = Synth()..addSineVoices(8, attack: 0.01, release: 0.3);
  synth.busName = 'lead';
  final lead = Sound.fromSynth(synth, volume: 0.5)..play();

  Channel.ambient.busName = 'ambient';
  final drone = Sound.fromFile(
    _resource('drone.ogg'),
    channel: Channel.ambient,
    loop: true,
    volume: 0.4,
  )..busName = 'drone';
  drone.play();

  // A patcher named "tone": its `.r freq` hears patcher.tone.freq.
  final patcher = Patcher(mainOutputs: 1, name: 'tone');
  final sine = patcher.createObject(Obj.dSine, args: '220');
  final dac = patcher.createObject(Obj.dDac);
  final freq = patcher.createObject(Obj.gReceive, args: 'freq');
  patcher.connect(sine, outlet: 0, to: dac, inlet: 0);
  patcher.connect(freq, outlet: 0, to: sine, inlet: 0);
  final tone = Sound.fromPatcher(patcher, volume: 0.1)..play();

  // A sound drops bus values that arrive before it has loaded, and a synth
  // plays nothing until its voices are cloned.
  while (!drone.isReady || synth.voiceCount == 0) {
    await pump(sys, 16);
  }
  Bus.publish('demo.status', const BusString('ready'));

  // 3) Drive everything through the bus.
  print('Playing a phrase on synth.lead.note ...');
  for (final pitch in [60, 64, 67, 72]) {
    Bus.publish('synth.lead.note', BusList([1, pitch.toDouble(), 0.8]));
    await pump(sys, 250);
    Bus.publish('synth.lead.off', BusList([1, pitch.toDouble()]));
  }

  print('Moving the drone sound and the tone patcher ...');
  Bus.publish('sound.drone.position', const BusList([3, 0, 1]));
  Bus.publish('patcher.tone.freq', const BusFloat(330));
  await pump(sys, 1000);

  print('Fading the ambient channel through channel.ambient.volume ...');
  for (var v = 1.0; v >= 0.0; v -= 0.1) {
    Bus.publish('channel.ambient.volume', BusFloat(v));
    await pump(sys, 100);
  }

  Bus.publish('demo.status', const BusString('done'));
  await pump(sys, 100);
  print('Done. (missed callbacks=${sys.missedCallbacks})');

  // Cancel before close (close() would also close the streams).
  await tap.cancel();
  await status.cancel();
  lead.dispose();
  tone.dispose();
  drone.dispose();
  sys.close();
  exit(0);
}
