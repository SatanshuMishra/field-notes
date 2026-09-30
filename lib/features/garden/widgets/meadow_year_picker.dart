import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/format/plural.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

const Key meadowYearPickerButtonKey = ValueKey<String>('meadow-year-picker');
const Key meadowYearPickerPopoverKey = ValueKey<String>(
  'meadow-year-picker-popover',
);

ValueKey<String> meadowYearRowKey(int year) =>
    ValueKey<String>('meadow-year-$year');

const String meadowYearPickerLabel = 'Your meadows, year by year';
const String _dismissLabel = 'Close your meadows';

const double _minTapTarget = 48;
const double _popoverWidth = 300;
const double _popoverMaxHeight = 360;
const double _compactPopoverWidth = 236;
const double _compactPopoverMaxHeight = 300;
const double _popoverBorder = 2;
const double _popoverRadius = 14;
const double _popoverPadding = 6;
const Offset _popoverGap = Offset(0, 8);
const Offset _popoverHardShadow = Offset(3, 3);
const Offset _buttonShadow = Offset(1.5, 1.5);
const Duration _popDuration = Duration(milliseconds: 140);
const Color _clearBarrier = Color(0x00000000);
const BorderRadius _rowRadius = BorderRadius.all(Radius.circular(10));
const Radius _stripeRadius = Radius.circular(3);
const int _buttonShadowAlpha = 0x33;
const int _openRowAlpha = 0x21;
const int _emptyWeekAlpha = 0x1A;
const int _aheadEdgeAlpha = 0x33;
const int _daysPerWeek = 7;
const double _weekGap = 1;
const double _aheadDashShare = 0.5;
const double _caretStroke = 2.4;

final Path _caret = Path()
  ..moveTo(6, 9)
  ..lineTo(12, 15)
  ..lineTo(18, 9);

String _metaOf(MeadowYear year, {required bool current}) => current
    ? '${pluralize(year.blooms + year.sprouts, 'day')} so far'
    : pluralize(year.blooms, 'bloom');

String _titleOf(MeadowYear year, {required bool current}) =>
    current ? 'This year, still growing' : year.weather;

class MeadowYearPicker extends StatefulWidget {
  const MeadowYearPicker({
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
  State<MeadowYearPicker> createState() => _MeadowYearPickerState();
}

class _MeadowYearPickerState extends State<MeadowYearPicker> {
  final LayerLink _link = LayerLink();
  Route<int>? _route;

  Future<void> _show() async {
    if (_route != null) {
      return;
    }
    final RawDialogRoute<int> route = RawDialogRoute<int>(
      barrierDismissible: true,
      barrierLabel: _dismissLabel,
      barrierColor: _clearBarrier,
      transitionDuration: Duration.zero,
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) => _YearPopoverLayer(
            link: _link,
            years: widget.years,
            openYear: widget.openYear,
            compact: widget.compact,
          ),
    );
    setState(() => _route = route);
    final int? picked = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<int>(route);
    if (!mounted) {
      return;
    }
    setState(() => _route = null);
    if (picked != null) {
      widget.onPick(picked);
    }
  }

  @override
  void dispose() {
    final Route<int>? route = _route;
    if (route != null) {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        if (route.isActive) {
          route.navigator?.removeRoute(route);
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool compact = widget.compact;
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(compact ? 9 : 11),
    );
    final double caretSize = compact ? 10 : 12;
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: _route == null ? colors.cardBright : colors.cardLight,
        border: context.shadows.outline,
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadowTint(_buttonShadowAlpha),
            offset: _buttonShadow,
          ),
        ],
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 9.5, vertical: 6.5)
            : const EdgeInsets.symmetric(horizontal: 12.5, vertical: 8.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '${widget.openYear}',
              maxLines: 1,
              softWrap: false,
              style: context.textStyles.captureLabelSans.copyWith(
                color: colors.ink,
                fontSize: compact ? 11 : 13,
              ),
            ),
            SizedBox(width: compact ? 4 : 6),
            CustomPaint(
              size: Size.square(caretSize),
              painter: _CaretPainter(colors.ink),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label: meadowYearPickerLabel,
      value: '${widget.openYear}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: meadowYearPickerButtonKey,
          behavior: HitTestBehavior.opaque,
          onTap: _show,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: FocusRing(
                onPressed: _show,
                borderRadius: radius,
                child: ExcludeSemantics(
                  child: CompositedTransformTarget(link: _link, child: face),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YearPopoverLayer extends StatelessWidget {
  const _YearPopoverLayer({
    required this.link,
    required this.years,
    required this.openYear,
    required this.compact,
  });

  final LayerLink link;
  final List<MeadowYear> years;
  final int openYear;
  final bool compact;

  void _pick(BuildContext context, int year) {
    if (ModalRoute.isCurrentOf(context) ?? false) {
      Navigator.of(context).pop(year);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            targetAnchor: compact
                ? Alignment.bottomLeft
                : Alignment.bottomRight,
            followerAnchor: compact ? Alignment.topLeft : Alignment.topRight,
            offset: _popoverGap,
            child: _YearPopover(
              years: years,
              openYear: openYear,
              compact: compact,
              onPick: (int year) => _pick(context, year),
            ),
          ),
        ),
      ],
    );
  }
}

class _YearPopover extends StatelessWidget {
  const _YearPopover({
    required this.years,
    required this.openYear,
    required this.compact,
    required this.onPick,
  });

  final List<MeadowYear> years;
  final int openYear;
  final bool compact;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final double width = compact ? _compactPopoverWidth : _popoverWidth;
    final Widget panel = DialogHost(
      child: ConstrainedBox(
        key: meadowYearPickerPopoverKey,
        constraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
          maxHeight: compact ? _compactPopoverMaxHeight : _popoverMaxHeight,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.cardWarm,
            border: Border.fromBorderSide(
              BorderSide(color: colors.line, width: _popoverBorder),
            ),
            borderRadius: const BorderRadius.all(
              Radius.circular(_popoverRadius),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(color: colors.shadow, offset: _popoverHardShadow),
              ...Shadows.softLift,
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(_popoverBorder),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(_popoverRadius - _popoverBorder),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(_popoverPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                      child: Semantics(
                        header: true,
                        child: Text(
                          'your meadows',
                          style: context.textStyles.pageEyebrowAccent.copyWith(
                            fontSize: compact ? 13 : 15,
                          ),
                        ),
                      ),
                    ),
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return panel;
    }
    final Alignment origin = compact ? Alignment.topLeft : Alignment.topRight;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _popDuration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double progress, Widget? child) {
        return Opacity(
          opacity: progress,
          child: Transform.scale(
            scale: 0.96 + 0.04 * progress,
            alignment: origin,
            child: child,
          ),
        );
      },
      child: panel,
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
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles styles = context.textStyles;
    final Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
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
                style: styles.streakAccent.copyWith(
                  color: colors.ink,
                  fontSize: compact ? 17 : 19,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _metaOf(year, current: current),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.captionSans.copyWith(
                    fontSize: compact ? 9 : 11,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              _titleOf(year, current: current),
              style: styles.memoryTitleSerif.copyWith(
                color: colors.inkSoft,
                fontSize: compact ? 12 : 13,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(
            height: compact ? 6 : 7,
            child: CustomPaint(
              painter: _WeekStripePainter(
                weeks: year.weeks,
                limit: year.limit,
                empty: colors.ink.withAlpha(_emptyWeekAlpha),
                edge: colors.ink.withAlpha(_aheadEdgeAlpha),
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
                  borderRadius: _rowRadius,
                  placement: FocusRingPlacement.edge,
                  child: DecoratedBox(
                    decoration: open
                        ? BoxDecoration(
                            color: Palette.coral.withAlpha(_openRowAlpha),
                            border: const Border.fromBorderSide(
                              BorderSide(
                                color: Palette.coral,
                                width: Shapes.outlineWidth,
                              ),
                            ),
                            borderRadius: _rowRadius,
                          )
                        : const BoxDecoration(),
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

class _CaretPainter extends CustomPainter {
  const _CaretPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _caret,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _caretStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) => oldDelegate.color != color;
}
