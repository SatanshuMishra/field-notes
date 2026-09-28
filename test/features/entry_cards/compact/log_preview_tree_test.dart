import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/compact/log_preview.dart';
import 'package:field_notes/features/note_engine/capabilities.dart';

Entry _textEntry(String id, String textContent) {
  final int at = DateTime(2026, 1, 1, 9).millisecondsSinceEpoch;
  return Entry(
    id: id,
    dayId: 'd1',
    type: EntryType.text,
    textContent: textContent,
    createdAt: at,
    updatedAt: at,
  );
}

final class _Expected {
  const _Expected({
    required this.source,
    required this.lead,
    required this.snippet,
    required this.isLong,
    required this.photoCount,
    required this.firstPhotoReference,
    required this.meta,
  });

  final String source;
  final String lead;
  final String snippet;
  final bool isLong;
  final int photoCount;
  final String? firstPhotoReference;
  final String meta;
}

void _expectPreview(_Expected expected) {
  final LogPreview preview = logPreviewOf(_textEntry('e1', expected.source));
  final String reason = expected.source;
  expect(preview.lead, expected.lead, reason: reason);
  expect(preview.snippet, expected.snippet, reason: reason);
  expect(preview.isLong, expected.isLong, reason: reason);
  expect(preview.photoCount, expected.photoCount, reason: reason);
  expect(
    preview.firstPhotoReference,
    expected.firstPhotoReference,
    reason: reason,
  );
  expect(preview.meta, expected.meta, reason: reason);
}

List<String> _argumentListsOf(String contents, String callee) {
  final RegExp call = RegExp('(?<![A-Za-z0-9_])${RegExp.escape(callee)}\\(');
  final List<String> lists = <String>[];
  for (final RegExpMatch match in call.allMatches(contents)) {
    int depth = 1;
    int at = match.end;
    while (at < contents.length && depth > 0) {
      final String char = contents[at];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      }
      at++;
    }
    lists.add(contents.substring(match.end, at - 1));
  }
  return lists;
}

void main() {
  group('logPreviewOf over the syntax tree', () {
    test(
      'the preview reads the new tree and keeps its output for unchanged shapes',
      () {
        const List<_Expected> unchanged = <_Expected>[
          _Expected(
            source: '# Harbour day\n\nThe fog lifted.',
            lead: 'Harbour day',
            snippet: 'The fog lifted.',
            isLong: false,
            photoCount: 0,
            firstPhotoReference: null,
            meta: '',
          ),
          _Expected(
            source: 'Packed the tent. Left at nine.\n\n- stove\n- matches',
            lead: 'Packed the tent.',
            snippet: 'Left at nine. stove matches',
            isLong: false,
            photoCount: 0,
            firstPhotoReference: null,
            meta: '',
          ),
          _Expected(
            source: '> The fog lifted.\n> We sailed at noon.',
            lead: 'The fog lifted.',
            snippet: 'We sailed at noon.',
            isLong: false,
            photoCount: 0,
            firstPhotoReference: null,
            meta: '',
          ),
          _Expected(
            source: 'Hi.\n\n![Low tide](photo/7f3ac91b2d4e "left small")',
            lead: 'Hi.',
            snippet: '',
            isLong: true,
            photoCount: 1,
            firstPhotoReference: '7f3ac91b2d4e',
            meta: '1 photo',
          ),
          _Expected(
            source: '![Low tide](photo/7f3ac91b2d4e)',
            lead: 'Low tide',
            snippet: '',
            isLong: true,
            photoCount: 1,
            firstPhotoReference: '7f3ac91b2d4e',
            meta: '1 photo',
          ),
        ];
        const List<_Expected> followingTheTree = <_Expected>[
          _Expected(
            source: '# Title #\n\nBody.',
            lead: 'Title',
            snippet: 'Body.',
            isLong: false,
            photoCount: 0,
            firstPhotoReference: null,
            meta: '',
          ),
          _Expected(
            source: '#### Tide table\n\nLow at noon.',
            lead: 'Tide table',
            snippet: 'Low at noon.',
            isLong: false,
            photoCount: 0,
            firstPhotoReference: null,
            meta: '',
          ),
          _Expected(
            source: '- [ ] pack the tent',
            lead: 'pack the tent',
            snippet: '',
            isLong: false,
            photoCount: 0,
            firstPhotoReference: null,
            meta: '',
          ),
          _Expected(
            source: '<https://harbour.example> was the booking page.',
            lead: 'https://harbour.example was the booking page.',
            snippet: '',
            isLong: false,
            photoCount: 0,
            firstPhotoReference: null,
            meta: '',
          ),
          _Expected(
            source: '- a\n  ![p](photo/abc123abc123)',
            lead: 'a !p',
            snippet: '',
            isLong: false,
            photoCount: 0,
            firstPhotoReference: null,
            meta: '',
          ),
        ];
        for (final _Expected expected in unchanged) {
          _expectPreview(expected);
        }
        for (final _Expected expected in followingTheTree) {
          _expectPreview(expected);
        }
      },
    );

    test('a table leads with its cells, or with its pipes when tables are off',
        () {
      final LogPreview preview = logPreviewOf(
        _textEntry('e2', '| Item | Qty |\n| - | - |\n| tent | 1 |'),
      );

      expect(
        preview.lead,
        tablesEnabled
            ? 'Item Qty tent 1'
            : '| Item | Qty | | - | - | | tent | 1 |',
      );
    });

    test('every consumer under lib passes the table switch to the grammar', () {
      final Map<String, List<String>> plainTextCalls = <String, List<String>>{};
      final Map<String, List<String>> treeCalls = <String, List<String>>{};
      for (final FileSystemEntity entity
          in Directory('lib').listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final String path = p.posix.joinAll(p.split(entity.path));
        final String contents = entity.readAsStringSync();
        if (path != 'lib/domain/notes/note_plain_text.dart') {
          final List<String> calls = _argumentListsOf(contents, 'plainTextOf');
          if (calls.isNotEmpty) {
            plainTextCalls[path] = calls;
          }
        }
        if (path == 'lib/features/entry_cards/compact/log_preview.dart') {
          treeCalls[path] = _argumentListsOf(contents, 'parseNoteTree');
        }
      }

      expect(
        plainTextCalls.map(
          (String path, List<String> calls) =>
              MapEntry<String, int>(path, calls.length),
        ),
        <String, int>{
          'lib/features/search/search_day_view.dart': 2,
          'lib/features/today/today_memory.dart': 1,
        },
      );
      for (final MapEntry<String, List<String>> file
          in plainTextCalls.entries) {
        for (final String arguments in file.value) {
          expect(arguments, contains('tables: tablesEnabled'), reason: file.key);
        }
      }
      final List<String> previewCalls =
          treeCalls['lib/features/entry_cards/compact/log_preview.dart'] ??
              const <String>[];
      expect(previewCalls, hasLength(1));
      expect(previewCalls.single, contains('tables: tablesEnabled'));
    });
  });
}
