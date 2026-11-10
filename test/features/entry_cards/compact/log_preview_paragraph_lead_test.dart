import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/compact/log_preview.dart';

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

void main() {
  group('logPreviewOf opening paragraph', () {
    test('a paragraph without a full stop is never promoted to a title', () {
      final Entry entry = _textEntry(
        'e1',
        'Photos from the beach\n\nThe tide was out and the sand was warm.',
      );

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.title, isEmpty);
      expect(
        preview.snippet,
        'Photos from the beach The tide was out and the sand was warm.',
      );
    });
  });
}
