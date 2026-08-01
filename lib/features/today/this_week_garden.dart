import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:flutter/widgets.dart';

import 'today_week.dart';

const String thisWeekGardenTitle = "this week's garden";

const double _titleGap = 2;

class ThisWeekGarden extends StatelessWidget {
  const ThisWeekGarden({
    super.key,
    required this.cells,
    this.title = thisWeekGardenTitle,
    this.bloomSize = 26,
  });

  final List<TodayWeekCell> cells;
  final String title;
  final double bloomSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: TypographyTokens.sectionHeaderAccent),
        const SizedBox(height: _titleGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (final TodayWeekCell cell in cells)
              _WeekCell(cell: cell, bloomSize: bloomSize),
          ],
        ),
      ],
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({required this.cell, required this.bloomSize});

  final TodayWeekCell cell;
  final double bloomSize;

  @override
  Widget build(BuildContext context) {
    final Mood? mood = cell.mood;
    return Semantics(
      label: mood == null
          ? '${cell.weekdayLabel}, no mood'
          : '${cell.weekdayLabel}, ${mood.label}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: bloomSize,
              child: mood == null
                  ? CustomPaint(
                      painter: DashedBorderPainter(
                        color: Palette.placeholder,
                        radius: bloomSize / 2,
                      ),
                    )
                  : FlowerBloom.forMood(mood, size: bloomSize),
            ),
            const SizedBox(height: 6),
            Text(
              cell.weekdayLabel,
              style: cell.isToday
                  ? TypographyTokens.captionSans.copyWith(
                      color: Palette.coral,
                      fontWeight: FontWeight.w700,
                    )
                  : TypographyTokens.captionSans,
            ),
          ],
        ),
      ),
    );
  }
}
