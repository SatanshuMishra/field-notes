import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../domain/models/models.dart';
import '../media/media_image.dart';
import '../media/media_resolver.dart';

class InlinePhotoStrip extends StatelessWidget {
  const InlinePhotoStrip({
    super.key,
    required this.photos,
    required this.resolver,
    this.thumbnailSize = 72,
    this.spacing = 8,
  });

  final List<EntryPhoto> photos;
  final MediaResolver resolver;
  final double thumbnailSize;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final List<EntryPhoto> ordered = <EntryPhoto>[...photos]
      ..sort((EntryPhoto a, EntryPhoto b) => a.sortOrder.compareTo(b.sortOrder));
    return SizedBox(
      height: thumbnailSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ordered.length,
        separatorBuilder: (BuildContext context, int index) =>
            SizedBox(width: spacing),
        itemBuilder: (BuildContext context, int index) => MediaImage(
          resolver: resolver,
          mediaId: ordered[index].mediaId,
          errorLabel: 'Photo',
          width: thumbnailSize,
          height: thumbnailSize,
          borderRadius: Shapes.buttonBorderRadius,
        ),
      ),
    );
  }
}
