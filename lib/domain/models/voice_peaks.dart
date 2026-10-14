import 'dart:convert';
import 'dart:math';

const int voicePeaksLimit = 36000;
const Duration voicePeaksWindow = Duration(milliseconds: 100);

double roundVoicePeak(double v) => (v * 100).round() / 100;

String encodeVoicePeaks(List<double> peaks) {
  return '[${peaks.map(_encodedPeak).join(',')}]';
}

String _encodedPeak(double peak) {
  if (!peak.isFinite || peak < 0 || peak > 1) {
    throw ArgumentError.value(peak, 'peaks', 'Not a peak from 0 to 1.');
  }
  final double rounded = roundVoicePeak(peak);
  return rounded == rounded.truncateToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

List<double>? decodeVoicePeaks(Object? stored) {
  if (stored is! String) {
    return null;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(stored);
  } on FormatException {
    return null;
  }
  if (decoded is! List<Object?> || decoded.length > voicePeaksLimit) {
    return null;
  }
  final List<double> peaks = <double>[];
  for (final Object? value in decoded) {
    if (value is! num || value < 0 || value > 1) {
      return null;
    }
    peaks.add(value.toDouble());
  }
  return List<double>.unmodifiable(peaks);
}

class VoicePeaksAccumulator {
  List<double> _peaks = <double>[];
  int _valuesPerWindow = 1;
  int _filled = 0;
  double _current = 0;

  Duration get windowLength => voicePeaksWindow * _valuesPerWindow;

  void add(double value) {
    if (_filled == 0 && _peaks.length == voicePeaksLimit) {
      _peaks = <double>[
        for (int i = 0; i < _peaks.length; i += 2)
          max(_peaks[i], _peaks[i + 1]),
      ];
      _valuesPerWindow *= 2;
    }
    _current = _filled == 0 ? value : max(_current, value);
    _filled += 1;
    if (_filled == _valuesPerWindow) {
      _peaks.add(_current);
      _filled = 0;
    }
  }

  List<double> finish() {
    return List<double>.unmodifiable(<double>[
      ..._peaks,
      if (_filled > 0) _current,
    ]);
  }
}
