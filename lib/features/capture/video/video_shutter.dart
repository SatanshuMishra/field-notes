import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/motion/motion_tokens.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';

enum VideoShutterForm { ready, countdown, pause, stop, resume }

ValueKey<String> videoShutterFormKey(VideoShutterForm form) =>
    ValueKey<String>('video-shutter-form-${form.name}');

const Color _shutterRing = Color(0xEBF3E6D1);
const Color _shutterPauseInk = Color(0xFFFFFFFF);

const double _sidebarShutter = 80;
const double _bottomBarShutter = 72;
const double _shutterRingWidth = 3;
const double _sidebarShutterDot = 30;
const double _bottomBarShutterDot = 27;
const double _countdownDotShare = 2 / 3;
const double _sidebarStopSquare = 26;
const double _bottomBarStopSquare = 24;
const double _stopSquareRadius = 5;
const double _shutterPauseGlyph = 26;
const double _ringStart = -math.pi / 2;
const double _fullTurn = 2 * math.pi;

double videoShutterDiameter({required bool sidebar}) =>
    sidebar ? _sidebarShutter : _bottomBarShutter;

class VideoCountdownRingPainter extends CustomPainter {
  const VideoCountdownRingPainter({
    required this.fraction,
    required this.color,
    this.strokeWidth = _shutterRingWidth,
  });

  final double fraction;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double sweep = fraction.clamp(0.0, 1.0) * _fullTurn;
    if (sweep <= 0 || size.isEmpty) {
      return;
    }
    final Rect bounds = (Offset.zero & size).deflate(strokeWidth / 2);
    canvas.drawArc(
      bounds,
      _ringStart,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(VideoCountdownRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

class VideoShutterFace extends StatelessWidget {
  const VideoShutterFace({
    super.key,
    required this.form,
    required this.sidebar,
    required this.breath,
    required this.fade,
  });

  final VideoShutterForm form;
  final bool sidebar;
  final Animation<double> breath;
  final Duration fade;

  @override
  Widget build(BuildContext context) {
    final double diameter = videoShutterDiameter(sidebar: sidebar);
    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: _shutterRing, width: _shutterRingWidth),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: fade,
            switchInCurve: Motion.fadeCurve,
            switchOutCurve: Motion.fadeCurve,
            child: KeyedSubtree(
              key: videoShutterFormKey(form),
              child: _core(context, diameter),
            ),
          ),
        ],
      ),
    );
  }

  double get _dot => sidebar ? _sidebarShutterDot : _bottomBarShutterDot;

  Widget _core(BuildContext context, double diameter) {
    final Color record = context.colors.accentRecord;
    return switch (form) {
      VideoShutterForm.ready ||
      VideoShutterForm.resume => _recordDot(record, _dot),
      VideoShutterForm.countdown => SizedBox.square(
        dimension: diameter,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: AnimatedBuilder(
                animation: breath,
                builder: (BuildContext context, Widget? _) => CustomPaint(
                  painter: VideoCountdownRingPainter(
                    fraction: breath.value,
                    color: record,
                  ),
                ),
              ),
            ),
            _recordDot(record, _dot * _countdownDotShare),
          ],
        ),
      ),
      VideoShutterForm.pause => const IconStickerGlyphIcon(
        glyph: IconStickerGlyph.pause,
        color: _shutterPauseInk,
        size: _shutterPauseGlyph,
      ),
      VideoShutterForm.stop => SizedBox.square(
        dimension: sidebar ? _sidebarStopSquare : _bottomBarStopSquare,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: record,
            borderRadius: const BorderRadius.all(
              Radius.circular(_stopSquareRadius),
            ),
          ),
        ),
      ),
    };
  }

  Widget _recordDot(Color color, double dimension) {
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
