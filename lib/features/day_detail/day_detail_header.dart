import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'day_detail_heading.dart';

const Key dayDetailBackKey = ValueKey<String>('day-detail-back');

const String dayDetailCloseLabel = 'Close';

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

class DayDetailHeader extends StatelessWidget {
  const DayDetailHeader({
    super.key,
    required this.date,
    required this.today,
    required this.onClose,
    this.closeLabel = dayDetailCloseLabel,
  });

  final String date;
  final DateTime today;
  final VoidCallback onClose;
  final String closeLabel;

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
            _headerHorizontalPadding,
            _headerVerticalPadding - _backVerticalReach,
          ),
          child: Row(
            children: <Widget>[
              _backButton(context),
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
                    Text(
                      heading.title,
                      style: textStyles.headlineSerif.copyWith(
                        height: _titleLineHeight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DashedDivider(thickness: _ruleThickness, color: colors.ink25),
      ],
    );
  }

  Widget _backButton(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      button: true,
      label: closeLabel,
      onTap: onClose,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onClose,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FocusRing(
              onPressed: onClose,
              borderRadius: _backBorderRadius,
              child: Container(
                key: dayDetailBackKey,
                width: _backExtent,
                height: _backExtent,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.cardWarm,
                  border: context.shadows.outline,
                  borderRadius: _backBorderRadius,
                ),
                child: SizedBox.square(
                  dimension: _chevronExtent,
                  child: CustomPaint(
                    painter: _BackChevronPainter(color: colors.ink),
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

class _BackChevronPainter extends CustomPainter {
  const _BackChevronPainter({required this.color});

  final Color color;

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
    const double reach = _chevronArm / 2;
    final Path path = Path()
      ..moveTo(cx + reach, cy - _chevronArm)
      ..lineTo(cx - reach, cy)
      ..lineTo(cx + reach, cy + _chevronArm);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_BackChevronPainter oldDelegate) =>
      color != oldDelegate.color;
}
