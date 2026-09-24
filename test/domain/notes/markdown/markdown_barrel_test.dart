import 'dart:io';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:flutter_test/flutter_test.dart';

const String _grammarDir = 'lib/domain/notes/markdown';

final RegExp _importUriPattern = RegExp(r"^import\s+'([^']+)'", multiLine: true);

final RegExp _typeDeclPattern = RegExp(
  r'^(?:(?:abstract|base|final|interface|sealed|mixin)\s+)*'
  r'(class|enum|mixin|extension|typedef)\b(.*)$',
);

final RegExp _functionDeclPattern = RegExp(
  r'^[A-Za-z_][A-Za-z0-9_<>?., ]*\s[a-zA-Z_][A-Za-z0-9_]*\(',
);

final RegExp _variableDeclPattern = RegExp(
  r'^(?:const|final|var|late)\s',
);

String? _functionNameOf(String matchedPrefix) {
  final String withoutParen = matchedPrefix.substring(0, matchedPrefix.length - 1);
  final int lastSpace = withoutParen.lastIndexOf(' ');
  return lastSpace < 0 ? null : withoutParen.substring(lastSpace + 1);
}

String? _variableNameOf(String line) {
  final int equalsAt = line.indexOf('=');
  if (equalsAt < 0) {
    return null;
  }
  final String beforeEquals = line.substring(0, equalsAt).trim();
  final int lastSpace = beforeEquals.lastIndexOf(' ');
  return lastSpace < 0 ? null : beforeEquals.substring(lastSpace + 1);
}

const Set<String> _functionNameExceptions = <String>{
  'sanitizePhotoCaption',
  'canonicalPhotoLine',
  'parseNoteTree',
  'plainTextOfTree',
};

List<File> _grammarFiles() {
  final List<File> files = Directory(_grammarDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

bool _isMdPrefixed(String name) => name.startsWith('Md') || name.startsWith('_');

bool _islowerMdPrefixed(String name) => name.startsWith('md') || name.startsWith('_');

void main() {
  const String source = 'Some **fog**\n\n![Low tide](photo/4fef9c2c3c9a "left small")';
  const String newSource = 'Some **fogx**\n\n![Low tide](photo/4fef9c2c3c9a "left small")';

  test('the markdown barrel exports the tree, parsers, photo line and plain text', () {
    expect(source.length, 58);

    final MdTree tree = parseNoteTree(source);
    expect(tree.blocks.length, 2);
    expect(tree.blocks[0], isA<MdBlock>());
    expect(tree.blocks[0].kind, MdBlockKind.paragraph);
    expect(tree.blocks[0].inlines, isNotEmpty);
    for (final MdInline inline in tree.blocks[0].inlines) {
      expect(inline, isA<MdInline>());
    }
    expect(tree.blocks[1], isA<MdBlock>());
    expect(tree.blocks[1].kind, MdBlockKind.photoLine);

    expect(plainTextOfTree(tree, source), 'Some fog\n\nLow tide');

    const MdIncrementalParser parser = MdIncrementalParser();
    final MdReparse reparse = parser.reparse(
      tree,
      source,
      newSource,
      const MdEdit(start: 10, end: 10, inserted: 'x'),
    );
    expect(reparse.tree, parseNoteTree(newSource));

    final MdPhotoPlacement placement = MdPhotoPlacement.parse('left small');
    expect(placement.side, MdPhotoSide.left);
    expect(placement.size, MdPhotoSize.small);
    expect(MdPhotoSize.small.fraction, 1 / 3);

    expect(sanitizePhotoCaption('a]b\nc'), 'ab c');

    expect(
      canonicalPhotoLine('4fef9c2c3c9a', 'Low tide', placement),
      '![Low tide](photo/4fef9c2c3c9a "left small")',
    );

    final String barrel = File('$_grammarDir/markdown.dart').readAsStringSync();
    for (final File file in _grammarFiles()) {
      if (file.path == '$_grammarDir/markdown.dart') {
        continue;
      }
      final String relative = file.path.substring('$_grammarDir/'.length);
      expect(
        barrel.contains("'$relative'"),
        isTrue,
        reason: '$relative is not exported by the barrel',
      );
    }
  });

  test('the grammar never imports flutter, dart:ui or lib/features', () {
    for (final File file in _grammarFiles()) {
      final String content = file.readAsStringSync();
      for (final RegExpMatch match in _importUriPattern.allMatches(content)) {
        final String uri = match.group(1)!;
        expect(
          uri.startsWith('package:flutter'),
          isFalse,
          reason: '${file.path} imports $uri',
        );
        expect(uri, isNot('dart:ui'), reason: '${file.path} imports dart:ui');
        expect(
          uri.startsWith('package:field_notes/features/'),
          isFalse,
          reason: '${file.path} imports $uri',
        );
        final bool isRelative = !uri.startsWith('package:') && !uri.startsWith('dart:');
        expect(
          isRelative && uri.contains('features/'),
          isFalse,
          reason: '${file.path} imports $uri',
        );
      }
    }
  });

  test('markdown.dart contains only export directives', () {
    final String barrel = File('$_grammarDir/markdown.dart').readAsStringSync();
    final List<String> lines = barrel.split('\n');
    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      expect(
        trimmed.startsWith('export '),
        isTrue,
        reason: 'unexpected line in markdown.dart: $trimmed',
      );
    }
  });

  test('every grammar declaration carries the Md prefix', () {
    for (final File file in _grammarFiles()) {
      if (file.path == '$_grammarDir/markdown.dart') {
        continue;
      }
      final List<String> lines = file.readAsLinesSync();
      for (final String line in lines) {
        final RegExpMatch? typeMatch = _typeDeclPattern.firstMatch(line);
        if (typeMatch != null) {
          final String remainder = typeMatch.group(2)!.trimLeft();
          final RegExpMatch? nameMatch = RegExp(r'^([a-zA-Z_][A-Za-z0-9_]*)').firstMatch(remainder);
          final String? name = nameMatch?.group(1);
          final bool isUnnamedExtension = typeMatch.group(1) == 'extension' && name == 'on';
          if (!isUnnamedExtension) {
            expect(
              name != null && _isMdPrefixed(name),
              isTrue,
              reason: '${file.path}: "$line" is not Md-prefixed',
            );
          }
          continue;
        }

        if (_functionDeclPattern.hasMatch(line) &&
            !line.startsWith('import') &&
            !line.startsWith('export') &&
            !line.startsWith('part') &&
            !line.startsWith('library') &&
            !line.startsWith('const') &&
            !line.startsWith('final') &&
            !line.startsWith('var') &&
            !line.startsWith('late') &&
            !line.startsWith('external')) {
          final String? name = _functionNameOf(_functionDeclPattern.stringMatch(line)!);
          if (name != null) {
            expect(
              _islowerMdPrefixed(name) || _functionNameExceptions.contains(name),
              isTrue,
              reason: '${file.path}: "$line" is not md-prefixed',
            );
          }
          continue;
        }

        if (_variableDeclPattern.hasMatch(line) && !_typeDeclPattern.hasMatch(line)) {
          final String? name = _variableNameOf(line);
          if (name != null) {
            expect(
              _islowerMdPrefixed(name),
              isTrue,
              reason: '${file.path}: "$line" is not md-prefixed',
            );
          }
        }
      }
    }
  });
}
