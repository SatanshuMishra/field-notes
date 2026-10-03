import 'dart:convert';
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
const double _minHeight = 0.14;
const double _maxHeight = 1;
const double _envelopeFloor = 0.45;
const double _envelopeSwing = 0.55;
const double _heightFloor = 0.35;
const double _heightSwing = 0.75;
const int _lcgMultiplier = 9301;
const int _lcgIncrement = 49297;
const int _lcgModulus = 233280;
const int _seedSpread = 131;

const double _playheadWidth = 2;
const double _playheadReach = 2;
const double _playheadHalo = 2;
const double _playheadHaloAlpha = 0.18;
const Radius _playheadRadius = Radius.circular(1);

const Duration _colourShift = Duration(milliseconds: 150);
const Curve _colourCurve = Curves.ease;

const int _fnvOffset = 0x811c9dc5;
const int _fnvPrime = 0x01000193;
const int _uint32Mask = 0xFFFFFFFF;
const int _int31Mask = 0x7FFFFFFF;

const Key voiceWaveformPlayheadKey = ValueKey<String>('voice-wave-playhead');

Key voiceWaveformBarKey(int index) => ValueKey<String>('voice-wave-bar-$index');

int voiceWaveformSeed(String id) =>
    utf8
        .encode(id)
        .fold<int>(
          _fnvOffset,
          (int hash, int byte) => ((hash ^ byte) * _fnvPrime) & _uint32Mask,
        ) &
    _int31Mask;

int voiceWaveformBarCount(double width) => math.max(
  voiceWaveformMinBars,
  ((width + voiceWaveformBarGap) /
          (voiceWaveformBarWidth + voiceWaveformBarGap))
      .floor(),
);

List<double> voiceWaveformHeights(int seed, int count) =>
    List<double>.unmodifiable(<double>[
      for (int index = 0; index < count; index++) _heightAt(seed, index, count),
    ]);

double _heightAt(int seed, int index, int count) {
  final int first =
      ((seed * _seedSpread + index) * _lcgMultiplier + _lcgIncrement) %
      _lcgModulus;
  final int second = (first * _lcgMultiplier + _lcgIncrement) % _lcgModulus;
  final double random = second / _lcgModulus;
  final double envelope =
      _envelopeFloor +
      _envelopeSwing * math.sin(math.pi * (index + 0.5) / count);
  return (envelope * (_heightFloor + random * _heightSwing)).clamp(
    _minHeight,
    _maxHeight,
  );
}

bool voiceWaveformBarPlayed(int index, int count, double progress) =>
    (index + 0.5) / count <= progress;

class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.seed,
    required this.active,
    required this.progress,
    this.onSeek,
  });

  final int seed;
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
                          seed: seed,
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
    required this.seed,
    required this.width,
    required this.active,
    required this.progress,
  });

  final int seed;
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
    final List<double> heights = voiceWaveformHeights(seed, count);
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
