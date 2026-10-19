import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'day_detail_heading.dart';

const Key dayDetailBackKey = ValueKey<String>('day-detail-back');

const Key dayDetailEarlierDayKey = ValueKey<String>('day-detail-earlier-day');
const Key dayDetailLaterDayKey = ValueKey<String>('day-detail-later-day');

const String dayDetailCloseLabel = 'Close';
const String dayDetailEarlierDayLabel = 'Earlier day';
const String dayDetailLaterDayLabel = 'Later day';

const double _headerVerticalPadding = 16;
const double _headerHorizontalPadding = 18;
const double _headerGap = 12;
const double _ruleThickness = 1.5;
const double _backExtent = 34;
const BorderRadius _backBorderRadius = BorderRadius.all(Radius.circular(10));
const double _minTapTarget = 48;
const double _backReach = (_minTapTarget - _backExtent) / 2;
const double _backVerticalReach = 4;
const double _chevronExtent = 16;
const double _chevronArm = 4.5;
const double _chevronStrokeWidth = 2;
const double _titleLineHeight = 1;
const EdgeInsets _sheetHeaderPadding = EdgeInsets.fromLTRB(18, 6, 18, 10);
const double _sheetTitleSize = 22;
const double _sheetTitleLineHeight = 1.05;
const double _disabledStepOpacity = 0.4;

class DayDetailSheetHeader extends StatelessWidget {
  const DayDetailSheetHeader({
    super.key,
    required this.date,
    required this.today,
    this.onEarlier,
    this.onLater,
  });

  final String date;
  final DateTime today;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final DayDetailHeading heading = dayDetailHeadingFor(date, today: today);
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: _sheetHeaderPadding.copyWith(
            right: _sheetHeaderPadding.right - _backReach,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      dayDetailKickerFor(date, today: today),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyles.stampAccent.copyWith(
                        color: colors.accentInk,
                      ),
                    ),
                    Text(
                      heading.title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: textStyles.headlineSerif.copyWith(
                        fontSize: _sheetTitleSize,
                        height: _sheetTitleLineHeight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _headerGap - _backReach),
              _DayStepButtons(onEarlier: onEarlier, onLater: onLater),
            ],
          ),
        ),
        DashedDivider(thickness: _ruleThickness, color: colors.ink22),
      ],
    );
  }
}

class DayDetailHeader extends StatelessWidget {
  const DayDetailHeader({
    super.key,
    required this.date,
    required this.today,
    required this.onClose,
    this.closeLabel = dayDetailCloseLabel,
    this.onEarlier,
    this.onLater,
  });

  final String date;
  final DateTime today;
  final VoidCallback onClose;
  final String closeLabel;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final DayDetailHeading heading = dayDetailHeadingFor(date, today: today);
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _headerHorizontalPadding - _backReach,
            _headerVerticalPadding - _backVerticalReach,
            _headerHorizontalPadding - _backReach,
            _headerVerticalPadding - _backVerticalReach,
          ),
          child: Row(
            children: <Widget>[
              _ChevronButton(
                faceKey: dayDetailBackKey,
                label: closeLabel,
                direction: AxisDirection.left,
                onPressed: onClose,
              ),
              const SizedBox(width: _headerGap - _backReach),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      dayDetailKickerFor(date, today: today),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyles.stampAccent.copyWith(
                        color: colors.accentInk,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        heading.title,
                        maxLines: 1,
                        softWrap: false,
                        style: textStyles.headlineSerif.copyWith(
                          height: _titleLineHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _headerGap - _backReach),
              _DayStepButtons(onEarlier: onEarlier, onLater: onLater),
            ],
          ),
        ),
        DashedDivider(thickness: _ruleThickness, color: colors.ink25),
      ],
    );
  }
}

class _DayStepButtons extends StatelessWidget {
  const _DayStepButtons({this.onEarlier, this.onLater});

  final VoidCallback? onEarlier;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ChevronButton(
          faceKey: dayDetailEarlierDayKey,
          label: dayDetailEarlierDayLabel,
          direction: AxisDirection.left,
          onPressed: onEarlier,
        ),
        _ChevronButton(
          faceKey: dayDetailLaterDayKey,
          label: dayDetailLaterDayLabel,
          direction: AxisDirection.right,
          onPressed: onLater,
        ),
      ],
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({
    required this.faceKey,
    required this.label,
    required this.direction,
    required this.onPressed,
  });

  final Key faceKey;
  final String label;
  final AxisDirection direction;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool enabled = onPressed != null;
    return Pressable(
      label: label,
      tooltip: label,
      onPressed: onPressed,
      borderRadius: _backBorderRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _minTapTarget,
          minHeight: _minTapTarget,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Opacity(
            opacity: enabled ? 1 : _disabledStepOpacity,
            child: Container(
              key: faceKey,
              width: _backExtent,
              height: _backExtent,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.cardWarm,
                border: context.shadows.outline,
                borderRadius: _backBorderRadius,
              ),
              foregroundDecoration: HoverStyle.decoration(
                color: hovered
                    ? HoverStyle.of(
                        context,
                        FocusRingSurface.light,
                        HoverShape.rounded,
                      )
                    : null,
                shape: HoverShape.rounded,
                borderRadius: _backBorderRadius,
              ),
              child: SizedBox.square(
                dimension: _chevronExtent,
                child: CustomPaint(
                  painter: _ChevronPainter(
                    color: colors.ink,
                    direction: direction,
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

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.color, required this.direction});

  final Color color;
  final AxisDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _chevronStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double reach = direction == AxisDirection.right
        ? -_chevronArm / 2
        : _chevronArm / 2;
    final Path path = Path()
      ..moveTo(cx + reach, cy - _chevronArm)
      ..lineTo(cx - reach, cy)
      ..lineTo(cx + reach, cy + _chevronArm);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      color != oldDelegate.color || direction != oldDelegate.direction;
}
