import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdPhotoLine, MdPhotoPlacement, MdPhotoSide, MdPhotoSize;

import '../features/notes/support/notes_harness.dart'
    show photoIdA, photoIdB, photoLine;
import 'photo_line_fixture.dart';

void main() {
  test('the fixture writes the canonical line for every side and size', () {
    for (final MdPhotoSide side in MdPhotoSide.values) {
      for (final MdPhotoSize size in MdPhotoSize.values) {
        expect(
          mdPhotoLine(photoIdA, side: side, size: size),
          '![](photo/a1b2c3d4e5f6 "${side.name} ${size.name}")',
        );
      }
    }
    expect(
      mdPhotoLine(
        photoIdB,
        caption: 'Low tide',
        side: MdPhotoSide.left,
        size: MdPhotoSize.large,
      ),
      '![Low tide](photo/b2c3d4e5f6a1 "left large")',
    );
    expect(mdPhotoLine(photoIdA), '![](photo/a1b2c3d4e5f6 "right medium")');
  });

  test('the fixture matches the harness photoLine for the default placement', () {
    expect(mdPhotoLine(photoIdA), photoLine(photoIdA));
    expect(
      mdPhotoLine(photoIdA, caption: 'Low tide'),
      photoLine(photoIdA, caption: 'Low tide'),
    );
  });

  test('the fixture sanitises and trims the caption', () {
    expect(
      mdPhotoLine(photoIdA, caption: '  a]b\nc  '),
      '![ab c](photo/a1b2c3d4e5f6 "right medium")',
    );
  });

  test('the fixture output round-trips through MdPhotoLine.match', () {
    final String line = mdPhotoLine(
      photoIdB,
      side: MdPhotoSide.centre,
      size: MdPhotoSize.small,
    );
    final MdPhotoLine? match = MdPhotoLine.match(line, 0, line.length);
    expect(match?.reference, 'b2c3d4e5f6a1');
    expect(
      match?.placement,
      const MdPhotoPlacement(side: MdPhotoSide.centre, size: MdPhotoSize.small),
    );
  });
}
