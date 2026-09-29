import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/immersive/stage_phase.dart';

const String selfViewSemanticLabel = 'Self-view';
const String selfViewOnLabel = 'Self-view on';
const String selfViewOffLabel = 'Self-view off';
const String selfViewMirrorOnLabel = 'Mirror on';
const String selfViewMirrorOffLabel = 'Mirror off';

const Color _chipFill = Color(0x80140F0C);
const Color _chipEdge = Color(0x38F3E6D1);
const Color _chipInk = Color(0xFFF3E6D1);

const Color _glyphInk = Color(0xCCFFFFFF);

const double _minTapTarget = 48;
const double _edgeWidth = 1;
const double _labelSize = 11;
const double _glyphSize = 13;
const double _glyphGap = 7;
const double _glyphStroke = 2;
const double _glyphViewBox = 24;
const BorderRadius _chipRadius = BorderRadius.all(Radius.circular(16));
const EdgeInsets _sidebarPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 7,
);
const EdgeInsets _bottomBarPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 6,
);

class SelfViewChip extends StatelessWidget {
  const SelfViewChip({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    final String label = switch ((sidebar, value)) {
      (true, true) => selfViewOnLabel,
      (true, false) => selfViewOffLabel,
      (false, true) => selfViewMirrorOnLabel,
      (false, false) => selfViewMirrorOffLabel,
    };
    void toggle() => onChanged(!value);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: selfViewSemanticLabel,
      toggled: value,
      onTap: toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FocusRing(
              onPressed: toggle,
              surface: FocusRingSurface.dark,
              borderRadius: _chipRadius,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: _chipFill,
                  border: Border.fromBorderSide(
                    BorderSide(color: _chipEdge, width: _edgeWidth),
                  ),
                  borderRadius: _chipRadius,
                ),
                child: Padding(
                  padding: sidebar ? _sidebarPadding : _bottomBarPadding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (sidebar) ...const <Widget>[
                        SizedBox.square(
                          dimension: _glyphSize,
                          child: CustomPaint(painter: _CameraGlyphPainter()),
                        ),
                        SizedBox(width: _glyphGap),
                      ],
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontFamily: TypographyTokens.sans,
                          fontSize: _labelSize,
                          fontWeight: FontWeight.w600,
                          color: _chipInk,
                        ),
                      ),
                    ],
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

class _CameraGlyphPainter extends CustomPainter {
  const _CameraGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = _glyphInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = _glyphStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / _glyphViewBox);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 7, 18, 13),
        const Radius.circular(2.5),
      ),
      stroke,
    );
    canvas.drawCircle(const Offset(12, 13.5), 3.6, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(8, 7)
        ..lineTo(9.4, 4.6)
        ..lineTo(14.6, 4.6)
        ..lineTo(16, 7),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CameraGlyphPainter oldDelegate) => false;
}
