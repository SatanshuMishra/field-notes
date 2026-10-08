import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';

const String _positionLabel = 'Playback position';

const double _barRadius = 2;
const double _tallBar = 0.62;
const double _unplayedAlpha = 0.28;
const double _tallUnplayedAlpha = 0.46;

const double _playheadWidth = 2;
const double _playheadReach = 6;
const Radius _playheadRadius = Radius.circular(_playheadWidth / 2);

class ViewerWaveform extends StatelessWidget {
  const ViewerWaveform({
    super.key,
    required this.seed,
    required this.progress,
    required this.active,
    required this.height,
    this.onSeek,
    this.semanticValue,
    this.increasedValue,
    this.decreasedValue,
    this.onIncrease,
    this.onDecrease,
  });

  final int seed;
  final double progress;
  final bool active;
  final double height;
  final ValueChanged<double>? onSeek;
  final String? semanticValue;
  final String? increasedValue;
  final String? decreasedValue;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  @override
  Widget build(BuildContext context) {
    final double shown = progress.isNaN ? 0 : progress.clamp(0.0, 1.0);
    final ValueChanged<double>? seek = onSeek;
    return Semantics(
      container: true,
      slider: true,
      enabled: seek != null,
      label: _positionLabel,
      value: semanticValue,
      increasedValue: increasedValue,
      decreasedValue: decreasedValue,
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      child: NoSwipe(
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : voiceWaveformMinBars *
                            (voiceWaveformBarWidth + voiceWaveformBarGap) -
                        voiceWaveformBarGap;
              return MouseRegion(
                cursor: seek == null
                    ? MouseCursor.defer
                    : SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTapUp: seek == null
                      ? null
                      : (TapUpDetails details) =>
                            seek(_fractionAt(details.localPosition.dx, width)),
                  onHorizontalDragStart: seek == null
                      ? null
                      : (DragStartDetails details) =>
                            seek(_fractionAt(details.localPosition.dx, width)),
                  onHorizontalDragUpdate: seek == null
                      ? null
                      : (DragUpdateDetails details) =>
                            seek(_fractionAt(details.localPosition.dx, width)),
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(width, height),
                        painter: _WaveformPainter(
                          seed: seed,
                          progress: shown,
                          active: active,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.seed,
    required this.progress,
    required this.active,
  });

  final int seed;
  final double progress;
  final bool active;

  Color _colourFor(int index, int count, double fraction) {
    if (voiceWaveformBarPlayed(index, count, progress)) {
      return Palette.mediaPlayed;
    }
    return Palette.mediaInk.withValues(
      alpha: fraction > _tallBar ? _tallUnplayedAlpha : _unplayedAlpha,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final int count = voiceWaveformBarCount(size.width);
    final List<double> heights = voiceWaveformHeights(seed, count);
    const double stride = voiceWaveformBarWidth + voiceWaveformBarGap;
    final double span = count * stride - voiceWaveformBarGap;
    final double start = (size.width - span) / 2;
    final double middle = size.height / 2;
    final Paint bar = Paint()..isAntiAlias = true;
    for (int index = 0; index < count; index++) {
      final double fraction = heights[index];
      final double barHeight = size.height * fraction;
      bar.color = _colourFor(index, count, fraction);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            start + index * stride,
            middle - barHeight / 2,
            voiceWaveformBarWidth,
            barHeight,
          ),
          const Radius.circular(_barRadius),
        ),
        bar,
      );
    }
    if (!active) {
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * progress - _playheadWidth / 2,
          -_playheadReach,
          _playheadWidth,
          size.height + _playheadReach * 2,
        ),
        _playheadRadius,
      ),
      Paint()..color = Palette.mediaInk,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.progress != progress ||
      oldDelegate.active != active;
}
