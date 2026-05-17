// M5 example — programmatic patcher graph as a sound source.
//
// Builds a tiny graph (sine → dac), wraps it in a Sound, plays for 3s,
// shifts pitch via a control message, dumps the graph to JSON, then
// rebuilds it from that JSON in a fresh patcher.
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo13_patcher.dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

Future<void> main() async {
  final sys = System.instance;
  sys.init();

  // Build: [~sine 220] → [~dac]
  final p = Patcher(mainOutputs: 1);
  final sine = p.createObject(Obj.dSine, args: '220');
  final dac = p.createObject(Obj.dDac);
  p.connect(sine, outlet: 0, to: dac, inlet: 0);

  // Also place a named receiver so we can pass a frequency in from Dart.
  final recv = p.createObject(Obj.gReceive, args: 'freq');
  p.connect(recv, outlet: 0, to: sine, inlet: 0);

  print('Patcher has ${p.objects} objects, sine.type=${sine.type}, '
      'sine.inputs=${sine.inputs}, sine.outputs=${sine.outputs}');

  final sound = Sound.fromPatcher(p, volume: 0.3);
  sound.play();
  print('Playing 220 Hz sine...');
  for (var i = 0; i < 100; i++) { sys.update(); sys.sleep(16); }

  // Send a new frequency through the named receiver.
  final ok = p.passFloat(440, 'freq');
  print('passFloat(440, "freq") = $ok — should be A4 now');
  for (var i = 0; i < 100; i++) { sys.update(); sys.sleep(16); }

  // Round-trip via JSON: dump the current graph, parse into a fresh
  // patcher, count objects.
  final json = p.dumpJson();
  print('JSON length = ${json.length} chars');

  final p2 = Patcher(mainOutputs: 1);
  p2.parseJson(json);
  print('Parsed graph: ${p2.objects} objects (original had ${p.objects})');

  print('Done. (missed callbacks=${sys.missedCallbacks})');
  sound.dsp = null;
  sound.stop();
  sys.close();
  exit(0);
}
