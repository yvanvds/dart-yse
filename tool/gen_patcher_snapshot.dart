// Generates docs/source/_data/patcher_objects.json — the patcher metadata
// snapshot the docs site renders its object reference from (#69) — from the
// patcher registry of the libyse this package binds.
//
// Before #69 the snapshot was copied by hand from upstream libYSE and fell
// 263 objects behind the engine. Generating it from `PatcherRegistry` makes
// the docs describe exactly the registry the wrapper binds, and the `--check`
// mode (run by test/gen_patcher_snapshot_test.dart) fails when the two drift.
//
// The docs build itself needs no engine: the snapshot is committed, and the
// Sphinx hook in docs/source/conf.py renders the per-category pages from it.
//
// Usage (from the package root, with libyse resolvable):
//   $env:YSE_DLL_PATH = "$PWD\third_party\yse-soundengine\build\bin"
//   dart run tool/gen_patcher_snapshot.dart            # rewrite the file
//   dart run tool/gen_patcher_snapshot.dart --check    # exit 1 if stale
//
// Options:
//   --out <path>     output file (default: docs/source/_data/patcher_objects.json)
//
// The output is deterministic: object types and every object's keys in
// sorted order, two-space indent, LF line endings, trailing newline. That
// is the layout upstream's `python yse.py dump-patcher-meta` writes, so the
// two snapshots diff cleanly.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:yse/yse.dart';

const _defaultOut = 'docs/source/_data/patcher_objects.json';

void main(List<String> args) {
  final i = args.indexOf('--out');
  final out = File(i >= 0 && i + 1 < args.length ? args[i + 1] : _defaultOut);
  final check = args.contains('--check');

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

  final snapshot = renderPatcherSnapshot(
    jsonDecode(json) as Map<String, dynamic>,
  );
  if (check) {
    final current = out.existsSync() ? out.readAsStringSync() : '';
    if (current.replaceAll('\r\n', '\n') != snapshot) {
      stderr.writeln(
        '${out.path} is stale; run dart run tool/gen_patcher_snapshot.dart',
      );
      exitCode = 1;
      return;
    }
    print('${out.path} is up to date.');
    return;
  }
  out.writeAsStringSync(snapshot);
  print('Wrote ${out.path}.');
}

/// Renders the snapshot file for registry [metadata] (the decoded
/// `PatcherRegistry.metadataJson()`): every map's keys sorted, two-space
/// indent, trailing newline. List order is kept (pins are in index order).
String renderPatcherSnapshot(Map<String, dynamic> metadata) =>
    '${const JsonEncoder.withIndent('  ').convert(_sorted(metadata))}\n';

Object? _sorted(Object? value) => switch (value) {
  Map() => {
    for (final key in value.keys.map((k) => k as String).toList()..sort())
      key: _sorted(value[key]),
  },
  List() => [for (final v in value) _sorted(v)],
  _ => value,
};
