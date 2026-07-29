import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';
import '../../../domain/models/models.dart';
import '../media/media_image.dart';
import '../media/media_resolver.dart';

const double _separatorGap = 10;
const double _separatorThickness = 1;
const BorderRadius _thumbnailBorderRadius =
    BorderRadius.all(Radius.circular(Shapes.radiusThumb));

class InlinePhotoStrip extends StatelessWidget {
  const InlinePhotoStrip({
    super.key,
    required this.photos,
    required this.resolver,
    this.thumbnailSize = 56,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: _separatorGap),
        const DashedDivider(
          thickness: _separatorThickness,
          color: Palette.ink25,
        ),
        const SizedBox(height: _separatorGap),
        SizedBox(
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
              borderRadius: _thumbnailBorderRadius,
              border: Shapes.outline,
            ),
          ),
        ),
      ],
    );
  }
}
