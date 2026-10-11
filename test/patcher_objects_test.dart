// Integration tests for the generated `Obj` constants and the registry
// metadata they come from (#64): every constant is a real type, every
// registry type has a constant, the categories map onto `PCategory`, and
// `PatcherObjectType.requiresMidiDevice` reads the metadata JSON flag.
//
// These drive the real `libyse.dll` / `libyse.so`; set `YSE_DLL_PATH` to the
// directory holding it (see README / CLAUDE.md).
@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:yse/yse.dart';

import 'support/dart_script.dart';
import 'support/engine_pin.dart';

void main() {
  setUpAll(noticeUnpinnedEngine);

  late System sys;

  setUpAll(() {
    sys = System.instance;
    sys.initOffline();
  });

  tearDownAll(() {
    sys.close();
  });

  group('Obj', () {
    test('every constant is a valid object type', () {
      for (final type in Obj.all) {
        expect(Obj.isValid(type), isTrue, reason: type);
      }
    });

    test('covers the registry exactly, without duplicates', () {
      expect(Obj.all.toSet(), hasLength(Obj.all.length));
      expect(Obj.all.toSet(), PatcherRegistry.typeNames().toSet());
      expect(Obj.all, hasLength(PatcherRegistry.typeCount));
    });

    test('has the subpatcher boundary objects (#61)', () {
      expect(Obj.patcher, 'patcher');
      expect(Obj.gInlet, '.inlet');
      expect(Obj.gOutlet, '.outlet');
      expect(Obj.dInlet, '~inlet');
      expect(Obj.dOutlet, '~outlet');
    });

    test('keeps the names shipped before #64', () {
      const legacy = {
        Obj.dDac: '~dac',
        Obj.gReceive: '.r',
        Obj.gSubtract: '.-',
        Obj.dSubtract: '~-',
        Obj.midiToFrequency: '.mtof',
        Obj.frequencyToMidi: '.ftom',
        Obj.mOut: '.midiout',
        Obj.mNoteOn: '.noteon',
        Obj.mPolyPress: '.polypressure',
        Obj.mChanPress: '.channelpressure',
        Obj.mProgChange: '.programchange',
      };
      legacy.forEach((constant, value) => expect(constant, value));
    });

    test('lib/src/patcher_objects.dart matches the bound registry', () async {
      final r = await runDartScript(
        'tool/gen_obj_constants.dart',
        args: ['--check'],
      );
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('registry metadata', () {
    test('PCategory covers every category the registry reports', () {
      final meta =
          jsonDecode(PatcherRegistry.metadataJson()) as Map<String, dynamic>;
      for (final MapEntry(key: type, value: m) in meta.entries) {
        final cat = (m as Map<String, dynamic>)['category'] as String;
        final matches = PCategory.values.where(
          (c) => c.native.name == 'YSE_PCAT_$cat',
        );
        expect(matches, hasLength(1), reason: '$type: $cat');
        expect(PatcherRegistry.type(type)!.category, matches.single);
      }
    });

    test('requiresMidiDevice is true for .midiout, false for ~sine', () {
      expect(PatcherRegistry.type(Obj.mOut)!.requiresMidiDevice, isTrue);
      expect(PatcherRegistry.type(Obj.mMidiinfo)!.requiresMidiDevice, isTrue);
      expect(PatcherRegistry.type(Obj.dSine)!.requiresMidiDevice, isFalse);
      // A MIDI-category object without a port (pure message formatting).
      expect(PatcherRegistry.type(Obj.mNoteOn)!.requiresMidiDevice, isFalse);
    });

    test('descriptions are tooltip-length (3.0.1)', () {
      for (final t in PatcherRegistry.types()) {
        expect(t.description, isNotEmpty, reason: t.name);
        expect(t.description.length, lessThanOrEqualTo(300), reason: t.name);
      }
    });
  });
}
