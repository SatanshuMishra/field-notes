import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/notes/notes.dart';

typedef _ValidCase = ({String title, PhotoSide side, PhotoSize size});

const List<_ValidCase> _validCases = <_ValidCase>[
  (title: 'right medium', side: PhotoSide.right, size: PhotoSize.medium),
  (title: 'Left SMALL', side: PhotoSide.left, size: PhotoSize.small),
  (title: 'full', side: PhotoSide.right, size: PhotoSize.full),
  (title: '', side: PhotoSide.right, size: PhotoSize.medium),
  (title: '   ', side: PhotoSide.right, size: PhotoSize.medium),
];

const List<String> _invalidTitles = <String>[
  'right huge',
  'sideways',
  'left right',
  'small large',
  'right medium tilt',
];

void main() {
  test('an unknown or repeated token makes a placement invalid', () {
    for (final _ValidCase valid in _validCases) {
      final PhotoPlacement placement = PhotoPlacement.parse(valid.title);
      expect(placement.isValid, isTrue, reason: '"${valid.title}"');
      expect(placement.side, valid.side, reason: '"${valid.title}"');
      expect(placement.size, valid.size, reason: '"${valid.title}"');
    }
    for (final String title in _invalidTitles) {
      expect(PhotoPlacement.parse(title).isValid, isFalse, reason: '"$title"');
    }

    final PhotoPlacement edited =
        PhotoPlacement.parse('right huge').copyWith(side: PhotoSide.left);
    expect(edited.isValid, isTrue);
    expect(edited.format(), 'left medium');
  });
}
