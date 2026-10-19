import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sharedPiece = 'lib/design/interaction/pressable.dart';
const int _furthestParent = 40;

final RegExp _pressableOpen = RegExp(r'(^|[^A-Za-z_])Pressable\(');
final RegExp _semanticsOpen = RegExp(
  r'^(return\s+)?(child:\s*)?(MergeSemantics|Semantics)\($',
);
final RegExp _transparentOpen = RegExp(
  r'^(return\s+)?(child:\s*)?(MouseRegion|Padding)\($',
);
final RegExp _namedArgument = RegExp(r'^[A-Za-z_]+:\s[^(){}]*,$');
final RegExp _hoverArgument = RegExp(r'^onEnter:.*,$');

String? _semanticsParent(List<String> lines, int pressableLine) {
  for (
    int index = pressableLine - 1;
    index >= 0 && index >= pressableLine - _furthestParent;
    index--
  ) {
    final String line = lines[index].trim();
    if (_semanticsOpen.hasMatch(line)) {
      return '${index + 1}';
    }
    final bool passesThrough =
        _transparentOpen.hasMatch(line) ||
        _namedArgument.hasMatch(line) ||
        _hoverArgument.hasMatch(line) ||
        line == 'child:';
    if (!passesThrough) {
      return null;
    }
  }
  return null;
}

List<String> _wrappedPressables() {
  final List<File> sources =
      Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (File file) =>
                file.path.endsWith('.dart') && file.path != _sharedPiece,
          )
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  final List<String> found = <String>[];
  for (final File source in sources) {
    final List<String> lines = source.readAsLinesSync();
    for (int index = 0; index < lines.length; index++) {
      if (!_pressableOpen.hasMatch(lines[index])) {
        continue;
      }
      final String? wrapper = _semanticsParent(lines, index);
      if (wrapper != null) {
        found.add('${source.path}:${index + 1} (Semantics at line $wrapper)');
      }
    }
  }
  return found;
}

void main() {
  test('no Semantics or MergeSemantics wraps a Pressable', () {
    expect(
      _wrappedPressables(),
      isEmpty,
      reason:
          'Pressable builds its own semantics node, so a wrapper outside it '
          'splits the control into a nameless outer node and a named inner '
          'one; pass the flag to Pressable instead.',
    );
  });
}
