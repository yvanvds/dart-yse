// Pure-Dart tests for the Obj constant generator
// (tool/gen_obj_constants.dart, #64). No engine needed: these feed the
// renderer hand-made metadata.

import 'package:test/test.dart';

import '../tool/gen_obj_constants.dart';

void main() {
  group('dartName', () {
    test('mirrors the upstream YSE::OBJ name', () {
      expect(dartName('D_SINE'), 'dSine');
      expect(dartName('G_ARRAY_INDEXOF'), 'gArrayIndexof');
      expect(dartName('M_XBENDIN2'), 'mXbendin2');
      expect(dartName('PATCHER'), 'patcher');
      expect(dartName('D_INLET'), 'dInlet');
    });

    test('keeps the names shipped before #64', () {
      expect(dartName('G_SUBSTRACT'), 'gSubtract');
      expect(dartName('MIDITOFREQUENCY'), 'midiToFrequency');
      expect(dartName('M_NOTEON'), 'mNoteOn');
      expect(dartName('M_PROGCHANGE'), 'mProgChange');
    });
  });

  test('parseDefObjs reads every DEFOBJ line', () {
    const header = '''
#define DEFOBJ(name, tag) static constexpr char const* name = tag
    DEFOBJ(PATCHER, "patcher");
    DEFOBJ(D_SINE, "~sine");
    DEFOBJ(G_ARRAY_AT, ".array.at");
''';
    expect(parseDefObjs(header), {
      'patcher': 'PATCHER',
      '~sine': 'D_SINE',
      '.array.at': 'G_ARRAY_AT',
    });
  });

  group('renderObjConstants', () {
    Map<String, dynamic> meta(
      String category,
      String desc, {
      bool midi = false,
    }) => {
      'category': category,
      'description': desc,
      'requires_midi_device': midi,
    };

    test('groups by category, escapes markup and notes MIDI ports', () {
      final src = renderObjConstants(
        metadata: {
          '~sine': meta('OSC', 'Sine.'),
          '.midiout': meta('MIDI', 'Sends <bytes> [1,2] *now*.', midi: true),
        },
        cppNames: {'~sine': 'D_SINE', '.midiout': 'M_OUT'},
      );
      expect(src, contains("static const String dSine = '~sine';"));
      expect(src, contains("static const String mOut = '.midiout';"));
      // Oscillators come before MIDI (PCategory order).
      expect(
        src.indexOf('// ─── oscillator'),
        lessThan(src.indexOf('// ─── midi')),
      );
      expect(src, contains(r'Sends \<bytes\> \[1,2\] \*now\*.'));
      expect(src, contains('Holds a MIDI port'));
      expect(src, contains('static const List<String> all = ['));
    });

    test('refuses a registry / header mismatch', () {
      expect(
        () => renderObjConstants(
          metadata: {'~sine': meta('OSC', 'Sine.')},
          cppNames: {'~saw': 'D_SAW'},
        ),
        throwsFormatException,
      );
    });

    test('refuses an unknown category', () {
      expect(
        () => renderObjConstants(
          metadata: {'~sine': meta('NOPE', 'Sine.')},
          cppNames: {'~sine': 'D_SINE'},
        ),
        throwsFormatException,
      );
    });

    test('refuses two types with the same Dart name', () {
      expect(
        () => renderObjConstants(
          metadata: {'~a': meta('OSC', 'A.'), '~b': meta('OSC', 'B.')},
          cppNames: {'~a': 'D_X', '~b': 'D_X'},
        ),
        throwsFormatException,
      );
    });
  });
}
