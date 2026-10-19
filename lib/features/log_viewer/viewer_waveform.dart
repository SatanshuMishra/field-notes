import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';

const String _positionLabel = 'Playback position';

const double _barWidth = 4;
const double _barGap = 3;
const double _barRadius = 2;
const BorderRadius _seekHoverRadius = BorderRadius.all(
  Radius.circular(_barRadius),
);
const double _tallBar = 0.62;
const double _unplayedAlpha = 0.28;
const double _tallUnplayedAlpha = 0.46;

const double _playheadWidth = 2;
const double _playheadReach = 6;
const Radius _playheadRadius = Radius.circular(_playheadWidth / 2);

class ViewerWaveform extends StatefulWidget {
  const ViewerWaveform({
    super.key,
    required this.peaks,
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

  final List<double>? peaks;
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
  State<ViewerWaveform> createState() => _ViewerWaveformState();
}

class _ViewerWaveformState extends State<ViewerWaveform> {
  final FocusNode _pressFocus = FocusNode(
    debugLabel: 'viewer waveform press',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _pressFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = widget.progress;
    final double height = widget.height;
    final double shown = progress.isNaN ? 0 : progress.clamp(0.0, 1.0);
    final ValueChanged<double>? seek = widget.onSeek;
    return Semantics(
      container: true,
      slider: true,
      enabled: seek != null,
      label: _positionLabel,
      value: widget.semanticValue,
      increasedValue: widget.increasedValue,
      decreasedValue: widget.decreasedValue,
      onIncrease: widget.onIncrease,
      onDecrease: widget.onDecrease,
      child: NoSwipe(
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : voiceWaveformMinBars * (_barWidth + _barGap) - _barGap;
              return ExcludeSemantics(
                child: Pressable(
                  label: _positionLabel,
                  onPressedAt: seek == null
                      ? null
                      : (Offset localPosition) =>
                            seek(_fractionAt(localPosition.dx, width)),
                  surface: FocusRingSurface.dark,
                  borderRadius: _seekHoverRadius,
                  focusNode: _pressFocus,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onHorizontalDragStart: seek == null
                        ? null
                        : (DragStartDetails details) => seek(
                            _fractionAt(details.localPosition.dx, width),
                          ),
                    onHorizontalDragUpdate: seek == null
                        ? null
                        : (DragUpdateDetails details) => seek(
                            _fractionAt(details.localPosition.dx, width),
                          ),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(width, height),
                        painter: _WaveformPainter(
                          peaks: widget.peaks,
                          progress: shown,
                          active: widget.active,
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
    required this.peaks,
    required this.progress,
    required this.active,
  });

  final List<double>? peaks;
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
    const double stride = _barWidth + _barGap;
    final int count = math.max(
      voiceWaveformMinBars,
      ((size.width + _barGap) / stride).floor(),
    );
    final List<double> heights = voiceWaveformBars(peaks, count);
    final double span = count * stride - _barGap;
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
            _barWidth,
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
      !identical(oldDelegate.peaks, peaks) ||
      oldDelegate.progress != progress ||
      oldDelegate.active != active;
}
