// Generates lib/src/patcher_objects.dart — the `Obj` type-name constants —
// from the patcher registry of the libyse this package binds (#64).
//
// The registry (305 objects in libYSE 3.x) is the source of truth for which
// object types exist, their category and their description. Upstream's
// `patcher/pObjectList.hpp` is the source of truth for the canonical C++
// constant name of each type (`DEFOBJ(D_SINE, "~sine")`); the Dart name
// mirrors it (`D_SINE` → `dSine`), with a small override table for the
// names the wrapper already shipped and for multi-word names upstream spells
// as one all-caps word. The tool fails if the registry and the header
// disagree about which types exist.
//
// Usage (from the package root, with libyse resolvable):
//   $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//   dart run tool/gen_obj_constants.dart            # rewrite the file
//   dart run tool/gen_obj_constants.dart --check    # exit 1 if stale
//
// Options:
//   --header <path>  pObjectList.hpp (default: the submodule's copy)
//   --out <path>     output file (default: lib/src/patcher_objects.dart)
//
// The output is deterministic: categories in `PCategory` order, objects in
// type-name order within a category, then `dart format`.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:yse/yse.dart';

const _defaultHeader =
    'third_party/yse-soundengine/YseEngine/patcher/pObjectList.hpp';
const _defaultOut = 'lib/src/patcher_objects.dart';

/// C++ name → Dart name, where the mechanical conversion is not wanted.
///
/// The first block keeps the names the wrapper shipped before #64 (so
/// downstream code keeps compiling, and upstream's `SUBSTRACT` typo stays
/// out of the Dart surface). The second splits all-caps compounds into
/// readable words.
const nameOverrides = <String, String>{
  'G_SUBSTRACT': 'gSubtract',
  'D_SUBSTRACT': 'dSubtract',
  'MIDITOFREQUENCY': 'midiToFrequency',
  'FREQUENCYTOMIDI': 'frequencyToMidi',
  'M_NOTEON': 'mNoteOn',
  'M_NOTEOFF': 'mNoteOff',
  'M_POLYPRESS': 'mPolyPress',
  'M_CHANPRESS': 'mChanPress',
  'M_PROGCHANGE': 'mProgChange',
  //
  'G_REVERSESUBSTRACT': 'gReverseSubtract',
  'G_REVERSEDIVIDE': 'gReverseDivide',
  'G_INTDIVIDE': 'gIntDivide',
  'G_NOTEQUAL': 'gNotEqual',
  'G_LESSEQUAL': 'gLessEqual',
  'G_GREATEREQUAL': 'gGreaterEqual',
  'G_LOGICALAND': 'gLogicalAnd',
  'G_LOGICALOR': 'gLogicalOr',
  'G_BITAND': 'gBitAnd',
  'G_BITOR': 'gBitOr',
  'G_SHIFTLEFT': 'gShiftLeft',
  'G_SHIFTRIGHT': 'gShiftRight',
};

Future<void> main(List<String> args) async {
  String opt(String flag, String fallback) {
    final i = args.indexOf(flag);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final check = args.contains('--check');
  final header = File(opt('--header', _defaultHeader));
  final out = File(opt('--out', _defaultOut));
  if (!header.existsSync()) {
    stderr.writeln('Header not found: ${header.path}');
    exitCode = 66;
    return;
  }

  final sys = System.instance..initOffline();
  final String json;
  try {
    json = PatcherRegistry.metadataJson();
  } finally {
    sys.close();
  }
  if (json.isEmpty) {
    stderr.writeln('yse_patcher_get_metadata_json returned nothing');
    exitCode = 70;
    return;
  }

  final String source;
  try {
    source = renderObjConstants(
      metadata: jsonDecode(json) as Map<String, dynamic>,
      cppNames: parseDefObjs(header.readAsStringSync()),
    );
  } on FormatException catch (e) {
    stderr.writeln('ERROR: ${e.message}');
    exitCode = 1;
    return;
  }

  final formatted = await _dartFormat(source);
  if (check) {
    final current = out.existsSync() ? out.readAsStringSync() : '';
    if (current.replaceAll('\r\n', '\n') != formatted) {
      stderr.writeln(
        '${out.path} is stale; run dart run tool/gen_obj_constants.dart',
      );
      exitCode = 1;
      return;
    }
    print('${out.path} is up to date.');
    return;
  }
  out.writeAsStringSync(formatted);
  print('Wrote ${out.path}.');
}

/// `type name → C++ constant name` from every `DEFOBJ(NAME, "type")` line.
Map<String, String> parseDefObjs(String header) => {
  for (final m in RegExp(
    r'DEFOBJ\(\s*(\w+)\s*,\s*"([^"]+)"\s*\)',
  ).allMatches(header))
    m.group(2)!: m.group(1)!,
};

/// The Dart constant name for a C++ `YSE::OBJ` name.
///
/// `D_SINE` → `dSine`, `G_ARRAY_INDEXOF` → `gArrayIndexof`,
/// `PATCHER` → `patcher`; [nameOverrides] wins.
String dartName(String cppName) {
  final override = nameOverrides[cppName];
  if (override != null) return override;
  final parts = cppName.toLowerCase().split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

/// Renders the (unformatted) source of lib/src/patcher_objects.dart.
///
/// Throws [FormatException] when the registry and the header disagree, a
/// category is unknown, or two types map to the same Dart name.
String renderObjConstants({
  required Map<String, dynamic> metadata,
  required Map<String, String> cppNames,
}) {
  final missing = metadata.keys.where((t) => !cppNames.containsKey(t));
  final extra = cppNames.keys.where((t) => !metadata.containsKey(t));
  if (missing.isNotEmpty || extra.isNotEmpty) {
    throw FormatException(
      'registry and pObjectList.hpp disagree. '
      'Not in the header: ${missing.join(' ')}. '
      'Not in the registry: ${extra.join(' ')}.',
    );
  }

  final byCategory = <PCategory, List<String>>{};
  for (final MapEntry(key: type, value: meta) in metadata.entries) {
    final cat = (meta as Map<String, dynamic>)['category'] as String;
    final pc = PCategory.values.where((c) => c.native.name == 'YSE_PCAT_$cat');
    if (pc.isEmpty) throw FormatException('unknown category $cat for $type');
    byCategory.putIfAbsent(pc.single, () => []).add(type);
  }

  final names = <String, String>{};
  for (final type in metadata.keys) {
    final name = dartName(cppNames[type]!);
    final clash = names.entries.where((e) => e.value == name);
    if (clash.isNotEmpty) {
      throw FormatException(
        'both "${clash.single.key}" and "$type" map to Obj.$name',
      );
    }
    names[type] = name;
  }

  final buf = StringBuffer()
    ..writeln('// GENERATED by tool/gen_obj_constants.dart from the patcher')
    ..writeln('// registry and upstream patcher/pObjectList.hpp. Do not edit')
    ..writeln('// by hand; rerun the tool after an engine update.')
    ..writeln()
    ..writeln("part of 'patcher.dart';")
    ..writeln()
    ..writeln('/// Compile-time string identifiers for patcher object types.')
    ..writeln('///')
    ..writeln(
      '/// Pass any of these to [Patcher.createObject] instead of a raw',
    )
    ..writeln('/// string literal; the two are interchangeable. The `~` prefix')
    ..writeln('/// marks DSP / audio-rate objects, `.` marks control-rate')
    ..writeln('/// objects. Every type in the engine registry has a constant,')
    ..writeln('/// named after its `YSE::OBJ` constant in upstream')
    ..writeln('/// `patcher/pObjectList.hpp` (`D_SINE` becomes [dSine]).')
    ..writeln('///')
    ..writeln('/// [all] lists every constant. For the full per-object schema')
    ..writeln('/// (inlets, outlets, parameters) use [PatcherRegistry].')
    ..writeln('class Obj {')
    ..writeln('  Obj._();')
    ..writeln();

  for (final cat in PCategory.values) {
    final types = byCategory[cat];
    if (types == null) continue;
    types.sort();
    buf
      ..writeln('  // ─── ${cat.name} ${'─' * (66 - cat.name.length)}')
      ..writeln();
    for (final type in types) {
      final meta = metadata[type] as Map<String, dynamic>;
      final text =
          '``$type``: ${_escape((meta['description'] as String).trim())}';
      for (final line in _wrap(text, 72)) {
        buf.writeln('  /// $line');
      }
      if (meta['requires_midi_device'] == true) {
        buf
          ..writeln('  ///')
          ..writeln('  /// Holds a MIDI port: only in builds with MIDI device')
          ..writeln('  /// support (not macOS / Android).');
      }
      buf.writeln("  static const String ${names[type]} = '$type';");
      buf.writeln();
    }
  }

  buf
    ..writeln('  /// Every constant above, in registry (type-name) order.')
    ..writeln('  static const List<String> all = [');
  for (final type in metadata.keys.toList()..sort()) {
    buf.writeln('    ${names[type]},');
  }
  buf
    ..writeln('  ];')
    ..writeln()
    ..writeln('  /// Whether [type] is a known object type identifier.')
    ..writeln('  static bool isValid(String type) => using((arena) {')
    ..writeln('    final cstr = type.toNativeUtf8(allocator: arena);')
    ..writeln('    return bindings.patcher_is_valid_object(cstr.cast()) != 0;')
    ..writeln('  });')
    ..writeln('}');
  return buf.toString();
}

/// Backslash-escapes the characters dartdoc Markdown or Sphinx RST would
/// read as markup. A backslash escape renders as the bare character in
/// both.
String _escape(String s) =>
    s.replaceAllMapped(RegExp(r'[\\\[\]<>*_`|]'), (m) => '\\${m[0]}');

/// Greedy word wrap. A word that would start a line and read as a Markdown
/// / RST list or block marker stays on the previous line instead.
List<String> _wrap(String text, int width) {
  final risky = RegExp(r'^([-+*|#>]|\d+[.)]|\.\.)$');
  final lines = <String>[];
  var line = '';
  for (final word in text.split(RegExp(r'\s+'))) {
    if (line.isEmpty) {
      line = word;
    } else if (line.length + 1 + word.length <= width || risky.hasMatch(word)) {
      line = '$line $word';
    } else {
      lines.add(line);
      line = word;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines;
}

/// The `dart` CLI of the running SDK. The tests run this tool on the
/// standalone VM (`dartvm`, see test/support/dart_script.dart), which has no
/// `format` command, so a `dartvm` is swapped for the `dart` next to it.
String _dartExecutable() {
  final exe = File(Platform.resolvedExecutable);
  if (!exe.uri.pathSegments.last.startsWith('dartvm')) return exe.path;
  final name = Platform.isWindows ? 'dart.exe' : 'dart';
  return '${exe.parent.path}${Platform.pathSeparator}$name';
}

Future<String> _dartFormat(String source) async {
  // Format inside the package so `dart format` uses the package's language
  // version (and so its style) rather than the SDK default.
  await Directory('.dart_tool').create();
  final tmp = await Directory('.dart_tool').createTemp('gen_obj_');
  try {
    final f = File('${tmp.path}/patcher_objects.dart');
    await f.writeAsString(source);
    final r = await Process.run(_dartExecutable(), ['format', f.path]);
    if (r.exitCode != 0) {
      throw StateError('dart format failed: ${r.stderr}');
    }
    return (await f.readAsString()).replaceAll('\r\n', '\n');
  } finally {
    await tmp.delete(recursive: true);
  }
}
