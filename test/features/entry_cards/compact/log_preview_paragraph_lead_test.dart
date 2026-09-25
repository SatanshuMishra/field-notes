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
  group('logPreviewOf card lead paragraph boundary', () {
    test('a lead without a full stop ends at its paragraph', () {
      final Entry entry = _textEntry(
        'e1',
        'Photos from the beach\n\nThe tide was out and the sand was warm.',
      );

      final LogPreview preview = logPreviewOf(entry);

      expect(preview.lead, 'Photos from the beach');
      expect(preview.snippet, 'The tide was out and the sand was warm.');
    });
  });
}
