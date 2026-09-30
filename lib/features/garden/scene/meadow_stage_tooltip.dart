import 'package:flutter/widgets.dart';

import 'package:field_notes/design/format/plural.dart';
import 'package:field_notes/design/tokens/field_notes_colors.dart';
import 'package:field_notes/design/tokens/shapes.dart';
import 'package:field_notes/design/tokens/theme_context.dart';
import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/today/today_date.dart';

const String meadowSpruceTitle = 'The old spruce';
const String meadowSproutLabel = 'Wrote, no mood · Sprout';

const String _separator = ' · ';
const int _shadowAlpha = 0x33;

class MeadowTip {
  const MeadowTip({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  bool operator ==(Object other) =>
      other is MeadowTip && other.title == title && other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(title, subtitle);
}

MeadowTip meadowPlantTip({
  required int year,
  required int dayIndex,
  required Mood? mood,
  required int entries,
}) {
  final DateTime date = DateTime(year, 1, 1 + dayIndex);
  return MeadowTip(
    title: '${shortWeekdayLabel(date)}, ${shortMonthDayLabel(date)}',
    subtitle: <String>[
      if (mood == null)
        meadowSproutLabel
      else
        '${mood.label}$_separator${mood.flower.label}',
      if (entries > 0) pluralize(entries, 'entry', 'entries'),
    ].join(_separator),
  );
}

MeadowTip meadowSpruceTip(MeadowYear year) => MeadowTip(
  title: meadowSpruceTitle,
  subtitle: meadowRunLabel(year.year, year.longestRun),
);

class MeadowStageTooltip extends StatelessWidget {
  const MeadowStageTooltip({
    super.key,
    required this.tip,
    required this.compact,
  });

  final MeadowTip tip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final _TooltipMetrics metrics = compact
        ? _TooltipMetrics.card
        : _TooltipMetrics.bubble;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardBright,
        border: Border.all(color: colors.line, width: Shapes.outlineWidth),
        borderRadius: BorderRadius.all(Radius.circular(metrics.radius)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadowTint(_shadowAlpha),
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Padding(
        padding: metrics.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tip.title,
              maxLines: 1,
              softWrap: false,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
              style: TextStyle(
                fontFamily: TypographyTokens.serif,
                fontSize: metrics.titleSize,
                fontWeight: FontWeight.w500,
                height: metrics.titleHeight,
                color: colors.ink,
              ),
            ),
            SizedBox(height: metrics.gap),
            Text(
              tip.subtitle,
              maxLines: 1,
              softWrap: false,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: metrics.subtitleSize,
                fontWeight: FontWeight.w500,
                color: colors.mutedDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TooltipMetrics {
  const _TooltipMetrics({
    required this.radius,
    required this.padding,
    required this.titleSize,
    required this.titleHeight,
    required this.subtitleSize,
    required this.gap,
  });

  static const _TooltipMetrics bubble = _TooltipMetrics(
    radius: Shapes.radiusControl,
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    titleSize: 16,
    titleHeight: 1.1,
    subtitleSize: 12,
    gap: 3,
  );

  static const _TooltipMetrics card = _TooltipMetrics(
    radius: Shapes.radiusSm,
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    titleSize: 14,
    titleHeight: 1.15,
    subtitleSize: 10,
    gap: 2,
  );

  final double radius;
  final EdgeInsets padding;
  final double titleSize;
  final double titleHeight;
  final double subtitleSize;
  final double gap;
}
