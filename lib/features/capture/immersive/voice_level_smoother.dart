import 'dart:math' as math;

const double _framesPerSecond = 60;
const double _riseRate = 0.32;
const double _fallRate = 0.085;
const double _longestStepSeconds = 1;
const double _onsetRise = 0.15;
const Duration _onsetGap = Duration(milliseconds: 90);

class VoiceLevelOnset {
  const VoiceLevelOnset({required this.intensity, required this.at});

  final double intensity;
  final Duration at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceLevelOnset &&
          runtimeType == other.runtimeType &&
          intensity == other.intensity &&
          at == other.at;

  @override
  int get hashCode => Object.hash(intensity, at);

  @override
  String toString() => 'VoiceLevelOnset(intensity: $intensity, at: $at)';
}

class VoiceLevelSmoother {
  double _level = 0;
  double _target = 0;
  double _heard = 0;
  Duration? _lastOnset;

  double get level => _level;

  double get target => _target;

  VoiceLevelOnset? hear(double level, Duration at) {
    final double previous = _heard;
    _heard = level;
    _target = level;
    if (level - previous < _onsetRise) {
      return null;
    }
    final Duration? lastOnset = _lastOnset;
    if (lastOnset != null && at - lastOnset < _onsetGap) {
      return null;
    }
    _lastOnset = at;
    return VoiceLevelOnset(intensity: level, at: at);
  }

  void hush() {
    _target = 0;
  }

  void advance(double dtSeconds) {
    _level = levelAfter(dtSeconds);
  }

  double levelAfter(double dtSeconds) {
    if (!dtSeconds.isFinite || dtSeconds <= 0) {
      return _level;
    }
    final double frames =
        math.min(dtSeconds, _longestStepSeconds) * _framesPerSecond;
    final double rate = _target > _level ? _riseRate : _fallRate;
    final double share = 1 - math.pow(1 - rate, frames).toDouble();
    return _level + (_target - _level) * share;
  }

  void reset() {
    _level = 0;
    _target = 0;
    _heard = 0;
    _lastOnset = null;
  }
}
