import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdPhotoPlacement, MdPhotoSide, MdPhotoSize, canonicalPhotoLine;

import '../features/notes/support/notes_harness.dart' show prefixOf;

String mdPhotoLine(
  String id, {
  String caption = '',
  MdPhotoSide side = MdPhotoSide.right,
  MdPhotoSize size = MdPhotoSize.medium,
}) {
  return canonicalPhotoLine(
    prefixOf(id),
    caption,
    MdPhotoPlacement(side: side, size: size),
  );
}
