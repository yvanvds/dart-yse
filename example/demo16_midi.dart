// M6 example — MIDI file playback + MIDI device enumeration.
//
// Lists MIDI output devices, plays the bundled demo.mid file, and (if a
// MIDI output device is available) also sends a couple of Note-On/Off
// messages so you can verify the MIDI-out path works.
//
// Run:
//   YSE_DLL_PATH=D:\yse-soundengine\build\bin  dart run example/demo16_midi.dart

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:yse/yse.dart';

String _resource(String name) => File([
      'third_party',
      'yse-soundengine',
      'TestResources',
      name,
    ].join(Platform.pathSeparator)).absolute.path;

Future<void> main() async {
  final sys = System.instance;
  sys.init();

  // 1) Device enumeration.
  print('MIDI inputs : ${sys.midiInDeviceCount}');
  for (var i = 0; i < sys.midiInDeviceCount; i++) {
    print('  [$i] ${sys.midiInDeviceName(i)}');
  }
  print('MIDI outputs: ${sys.midiOutDeviceCount}');
  for (var i = 0; i < sys.midiOutDeviceCount; i++) {
    print('  [$i] ${sys.midiOutDeviceName(i)}');
  }

  // 2) Play the bundled MIDI file (synthesised by whatever soundfont
  //    you have installed on the OS — YSE itself doesn't render MIDI
  //    notes to audio; it sends them to the OS MIDI subsystem).
  final mid = MidiFile(_resource('demo.mid'));
  mid.play();
  print('Playing demo.mid for 5 s...');
  for (var i = 0; i < 300; i++) { sys.update(); sys.sleep(16); }
  mid.stop();

  // 3) Send a couple of raw MIDI messages to the first output port,
  //    if any. The MIDI Mapper is typically the first synth.
  if (sys.midiOutDeviceCount > 0) {
    final out = MidiOut.open(0);
    print('Sending C4 → E4 → G4 chord to "${sys.midiOutDeviceName(0)}"...');
    out.noteOn(channel: 0, pitch: 60, velocity: 90);
    out.noteOn(channel: 0, pitch: 64, velocity: 90);
    out.noteOn(channel: 0, pitch: 67, velocity: 90);
    for (var i = 0; i < 100; i++) { sys.update(); sys.sleep(16); }
    out.allNotesOff();
    out.dispose();
  }

  print('Done. (missed callbacks=${sys.missedCallbacks})');
  mid.dispose();
  sys.close();
  exit(0);
}
