import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import '../model/calendar_month.dart';
import 'calendar_chevron_button.dart';

const String calendarBrowseHint = '← → to browse · T for this week';

const double _hintGap = 16;
const double _actionGap = 8;
const double _chevronGap = 6;
const double _titleCaretSize = 16;
const double _titleCaretGap = 4;
const EdgeInsets _titlePadding = EdgeInsets.symmetric(
  horizontal: 6,
  vertical: 4,
);
const EdgeInsets _thisWeekPadding = EdgeInsets.fromLTRB(10, 7, 12, 7);
const double _thisWeekArrowSize = 12;
const double _thisWeekArrowGap = 5;

const TextStyle _titleStyle = TypographyTokens.displaySerif;

const TextStyle _hintStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: Palette.muted,
);

const TextStyle _thisWeekStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  height: 1,
  color: Palette.onAccent,
);

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    super.key,
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.currentMonth,
    this.onShowCurrentMonth,
    this.onOpenPicker,
    this.titleKey,
    this.thisWeekKey,
    this.pickerLink,
  });

  final MonthRef month;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final MonthRef? currentMonth;
  final VoidCallback? onShowCurrentMonth;
  final VoidCallback? onOpenPicker;
  final Key? titleKey;
  final Key? thisWeekKey;
  final LayerLink? pickerLink;

  @override
  Widget build(BuildContext context) {
    final MonthRef? current = currentMonth;
    final VoidCallback? showCurrent = onShowCurrentMonth;
    final bool showThisWeek =
        current != null && showCurrent != null && current != month;
    final bool thisWeekPointsBack = current != null &&
        (month.year * 12 + month.month) > (current.year * 12 + current.month);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextScaler scaler = MediaQuery.textScalerOf(context);
        final TextDirection direction = Directionality.of(context);
        final double actionsWidth = calendarChevronButtonSize * 2 +
            _chevronGap +
            (showThisWeek ? _actionGap + _thisWeekWidth(scaler, direction) : 0);
        final double titleWidth =
            _textWidth(month.title, _titleStyle, scaler, direction) +
                _titlePadding.horizontal +
                _titleCaretGap +
                _titleCaretSize;
        final double hintWidth = _textWidth(
          calendarBrowseHint,
          _hintStyle,
          scaler,
          direction,
        );
        final bool showHint =
            constraints.maxWidth - titleWidth - actionsWidth - _hintGap * 2 >=
                hintWidth;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(left: _titlePadding.left),
                    child: Text(
                      'explore',
                      style: TypographyTokens.pageEyebrowAccent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _anchored(
                    _TitleButton(
                      key: titleKey,
                      title: month.title,
                      onPressed: onOpenPicker,
                    ),
                  ),
                ],
              ),
            ),
            if (showHint) ...<Widget>[
              const SizedBox(width: _hintGap),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  calendarBrowseHint,
                  maxLines: 1,
                  softWrap: false,
                  style: _hintStyle,
                ),
              ),
              const SizedBox(width: _hintGap),
            ],
            if (showThisWeek) ...<Widget>[
              _ThisWeekButton(
                key: thisWeekKey,
                pointsBack: thisWeekPointsBack,
                onPressed: showCurrent,
              ),
              const SizedBox(width: _actionGap),
            ],
            CalendarChevronButton(
              direction: ChevronDirection.previous,
              semanticLabel: 'Previous month',
              onPressed: onPreviousMonth,
            ),
            const SizedBox(width: _chevronGap),
            CalendarChevronButton(
              direction: ChevronDirection.next,
              semanticLabel: 'Next month',
              onPressed: onNextMonth,
            ),
          ],
        );
      },
    );
  }

  Widget _anchored(Widget child) {
    final LayerLink? link = pickerLink;
    if (link == null) {
      return child;
    }
    return CompositedTransformTarget(link: link, child: child);
  }

  static double _thisWeekWidth(TextScaler scaler, TextDirection direction) =>
      _thisWeekPadding.horizontal +
      Shapes.outlineWidth * 2 +
      _thisWeekArrowSize +
      _thisWeekArrowGap +
      _textWidth('This week', _thisWeekStyle, scaler, direction);

  static double _textWidth(
    String text,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }
}

class _TitleButton extends StatefulWidget {
  const _TitleButton({super.key, required this.title, this.onPressed});

  final String title;
  final VoidCallback? onPressed;

  @override
  State<_TitleButton> createState() => _TitleButtonState();
}

class _TitleButtonState extends State<_TitleButton> {
  bool _hovered = false;

  void _setHovered(bool hovered) {
    if (_hovered != hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Jump to a month',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _hovered ? Palette.ink08 : null,
              borderRadius: const BorderRadius.all(
                Radius.circular(Shapes.radiusCell),
              ),
            ),
            child: Padding(
              padding: _titlePadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle,
                    ),
                  ),
                  const SizedBox(width: _titleCaretGap),
                  const CalendarChevronGlyph(
                    direction: ChevronDirection.down,
                    size: _titleCaretSize,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThisWeekButton extends StatelessWidget {
  const _ThisWeekButton({
    super.key,
    required this.pointsBack,
    required this.onPressed,
  });

  final bool pointsBack;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'This week',
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Palette.coral,
              border: Shapes.outline,
              borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusSm)),
              boxShadow: Shadows.control,
            ),
            child: Padding(
              padding: _thisWeekPadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox.square(
                    dimension: _thisWeekArrowSize,
                    child: CustomPaint(
                      painter: _ArrowPainter(pointsBack: pointsBack),
                    ),
                  ),
                  const SizedBox(width: _thisWeekArrowGap),
                  const Text('This week', style: _thisWeekStyle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.pointsBack});

  final bool pointsBack;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Palette.onAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final double cy = size.height / 2;
    final double inset = size.width * 0.15;
    final double head = size.width * 0.32;
    final double tip = pointsBack ? inset : size.width - inset;
    final double tail = pointsBack ? size.width - inset : inset;
    final double back = pointsBack ? tip + head : tip - head;
    final Path path = Path()
      ..moveTo(tail, cy)
      ..lineTo(tip, cy)
      ..moveTo(back, cy - head)
      ..lineTo(tip, cy)
      ..lineTo(back, cy + head);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.pointsBack != pointsBack;
}
