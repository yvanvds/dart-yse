// Tests for `MidiOut.raw` (issue #68, libYSE #748 / #903): sending a MIDI
// message byte for byte, which is the only way to send two-byte messages and
// SysEx.
//
// The message validation is pure Dart and needs no device. The engine-facing
// part drives the real `libyse.dll` / `libyse.so`, so the library must be
// resolvable — set `YSE_DLL_PATH` to the directory holding it (see README /
// CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test test/midi_out_test.dart
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test test/midi_out_test.dart
//
// CI has no MIDI device (and a dev box's devices are not ours to send to), so
// the engine tests only use a port that cannot exist. Its documented
// behaviour is that the port stays unopened and every send is a silent
// no-op; what is checked is that `raw` gets two-byte and long SysEx messages
// across the FFI boundary without throwing or crashing, and that a bad
// message is refused in Dart before it reaches the engine.
//
// Not covered: the bytes arriving on the wire. That needs a virtual or
// loopback MIDI port, which neither the Windows nor the Linux CI runner has.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yse/src/midi.dart' show validateMidiRaw;
import 'package:yse/yse.dart';

/// A port index no host enumerates.
const _noSuchPort = 65535;

void main() {
  group('validateMidiRaw accepts', () {
    final valid = <String, List<int>>{
      'note on': [0x90, 60, 100],
      'note off': [0x8F, 60, 0],
      'poly pressure': [0xA2, 60, 10],
      'control change': [0xB0, 7, 127],
      'pitch bend': [0xE0, 0x00, 0x40],
      'program change (2 bytes)': [0xC0, 5],
      'channel pressure (2 bytes)': [0xDF, 64],
      'MTC quarter frame': [0xF1, 0x21],
      'song position': [0xF2, 0x10, 0x02],
      'song select': [0xF3, 3],
      'tune request': [0xF6],
      'timing clock': [0xF8],
      'system reset': [0xFF],
      'short SysEx': [0xF0, 0x7E, 0x7F, 0x09, 0x01, 0xF7],
      'empty SysEx': [0xF0, 0xF7],
      'long SysEx': [0xF0, for (var i = 0; i < 4096; i++) i & 0x7F, 0xF7],
    };
    valid.forEach((name, bytes) {
      test(name, () => expect(() => validateMidiRaw(bytes), returnsNormally));
    });
  });

  group('validateMidiRaw rejects', () {
    final invalid = <String, List<int>>{
      'a value above 255': [0x90, 60, 256],
      'a negative value': [0x90, -1, 100],
      'a leading data byte (running status)': [60, 100],
      'a data byte with the high bit set': [0x90, 0x80, 100],
      'a 3-byte program change': [0xC0, 5, 0],
      'a 2-byte note on': [0x90, 60],
      'a 4-byte control change': [0xB0, 7, 100, 0],
      'two messages in one call': [0x90, 60, 100, 0x80, 60, 0],
      'a realtime byte with data': [0xF8, 0],
      'SysEx without 0xF7': [0xF0, 0x7E, 0x7F],
      'SysEx of a single 0xF0': [0xF0],
      'SysEx with a status byte inside': [0xF0, 0x7E, 0x90, 0xF7],
      'a stray 0xF7': [0xF7],
      'undefined 0xF4': [0xF4],
      'undefined 0xF5': [0xF5],
    };
    invalid.forEach((name, bytes) {
      test(name, () {
        expect(() => validateMidiRaw(bytes), throwsArgumentError);
      });
    });
  });

  group('MidiOut.raw on an unopened port', () {
    /// Opens the port that cannot exist, or returns null (and skips the
    /// test) on builds without MIDI device support (macOS / Android), where
    /// there is no MidiOut at all.
    MidiOut? openUnopenable() {
      final MidiOut out;
      try {
        out = MidiOut.open(_noSuchPort);
      } on YseException {
        markTestSkipped('MidiOut is not available on this platform');
        return null;
      }
      addTearDown(out.dispose);
      return out;
    }

    test('sends two-byte messages and SysEx as a silent no-op', () {
      final out = openUnopenable();
      if (out == null) return;
      expect(() => out.raw([0xC0, 5]), returnsNormally);
      expect(() => out.raw([0xD0, 64]), returnsNormally);
      expect(() => out.raw([0xF8]), returnsNormally);
      expect(
        () => out.raw([0xF0, for (var i = 0; i < 4096; i++) i & 0x7F, 0xF7]),
        returnsNormally,
      );
      // The three-byte path is unchanged alongside it.
      expect(() => out.raw3(0x90, 60, 100), returnsNormally);
    });

    test('an empty list is a no-op, although it is not a message', () {
      final out = openUnopenable();
      if (out == null) return;
      expect(() => out.raw(const []), returnsNormally);
    });

    test('refuses a malformed message before it reaches the engine', () {
      final out = openUnopenable();
      if (out == null) return;
      expect(() => out.raw([0xC0, 5, 0]), throwsArgumentError);
      expect(() => out.raw([0xF0, 0x7E]), throwsArgumentError);
      expect(() => out.raw([60, 100]), throwsArgumentError);
      expect(() => out.raw([0x90, 60, 300]), throwsArgumentError);
    });

    test('is a no-op after dispose', () {
      final out = openUnopenable();
      if (out == null) return;
      out.dispose();
      expect(() => out.raw([0xC0, 5]), returnsNormally);
      expect(() => out.raw([0xF0, 0x01, 0xF7]), returnsNormally);
    });
  });
}
