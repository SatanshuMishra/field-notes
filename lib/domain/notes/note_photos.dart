import 'package:flutter/foundation.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';

@immutable
final class NotePhoto {
  const NotePhoto({required this.reference, required this.caption});

  final String reference;
  final String caption;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotePhoto &&
          reference == other.reference &&
          caption == other.caption;

  @override
  int get hashCode => Object.hash(reference, caption);

  @override
  String toString() => "NotePhoto($reference, '$caption')";
}

List<NotePhoto> notePhotosOf(MdTree tree) =>
    List<NotePhoto>.unmodifiable(<NotePhoto>[
      for (final MdBlock block in tree.blocks)
        if (block.photoLine case final MdPhotoLineData photo)
          NotePhoto(reference: photo.reference, caption: photo.caption),
    ]);
