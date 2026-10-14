import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

const double voiceWaveformBarWidth = 3;
const double voiceWaveformBarGap = 2;
const double voiceWaveformBarsHeight = 28;
const double voiceWaveformTargetHeight = 48;
const int voiceWaveformMinBars = 8;

const double _barRadius = 2;
const double _midThreshold = 0.62;
const double _minHeight = 0.07;
const double _highestWeight = 0.65;
const double _meanWeight = 0.35;
const double _smallestLargest = 0.001;

const double _playheadWidth = 2;
const double _playheadReach = 2;
const double _playheadHalo = 2;
const double _playheadHaloAlpha = 0.18;
const Radius _playheadRadius = Radius.circular(1);

const Duration _colourShift = Duration(milliseconds: 150);
const Curve _colourCurve = Curves.ease;

const Key voiceWaveformPlayheadKey = ValueKey<String>('voice-wave-playhead');

Key voiceWaveformBarKey(int index) => ValueKey<String>('voice-wave-bar-$index');

int voiceWaveformBarCount(double width) => math.max(
  voiceWaveformMinBars,
  ((width + voiceWaveformBarGap) /
          (voiceWaveformBarWidth + voiceWaveformBarGap))
      .floor(),
);

List<double> voiceWaveformBars(List<double>? peaks, int count) {
  if (peaks == null || peaks.isEmpty) {
    return List<double>.unmodifiable(List<double>.filled(count, _minHeight));
  }
  final List<double> values = <double>[
    for (int index = 0; index < count; index++) _barValue(peaks, index, count),
  ];
  final double largest = math.max(
    _smallestLargest,
    values.fold<double>(0, math.max),
  );
  return List<double>.unmodifiable(<double>[
    for (final double value in values) math.max(_minHeight, value / largest),
  ]);
}

double _barValue(List<double> peaks, int index, int count) {
  final int total = peaks.length;
  final double from = index * total / count;
  final double to = math.max(from + 1, (index + 1) * total / count);
  final int first = from.floor();
  final int end = math.min(total, to.ceil());
  final Iterable<double> share = peaks.getRange(first, end);
  final double highest = share.reduce(math.max);
  final double mean =
      share.fold<double>(0, (double sum, double peak) => sum + peak) /
      (end - first);
  return _highestWeight * highest + _meanWeight * mean;
}

bool voiceWaveformBarPlayed(int index, int count, double progress) =>
    (index + 0.5) / count <= progress;

class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.peaks,
    required this.active,
    required this.progress,
    this.onSeek,
  });

  final List<double>? peaks;
  final bool active;
  final double progress;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final double shown = progress.isNaN ? 0 : progress.clamp(0.0, 1.0);
    return SizedBox(
      height: voiceWaveformTargetHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : voiceWaveformMinBars *
                        (voiceWaveformBarWidth + voiceWaveformBarGap) -
                    voiceWaveformBarGap;
          final ValueChanged<double>? seek = onSeek;
          return MouseRegion(
            cursor: seek == null ? MouseCursor.defer : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapUp: seek == null
                  ? null
                  : (TapUpDetails details) =>
                        seek(_fractionAt(details.localPosition.dx, width)),
              child: ExcludeSemantics(
                child: SizedBox(
                  width: width,
                  height: voiceWaveformTargetHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: <Widget>[
                      RepaintBoundary(
                        child: _Bars(
                          peaks: peaks,
                          width: width,
                          active: active,
                          progress: shown,
                        ),
                      ),
                      if (active) _playhead(context, width * shown),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  Widget _playhead(BuildContext context, double centre) {
    const double height = voiceWaveformBarsHeight + _playheadReach * 2;
    return Positioned(
      key: voiceWaveformPlayheadKey,
      left: centre - _playheadWidth / 2,
      top: (voiceWaveformTargetHeight - height) / 2,
      width: _playheadWidth,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.accentInk,
          borderRadius: const BorderRadius.all(_playheadRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Palette.coral.withValues(alpha: _playheadHaloAlpha),
              spreadRadius: _playheadHalo,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.peaks,
    required this.width,
    required this.active,
    required this.progress,
  });

  final List<double>? peaks;
  final double width;
  final bool active;
  final double progress;

  Color _colourFor(
    int index,
    int count,
    double height,
    FieldNotesColors colors,
  ) {
    if (active) {
      return voiceWaveformBarPlayed(index, count, progress)
          ? Palette.coral
          : colors.ink22;
    }
    return height > _midThreshold ? colors.waveMid : colors.waveLight;
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final int count = voiceWaveformBarCount(width);
    final List<double> heights = voiceWaveformBars(peaks, count);
    final double stride = math.max(
      voiceWaveformBarWidth + voiceWaveformBarGap,
      (width - voiceWaveformBarWidth) / (count - 1),
    );
    final Duration shift = MediaQuery.maybeDisableAnimationsOf(context) == true
        ? Duration.zero
        : _colourShift;
    return SizedBox(
      width: width,
      height: voiceWaveformBarsHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          for (int index = 0; index < count; index++)
            Positioned(
              key: voiceWaveformBarKey(index),
              left: index * stride,
              top: voiceWaveformBarsHeight * (1 - heights[index]) / 2,
              width: voiceWaveformBarWidth,
              height: voiceWaveformBarsHeight * heights[index],
              child: AnimatedContainer(
                duration: shift,
                curve: _colourCurve,
                decoration: BoxDecoration(
                  color: _colourFor(index, count, heights[index], colors),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_barRadius),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
