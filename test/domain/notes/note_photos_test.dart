import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/domain/notes/note_photos.dart';

import '../../features/notes/support/notes_harness.dart'
    show photoIdA, photoIdB, photoIdC, prefixOf;
import '../../support/photo_line_fixture.dart';

void main() {
  test('a note lists its photos in order with captions', () {
    final String source = <String>[
      '# Low tide walk',
      mdPhotoLine(photoIdA, caption: 'The harbour wall'),
      'We walked out past the ferry office.',
      mdPhotoLine(photoIdB, side: MdPhotoSide.left),
      '- [ ] buy stamps',
      mdPhotoLine(
        photoIdC,
        caption: 'Gulls on the pier',
        size: MdPhotoSize.large,
      ),
      'Home before the rain.',
    ].join('\n\n');

    expect(notePhotosOf(parseNoteTree(source)), <NotePhoto>[
      NotePhoto(reference: prefixOf(photoIdA), caption: 'The harbour wall'),
      NotePhoto(reference: prefixOf(photoIdB), caption: ''),
      NotePhoto(reference: prefixOf(photoIdC), caption: 'Gulls on the pier'),
    ]);
    expect(
      notePhotosOf(
        parseNoteTree('A quiet morning.\n\n- rain on the roof\n\n> no photos'),
      ),
      isEmpty,
    );
    expect(notePhotosOf(parseNoteTree('')), isEmpty);
  });
}
