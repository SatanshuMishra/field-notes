import 'dart:math' as math;

import 'package:field_notes/domain/models/voice_peaks.dart';
import 'package:field_notes/features/capture/immersive/voice_level_smoother.dart';

typedef _OpenWindow = ({int index, double high});

class VoicePeakSampler {
  final VoiceLevelSmoother _smoother = VoiceLevelSmoother();
  final VoicePeaksAccumulator _peaks = VoicePeaksAccumulator();
  _OpenWindow _open = (index: 0, high: 0);
  Duration _heardAt = Duration.zero;

  void hear(double level, Duration recorded) {
    final Duration at = _notBeforeHeard(recorded);
    _open = _closeWindowsUntil(at, _open, _peaks);
    _smoother.advance(_seconds(at - _heardAt));
    _heardAt = at;
    _open = (index: _open.index, high: math.max(_open.high, _smoother.level));
    _smoother.hear(_heardLevel(level), at);
  }

  List<double> finish(Duration recorded) {
    final Duration at = _notBeforeHeard(recorded);
    final VoicePeaksAccumulator peaks = _copyOfPeaks();
    final _OpenWindow open = _closeWindowsUntil(at, _open, peaks);
    if (at > voicePeaksWindow * open.index) {
      peaks.add(roundVoicePeak(math.max(open.high, _levelAt(at))));
    }
    return peaks.finish();
  }

  _OpenWindow _closeWindowsUntil(
    Duration at,
    _OpenWindow open,
    VoicePeaksAccumulator into,
  ) {
    _OpenWindow current = open;
    while (voicePeaksWindow * (current.index + 1) <= at) {
      final double edge = _levelAt(voicePeaksWindow * (current.index + 1));
      into.add(roundVoicePeak(math.max(current.high, edge)));
      current = (index: current.index + 1, high: edge);
    }
    return current;
  }

  VoicePeaksAccumulator _copyOfPeaks() {
    final int perPeak =
        _peaks.windowLength.inMicroseconds ~/ voicePeaksWindow.inMicroseconds;
    final int inLastPeak = _open.index % perPeak;
    final List<double> kept = _peaks.finish();
    final VoicePeaksAccumulator copy = VoicePeaksAccumulator();
    for (int i = 0; i < kept.length; i++) {
      final bool partial = inLastPeak > 0 && i == kept.length - 1;
      for (int n = 0; n < (partial ? inLastPeak : perPeak); n++) {
        copy.add(kept[i]);
      }
    }
    return copy;
  }

  double _levelAt(Duration at) => _smoother.levelAfter(_seconds(at - _heardAt));

  Duration _notBeforeHeard(Duration recorded) =>
      recorded < _heardAt ? _heardAt : recorded;

  double _seconds(Duration span) =>
      span.inMicroseconds / Duration.microsecondsPerSecond;

  double _heardLevel(double level) =>
      level.isFinite ? level.clamp(0.0, 1.0) : 0;
}
