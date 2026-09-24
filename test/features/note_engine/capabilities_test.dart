import 'dart:io';

import 'package:field_notes/features/note_engine/capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tables and spell check are available by default', () {
    expect(tablesEnabled, isTrue);
    expect(spellCheckAvailable, isTrue);
  });

  test('capabilities.dart is a one-line-per-switch file with no imports', () {
    final File file = File('lib/features/note_engine/capabilities.dart');
    final List<String> lines = file.readAsLinesSync();

    final RegExp declaration =
        RegExp(r'^const bool (\w+) = (true|false);$');
    final Map<String, String> declared = <String, String>{};

    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      expect(trimmed.startsWith('import '), isFalse);
      expect(trimmed.startsWith('export '), isFalse);

      final RegExpMatch? match = declaration.firstMatch(trimmed);
      expect(match, isNotNull);
      final String name = match!.group(1)!;
      expect(declared.containsKey(name), isFalse);
      declared[name] = match.group(2)!;
    }

    expect(declared.keys.toSet(), <String>{'tablesEnabled', 'spellCheckAvailable'});
  });
}
