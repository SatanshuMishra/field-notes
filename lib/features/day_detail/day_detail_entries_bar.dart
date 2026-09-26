import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

const Key dayDetailAddNoteKey = ValueKey<String>('day-detail-add-note');

const double _buttonHorizontalPadding = 13;
const double _buttonVerticalPadding = 7;
const double _plusExtent = 14;
const double _plusArm = 4.5;
const double _plusStrokeWidth = 2;
const double _plusGap = 5;
const double _rowGap = 12;
const double _minTapTarget = 48;

String dayDetailEntryCountLabel(int count) {
  if (count == 1) {
    return '1 log that day';
  }
  return '${count < 0 ? 0 : count} logs that day';
}

class DayDetailEntriesBar extends StatelessWidget {
  const DayDetailEntriesBar({
    super.key,
    required this.entryCount,
    required this.onAddNote,
    this.addNoteLabel = 'Add a note',
  });

  final int? entryCount;
  final VoidCallback? onAddNote;
  final String addNoteLabel;

  @override
  Widget build(BuildContext context) {
    final int? count = entryCount;
    return Row(
      children: <Widget>[
        Expanded(
          child: count == null
              ? const SizedBox.shrink()
              : Text(
                  dayDetailEntryCountLabel(count),
                  style: TypographyTokens.stampAccent,
                ),
        ),
        const SizedBox(width: _rowGap),
        _addNoteButton(),
      ],
    );
  }

  Widget _addNoteButton() {
    return Semantics(
      button: true,
      enabled: onAddNote != null,
      child: GestureDetector(
        key: dayDetailAddNoteKey,
        behavior: HitTestBehavior.opaque,
        onTap: onAddNote,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _buttonHorizontalPadding,
                vertical: _buttonVerticalPadding,
              ),
              decoration: const BoxDecoration(
                color: Palette.coral,
                border: Shapes.outline,
                borderRadius: Shapes.buttonBorderRadius,
                boxShadow: Shadows.control,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox.square(
                    dimension: _plusExtent,
                    child: CustomPaint(painter: _PlusPainter()),
                  ),
                  const SizedBox(width: _plusGap),
                  Text(
                    addNoteLabel,
                    style: TypographyTokens.captureLabelSans
                        .copyWith(color: Palette.onAccent),
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

class _PlusPainter extends CustomPainter {
  const _PlusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = Palette.onAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = _plusStrokeWidth
      ..strokeCap = StrokeCap.round;
    final Offset centre = size.center(Offset.zero);
    canvas
      ..drawLine(
        centre.translate(-_plusArm, 0),
        centre.translate(_plusArm, 0),
        stroke,
      )
      ..drawLine(
        centre.translate(0, -_plusArm),
        centre.translate(0, _plusArm),
        stroke,
      );
  }

  @override
  bool shouldRepaint(_PlusPainter oldDelegate) => false;
}
