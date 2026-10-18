import 'dart:math' as math;
import 'dart:typed_data';

import 'package:rnnoise/rnnoise.dart';

import 'package:field_notes/domain/settings/input_profile.dart';

const int naturalVoiceAttenuationLimitDb = 15;

enum NaturalVoiceStage { deEsser, leveller, limiter }

const int _sampleRate = 48000;
const int _frameSize = Denoiser.frameSize;
const int _rnnoiseDelaySamples = 960;
const int _bytesPerSample = 2;
const int _minSample = -32768;
const int _maxSample = 32767;
const double _fullScale = 32768;

const double _deEsserSplitHz = 6000;
const double _deEsserMaxReductionDb = 6;
const double _deEsserThresholdDb = -12;
const double _deEsserAttackSeconds = 0.001;
const double _deEsserReleaseSeconds = 0.060;
const List<double> _butterworthFourthOrderQ = <double>[0.54119610, 1.30656296];

const double _levellerTargetLufs = -18;
const int _levellerWindowFrames = 300;
const double _levellerMaxDbPerSecond = 3;
const double _levellerMinGainDb = -10;
const double _levellerMaxGainDb = 20;
const double _levellerVoiceThreshold = 0.5;
const double _levellerSilenceLufs = -70;
const double _loudnessOffset = -0.691;

const int _limiterLookAheadSamples = 72;
const int _limiterInterpolationReach = 8;
const int _limiterOversampling = 4;
const double _limiterCeilingDbtp = -1;
const double _limiterSafetyDb = 0.1;
const double _limiterReleaseSeconds = 0.080;

const Set<NaturalVoiceStage> _allStages = <NaturalVoiceStage>{
  NaturalVoiceStage.deEsser,
  NaturalVoiceStage.leveller,
  NaturalVoiceStage.limiter,
};

double _dbToGain(double db) => math.pow(10, db / 20).toDouble();

int _toSample(double value) => value.round().clamp(_minSample, _maxSample);

class NaturalVoiceChain {
  factory NaturalVoiceChain({
    required InputProfile profile,
    required int volume,
    int attenuationLimitDb = naturalVoiceAttenuationLimitDb,
    Set<NaturalVoiceStage> stages = _allStages,
  }) {
    if (profile == InputProfile.studio) {
      return NaturalVoiceChain._(volume, null);
    }
    return NaturalVoiceChain._(
      volume,
      _IsolationPath(
        volume: volume,
        mixGain: _dbToGain(-attenuationLimitDb.toDouble()),
        deEsser: stages.contains(NaturalVoiceStage.deEsser) ? _DeEsser() : null,
        leveller: stages.contains(NaturalVoiceStage.leveller)
            ? _Leveller()
            : null,
        limiter: stages.contains(NaturalVoiceStage.limiter) ? _Limiter() : null,
      ),
    );
  }

  NaturalVoiceChain._(this._volume, this._isolation);

  final int _volume;
  final _IsolationPath? _isolation;

  int get delaySamples => _isolation?.delaySamples ?? 0;

  double get levellerGainDb => _isolation?.leveller?.gainDb ?? 0;

  Uint8List process(Uint8List pcm16) {
    if (pcm16.length.isOdd) {
      throw ArgumentError.value(
        pcm16.length,
        'pcm16',
        'PCM must hold a whole number of 16-bit samples',
      );
    }
    final ByteData input = ByteData.sublistView(pcm16);
    final int count = pcm16.length ~/ _bytesPerSample;
    final _IsolationPath? isolation = _isolation;
    if (isolation != null) {
      return isolation.process(input, count);
    }
    final Uint8List output = Uint8List(pcm16.length);
    final ByteData data = ByteData.sublistView(output);
    for (int index = 0; index < count; index += 1) {
      final int sample = input.getInt16(index * _bytesPerSample, Endian.little);
      data.setInt16(
        index * _bytesPerSample,
        _toSample(sample * _volume / 100),
        Endian.little,
      );
    }
    return output;
  }

  Uint8List flush() => _isolation?.flush() ?? Uint8List(0);

  void dispose() => _isolation?.dispose();
}

class _IsolationPath {
  _IsolationPath({
    required this.volume,
    required this.mixGain,
    required this.deEsser,
    required this.leveller,
    required this.limiter,
  }) : _denoiser = Denoiser();

  final int volume;
  final double mixGain;
  final _DeEsser? deEsser;
  final _Leveller? leveller;
  final _Limiter? limiter;
  final Denoiser _denoiser;
  final Float32List _frame = Float32List(_frameSize);
  final Float64List _dryFrame = Float64List(_frameSize);
  final Float64List _work = Float64List(_frameSize);
  final Float64List _dryDelay = Float64List(_rnnoiseDelaySamples);
  int _dryPosition = 0;
  int _filled = 0;
  int _received = 0;
  int _returned = 0;
  bool _disposed = false;

  int get delaySamples => _rnnoiseDelaySamples + (limiter?.latency ?? 0);

  Uint8List process(ByteData input, int count) {
    _checkLive();
    final Uint8List output = Uint8List(
      ((_filled + count) ~/ _frameSize) * _frameSize * _bytesPerSample,
    );
    final ByteData sink = ByteData.sublistView(output);
    int written = 0;
    for (int index = 0; index < count; index += 1) {
      final int sample = input.getInt16(index * _bytesPerSample, Endian.little);
      written = _push(sample * volume / 100, sink, written);
    }
    _received += count;
    _returned += written;
    return output;
  }

  Uint8List flush() {
    _checkLive();
    final int owed = math.max(0, _received + delaySamples - _returned);
    final int frames = (_filled + owed + _frameSize - 1) ~/ _frameSize;
    final Uint8List produced = Uint8List(frames * _frameSize * _bytesPerSample);
    final ByteData sink = ByteData.sublistView(produced);
    int written = 0;
    while (written < owed) {
      written = _push(0, sink, written);
    }
    _returned += owed;
    return Uint8List.sublistView(produced, 0, owed * _bytesPerSample);
  }

  int _push(double sample, ByteData sink, int written) {
    _dryFrame[_filled] = _dryDelay[_dryPosition];
    _dryDelay[_dryPosition] = sample;
    _dryPosition = (_dryPosition + 1) % _rnnoiseDelaySamples;
    _frame[_filled] = sample;
    _filled += 1;
    if (_filled < _frameSize) {
      return written;
    }
    _filled = 0;
    _runFrame();
    for (int index = 0; index < _frameSize; index += 1) {
      sink.setInt16(
        (written + index) * _bytesPerSample,
        _toSample(_work[index]),
        Endian.little,
      );
    }
    return written + _frameSize;
  }

  void _runFrame() {
    final Float32List cleaned = _denoiser.process(_frame);
    final double voiceProbability = _denoiser.voiceProbability;
    for (int index = 0; index < _frameSize; index += 1) {
      _work[index] = cleaned[index] + _dryFrame[index] * mixGain;
    }
    deEsser?.run(_work);
    leveller?.run(_work, voiceProbability);
    limiter?.run(_work);
  }

  void _checkLive() {
    if (_disposed) {
      throw StateError('This natural voice chain has been disposed.');
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _denoiser.dispose();
  }
}

double _smoothing(double seconds) => 1 - math.exp(-1 / (seconds * _sampleRate));

class _Biquad {
  _Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);

  factory _Biquad.highPass(double frequency, double q) {
    final double omega = 2 * math.pi * frequency / _sampleRate;
    final double cosine = math.cos(omega);
    final double alpha = math.sin(omega) / (2 * q);
    final double a0 = 1 + alpha;
    return _Biquad(
      (1 + cosine) / 2 / a0,
      -(1 + cosine) / a0,
      (1 + cosine) / 2 / a0,
      -2 * cosine / a0,
      (1 - alpha) / a0,
    );
  }

  final double b0;
  final double b1;
  final double b2;
  final double a1;
  final double a2;
  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;

  double run(double x) {
    final double y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}

class _DeEsser {
  _DeEsser() {
    final double warped = math.tan(math.pi * _deEsserSplitHz / _sampleRate);
    _splitGain = 1 / (1 + warped);
    _splitPole = (warped - 1) / (warped + 1);
  }

  late final double _splitGain;
  late final double _splitPole;
  final List<_Biquad> _detector = <_Biquad>[
    for (final double q in _butterworthFourthOrderQ)
      _Biquad.highPass(_deEsserSplitHz, q),
  ];
  final double _attack = _smoothing(_deEsserAttackSeconds);
  final double _release = _smoothing(_deEsserReleaseSeconds);
  final double _thresholdRatio = math
      .pow(10, _deEsserThresholdDb / 10)
      .toDouble();
  final double _floor = _dbToGain(-_deEsserMaxReductionDb);
  double _previousInput = 0;
  double _previousHigh = 0;
  double _bandLevel = 0;
  double _fullLevel = 0;

  void run(Float64List frame) {
    final _Biquad first = _detector[0];
    final _Biquad second = _detector[1];
    for (int index = 0; index < frame.length; index += 1) {
      final double x = frame[index];
      final double high =
          _splitGain * (x - _previousInput) - _splitPole * _previousHigh;
      _previousInput = x;
      _previousHigh = high;
      final double band = second.run(first.run(x));
      final double bandPower = band * band;
      final double fullPower = x * x;
      _bandLevel +=
          (bandPower > _bandLevel ? _attack : _release) *
          (bandPower - _bandLevel);
      _fullLevel +=
          (fullPower > _fullLevel ? _attack : _release) *
          (fullPower - _fullLevel);
      double gain = 1;
      if (_bandLevel > _fullLevel * _thresholdRatio && _bandLevel > 0) {
        gain = math.max(
          _floor,
          math.sqrt(_fullLevel * _thresholdRatio / _bandLevel),
        );
      }
      frame[index] = x - (1 - gain) * high;
    }
  }
}

class _Leveller {
  final _Biquad _shelf = _Biquad(
    1.53512485958697,
    -2.69169618940638,
    1.19839281085285,
    -1.69065929318241,
    0.73248077421585,
  );
  final _Biquad _highPass = _Biquad(
    1.0,
    -2.0,
    1.0,
    -1.99004745483398,
    0.99007225036621,
  );
  final Float64List _energies = Float64List(_levellerWindowFrames);
  final Uint8List _voiced = Uint8List(_levellerWindowFrames);
  int _slot = 0;
  double _gainDb = 0;

  double get gainDb => _gainDb;

  void run(Float64List frame, double voiceProbability) {
    double energy = 0;
    for (int index = 0; index < frame.length; index += 1) {
      final double weighted = _highPass.run(
        _shelf.run(frame[index] / _fullScale),
      );
      energy += weighted * weighted;
    }
    final bool voiced = voiceProbability >= _levellerVoiceThreshold;
    _energies[_slot] = energy;
    _voiced[_slot] = voiced ? 1 : 0;
    _slot = (_slot + 1) % _levellerWindowFrames;
    final double startGain = _dbToGain(_gainDb);
    if (voiced) {
      _gainDb = _nextGainDb(frame.length);
    }
    final double endGain = _dbToGain(_gainDb);
    for (int index = 0; index < frame.length; index += 1) {
      final double gain =
          startGain + (endGain - startGain) * (index + 1) / frame.length;
      frame[index] *= gain;
    }
  }

  double _nextGainDb(int frameLength) {
    double sum = 0;
    int frames = 0;
    for (int slot = 0; slot < _levellerWindowFrames; slot += 1) {
      if (_voiced[slot] == 1) {
        sum += _energies[slot];
        frames += 1;
      }
    }
    if (frames == 0 || sum <= 0) {
      return _gainDb;
    }
    final double loudness =
        _loudnessOffset +
        10 * math.log(sum / (frames * frameLength)) / math.ln10;
    if (loudness < _levellerSilenceLufs) {
      return _gainDb;
    }
    final double target = (_levellerTargetLufs - loudness).clamp(
      _levellerMinGainDb,
      _levellerMaxGainDb,
    );
    final double step = _levellerMaxDbPerSecond * frameLength / _sampleRate;
    return _gainDb + (target - _gainDb).clamp(-step, step);
  }
}

class _Limiter {
  _Limiter() {
    for (int phase = 1; phase < _limiterOversampling; phase += 1) {
      final double offset = phase / _limiterOversampling;
      final Float64List taps = Float64List(_window);
      double sum = 0;
      for (int tap = 0; tap < _window; tap += 1) {
        final double distance = offset - (tap - _limiterInterpolationReach + 1);
        taps[tap] = _sinc(distance) * _blackman(distance);
        sum += taps[tap];
      }
      for (int tap = 0; tap < _window; tap += 1) {
        taps[tap] /= sum;
      }
      _phases.add(taps);
    }
  }

  static const int _window = 2 * _limiterInterpolationReach;
  static const int _span = _limiterLookAheadSamples + 1;

  final List<Float64List> _phases = <Float64List>[];
  final Float64List _history = Float64List(2 * _window);
  final Float64List _delay = Float64List(
    _limiterInterpolationReach + _limiterLookAheadSamples,
  );
  final Float64List _required = Float64List(_span)..fillRange(0, _span, 1);
  final Float64List _held = Float64List(_span)..fillRange(0, _span, 1);
  final double _ceiling =
      _fullScale * _dbToGain(_limiterCeilingDbtp - _limiterSafetyDb);
  final double _releaseRate = _smoothing(_limiterReleaseSeconds);
  int _historySlot = 0;
  int _delaySlot = 0;
  int _spanSlot = 0;
  double _previousPeak = 0;
  double _released = 1;
  double _minimum = 1;
  double _heldSum = _span.toDouble();

  int get latency => _delay.length;

  void run(Float64List frame) {
    final Float64List first = _phases[0];
    final Float64List second = _phases[1];
    final Float64List third = _phases[2];
    for (int index = 0; index < frame.length; index += 1) {
      final double x = frame[index];
      _history[_historySlot] = x;
      _history[_historySlot + _window] = x;
      _historySlot = (_historySlot + 1) % _window;
      final int start = _historySlot;
      double a = 0;
      double b = 0;
      double c = 0;
      for (int tap = 0; tap < _window; tap += 1) {
        final double value = _history[start + tap];
        a += value * first[tap];
        b += value * second[tap];
        c += value * third[tap];
      }
      final double centre = _history[start + _limiterInterpolationReach - 1]
          .abs();
      final double between = math.max(
        math.max(a.abs(), b.abs()),
        math.max(c.abs(), centre),
      );
      final double peak = math.max(between, _previousPeak);
      _previousPeak = between;
      final double required = peak > _ceiling ? _ceiling / peak : 1;
      _released = math.min(
        required,
        _released + (1 - _released) * _releaseRate,
      );
      final double leaving = _required[_spanSlot];
      _required[_spanSlot] = _released;
      if (_released <= _minimum) {
        _minimum = _released;
      } else if (leaving <= _minimum) {
        _minimum = _required[0];
        for (int slot = 1; slot < _span; slot += 1) {
          _minimum = math.min(_minimum, _required[slot]);
        }
      }
      _heldSum += _minimum - _held[_spanSlot];
      _held[_spanSlot] = _minimum;
      _spanSlot = (_spanSlot + 1) % _span;
      final double delayed = _delay[_delaySlot];
      _delay[_delaySlot] = x;
      _delaySlot = (_delaySlot + 1) % _delay.length;
      frame[index] = delayed * math.min(1, _heldSum / _span);
    }
  }

  static double _sinc(double x) {
    if (x == 0) {
      return 1;
    }
    final double angle = math.pi * x;
    return math.sin(angle) / angle;
  }

  static double _blackman(double distance) {
    final double position = distance / _limiterInterpolationReach;
    if (position.abs() >= 1) {
      return 0;
    }
    return 0.42 +
        0.5 * math.cos(math.pi * position) +
        0.08 * math.cos(2 * math.pi * position);
  }
}
