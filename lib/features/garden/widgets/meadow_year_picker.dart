import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/format/plural.dart';
import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:flutter/material.dart';

const Key meadowYearPickerButtonKey = ValueKey<String>('meadow-year-picker');
const Key meadowYearPickerPopoverKey = ValueKey<String>(
  'meadow-year-picker-popover',
);

ValueKey<String> meadowYearRowKey(int year) =>
    ValueKey<String>('meadow-year-$year');

const String meadowYearPickerLabel = 'Your meadows, year by year';
const String meadowYearPickerHeading = 'your meadows';

const double _minTapTarget = 48;
const Radius _stripeRadius = Radius.circular(3);
const int _daysPerWeek = 7;
const double _weekGap = 1;
const double _aheadDashShare = 0.5;

String _metaOf(MeadowYear year, {required bool current}) => current
    ? '${pluralize(year.blooms + year.sprouts, 'day')} so far'
    : pluralize(year.blooms, 'bloom');

String _titleOf(MeadowYear year, {required bool current}) =>
    current ? 'This year, still growing' : year.weather;

class MeadowYearList extends StatelessWidget {
  const MeadowYearList({
    super.key,
    required this.years,
    required this.openYear,
    required this.onPick,
    required this.compact,
  });

  final List<MeadowYear> years;
  final int openYear;
  final ValueChanged<int> onPick;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: meadowYearPickerPopoverKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < years.length; index++)
          _YearRow(
            key: meadowYearRowKey(years[index].year),
            year: years[index],
            current: index == 0,
            open: years[index].year == openYear,
            compact: compact,
            onPressed: () => onPick(years[index].year),
          ),
      ],
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({
    super.key,
    required this.year,
    required this.current,
    required this.open,
    required this.compact,
    required this.onPressed,
  });

  final MeadowYear year;
  final bool current;
  final bool open;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(compact ? 14 : 12),
    );
    final Widget body = Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 11, 12, 12)
          : const EdgeInsets.fromLTRB(9, 8, 9, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '${year.year}',
                style: TextStyle(
                  fontFamily: TypographyTokens.accent,
                  fontSize: compact ? 20 : 19,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: meadowCream,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _metaOf(year, current: current),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: meadowSans(11, opacity: 0.7, weight: FontWeight.w400),
                ),
              ),
            ],
          ),
          Padding(
            padding: compact
                ? const EdgeInsets.only(top: 3, bottom: 7)
                : const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              _titleOf(year, current: current),
              style: TextStyle(
                fontFamily: TypographyTokens.serif,
                fontSize: compact ? 14 : 13,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: meadowCreamAt(0.88),
              ),
            ),
          ),
          SizedBox(
            height: 7,
            child: CustomPaint(
              painter: _WeekStripePainter(
                weeks: year.weeks,
                limit: year.limit,
                empty: meadowGlassWhite(0.14),
                edge: meadowGlassWhite(0.3),
              ),
            ),
          ),
        ],
      ),
    );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Semantics(
          button: true,
          selected: open,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _minTapTarget),
                child: FocusRing(
                  onPressed: onPressed,
                  surface: FocusRingSurface.dark,
                  borderRadius: radius,
                  placement: FocusRingPlacement.edge,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: meadowGlassWhite(open ? 0.16 : 0),
                      border: open
                          ? Border.all(color: meadowGlassWhite(0.35))
                          : null,
                      borderRadius: radius,
                    ),
                    child: body,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekStripePainter extends CustomPainter {
  const _WeekStripePainter({
    required this.weeks,
    required this.limit,
    required this.empty,
    required this.edge,
  });

  final List<Mood?> weeks;
  final int limit;
  final Color empty;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) {
      return;
    }
    final double width =
        (size.width - _weekGap * (weeks.length - 1)) / weeks.length;
    final Paint dash = Paint()
      ..color = edge
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, _stripeRadius),
    );
    for (int week = 0; week < weeks.length; week++) {
      final double left = week * (width + _weekGap);
      final Mood? mood = weeks[week];
      if (mood == null && week * _daysPerWeek >= limit) {
        canvas.drawLine(
          Offset(left, 0.5),
          Offset(left + width * _aheadDashShare, 0.5),
          dash,
        );
        continue;
      }
      canvas.drawRect(
        Rect.fromLTWH(left, 0, width, size.height),
        Paint()..color = mood == null ? empty : meadowChipColour(mood),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WeekStripePainter oldDelegate) =>
      !identical(oldDelegate.weeks, weeks) ||
      oldDelegate.limit != limit ||
      oldDelegate.empty != empty ||
      oldDelegate.edge != edge;
}
