// Unit tests for the music primitives (Note, PNote).
//
// These construct native note objects through `libyse.dll` / `libyse.so`, so
// they require the library to be resolvable — set `YSE_DLL_PATH` to the
// directory holding it (see README / CLAUDE.md):
//
//   Windows:  $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//             dart test
//   Linux:    export YSE_DLL_PATH="$PWD/third_party/yse-soundengine/build/bin"
//             dart test
//
// Notes are plain value objects: no System session and no rendering needed.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:yse/yse.dart';

void main() {
  group('Note.channel', () {
    test('constructor value reads back and the setter round-trips', () {
      final n = Note(pitch: 64, channel: 3);
      addTearDown(n.dispose);
      expect(n.channel, 3);

      n.channel = 16;
      expect(n.channel, 16);
    });
  });

  group('PNote.channel (issue #67)', () {
    test('constructor value reads back', () {
      final p = PNote(position: 0.5, pitch: 60, channel: 7);
      addTearDown(p.dispose);
      expect(p.channel, 7);
    });

    test('the setter round-trips and leaves the other fields alone', () {
      final p = PNote(position: 1.25, pitch: 67, volume: 0.5, length: 2);
      addTearDown(p.dispose);
      expect(p.channel, 1, reason: 'the constructor default');

      p.channel = 10;
      expect(p.channel, 10);
      expect(p.position, closeTo(1.25, 1e-6));
      expect(p.pitch, closeTo(67, 1e-6));
      expect(p.volume, closeTo(0.5, 1e-6));
      expect(p.length, closeTo(2, 1e-6));

      p.channel = 2;
      expect(p.channel, 2);
    });
  });
}
