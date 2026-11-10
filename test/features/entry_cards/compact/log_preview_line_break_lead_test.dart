import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/compact/log_preview.dart';

Entry _textEntry(String textContent) {
  final int at = DateTime(2026, 9, 23, 23, 45).millisecondsSinceEpoch;
  return Entry(
    id: 'e1',
    dayId: 'd1',
    type: EntryType.text,
    textContent: textContent,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  test('a first line followed by a line break is not a title', () {
    final LogPreview preview = logPreviewOf(
      _textEntry(
        'Photos from the beach\n'
        'The tide was out and the sand was warm. We found shells by the rocks.\n'
        '![](photo/abc123abc123 "right medium")\n',
      ),
    );

    expect(preview.title, isEmpty);
    expect(
      preview.snippet,
      'Photos from the beach The tide was out and the sand was warm. '
      'We found shells by the rocks.',
    );
  });
}
