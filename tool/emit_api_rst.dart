// Walks every Dart file in lib/src/ that backs a public declaration (class,
// enum or typedef) re-exported from lib/yse.dart, then emits one
// reStructuredText page per declaration into
// `docs/source/api/_generated/`. The Sphinx site `include::`s those pages
// from per-subsystem RST files under `docs/source/api/`.
//
// Why hand-roll instead of `dart doc`? The issue (#6) is to mirror the
// upstream libYSE docs site (Doxygen → Breathe → Sphinx). dartdoc comments
// stay the canonical source of truth on the Dart side; this tool is the
// analog of Doxygen's XML emitter — it lifts dartdoc + signatures into RST
// so Sphinx can lay everything out alongside the C++ engine docs.
//
// Usage:
//   dart run tool/emit_api_rst.dart --out docs/source/api/_generated
//
// The generator only relies on lexical AST analysis via package:analyzer;
// it never resolves types. Resolution would require a fully-pubbed package
// at run time, which would slow down both local builds and CI for no real
// gain — every signature we emit is verbatim from the source.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/token.dart';

void main(List<String> args) {
  final outFlagIdx = args.indexOf('--out');
  if (outFlagIdx < 0 || outFlagIdx + 1 >= args.length) {
    stderr.writeln('Usage: dart run tool/emit_api_rst.dart --out <dir>');
    exitCode = 64;
    return;
  }
  final outDir = Directory(args[outFlagIdx + 1]);
  outDir.createSync(recursive: true);

  final root = Directory.current;
  final libsrc = Directory('${root.path}/lib/src');
  if (!libsrc.existsSync()) {
    stderr.writeln('lib/src not found — run from the package root.');
    exitCode = 66;
    return;
  }

  // Use the public surface in lib/yse.dart to decide which declarations are
  // part of the documented API. Anything not re-exported there is internal.
  final yseDart = File('${root.path}/lib/yse.dart').readAsStringSync();
  final exports = parseReExports(yseDart);

  final emitted = <String>{};
  for (final entry in libsrc.listSync(recursive: false)) {
    if (entry is! File || !entry.path.endsWith('.dart')) continue;
    if (entry.path.endsWith('.g.dart')) continue;
    final pages = collectApiPages(entry.readAsStringSync(), exports.names);
    for (final MapEntry(key: name, value: rst) in pages.entries) {
      File('${outDir.path}/${apiPageSlug(name)}.rst').writeAsStringSync(rst);
      emitted.add(name);
    }
  }

  // Fail loudly rather than quietly ship a partial site (#75).
  final errors = coverageErrors(exports: exports, emitted: emitted);
  for (final error in errors) {
    stderr.writeln('ERROR: $error');
  }
  if (errors.isNotEmpty) exitCode = 1;

  print('Emitted ${emitted.length} API page(s) into ${outDir.path}');
}

/// The public surface declared by lib/yse.dart.
typedef ReExports = ({Set<String> names, List<String> withoutShow});

/// Pull the set of names re-exported from lib/yse.dart. The file uses
/// ``export 'src/foo.dart' show A, B, C;`` — we keep the names from the
/// ``show`` clause. Exports without a ``show`` clause are listed in
/// `withoutShow`: the generator can't tell which of their names are public,
/// so it treats them as an error rather than silently documenting nothing.
ReExports parseReExports(String content) {
  final names = <String>{};
  final withoutShow = <String>[];
  final result = parseString(content: content, throwIfDiagnostics: false);
  for (final directive in result.unit.directives) {
    if (directive is! ExportDirective) continue;
    final shows = directive.combinators.whereType<ShowCombinator>();
    if (shows.isEmpty) {
      withoutShow.add(directive.uri.stringValue ?? directive.uri.toString());
      continue;
    }
    for (final combinator in shows) {
      for (final id in combinator.shownNames) {
        names.add(id.name);
      }
    }
  }
  return (names: names, withoutShow: withoutShow);
}

/// Parses one lib/src Dart file and renders an RST page for every
/// declaration in it whose name is in [wanted]. Returns name → RST.
///
/// Covers classes, enums and typedefs (both `typedef X = T;` and the legacy
/// function-typedef form).
Map<String, String> collectApiPages(String source, Set<String> wanted) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  final visitor = _ClassVisitor(wanted);
  result.unit.accept(visitor);
  return {for (final cls in visitor.classes) cls.name: _renderClassRst(cls)};
}

/// Everything that should fail the docs build: re-exported names with no
/// generated page, and exports the generator can't enumerate.
List<String> coverageErrors({
  required ReExports exports,
  required Set<String> emitted,
}) {
  final missing = exports.names.difference(emitted).toList()..sort();
  return [
    if (missing.isNotEmpty)
      '${missing.length} re-exported name(s) not found in lib/src: '
          '${missing.join(', ')}',
    for (final uri in exports.withoutShow)
      "export '$uri' has no show clause; list its public names explicitly",
  ];
}

class _ClassInfo {
  final String name;
  final String? doc;
  final String? extendsClause;
  final List<String> implementsClause;
  final bool isAbstract;

  /// For a typedef, the full `typedef X = ...;` declaration; null otherwise.
  final String? typedefSignature;
  final List<_MemberInfo> constructors = [];
  final List<_MemberInfo> staticAccessors = [];
  final List<_MemberInfo> staticMethods = [];
  final List<_MemberInfo> accessors = [];
  final List<_MemberInfo> methods = [];
  final List<_EnumValueInfo> enumValues = [];
  final bool isEnum;

  _ClassInfo({
    required this.name,
    required this.doc,
    required this.extendsClause,
    required this.implementsClause,
    required this.isAbstract,
    required this.isEnum,
    this.typedefSignature,
  });
}

class _MemberInfo {
  final String label;
  final String signature;
  final String? doc;
  _MemberInfo({
    required this.label,
    required this.signature,
    required this.doc,
  });
}

class _EnumValueInfo {
  final String name;
  final String? doc;
  _EnumValueInfo({required this.name, required this.doc});
}

class _ClassVisitor extends RecursiveAstVisitor<void> {
  final Set<String> wanted;
  final List<_ClassInfo> classes = [];

  _ClassVisitor(this.wanted);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.name.lexeme;
    if (!wanted.contains(name)) return;
    final info = _ClassInfo(
      name: name,
      doc: _commentText(node.documentationComment),
      extendsClause: node.extendsClause?.superclass.toString(),
      implementsClause:
          node.implementsClause?.interfaces.map((t) => t.toString()).toList() ??
          const [],
      isAbstract: node.abstractKeyword != null,
      isEnum: false,
    );
    for (final member in node.members) {
      _addMember(info, member);
    }
    classes.add(info);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final name = node.name.lexeme;
    if (!wanted.contains(name)) return;
    final info = _ClassInfo(
      name: name,
      doc: _commentText(node.documentationComment),
      extendsClause: null,
      implementsClause: const [],
      isAbstract: false,
      isEnum: true,
    );
    for (final value in node.constants) {
      info.enumValues.add(
        _EnumValueInfo(
          name: value.name.lexeme,
          doc: _commentText(value.documentationComment),
        ),
      );
    }
    for (final member in node.members) {
      _addMember(info, member);
    }
    classes.add(info);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final name = node.name.lexeme;
    if (!wanted.contains(name)) return;
    classes.add(
      _typedefInfo(
        name,
        node.documentationComment,
        'typedef $name${node.typeParameters ?? ''} = ${node.type};',
      ),
    );
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    final name = node.name.lexeme;
    if (!wanted.contains(name)) return;
    final ret = node.returnType == null ? '' : '${node.returnType} ';
    classes.add(
      _typedefInfo(
        name,
        node.documentationComment,
        'typedef $ret$name${node.typeParameters ?? ''}${node.parameters};',
      ),
    );
  }

  _ClassInfo _typedefInfo(String name, Comment? doc, String signature) =>
      _ClassInfo(
        name: name,
        doc: _commentText(doc),
        extendsClause: null,
        implementsClause: const [],
        isAbstract: false,
        isEnum: false,
        typedefSignature: signature,
      );

  void _addMember(_ClassInfo info, ClassMember member) {
    if (member is ConstructorDeclaration) {
      // Skip private named constructors (._ etc).
      final ctorName = member.name?.lexeme;
      if (ctorName != null && ctorName.startsWith('_')) return;
      final label = ctorName == null ? info.name : '${info.name}.$ctorName';
      info.constructors.add(
        _MemberInfo(
          label: label,
          signature: _constructorSignature(info.name, member),
          doc: _commentText(member.documentationComment),
        ),
      );
    } else if (member is MethodDeclaration) {
      final memberName = member.name.lexeme;
      if (memberName.startsWith('_')) return;
      final signature = _methodSignature(member);
      final info0 = _MemberInfo(
        label: memberName,
        signature: signature,
        doc: _commentText(member.documentationComment),
      );
      if (member.isStatic) {
        if (member.isGetter || member.isSetter) {
          info.staticAccessors.add(info0);
        } else {
          info.staticMethods.add(info0);
        }
      } else {
        if (member.isGetter || member.isSetter) {
          info.accessors.add(info0);
        } else {
          info.methods.add(info0);
        }
      }
    } else if (member is FieldDeclaration) {
      for (final field in member.fields.variables) {
        final name = field.name.lexeme;
        if (name.startsWith('_')) continue;
        final type = member.fields.type?.toString() ?? 'dynamic';
        final isFinal = member.fields.isFinal;
        final isStatic = member.isStatic;
        final modifiers = <String>[
          if (isStatic) 'static',
          if (isFinal) 'final',
          if (member.fields.isConst) 'const',
        ].join(' ');
        final sig =
            '${modifiers.isEmpty ? '' : '$modifiers '}'
            '$type $name';
        final entry = _MemberInfo(
          label: name,
          signature: sig,
          doc: _commentText(member.documentationComment),
        );
        if (isStatic) {
          info.staticAccessors.add(entry);
        } else {
          info.accessors.add(entry);
        }
      }
    }
  }
}

String? _commentText(Comment? comment) {
  if (comment == null) return null;
  final lines = comment.tokens.map((Token t) {
    var line = t.lexeme;
    if (line.startsWith('///')) {
      line = line.substring(3);
    } else if (line.startsWith('/**')) {
      line = line.substring(3);
    } else if (line.startsWith('*/')) {
      line = line.substring(2);
    } else if (line.startsWith('*')) {
      line = line.substring(1);
    }
    if (line.startsWith(' ')) line = line.substring(1);
    return line;
  }).toList();
  // Trim trailing blank lines.
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  if (lines.isEmpty) return null;
  return _markdownToRst(lines).join('\n');
}

/// Rewrites the two block-level Markdown constructs dartdoc comments use
/// that docutils would misparse: fenced code blocks (```` ```dart ````)
/// become `.. code-block::` directives, and pipe tables become
/// `.. list-table::` directives. Everything else passes through verbatim.
List<String> _markdownToRst(List<String> lines) {
  final out = <String>[];
  void blankBefore() {
    if (out.isNotEmpty && out.last.trim().isNotEmpty) out.add('');
  }

  final fence = RegExp(r'^\s*```\s*(\w*)\s*$');
  var i = 0;
  while (i < lines.length) {
    final open = fence.firstMatch(lines[i]);
    if (open != null) {
      final lang = open.group(1)!.isEmpty ? 'dart' : open.group(1)!;
      blankBefore();
      out
        ..add('.. code-block:: $lang')
        ..add('');
      i++;
      while (i < lines.length && !RegExp(r'^\s*```\s*$').hasMatch(lines[i])) {
        out.add(lines[i].trim().isEmpty ? '' : '   ${lines[i]}');
        i++;
      }
      i++; // closing fence
      out.add('');
      continue;
    }
    if (lines[i].trimLeft().startsWith('|')) {
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
        final row = lines[i].trim();
        final cells = row
            .substring(1, row.endsWith('|') ? row.length - 1 : row.length)
            .split('|')
            .map((c) => c.trim())
            .toList();
        // Skip the header separator row (|---|:--:|).
        if (!cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c))) {
          rows.add(cells);
        }
        i++;
      }
      blankBefore();
      out
        ..add('.. list-table::')
        ..add('   :header-rows: 1')
        ..add('');
      for (final row in rows) {
        for (var c = 0; c < row.length; c++) {
          out.add('${c == 0 ? '   * - ' : '     - '}${row[c]}');
        }
      }
      out.add('');
      continue;
    }
    out.add(lines[i]);
    i++;
  }
  while (out.isNotEmpty && out.last.trim().isEmpty) {
    out.removeLast();
  }
  return out;
}

String _constructorSignature(String className, ConstructorDeclaration node) {
  final name = node.name?.lexeme;
  final factory = node.factoryKeyword != null ? 'factory ' : '';
  final ctorLabel = name == null ? className : '$className.$name';
  final params = node.parameters.toString();
  return '$factory$ctorLabel$params';
}

String _methodSignature(MethodDeclaration node) {
  final modifiers = <String>[
    if (node.isStatic) 'static',
    if (node.externalKeyword != null) 'external',
  ];
  final ret = node.returnType?.toString() ?? 'dynamic';
  final name = node.name.lexeme;
  final params = node.parameters?.toString() ?? '';
  if (node.isGetter) {
    return '${modifiers.isEmpty ? '' : '${modifiers.join(' ')} '}'
        '$ret get $name';
  }
  if (node.isSetter) {
    return '${modifiers.isEmpty ? '' : '${modifiers.join(' ')} '}'
        'set $name$params';
  }
  return '${modifiers.isEmpty ? '' : '${modifiers.join(' ')} '}'
      '$ret $name$params';
}

/// The `_generated/<slug>.rst` basename for the page of API name [name].
String apiPageSlug(String name) => _slug(name);

String _slug(String name) {
  // CamelCase → snake_case for filenames so they sort like a directory
  // listing of the API.
  final buf = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final ch = name[i];
    final lower = ch.toLowerCase();
    if (i > 0 && ch != lower) {
      buf.write('_');
    }
    buf.write(lower);
  }
  return buf.toString();
}

String _renderClassRst(_ClassInfo info) {
  final buf = StringBuffer();

  // Title.
  final title = info.isEnum
      ? 'enum ${info.name}'
      : info.typedefSignature != null
      ? 'typedef ${info.name}'
      : info.name;
  buf.writeln(title);
  buf.writeln('=' * title.length);
  buf.writeln();

  // Header line: class signature.
  buf.write('.. code-block:: dart\n\n   ');
  if (info.typedefSignature != null) {
    buf.write(info.typedefSignature);
  } else if (info.isEnum) {
    buf.write('enum ${info.name}');
  } else {
    if (info.isAbstract) buf.write('abstract ');
    buf.write('class ${info.name}');
    if (info.extendsClause != null) {
      buf.write(' extends ${info.extendsClause}');
    }
    if (info.implementsClause.isNotEmpty) {
      buf.write(' implements ${info.implementsClause.join(', ')}');
    }
  }
  buf.writeln();
  buf.writeln();

  if (info.doc != null) {
    buf.writeln(info.doc);
    buf.writeln();
  }

  if (info.enumValues.isNotEmpty) {
    buf.writeln('Values');
    buf.writeln('------');
    buf.writeln();
    for (final v in info.enumValues) {
      buf.writeln('.. _${_slug(info.name)}.${v.name}:');
      buf.writeln();
      buf.writeln('``${v.name}``');
      if (v.doc != null) {
        buf.writeln();
        for (final line in v.doc!.split('\n')) {
          buf.writeln('   $line');
        }
      }
      buf.writeln();
    }
  }

  _renderSection(buf, 'Constructors', info.constructors);
  _renderSection(buf, 'Static accessors', info.staticAccessors);
  _renderSection(buf, 'Static methods', info.staticMethods);
  _renderSection(buf, 'Properties', info.accessors);
  _renderSection(buf, 'Methods', info.methods);

  return buf.toString();
}

void _renderSection(StringBuffer buf, String title, List<_MemberInfo> items) {
  if (items.isEmpty) return;
  // Group setters / getters with the same name so they render once.
  final grouped = <String, List<_MemberInfo>>{};
  for (final m in items) {
    grouped.putIfAbsent(m.label, () => []).add(m);
  }
  buf.writeln(title);
  buf.writeln('-' * title.length);
  buf.writeln();
  for (final label in grouped.keys) {
    final variants = grouped[label]!;
    for (final v in variants) {
      buf.writeln('.. code-block:: dart');
      buf.writeln();
      buf.writeln('   ${v.signature}');
      buf.writeln();
    }
    final doc = variants
        .map((v) => v.doc)
        .firstWhere(
          (d) => d != null && d.trim().isNotEmpty,
          orElse: () => null,
        );
    if (doc != null) {
      for (final line in doc.split('\n')) {
        buf.writeln(line);
      }
      buf.writeln();
    }
  }
}
