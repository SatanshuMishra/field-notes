import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_heading.dart';
import 'package:flutter/widgets.dart';

import 'search_day_view.dart';

class SearchDayTile extends StatelessWidget {
  const SearchDayTile({
    super.key,
    required this.view,
    required this.onTap,
  });

  final SearchDayView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String title = dayDetailHeadingFor(view.date).title;
    final Mood? mood = view.mood;
    final String previewText =
        view.preview.isEmpty ? 'No entries yet' : view.preview;
    final String countLabel =
        view.entryCount == 1 ? '1 entry' : '${view.entryCount} entries';
    final String label = <String>[
      title,
      if (mood != null) mood.label,
      previewText,
      countLabel,
    ].join(', ');

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          child: StickerCard(
            child: Row(
              children: <Widget>[
                _SearchDayFlower(mood: view.mood),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: TypographyTokens.dateSerif,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        previewText,
                        style: TypographyTokens.bodySans,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(countLabel, style: TypographyTokens.captionSans),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchDayFlower extends StatelessWidget {
  const _SearchDayFlower({required this.mood});

  final Mood? mood;

  @override
  Widget build(BuildContext context) {
    final Mood? resolved = mood;
    if (resolved == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.cardAlt,
          border: Border.fromBorderSide(
            BorderSide(
              color: Palette.placeholder,
              width: Shapes.outlineWidth,
            ),
          ),
        ),
      );
    }
    return FlowerBloom.forMood(resolved, size: 40);
  }
}
