import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/dashed_divider.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';

const List<String> _monthLabels = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const int _weekColumns = 7;
const int _gridRows = 5;
const double _fadedOpacity = 0.22;
const double _cellRadius = 2;
const double _outlineWidth = 1;
const double _dashLength = 2;
const double _dashGap = 2;
const double _minTapTarget = 48;
const Color _highlightTint = Color(0x21C76A54);
const Color _clear = Color(0x00000000);
const Duration _tintDuration = Duration(milliseconds: 200);
const BorderRadius _monthRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusIconButton),
);

enum MeadowDayMark { mood, sprout, empty, future }

@immutable
class MeadowDaySquare {
  const MeadowDaySquare({required this.mark, this.fill, this.faded = false});

  final MeadowDayMark mark;
  final Color? fill;
  final bool faded;

  @override
  bool operator ==(Object other) =>
      other is MeadowDaySquare &&
      other.mark == mark &&
      other.fill == fill &&
      other.faded == faded;

  @override
  int get hashCode => Object.hash(mark, fill, faded);

  @override
  String toString() =>
      'MeadowDaySquare(mark: $mark, fill: $fill, faded: $faded)';
}

List<MeadowDaySquare> meadowMonthSquares(
  MeadowYear year,
  MeadowMonth month,
  int growthPoint,
) => List<MeadowDaySquare>.unmodifiable(<MeadowDaySquare>[
  for (int index = month.first; index < month.first + month.length; index++)
    _squareAt(year, index, growthPoint),
]);

MeadowDaySquare _squareAt(MeadowYear year, int index, int growthPoint) {
  if (index >= year.limit) {
    return const MeadowDaySquare(mark: MeadowDayMark.future);
  }
  final bool faded = index >= growthPoint;
  final MeadowDay? day = year.days[index];
  if (day == null) {
    return MeadowDaySquare(mark: MeadowDayMark.empty, faded: faded);
  }
  final Mood? mood = day.mood;
  if (mood == null) {
    return MeadowDaySquare(
      mark: MeadowDayMark.sprout,
      fill: meadowSproutChipColour,
      faded: faded,
    );
  }
  return MeadowDaySquare(
    mark: MeadowDayMark.mood,
    fill: meadowChipColour(mood),
    faded: faded,
  );
}

MeadowRange meadowMonthRange(MeadowMonth month) => MeadowRange(
  first: month.first,
  last: month.first + month.length - 1,
  key: 'm${month.month - 1}',
);

class _RibbonMetrics {
  const _RibbonMetrics({
    required this.columns,
    required this.gap,
    required this.padding,
    required this.cellGap,
    required this.labelGap,
    required this.labelSize,
    required this.chip,
    required this.tallySize,
    required this.tallySpacing,
    required this.tallyRunSpacing,
    required this.ruleGap,
    required this.rulePadding,
  });

  final int columns;
  final double gap;
  final double padding;
  final double cellGap;
  final double labelGap;
  final double labelSize;
  final double chip;
  final double tallySize;
  final double tallySpacing;
  final double tallyRunSpacing;
  final double ruleGap;
  final double rulePadding;

  double gridHeight(double monthWidth) {
    final double inner = math.max(0, monthWidth - padding * 2);
    final double cell = math.max(
      0,
      (inner - cellGap * (_weekColumns - 1)) / _weekColumns,
    );
    return cell * _gridRows + cellGap * (_gridRows - 1);
  }
}

const _RibbonMetrics _sidebar = _RibbonMetrics(
  columns: 12,
  gap: 8,
  padding: 6,
  cellGap: 2,
  labelGap: 5,
  labelSize: 11,
  chip: 16,
  tallySize: 12,
  tallySpacing: 16,
  tallyRunSpacing: 6,
  ruleGap: 12,
  rulePadding: 10,
);

const _RibbonMetrics _bottomBar = _RibbonMetrics(
  columns: 4,
  gap: 7,
  padding: 4,
  cellGap: 1.5,
  labelGap: 3,
  labelSize: 9,
  chip: 13,
  tallySize: 10,
  tallySpacing: 11,
  tallyRunSpacing: 5,
  ruleGap: 10,
  rulePadding: 8,
);

class MeadowRibbon extends StatelessWidget {
  const MeadowRibbon({
    super.key,
    required this.year,
    required this.compact,
    required this.growthPoint,
    required this.highlight,
    required this.onHighlight,
    this.columns,
    this.onFocus,
  });

  final MeadowYear year;
  final bool compact;
  final int growthPoint;
  final MeadowRange? highlight;
  final ValueChanged<MeadowRange?> onHighlight;
  final int? columns;
  final ValueChanged<int>? onFocus;

  @override
  Widget build(BuildContext context) {
    final _RibbonMetrics metrics = compact ? _bottomBar : _sidebar;
    final List<_TallyItem> tally = _tallyOf(year, growthPoint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              _months(metrics, constraints.maxWidth),
        ),
        if (tally.isNotEmpty) ...<Widget>[
          SizedBox(height: metrics.ruleGap),
          DashedDivider(
            thickness: 1,
            color: context.colors.ink18,
            dashLength: 3,
            dashGap: 3,
          ),
          SizedBox(height: metrics.rulePadding),
          _Tally(items: tally, metrics: metrics),
        ],
      ],
    );
  }

  Widget _months(_RibbonMetrics metrics, double width) {
    final int columns = this.columns ?? metrics.columns;
    final double monthWidth = math.max(
      0,
      (width - metrics.gap * (columns - 1)) / columns,
    );
    final double gridHeight = metrics.gridHeight(monthWidth);
    final List<MeadowMonth> months = year.months;
    final int rows = (months.length / columns).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int row = 0; row < rows; row++) ...<Widget>[
          if (row > 0) SizedBox(height: metrics.gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int column = 0; column < columns; column++) ...<Widget>[
                if (column > 0) SizedBox(width: metrics.gap),
                Expanded(
                  child: row * columns + column < months.length
                      ? _MonthButton(
                          year: year,
                          month: months[row * columns + column],
                          growthPoint: growthPoint,
                          metrics: metrics,
                          gridHeight: gridHeight,
                          compact: compact,
                          highlight: highlight,
                          onHighlight: onHighlight,
                          onFocus: onFocus,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.year,
    required this.month,
    required this.growthPoint,
    required this.metrics,
    required this.gridHeight,
    required this.compact,
    required this.highlight,
    required this.onHighlight,
    required this.onFocus,
  });

  final MeadowYear year;
  final MeadowMonth month;
  final int growthPoint;
  final _RibbonMetrics metrics;
  final double gridHeight;
  final bool compact;
  final MeadowRange? highlight;
  final ValueChanged<MeadowRange?> onHighlight;
  final ValueChanged<int>? onFocus;

  @override
  Widget build(BuildContext context) {
    final MeadowRange range = meadowMonthRange(month);
    final bool highlighted = highlight?.key == range.key;
    final ValueChanged<int>? focus = onFocus;
    void toggle() => onHighlight(highlighted ? null : range);
    final VoidCallback press = focus == null
        ? toggle
        : () => focus(month.month - 1);
    final Widget face = AnimatedContainer(
      duration: _tintDuration,
      constraints: const BoxConstraints(minHeight: _minTapTarget),
      padding: EdgeInsets.all(metrics.padding),
      decoration: BoxDecoration(
        color: highlighted ? _highlightTint : _clear,
        borderRadius: _monthRadius,
      ),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _monthLabels[month.month - 1],
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: context.textStyles.captureLabelSans.copyWith(
                color: context.colors.mutedDeep,
                fontSize: metrics.labelSize,
              ),
            ),
            SizedBox(height: metrics.labelGap),
            SizedBox(
              height: gridHeight,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: MeadowDayGridPainter(
                    squares: meadowMonthSquares(year, month, growthPoint),
                    cellGap: metrics.cellGap,
                    outline: context.colors.ink16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: highlighted,
      label: month.summary,
      onTap: press,
      child: MouseRegion(
        cursor: focus == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: compact
            ? null
            : (PointerEnterEvent event) => onHighlight(range),
        onExit: compact ? null : (PointerExitEvent event) => onHighlight(null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: compact || focus != null ? press : null,
          child: FocusRing(
            onPressed: press,
            borderRadius: _monthRadius,
            child: face,
          ),
        ),
      ),
    );
  }
}

class MeadowDayGridPainter extends CustomPainter {
  const MeadowDayGridPainter({
    required this.squares,
    required this.cellGap,
    required this.outline,
  });

  final List<MeadowDaySquare> squares;
  final double cellGap;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final double cell =
        (size.width - cellGap * (_weekColumns - 1)) / _weekColumns;
    if (cell <= _outlineWidth) {
      return;
    }
    final Radius radius = Radius.circular(math.min(_cellRadius, cell / 2));
    final Radius inner = Radius.circular(
      math.max(0, radius.x - _outlineWidth / 2),
    );
    for (int index = 0; index < squares.length; index++) {
      final MeadowDaySquare square = squares[index];
      final Rect rect = Rect.fromLTWH(
        (index % _weekColumns) * (cell + cellGap),
        (index ~/ _weekColumns) * (cell + cellGap),
        cell,
        cell,
      );
      final Color? fill = square.fill;
      if (fill != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, radius),
          Paint()..color = _fade(fill, square.faded),
        );
        continue;
      }
      final RRect edge = RRect.fromRectAndRadius(
        rect.deflate(_outlineWidth / 2),
        inner,
      );
      final Paint stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _outlineWidth
        ..color = _fade(outline, square.faded);
      if (square.mark == MeadowDayMark.future) {
        canvas.drawPath(_dashed(edge), stroke);
      } else {
        canvas.drawRRect(edge, stroke);
      }
    }
  }

  static Color _fade(Color colour, bool faded) =>
      faded ? colour.withValues(alpha: colour.a * _fadedOpacity) : colour;

  static Path _dashed(RRect edge) {
    final Path dashes = Path();
    for (final ui.PathMetric metric
        in (Path()..addRRect(edge)).computeMetrics()) {
      for (
        double start = 0;
        start < metric.length;
        start += _dashLength + _dashGap
      ) {
        dashes.addPath(
          metric.extractPath(
            start,
            math.min(start + _dashLength, metric.length),
          ),
          Offset.zero,
        );
      }
    }
    return dashes;
  }

  @override
  bool shouldRepaint(MeadowDayGridPainter oldDelegate) =>
      oldDelegate.cellGap != cellGap ||
      oldDelegate.outline != outline ||
      !listEquals(oldDelegate.squares, squares);
}

class _TallyItem {
  const _TallyItem({required this.mood, required this.count});

  final Mood? mood;
  final int count;
}

List<_TallyItem> _tallyOf(MeadowYear year, int growthPoint) {
  final List<MeadowDay> grown = <MeadowDay>[
    for (final MeadowDay day in year.days.nonNulls)
      if (day.index < growthPoint) day,
  ];
  final int sprouts = grown.where((MeadowDay day) => day.mood == null).length;
  return List<_TallyItem>.unmodifiable(<_TallyItem>[
    for (final Mood mood in moodOrder)
      if (grown.where((MeadowDay day) => day.mood == mood).length
          case final int count when count > 0)
        _TallyItem(mood: mood, count: count),
    if (sprouts > 0) _TallyItem(mood: null, count: sprouts),
  ]);
}

class _Tally extends StatelessWidget {
  const _Tally({required this.items, required this.metrics});

  final List<_TallyItem> items;
  final _RibbonMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final TextStyle count = context.textStyles.captureLabelSans.copyWith(
      color: colors.ink,
      fontSize: metrics.tallySize,
    );
    final TextStyle label = context.textStyles.captionSans.copyWith(
      fontSize: metrics.tallySize,
    );
    return Wrap(
      spacing: metrics.tallySpacing,
      runSpacing: metrics.tallyRunSpacing,
      children: <Widget>[
        for (final _TallyItem item in items)
          _tallyEntry(item, count: count, label: label, sage: colors.sage),
      ],
    );
  }

  Widget _tallyEntry(
    _TallyItem item, {
    required TextStyle count,
    required TextStyle label,
    required Color sage,
  }) {
    final Mood? mood = item.mood;
    final String name = mood?.label ?? (item.count == 1 ? 'Sprout' : 'Sprouts');
    return Semantics(
      container: true,
      label: '${item.count} $name',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: metrics.chip,
              child: mood == null
                  ? CustomPaint(painter: _SproutGlyphPainter(sage))
                  : FlowerBloom.forMood(mood, size: metrics.chip),
            ),
            const SizedBox(width: 5),
            Text('${item.count}', style: count),
            const SizedBox(width: 5),
            Text(name, style: label),
          ],
        ),
      ),
    );
  }
}

class _SproutGlyphPainter extends CustomPainter {
  const _SproutGlyphPainter(this.colour);

  final Color colour;

  static const double _viewBox = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / _viewBox;
    final Paint stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      Path()
        ..moveTo(12, 21)
        ..lineTo(12, 12)
        ..moveTo(12, 13)
        ..cubicTo(11, 9, 8, 7, 4, 7)
        ..cubicTo(4, 11, 7, 13, 12, 13)
        ..close()
        ..moveTo(12, 11)
        ..cubicTo(13, 7.5, 15.5, 6, 19, 6)
        ..cubicTo(19, 9.5, 16.5, 11, 12, 11)
        ..close(),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SproutGlyphPainter oldDelegate) =>
      oldDelegate.colour != colour;
}
