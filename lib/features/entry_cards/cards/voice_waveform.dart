import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import '../transport/transport_timeline.dart';

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

const Duration _colourShift = Duration(milliseconds: 150);
const Curve _colourCurve = Curves.ease;

const String voiceWaveformSeekLabel = 'Playback position';

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
    this.total,
    this.height = voiceWaveformTargetHeight,
    this.barsHeight = voiceWaveformBarsHeight,
    this.palette,
  });

  final List<double>? peaks;
  final bool active;
  final double progress;
  final ValueChanged<Duration>? onSeek;
  final Duration? total;
  final double height;
  final double barsHeight;
  final TransportPalette? palette;

  @override
  Widget build(BuildContext context) {
    final double shown = progress.isNaN ? 0 : progress.clamp(0.0, 1.0);
    final Duration? length = total;
    final TransportPalette colours =
        palette ?? TransportPalette.card(context.colors);
    final Widget timeline = TransportTimeline(
      label: voiceWaveformSeekLabel,
      position: Duration(
        milliseconds: ((length?.inMilliseconds ?? 0) * shown).round(),
      ),
      total: length,
      onSeek: onSeek,
      palette: colours,
      height: height,
      unboundedWidth:
          voiceWaveformMinBars * (voiceWaveformBarWidth + voiceWaveformBarGap) -
          voiceWaveformBarGap,
      face: (BuildContext context, double width, double fraction) => Center(
        child: RepaintBoundary(
          child: _Bars(
            peaks: peaks,
            width: width,
            height: barsHeight,
            active: active,
            progress: length == null ? shown : fraction,
            palette: colours,
          ),
        ),
      ),
    );
    return length == null ? ExcludeSemantics(child: timeline) : timeline;
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.peaks,
    required this.width,
    required this.height,
    required this.active,
    required this.progress,
    required this.palette,
  });

  final List<double>? peaks;
  final double width;
  final double height;
  final bool active;
  final double progress;
  final TransportPalette palette;

  Color _colourFor(int index, int count, double barShare) {
    if (active && voiceWaveformBarPlayed(index, count, progress)) {
      return palette.played;
    }
    return barShare > _midThreshold ? palette.waveTall : palette.wave;
  }

  @override
  Widget build(BuildContext context) {
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
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          for (int index = 0; index < count; index++)
            Positioned(
              key: voiceWaveformBarKey(index),
              left: index * stride,
              top: height * (1 - heights[index]) / 2,
              width: voiceWaveformBarWidth,
              height: height * heights[index],
              child: AnimatedContainer(
                duration: shift,
                curve: _colourCurve,
                decoration: BoxDecoration(
                  color: _colourFor(index, count, heights[index]),
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
