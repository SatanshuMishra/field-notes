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
  test('a title followed by one line break leads alone', () {
    final LogPreview preview = logPreviewOf(
      _textEntry(
        'Photos from the beach\n'
        'The tide was out and the sand was warm. We found shells by the rocks.\n'
        '![](photo/abc123abc123 "right medium")\n',
      ),
    );

    expect(preview.lead, 'Photos from the beach');
    expect(
      preview.snippet,
      'The tide was out and the sand was warm. We found shells by the rocks.',
    );
  });
}
