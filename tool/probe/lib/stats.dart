enum ProbePlatform { macos, android }

double percentile(List<double> values, double percent) {
  if (values.isEmpty) {
    throw ArgumentError.value(values, 'values', 'must not be empty');
  }
  if (!(percent > 0 && percent <= 100)) {
    throw ArgumentError.value(percent, 'percent', 'must lie in (0, 100]');
  }
  final List<double> sorted = List<double>.of(values)..sort();
  final int rank = (percent * sorted.length / 100).ceil() - 1;
  final int index = rank < 0 ? 0 : rank;
  return sorted[index];
}

final class TimingSummary {
  const TimingSummary({
    required this.count,
    required this.p50,
    required this.p95,
    required this.max,
  });

  final int count;
  final double p50;
  final double p95;
  final double max;
}

TimingSummary summarise(List<double> valuesMs) {
  if (valuesMs.isEmpty) {
    throw ArgumentError.value(valuesMs, 'valuesMs', 'must not be empty');
  }
  final double largest = valuesMs.reduce((double a, double b) => a > b ? a : b);
  return TimingSummary(
    count: valuesMs.length,
    p50: percentile(valuesMs, 50),
    p95: percentile(valuesMs, 95),
    max: largest,
  );
}

Map<String, TimingSummary> summarisePerNote(
  Map<String, List<double>> valuesMsByNote,
) {
  return <String, TimingSummary>{
    for (final MapEntry<String, List<double>> entry in valuesMsByNote.entries)
      entry.key: summarise(entry.value),
  };
}

final class FrameSample {
  const FrameSample({required this.buildMs, required this.rasterMs});

  final double buildMs;
  final double rasterMs;
}

double jankIntervalMs(ProbePlatform platform, double refreshHz) {
  if (!(refreshHz > 0)) {
    throw ArgumentError.value(refreshHz, 'refreshHz', 'must be positive');
  }
  return switch (platform) {
    ProbePlatform.macos => 1000 / refreshHz,
    ProbePlatform.android => 2000 / refreshHz,
  };
}

bool isJankyFrame(FrameSample frame, double intervalMs) =>
    frame.buildMs > intervalMs || frame.rasterMs > intervalMs;

int countJankyFrames(Iterable<FrameSample> frames, double intervalMs) =>
    frames.where((FrameSample frame) => isJankyFrame(frame, intervalMs)).length;

double framesPerSecond(int frames, Duration window) {
  if (window.inMicroseconds <= 0) {
    throw ArgumentError.value(window, 'window', 'must be positive');
  }
  return frames * 1000000 / window.inMicroseconds;
}

const Duration cpuSettle = Duration(seconds: 2);
const Duration cpuWindow = Duration(seconds: 10);

final RegExp _psCpuTime = RegExp(
  r'^(?:(\d+)-)?(?:(\d+):)?(\d+):(\d{2})(?:\.(\d+))?$',
);

Duration parsePsCpuTime(String text) {
  final String trimmed = text.trim();
  final RegExpMatch? match = _psCpuTime.firstMatch(trimmed);
  if (match == null) {
    throw FormatException('not a ps cputime', text);
  }
  final int days = int.parse(match.group(1) ?? '0');
  final int hours = int.parse(match.group(2) ?? '0');
  final int minutes = int.parse(match.group(3)!);
  final int seconds = int.parse(match.group(4)!);
  final String fraction = match.group(5) ?? '';
  final String micros = fraction.length >= 6
      ? fraction.substring(0, 6)
      : fraction.padRight(6, '0');
  return Duration(
    days: days,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    microseconds: int.parse(micros),
  );
}

Duration parseProcStatCpuTime(
  String statLine, {
  int clockTicksPerSecond = 100,
}) {
  if (clockTicksPerSecond <= 0) {
    throw ArgumentError.value(
      clockTicksPerSecond,
      'clockTicksPerSecond',
      'must be positive',
    );
  }
  final int close = statLine.lastIndexOf(')');
  if (close < 0) {
    throw FormatException('no command name in stat line', statLine);
  }
  final List<String> fields = statLine
      .substring(close + 1)
      .trim()
      .split(RegExp(r'\s+'))
      .where((String field) => field.isNotEmpty)
      .toList();
  const int firstField = 3;
  const int utimeIndex = 14 - firstField;
  const int stimeIndex = 15 - firstField;
  if (fields.length <= stimeIndex) {
    throw FormatException('stat line has too few fields', statLine);
  }
  final int? utime = int.tryParse(fields[utimeIndex]);
  final int? stime = int.tryParse(fields[stimeIndex]);
  if (utime == null || stime == null) {
    throw FormatException('utime or stime is not a number', statLine);
  }
  return Duration(
    microseconds: (utime + stime) * 1000000 ~/ clockTicksPerSecond,
  );
}

double cpuPercentOfOneCore({
  required Duration cpuStart,
  required Duration cpuEnd,
  required Duration wall,
}) {
  if (wall.inMicroseconds <= 0) {
    throw ArgumentError.value(wall, 'wall', 'must be positive');
  }
  return (cpuEnd - cpuStart).inMicroseconds * 100 / wall.inMicroseconds;
}

final class ClockMap {
  const ClockMap._(this.offsetMicros);

  factory ClockMap.fromPairs(List<(int, int)> pairs) {
    if (pairs.isEmpty) {
      throw ArgumentError.value(pairs, 'pairs', 'must not be empty');
    }
    final double total = pairs.fold<double>(
      0,
      (double sum, (int, int) pair) => sum + (pair.$2 - pair.$1 / 1000),
    );
    return ClockMap._(total / pairs.length);
  }

  final double offsetMicros;

  int toProbeMicros(int driverNanos) =>
      (driverNanos / 1000 + offsetMicros).round();
}
