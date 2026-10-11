// Ports libYSE's long-form patcher object notes into the docs site (#78).
//
// Since libYSE 3.0.1 an object's registry description is a short summary;
// the long-form notes (message formats, edge cases, examples) live upstream
// in documentation/source/_data/patcher_notes/<category slug>.rst. This tool
// copies them to docs/source/_data/patcher_notes/, where the render hook in
// docs/source/conf.py places each object's notes under its summary.
//
// The copy is committed because the docs workflow does not check out the
// engine submodule. `--check` (run by test/port_patcher_notes_test.dart)
// fails when the committed copy drifts from the submodule's notes.
//
// The notes are written for the upstream docs tree, so the copy is rewritten
// deterministically:
//
// - `:doc:` links to an object category page (`/patcher/objects/<slug>`, or
//   a bare `<slug>` relative to it) point at our own page under
//   `/api/patcher_objects/`.
// - Every other `:doc:` and every `:ref:` (the patcher guide: messages, time,
//   data, files, ...) only exists upstream. It becomes a `:yse-cpp:` link
//   into the published libYSE site, titled with the target's section title
//   and, for a `:ref:`, anchored at the label. Titles and anchors are read
//   from the upstream source tree, so a renamed or removed target fails the
//   port instead of producing a broken link.
// - The few C++ host-API names the notes mention (`YSE::Randomize()`,
//   `CreateObject`, `ParseJSON`, ...) become their Dart equivalents, and the
//   "(`yse_...()` in C)" asides are dropped. The table is [cppToDart]. A C++
//   name the table does not cover fails the port, as does a table entry no
//   note uses any more. The notes have no C++ code samples: their code
//   blocks are patch notation (`[.metro 100] -> ...`) and are kept as is.
// - Any other Sphinx role fails the port.
//
// Usage (from the package root; no engine build needed):
//   dart run tool/port_patcher_notes.dart            # rewrite the copy
//   dart run tool/port_patcher_notes.dart --check    # exit 1 if stale
//
// Options:
//   --src <dir>   upstream docs source (default:
//                 third_party/yse-soundengine/documentation/source)
//   --out <dir>   output directory (default: docs/source/_data/patcher_notes)

// ignore_for_file: avoid_print

import 'dart:io';

const _defaultSrc = 'third_party/yse-soundengine/documentation/source';
const _defaultOut = 'docs/source/_data/patcher_notes';
const _marker = '.. patcher-object::';

/// C++ host-API mentions in the upstream notes and what replaces them.
///
/// Each pattern must match somewhere in the notes ([portAllNotes] fails on a
/// stale entry), and [_cppLeftover] must find nothing after the rewrite.
final List<(Pattern, String)> cppToDart = [
  ('``YSE::System().update()``', '``System.instance.update()``'),
  ('``System::update()``', '``System.instance.update()``'),
  ('``System().init()``', '``System.instance.init()``'),
  ('``YSE::Log().setLogfile()``', '``Log.instance.logfile``'),
  ('``YSE::Log().setHandler()``', '``Log.instance.messages``'),
  ('``YSE::Randomize()``', '``System.randomize()``'),
  ('``YSE::RandomSeed()``', '``System.randomSeed()``'),
  ('``patcher::create``', '``Patcher(mainOutputs: ...)``'),
  ('``ParseJSON``', '``Patcher.parseJson``'),
  ('``CreateObject``', '``Patcher.createObject``'),
  ('``SetContainer``', '``Patcher.setContainer``'),
  ('``PassData``', '``Patcher.passInt`` / ``passFloat`` / ``passString``'),
  ('``PassBang``', '``Patcher.passBang``'),
  // "(``yse_randomize()`` in C)": the C API name next to a C++ one.
  (RegExp(r'\s*\(``yse_\w+\(\)`` in C\)'), ''),
];

/// C++ API spellings that must not survive the rewrite.
final _cppLeftover = RegExp(
  r'YSE::|\byse_\w+\(|\bSystem\(\)|``[a-z]+::[a-z]+``|``[A-Z][a-z]+[A-Z]\w*``',
);

/// `:role:`content`` (content may wrap onto the next line).
final _role = RegExp(r':([a-z][\w+-]*):`([^`]+)`');

/// `Title <target>` inside a role.
final _explicit = RegExp(r'^(.*\S)\s*<([^<>]+)>$', dotAll: true);

/// An RST section adornment line.
final _adornment = RegExp(r'^([=\-~^"#*+`:.\x27_])\1{2,}\s*$');

/// `.. _label:`
final _label = RegExp(r'^\.\. _([\w-]+):\s*$');

/// Titles and labels of the upstream docs tree, used to resolve links.
class UpstreamDocs {
  /// `/patcher/messages` -> `Messages`.
  final Map<String, String> titles;

  /// `data-saved` -> (`/patcher/data`, `What is saved with the patch`).
  final Map<String, (String, String)> labels;

  const UpstreamDocs({required this.titles, required this.labels});

  /// Reads every `.rst` page under [sourceDir] (skipping `_`-prefixed dirs).
  factory UpstreamDocs.scan(Directory sourceDir) {
    final titles = <String, String>{};
    final labels = <String, (String, String)>{};
    final root = sourceDir.absolute.path.replaceAll(r'\', '/');
    final files =
        sourceDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.rst'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      // `patcher/data.rst` -> `/patcher/data`.
      final rel = file.absolute.path
          .replaceAll(r'\', '/')
          .substring(root.length)
          .replaceFirst(RegExp('^/'), '');
      if (rel.split('/').any((p) => p.startsWith('_'))) continue;
      final doc = '/${rel.substring(0, rel.length - '.rst'.length)}';
      final lines = file.readAsLinesSync();
      final title = _pageTitle(lines);
      if (title != null) titles[doc] = title;
      for (var i = 0; i < lines.length; i++) {
        final m = _label.firstMatch(lines[i]);
        if (m == null) continue;
        final t = _titleAfterLabel(lines, i + 1);
        if (t != null) labels[m.group(1)!] = (doc, t);
      }
    }
    return UpstreamDocs(titles: titles, labels: labels);
  }
}

/// A section title as plain text: inline markup (``literal``, *emphasis*)
/// cannot nest inside the role that links to it.
String _plain(String title) =>
    title.replaceAll('``', '').replaceAll(RegExp(r'(?<!\w)\*+|\*+(?!\w)'), '');

bool _isTitleAt(List<String> lines, int i) =>
    i + 1 < lines.length &&
    lines[i].trim().isNotEmpty &&
    !lines[i].startsWith('..') &&
    !lines[i].startsWith(' ') &&
    !_adornment.hasMatch(lines[i]) &&
    _adornment.hasMatch(lines[i + 1]);

/// A page's title: its first section title.
String? _pageTitle(List<String> lines) {
  for (var i = 0; i < lines.length; i++) {
    if (_isTitleAt(lines, i)) return _plain(lines[i].trim());
  }
  return null;
}

/// The title of the section a label at line `from - 1` points at: the next
/// line that is not blank, another label or an overline. Null when that is
/// not a section title (a label on a paragraph or directive).
String? _titleAfterLabel(List<String> lines, int from) {
  for (var i = from; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty || _label.hasMatch(line)) continue;
    if (_adornment.hasMatch(line)) continue; // overline
    return _isTitleAt(lines, i) ? _plain(line.trim()) : null;
  }
  return null;
}

/// Rewrites one upstream notes file for category [slug].
///
/// The upstream preamble (comments before the first marker) is replaced by a
/// generated-file header; cross-references and C++ names are rewritten as
/// described at the top of this file. [used] collects the indexes of the
/// [cppToDart] entries that matched. Throws [FormatException] on anything
/// that cannot be rewritten.
String portNotes(
  String text,
  String slug,
  UpstreamDocs upstream, {
  Set<int>? used,
}) {
  text = text.replaceAll('\r\n', '\n');
  final start = text.indexOf(
    RegExp('^${RegExp.escape(_marker)}', multiLine: true),
  );
  if (start < 0) {
    throw FormatException('$slug.rst has no "$_marker" marker');
  }
  var body = text.substring(start);

  for (var i = 0; i < cppToDart.length; i++) {
    final (pattern, replacement) = cppToDart[i];
    if (pattern.allMatches(body).isEmpty) continue;
    used?.add(i);
    body = body.replaceAll(pattern, replacement);
  }
  final leftover = _cppLeftover.firstMatch(body);
  if (leftover != null) {
    throw FormatException(
      '$slug.rst: no Dart equivalent for C++ API "${leftover.group(0)}"; '
      'add it to cppToDart in tool/port_patcher_notes.dart',
    );
  }

  body = body.replaceAllMapped(_role, (m) {
    final role = m.group(1)!;
    final content = m.group(2)!;
    final explicit = _explicit.firstMatch(content);
    final title = explicit?.group(1);
    final target = (explicit?.group(2) ?? content).trim();
    switch (role) {
      case 'doc':
        final doc = target.startsWith('/')
            ? target
            : '/patcher/objects/$target';
        const objects = '/patcher/objects/';
        if (doc.startsWith(objects)) {
          final local = '/api/patcher_objects/${doc.substring(objects.length)}';
          return title == null ? ':doc:`$local`' : ':doc:`$title <$local>`';
        }
        final t =
            title ??
            upstream.titles[doc] ??
            (throw FormatException(
              '$slug.rst: :doc:`$target` has no page upstream',
            ));
        return ':yse-cpp:`$t <${doc.substring(1)}.html>`';
      case 'ref':
        final (doc, t) =
            upstream.labels[target] ??
            (throw FormatException(
              '$slug.rst: :ref:`$target` has no label upstream',
            ));
        return ':yse-cpp:`${title ?? t} <${doc.substring(1)}.html#$target>`';
      default:
        throw FormatException(
          '$slug.rst: role :$role: is not handled by '
          'tool/port_patcher_notes.dart',
        );
    }
  });

  final header =
      '.. Generated by tool/port_patcher_notes.dart from libYSE\'s\n'
      '   documentation/source/_data/patcher_notes/$slug.rst. Do not edit:\n'
      '   change the notes upstream, then rerun the tool.\n\n';
  return '$header${body.trimRight()}\n';
}

/// Ports every notes file under `<sourceDir>/_data/patcher_notes`, returning
/// `{file name: content}`. Throws [FormatException] on a stale [cppToDart]
/// entry or anything [portNotes] rejects.
Map<String, String> portAllNotes(Directory sourceDir) {
  final notesDir = Directory('${sourceDir.path}/_data/patcher_notes');
  if (!notesDir.existsSync()) {
    throw FormatException('${notesDir.path} does not exist');
  }
  final upstream = UpstreamDocs.scan(sourceDir);
  final files =
      notesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.rst'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final used = <int>{};
  final out = <String, String>{};
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final slug = name.substring(0, name.length - '.rst'.length);
    out[name] = portNotes(file.readAsStringSync(), slug, upstream, used: used);
  }
  for (var i = 0; i < cppToDart.length; i++) {
    if (!used.contains(i)) {
      throw FormatException(
        'cppToDart entry ${cppToDart[i].$1} matches no note any more; '
        'remove it from tool/port_patcher_notes.dart',
      );
    }
  }
  return out;
}

void main(List<String> args) {
  String opt(String name, String fallback) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final src = Directory(opt('--src', _defaultSrc));
  final out = Directory(opt('--out', _defaultOut));
  final check = args.contains('--check');

  final Map<String, String> ported;
  try {
    ported = portAllNotes(src);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exitCode = 65;
    return;
  }

  final existing = out.existsSync()
      ? {
          for (final f in out.listSync().whereType<File>())
            if (f.path.endsWith('.rst')) f.uri.pathSegments.last: f,
        }
      : <String, File>{};

  if (check) {
    final stale = <String>[
      for (final MapEntry(:key, :value) in ported.entries)
        if (existing[key]?.readAsStringSync().replaceAll('\r\n', '\n') != value)
          key,
      for (final name in existing.keys)
        if (!ported.containsKey(name)) name,
    ];
    if (stale.isNotEmpty) {
      stderr.writeln(
        '${out.path} is stale (${stale.join(', ')}); run '
        'dart run tool/port_patcher_notes.dart',
      );
      exitCode = 1;
      return;
    }
    print('${out.path} is up to date.');
    return;
  }

  out.createSync(recursive: true);
  for (final MapEntry(:key, :value) in existing.entries) {
    if (!ported.containsKey(key)) value.deleteSync();
  }
  for (final MapEntry(:key, :value) in ported.entries) {
    File('${out.path}/$key').writeAsStringSync(value);
  }
  print('Wrote ${ported.length} notes files to ${out.path}.');
}
