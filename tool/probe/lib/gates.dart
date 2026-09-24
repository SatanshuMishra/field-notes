import 'dart:convert';
import 'dart:io';

import 'oracles.dart';
import 'stats.dart';

enum ProbeBuild { profile, debug }

enum GateVerdict { pass, fail, reported }

enum GateLimitKind { timing, count, idle, rate, perCase, reported }

final class GateLimit {
  const GateLimit.timing(this.display, {this.p95Ms, this.maxMs})
    : kind = GateLimitKind.timing,
      maxCount = null,
      framesPerSecond = null,
      cpuPercent = null,
      runs = null;

  const GateLimit.count(this.display, int this.maxCount)
    : kind = GateLimitKind.count,
      p95Ms = null,
      maxMs = null,
      framesPerSecond = null,
      cpuPercent = null,
      runs = null;

  const GateLimit.idle(
    this.display, {
    required double this.framesPerSecond,
    required double this.cpuPercent,
  }) : kind = GateLimitKind.idle,
       p95Ms = null,
       maxMs = null,
       maxCount = null,
       runs = null;

  const GateLimit.rate(this.display)
    : kind = GateLimitKind.rate,
      p95Ms = null,
      maxMs = null,
      maxCount = null,
      framesPerSecond = null,
      cpuPercent = null,
      runs = null;

  const GateLimit.perCase(this.display, int this.runs)
    : kind = GateLimitKind.perCase,
      p95Ms = null,
      maxMs = null,
      maxCount = null,
      framesPerSecond = null,
      cpuPercent = null;

  const GateLimit.reported(this.display)
    : kind = GateLimitKind.reported,
      p95Ms = null,
      maxMs = null,
      maxCount = null,
      framesPerSecond = null,
      cpuPercent = null,
      runs = null;

  final GateLimitKind kind;
  final String display;
  final double? p95Ms;
  final double? maxMs;
  final int? maxCount;
  final double? framesPerSecond;
  final double? cpuPercent;
  final int? runs;

  @override
  bool operator ==(Object other) =>
      other is GateLimit &&
      other.kind == kind &&
      other.display == display &&
      other.p95Ms == p95Ms &&
      other.maxMs == maxMs &&
      other.maxCount == maxCount &&
      other.framesPerSecond == framesPerSecond &&
      other.cpuPercent == cpuPercent &&
      other.runs == runs;

  @override
  int get hashCode => Object.hash(
    kind,
    display,
    p95Ms,
    maxMs,
    maxCount,
    framesPerSecond,
    cpuPercent,
    runs,
  );

  @override
  String toString() =>
      'GateLimit.${kind.name}($display, p95Ms: $p95Ms, '
      'maxMs: $maxMs, maxCount: $maxCount, framesPerSecond: $framesPerSecond, '
      'cpuPercent: $cpuPercent, runs: $runs)';
}

final class GateRow {
  const GateRow({
    required this.id,
    required this.scenarios,
    required this.macos,
    required this.android,
    this.blocking = true,
  });

  final String id;
  final List<String> scenarios;
  final GateLimit macos;
  final GateLimit android;
  final bool blocking;

  GateLimit limitFor(ProbePlatform platform) => switch (platform) {
    ProbePlatform.macos => macos,
    ProbePlatform.android => android,
  };
}

const GateLimit _full = GateLimit.rate('100%');

const List<GateRow> gateRows = <GateRow>[
  GateRow(
    id: 'GP1',
    scenarios: <String>['perf-keystroke'],
    macos: GateLimit.timing('≤ 4 ms', p95Ms: 4),
    android: GateLimit.timing('≤ 8 ms', p95Ms: 8),
  ),
  GateRow(
    id: 'GP2',
    scenarios: <String>['perf-keystroke'],
    macos: GateLimit.timing('p95 ≤ 17 ms, max ≤ 25 ms', p95Ms: 17, maxMs: 25),
    android: GateLimit.timing('p95 ≤ 34 ms, max ≤ 50 ms', p95Ms: 34, maxMs: 50),
  ),
  GateRow(
    id: 'GP3',
    scenarios: <String>['perf-keystroke', 'perf-scroll'],
    macos: GateLimit.count('0', 0),
    android: GateLimit.count('0', 0),
  ),
  GateRow(
    id: 'GP4',
    scenarios: <String>['perf-idle'],
    macos: GateLimit.idle(
      '≤ 2 frames/s (0 when the caret is hidden) and ≤ 1% CPU',
      framesPerSecond: 2,
      cpuPercent: 1,
    ),
    android: GateLimit.idle('same', framesPerSecond: 2, cpuPercent: 1),
  ),
  GateRow(
    id: 'GP5',
    scenarios: <String>['perf-open'],
    macos: GateLimit.timing('≤ 33 ms', maxMs: 33),
    android: GateLimit.timing('≤ 66 ms', maxMs: 66),
  ),
  GateRow(
    id: 'GP6',
    scenarios: <String>['styling-ceiling'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GR1',
    scenarios: <String>['round-trip'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GR2',
    scenarios: <String>['side-edit-audit'],
    macos: GateLimit.count('0 side edits', 0),
    android: GateLimit.count('0 side edits', 0),
  ),
  GateRow(
    id: 'GR3',
    scenarios: <String>['held-clicks'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GR4',
    scenarios: <String>['monkey'],
    macos: GateLimit.count('0', 0),
    android: GateLimit.count('0', 0),
  ),
  GateRow(
    id: 'GR5',
    scenarios: <String>['undo-matrix'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GR6',
    scenarios: <String>['photo-move-matrix'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GR7',
    scenarios: <String>['photo-insert-matrix'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GR8',
    scenarios: <String>['draft-recovery'],
    macos: GateLimit.perCase('20 of 20 per case', 20),
    android: GateLimit.perCase('20 of 20 per case', 20),
  ),
  GateRow(
    id: 'GB1',
    scenarios: <String>['caret-audit'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GB2',
    scenarios: <String>['selection-audit'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GB3',
    scenarios: <String>['click-sweep'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GB4',
    scenarios: <String>['vertical-sweep'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GB5',
    scenarios: <String>['placement-matrix'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GB6',
    scenarios: <String>['keyboard-matrix'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GB7',
    scenarios: <String>['ime-matrix'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GB8',
    scenarios: <String>['a11y-matrix'],
    macos: _full,
    android: GateLimit.rate('100% (line movement reported)'),
  ),
  GateRow(
    id: 'GB9',
    scenarios: <String>['window-scale-matrix'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GB10',
    scenarios: <String>['reader-parity'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GB11',
    scenarios: <String>['toolbar-placement'],
    macos: _full,
    android: _full,
  ),
  GateRow(
    id: 'GP7',
    scenarios: <String>['perf-memory'],
    macos: GateLimit.reported('reported'),
    android: GateLimit.reported('reported'),
    blocking: false,
  ),
  GateRow(
    id: 'GT1',
    scenarios: <String>['table-matrix'],
    macos: GateLimit.rate('100%, not blocking'),
    android: GateLimit.rate('100%, not blocking'),
    blocking: false,
  ),
  GateRow(
    id: 'GSP1',
    scenarios: <String>['spell-matrix'],
    macos: GateLimit.rate('100%, not blocking'),
    android: GateLimit.rate('100%, not blocking'),
    blocking: false,
  ),
];

const List<String> probeScenarios = <String>[
  'table-matrix',
  'spell-matrix',
  'perf-keystroke',
  'perf-scroll',
  'perf-idle',
  'perf-open',
  'styling-ceiling',
  'round-trip',
  'side-edit-audit',
  'held-clicks',
  'monkey',
  'undo-matrix',
  'photo-move-matrix',
  'photo-insert-matrix',
  'draft-recovery',
  'caret-audit',
  'selection-audit',
  'click-sweep',
  'vertical-sweep',
  'placement-matrix',
  'keyboard-matrix',
  'ime-matrix',
  'a11y-matrix',
  'window-scale-matrix',
  'reader-parity',
  'toolbar-placement',
  'perf-memory',
];

List<ProbeBuild> buildModesFor(String scenario) {
  if (!probeScenarios.contains(scenario)) {
    throw ArgumentError.value(scenario, 'scenario', 'is not a probe scenario');
  }
  return switch (scenario) {
    'held-clicks' => const <ProbeBuild>[ProbeBuild.profile, ProbeBuild.debug],
    'monkey' => const <ProbeBuild>[ProbeBuild.debug],
    _ => const <ProbeBuild>[ProbeBuild.profile],
  };
}

final class RowOutcome {
  const RowOutcome({
    required this.row,
    required this.platform,
    required this.build,
    required this.measured,
    required this.values,
    required this.verdict,
  });

  final String row;
  final ProbePlatform platform;
  final ProbeBuild build;
  final String measured;
  final Map<String, Object?> values;
  final GateVerdict verdict;
}

typedef _Judgement = (String, Map<String, Object?>, GateVerdict);

typedef _Check = (bool, String);

List<RowOutcome> evaluateResult(Map<String, Object?> document) {
  final Object? scenario = document['scenario'];
  if (scenario is! String || !probeScenarios.contains(scenario)) {
    throw ArgumentError.value(scenario, 'scenario', 'is not a probe scenario');
  }
  final ProbePlatform platform = _byName(
    ProbePlatform.values,
    document['platform'],
    'platform',
  );
  final ProbeBuild build = _byName(
    ProbeBuild.values,
    document['build'],
    'build',
  );
  if (!buildModesFor(scenario).contains(build)) {
    throw ArgumentError.value(
      build.name,
      'build',
      '6.14 does not judge $scenario from a ${build.name} build',
    );
  }
  final Object rawSamples = document['samples'] ?? const <Object?>[];
  if (rawSamples is! List<Object?>) {
    throw ArgumentError.value(rawSamples, 'samples', 'must be a list');
  }
  final List<Map<String, Object?>> samples = <Map<String, Object?>>[
    for (final Object? sample in rawSamples)
      if (sample is Map<String, Object?>)
        sample
      else
        throw ArgumentError.value(sample, 'samples', 'must hold objects'),
  ];
  return <RowOutcome>[
    for (final GateRow row in gateRows)
      if (row.scenarios.contains(scenario))
        _outcome(row, platform, build, samples),
  ];
}

T _byName<T extends Enum>(List<T> values, Object? name, String field) {
  for (final T value in values) {
    if (value.name == name) {
      return value;
    }
  }
  throw ArgumentError.value(name, field, 'is not a known name');
}

RowOutcome _outcome(
  GateRow row,
  ProbePlatform platform,
  ProbeBuild build,
  List<Map<String, Object?>> samples,
) {
  final List<Map<String, Object?>> own = samples
      .where((Map<String, Object?> sample) => sample['row'] == row.id)
      .toList();
  final List<Map<String, Object?>> counted = own
      .where((Map<String, Object?> sample) => sample['reportedOnly'] != true)
      .toList();
  final List<Map<String, Object?>> reportedOnly = own
      .where((Map<String, Object?> sample) => sample['reportedOnly'] == true)
      .toList();
  final GateLimit limit = row.limitFor(platform);
  final _Judgement judgement = _judgeSafely(row, limit, platform, counted);
  return RowOutcome(
    row: row.id,
    platform: platform,
    build: build,
    measured: judgement.$1,
    values: <String, Object?>{
      ...judgement.$2,
      if (reportedOnly.isNotEmpty) 'reportedOnly': reportedOnly,
    },
    verdict: judgement.$3,
  );
}

_Judgement _judgeSafely(
  GateRow row,
  GateLimit limit,
  ProbePlatform platform,
  List<Map<String, Object?>> counted,
) {
  if (limit.kind == GateLimitKind.reported) {
    try {
      return _judgeMemory(counted);
    } on FormatException catch (error) {
      return (
        'malformed sample: ${error.message}',
        const <String, Object?>{},
        GateVerdict.reported,
      );
    }
  }
  if (counted.isEmpty) {
    return ('no samples', const <String, Object?>{}, GateVerdict.fail);
  }
  try {
    return switch (row.id) {
      'GP1' => _judgeKeystrokes(limit, counted),
      'GP2' => _judgeKeyToRaster(limit, counted),
      'GP3' => _judgeFrames(limit, platform, counted),
      'GP4' => _judgeIdle(limit, counted),
      'GP5' => _judgeOpen(limit, counted),
      'GR8' => _judgePerCase(limit, counted),
      _ => _judgeEverySample(counted),
    };
  } on FormatException catch (error) {
    return (
      'malformed sample: ${error.message}',
      const <String, Object?>{},
      GateVerdict.fail,
    );
  }
}

void _requireKind(List<Map<String, Object?>> samples, String kind) {
  for (final Map<String, Object?> sample in samples) {
    if (sample['kind'] != kind) {
      throw FormatException('expected kind $kind, got ${sample['kind']}');
    }
  }
}

String _ms(double value) => value.toStringAsFixed(2);

_Judgement _judgeKeystrokes(
  GateLimit limit,
  List<Map<String, Object?>> samples,
) {
  _requireKind(samples, 'keystroke');
  final Map<String, List<double>> byNote = <String, List<double>>{};
  for (final Map<String, Object?> sample in samples) {
    final String note = _string(sample['note'], 'note');
    final List<double> values = <double>[
      for (final Object? keystroke in _list(
        _map(sample['timings'], 'timings')['keystrokes'],
        'keystrokes',
      ))
        _num(_map(keystroke, 'keystroke')['handlerMs'], 'handlerMs') +
            _num(_map(keystroke, 'keystroke')['buildMs'], 'buildMs'),
    ];
    byNote[note] = <double>[...?byNote[note], ...values];
  }
  final Map<String, List<double>> nonEmpty = <String, List<double>>{
    for (final MapEntry<String, List<double>> entry in byNote.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value,
  };
  if (nonEmpty.isEmpty) {
    return ('no keystrokes', const <String, Object?>{}, GateVerdict.fail);
  }
  final Map<String, TimingSummary> summaries = summarisePerNote(nonEmpty);
  final MapEntry<String, TimingSummary> worst = summaries.entries.reduce(
    (MapEntry<String, TimingSummary> a, MapEntry<String, TimingSummary> b) =>
        b.value.p95 > a.value.p95 ? b : a,
  );
  final double threshold = limit.p95Ms ?? double.infinity;
  final bool pass =
      summaries.values.every(
        (TimingSummary summary) => summary.p95 <= threshold,
      ) &&
      nonEmpty.length == byNote.length;
  return (
    'worst ${worst.key} p95 ${_ms(worst.value.p95)} ms over '
        '${summaries.length} notes',
    <String, Object?>{
      'worstNote': worst.key,
      'worstP95': worst.value.p95,
      'perNote': <String, Object?>{
        for (final MapEntry<String, TimingSummary> entry in summaries.entries)
          entry.key: <String, Object?>{
            'count': entry.value.count,
            'p50': entry.value.p50,
            'p95': entry.value.p95,
            'max': entry.value.max,
          },
      },
    },
    pass ? GateVerdict.pass : GateVerdict.fail,
  );
}

_Judgement _judgeKeyToRaster(
  GateLimit limit,
  List<Map<String, Object?>> samples,
) {
  _requireKind(samples, 'keyToRaster');
  final List<double> intervals = <double>[];
  for (final Map<String, Object?> sample in samples) {
    final List<Object?> keystrokes = _list(
      _map(sample['timings'], 'timings')['keystrokes'],
      'keystrokes',
    );
    final Object? rawNanos = sample['keyDownNanos'];
    if (rawNanos != null) {
      final List<Object?> nanos = _list(rawNanos, 'keyDownNanos');
      if (nanos.length != keystrokes.length) {
        return (
          'keystroke count mismatch',
          <String, Object?>{
            'note': sample['note'],
            'keyDownNanos': nanos.length,
            'keystrokes': keystrokes.length,
          },
          GateVerdict.fail,
        );
      }
      final ClockMap clock = ClockMap.fromPairs(<(int, int)>[
        for (final Object? pair in _list(sample['clockPairs'], 'clockPairs'))
          _pair(pair),
      ]);
      for (int index = 0; index < keystrokes.length; index++) {
        final int keyDown = clock.toProbeMicros(
          _int(nanos[index], 'keyDownNanos'),
        );
        final int finish = _int(
          _map(keystrokes[index], 'keystroke')['rasterFinishMicros'],
          'rasterFinishMicros',
        );
        intervals.add((finish - keyDown) / 1000);
      }
    } else {
      for (final Object? keystroke in keystrokes) {
        final Map<String, Object?> entry = _map(keystroke, 'keystroke');
        final int keyDown = _int(entry['keyDownMicros'], 'keyDownMicros');
        final int finish = _int(
          entry['rasterFinishMicros'],
          'rasterFinishMicros',
        );
        intervals.add((finish - keyDown) / 1000);
      }
    }
  }
  if (intervals.isEmpty) {
    return ('no keystrokes', const <String, Object?>{}, GateVerdict.fail);
  }
  final TimingSummary summary = summarise(intervals);
  final bool pass =
      summary.p95 <= (limit.p95Ms ?? double.infinity) &&
      summary.max <= (limit.maxMs ?? double.infinity);
  return (
    'p50 ${_ms(summary.p50)} ms p95 ${_ms(summary.p95)} ms '
        'max ${_ms(summary.max)} ms over ${summary.count} keystrokes',
    <String, Object?>{
      'count': summary.count,
      'p50': summary.p50,
      'p95': summary.p95,
      'max': summary.max,
    },
    pass ? GateVerdict.pass : GateVerdict.fail,
  );
}

(int, int) _pair(Object? value) {
  final List<Object?> pair = _list(value, 'clockPair');
  if (pair.length != 2) {
    throw const FormatException('a clock pair is [driverNanos, probeMicros]');
  }
  return (_int(pair[0], 'driverNanos'), _int(pair[1], 'probeMicros'));
}

_Judgement _judgeFrames(
  GateLimit limit,
  ProbePlatform platform,
  List<Map<String, Object?>> samples,
) {
  _requireKind(samples, 'frames');
  int janky = 0;
  int frames = 0;
  final Map<String, int> jankyByPhase = <String, int>{};
  for (final Map<String, Object?> sample in samples) {
    final Map<String, Object?> timings = _map(sample['timings'], 'timings');
    final double interval = jankIntervalMs(
      platform,
      _num(timings['refreshHz'], 'refreshHz'),
    );
    final List<FrameSample> frameSamples = <FrameSample>[
      for (final Object? frame in _list(timings['frames'], 'frames'))
        FrameSample(
          buildMs: _num(_map(frame, 'frame')['buildMs'], 'buildMs'),
          rasterMs: _num(_map(frame, 'frame')['rasterMs'], 'rasterMs'),
        ),
    ];
    final int count = countJankyFrames(frameSamples, interval);
    final String phase = '${sample['phase'] ?? 'unknown'}';
    janky += count;
    frames += frameSamples.length;
    jankyByPhase[phase] = (jankyByPhase[phase] ?? 0) + count;
  }
  final bool pass = janky <= (limit.maxCount ?? 0);
  return (
    '$janky janky of $frames frames',
    <String, Object?>{
      'janky': janky,
      'frames': frames,
      'jankyByPhase': jankyByPhase,
    },
    pass ? GateVerdict.pass : GateVerdict.fail,
  );
}

Duration _cpuTime(Map<String, Object?> sample, String field) {
  final String raw = _string(sample[field], field);
  return switch (sample['cpuFormat']) {
    'ps' => parsePsCpuTime(raw),
    'procstat' => parseProcStatCpuTime(
      raw,
      clockTicksPerSecond: sample['clockTicks'] == null
          ? 100
          : _int(sample['clockTicks'], 'clockTicks'),
    ),
    _ => throw FormatException('unknown cpuFormat ${sample['cpuFormat']}'),
  };
}

_Judgement _judgeIdle(GateLimit limit, List<Map<String, Object?>> samples) {
  _requireKind(samples, 'idle');
  final double fpsLimit = limit.framesPerSecond ?? double.infinity;
  final double cpuLimit = limit.cpuPercent ?? double.infinity;
  final List<Map<String, Object?>> cases = <Map<String, Object?>>[
    for (final Map<String, Object?> sample in samples)
      _idleCase(sample, fpsLimit, cpuLimit),
  ];
  final Map<String, Object?> worst = cases.firstWhere(
    (Map<String, Object?> entry) => entry['pass'] != true,
    orElse: () => cases.reduce(
      (Map<String, Object?> a, Map<String, Object?> b) =>
          (b['cpuPercent']! as double) > (a['cpuPercent']! as double) ? b : a,
    ),
  );
  final bool pass = cases.every(
    (Map<String, Object?> entry) => entry['pass'] == true,
  );
  return (
    'worst ${worst['case']} ${_ms(worst['framesPerSecond']! as double)} '
        'frames/s ${_ms(worst['cpuPercent']! as double)}% CPU',
    <String, Object?>{
      'worstCase': worst['case'],
      'framesPerSecond': worst['framesPerSecond'],
      'cpuPercent': worst['cpuPercent'],
      'cases': cases,
    },
    pass ? GateVerdict.pass : GateVerdict.fail,
  );
}

Map<String, Object?> _idleCase(
  Map<String, Object?> sample,
  double fpsLimit,
  double cpuLimit,
) {
  final Duration window = Duration(
    milliseconds: _int(sample['windowMs'], 'windowMs'),
  );
  final int frames = _list(
    _map(sample['timings'], 'timings')['frames'],
    'frames',
  ).length;
  final bool caretVisible = _bool(sample['caretVisible'], 'caretVisible');
  final double fps = framesPerSecond(frames, window);
  final double cpu = cpuPercentOfOneCore(
    cpuStart: _cpuTime(sample, 'cpuStart'),
    cpuEnd: _cpuTime(sample, 'cpuEnd'),
    wall: window,
  );
  final bool framesPass = caretVisible ? fps <= fpsLimit : frames == 0;
  return <String, Object?>{
    'case': sample['case'],
    'caretVisible': caretVisible,
    'frames': frames,
    'framesPerSecond': fps,
    'cpuPercent': cpu,
    'pass': framesPass && cpu <= cpuLimit,
  };
}

_Judgement _judgeOpen(GateLimit limit, List<Map<String, Object?>> samples) {
  _requireKind(samples, 'open');
  final List<double> durations = <double>[
    for (final Map<String, Object?> sample in samples)
      _openDuration(_map(_map(sample['timings'], 'timings')['open'], 'open')),
  ];
  final double largest = durations.reduce(
    (double a, double b) => a > b ? a : b,
  );
  final bool pass = largest <= (limit.maxMs ?? double.infinity);
  return (
    'max ${_ms(largest)} ms over ${durations.length} opens',
    <String, Object?>{'max': largest, 'opens': durations},
    pass ? GateVerdict.pass : GateVerdict.fail,
  );
}

double _openDuration(Map<String, Object?> open) =>
    (_int(open['firstLineRasterFinishMicros'], 'firstLineRasterFinishMicros') -
        _int(open['dispatchedMicros'], 'dispatchedMicros')) /
    1000;

_Judgement _judgeMemory(List<Map<String, Object?>> samples) {
  final List<Map<String, Object?>> memory = samples
      .where((Map<String, Object?> sample) => sample['kind'] == 'memory')
      .toList();
  if (memory.isEmpty) {
    return ('no samples', const <String, Object?>{}, GateVerdict.reported);
  }
  final int peakRss = memory
      .map((Map<String, Object?> s) => _int(s['peakRssBytes'], 'peakRssBytes'))
      .reduce((int a, int b) => a > b ? a : b);
  final int imageCache = memory
      .map(
        (Map<String, Object?> s) =>
            _int(s['imageCacheBytes'], 'imageCacheBytes'),
      )
      .reduce((int a, int b) => a > b ? a : b);
  final int oversize = memory
      .map(
        (Map<String, Object?> s) =>
            _int(s['oversizeDecodes'], 'oversizeDecodes'),
      )
      .fold<int>(0, (int sum, int value) => sum + value);
  return (
    'peak RSS $peakRss bytes, image cache $imageCache bytes, '
        '$oversize oversize decodes',
    <String, Object?>{
      'peakRssBytes': peakRss,
      'imageCacheBytes': imageCache,
      'oversizeDecodes': oversize,
    },
    GateVerdict.reported,
  );
}

_Judgement _judgePerCase(GateLimit limit, List<Map<String, Object?>> samples) {
  _requireKind(samples, 'expect');
  final int runs = limit.runs ?? 1;
  final Map<String, List<bool>> byCase = <String, List<bool>>{};
  for (final Map<String, Object?> sample in samples) {
    final String name = '${sample['case']}';
    byCase[name] = <bool>[...?byCase[name], _checkExpect(sample).$1];
  }
  final Map<String, Object?> perCase = <String, Object?>{
    for (final MapEntry<String, List<bool>> entry in byCase.entries)
      entry.key: <String, Object?>{
        'passed': entry.value.where((bool pass) => pass).length,
        'runs': entry.value.length,
      },
  };
  final List<String> failing = <String>[
    for (final MapEntry<String, List<bool>> entry in byCase.entries)
      if (entry.value.length != runs || entry.value.any((bool pass) => !pass))
        '${entry.key} ${entry.value.where((bool pass) => pass).length} '
            'of ${entry.value.length}',
  ];
  return (
    failing.isEmpty
        ? '${byCase.length} cases at $runs of $runs'
        : 'failing: ${failing.join('; ')}',
    <String, Object?>{'cases': perCase, 'runs': runs},
    failing.isEmpty ? GateVerdict.pass : GateVerdict.fail,
  );
}

_Judgement _judgeEverySample(List<Map<String, Object?>> samples) {
  final List<(Map<String, Object?>, _Check)> checks =
      <(Map<String, Object?>, _Check)>[
        for (final Map<String, Object?> sample in samples)
          (sample, _checkGuarded(sample)),
      ];
  final List<(Map<String, Object?>, _Check)> failures = checks
      .where(((Map<String, Object?>, _Check) entry) => !entry.$2.$1)
      .toList();
  final Map<String, Map<String, double>> worstCaret = _worstCaret(samples);
  final String caretText = worstCaret.isEmpty
      ? ''
      : '; worst ${worstCaret.entries.map((MapEntry<String, Map<String, double>> entry) => '${entry.key} |dx| ${_ms(entry.value['dx']!)} '
            '|dTop| ${_ms(entry.value['dTop']!)} '
            '|dBottom| ${_ms(entry.value['dBottom']!)}').join(', ')}';
  final String failureText = failures.isEmpty
      ? ''
      : '; first failure ${failures.first.$1['case'] ?? failures.first.$1['kind']}: '
            '${failures.first.$2.$2}';
  return (
    '${checks.length - failures.length} of ${checks.length} samples pass'
        '$failureText$caretText',
    <String, Object?>{
      'samples': checks.length,
      'failed': failures.length,
      'failures': <Map<String, Object?>>[
        for (final (Map<String, Object?>, _Check) failure in failures.take(20))
          <String, Object?>{
            'case': failure.$1['case'],
            'kind': failure.$1['kind'],
            'detail': failure.$2.$2,
          },
      ],
      if (worstCaret.isNotEmpty) 'worstCaret': worstCaret,
    },
    failures.isEmpty ? GateVerdict.pass : GateVerdict.fail,
  );
}

Map<String, Map<String, double>> _worstCaret(
  List<Map<String, Object?>> samples,
) {
  final Map<String, Map<String, double>> worst =
      <String, Map<String, double>>{};
  for (final Map<String, Object?> sample in samples) {
    if (sample['kind'] != 'caret') {
      continue;
    }
    final Object? audit = sample['caretAudit'];
    if (audit is! Map<String, Object?> || audit['samples'] is! List<Object?>) {
      continue;
    }
    for (final Object? entry in audit['samples']! as List<Object?>) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final String kind = '${entry['blockKind']}';
      final Map<String, double> previous =
          worst[kind] ??
          const <String, double>{'dx': 0, 'dTop': 0, 'dBottom': 0};
      worst[kind] = <String, double>{
        for (final String field in const <String>['dx', 'dTop', 'dBottom'])
          field: _larger(previous[field]!, _absOrZero(entry[field])),
      };
    }
  }
  return worst;
}

double _larger(double a, double b) => a > b ? a : b;

double _absOrZero(Object? value) => value is num ? value.toDouble().abs() : 0;

_Check _checkGuarded(Map<String, Object?> sample) {
  try {
    return _checkSample(sample);
  } on FormatException catch (error) {
    return (false, 'malformed sample: ${error.message}');
  } on ArgumentError catch (error) {
    return (false, 'malformed sample: ${error.message}');
  }
}

_Check _checkSample(Map<String, Object?> sample) => switch (sample['kind']) {
  'styling' => _checkStyling(sample),
  'roundTrip' => _checkRoundTrip(sample),
  'sideEdit' => _checkSideEdit(sample),
  'errors' => _checkErrors(sample),
  'relocation' => _checkRelocation(sample),
  'caret' => _checkCaret(sample),
  'selection' => _checkSelection(sample),
  'click' => _checkClick(sample),
  'vertical' => _checkVertical(sample),
  'photo' => _checkPhoto(sample),
  'float' => _checkFloat(sample),
  'parity' => _checkParity(sample),
  'toolbar' => _checkToolbar(sample),
  'expect' => _checkExpect(sample),
  final Object? kind => (false, 'unknown sample kind $kind'),
};

_Check _checkStyling(Map<String, Object?> sample) {
  final List<Object?> blocks = _list(
    _map(sample['state'], 'state')['blocks'],
    'blocks',
  );
  for (int index = 0; index < blocks.length; index++) {
    final Map<String, Object?> block = _map(blocks[index], 'block');
    if (block['styleKind'] != block['kind']) {
      return (
        false,
        'block $index style ${block['styleKind']} for ${block['kind']}',
      );
    }
    final int runs = _int(block['styledRuns'], 'styledRuns');
    final int nodes = _int(block['inlineNodes'], 'inlineNodes');
    if (runs < nodes) {
      return (false, 'block $index has $runs styled runs for $nodes nodes');
    }
  }
  return (true, '${blocks.length} blocks styled');
}

_Check _checkRoundTrip(Map<String, Object?> sample) {
  final String atSave = _string(
    _map(sample['atSave'], 'atSave')['source'],
    'atSave.source',
  );
  final String reopened = _string(
    _map(sample['reopened'], 'reopened')['source'],
    'reopened.source',
  );
  return roundTripHolds(sourceAtSave: atSave, reopened: reopened)
      ? (true, 'round trip holds')
      : (false, 'reopened source differs from the trimmed saved source');
}

_Check _checkSideEdit(Map<String, Object?> sample) {
  final List<(int, int)> allowed = <(int, int)>[
    for (final Object? range in _list(sample['allowed'], 'allowed'))
      _intPair(range, 'allowed'),
  ];
  final List<(int, int, int)> changes = <(int, int, int)>[
    for (final Object? change in _list(sample['changes'], 'changes'))
      _intTriple(change),
  ];
  return changesWithin(allowed, changes)
      ? (true, 'changes inside the command range')
      : (false, '${sample['command']} changed bytes outside its range');
}

_Check _checkErrors(Map<String, Object?> sample) {
  final Map<String, Object?> errors = _map(sample['errors'], 'errors');
  final int count =
      _list(errors['errors'], 'errors.errors').length +
      _list(errors['drops'], 'errors.drops').length;
  return count == 0
      ? (true, 'no errors')
      : (false, '$count errors and dropped deltas');
}

OracleNote oracleNoteFromFixture(Map<String, Object?> fixture) {
  final List<OracleBlock> blocks = <OracleBlock>[
    for (final Object? block in _list(fixture['blocks'], 'blocks'))
      OracleBlock(
        _string(_map(block, 'block')['source'], 'source'),
        isPhoto: _map(block, 'block')['isPhoto'] == true,
        unclosedFence: _map(block, 'block')['unclosedFence'] == true,
      ),
  ];
  final List<String> separators = <String>[
    for (final Object? separator in _list(
      fixture['separators'] ?? const <Object?>[],
      'separators',
    ))
      _string(separator, 'separator'),
  ];
  return OracleNote(blocks: blocks, separators: separators);
}

_Check _checkRelocation(Map<String, Object?> sample) {
  final OracleNote note = oracleNoteFromFixture(
    _map(sample['fixture'], 'fixture'),
  );
  final Map<String, Object?> before = _map(sample['before'], 'before');
  final Map<String, Object?> after = _map(sample['after'], 'after');
  final String beforeSource = _string(before['source'], 'before.source');
  if (beforeSource != note.source) {
    return (false, 'before.source differs from the fixture');
  }
  final int photo = _int(sample['photo'], 'photo');
  final RelocationOp op = _byName(RelocationOp.values, sample['op'], 'op');
  final int? afterBlock = op == RelocationOp.drag
      ? _int(sample['afterBlock'], 'afterBlock')
      : null;
  final bool escaped = sample['escaped'] == true;
  final String? relocated = expectedRelocation(
    note,
    photo: photo,
    op: op,
    afterBlock: afterBlock,
  );
  final bool happened = relocated != null && !escaped;
  final String expected = happened ? relocated : beforeSource;
  if (_string(after['source'], 'after.source') != expected) {
    return (false, '${op.name} wrote other bytes than P3');
  }
  final int delta =
      _int(after['transactions'], 'after.transactions') -
      _int(before['transactions'], 'before.transactions');
  if (delta != (happened ? 1 : 0)) {
    return (false, '${op.name} recorded $delta transactions');
  }
  if (happened && op != RelocationOp.remove && after['photoSelected'] == null) {
    return (false, '${op.name} left no photo selected');
  }
  if (op == RelocationOp.drag) {
    final Object? hover = sample['hoverBoundary'];
    if (hover != null && !isValidBoundary(note, _int(hover, 'hoverBoundary'))) {
      return (false, 'insertion line drawn at $hover, inside a block');
    }
    final bool markable =
        afterBlock == -1 || !note.blocks[afterBlock!].unclosedFence;
    if (markable && hover != boundaryOffset(note, afterBlock: afterBlock!)) {
      return (
        false,
        'insertion line at $hover, not at '
            '${boundaryOffset(note, afterBlock: afterBlock)}',
      );
    }
  }
  return (true, '${op.name} matches P3');
}

_Check _checkCaret(Map<String, Object?> sample) {
  final List<Object?> audit = _list(
    _map(sample['caretAudit'], 'caretAudit')['samples'],
    'caretAudit.samples',
  );
  for (final Object? raw in audit) {
    final Map<String, Object?> entry = _map(raw, 'caret sample');
    if (!caretWithin(
      dx: _num(entry['dx'], 'dx'),
      dTop: _num(entry['dTop'], 'dTop'),
      dBottom: _num(entry['dBottom'], 'dBottom'),
    )) {
      return (
        false,
        'caret at ${entry['offset']} (${entry['blockKind']}) off by '
            'dx ${entry['dx']} dTop ${entry['dTop']} dBottom ${entry['dBottom']}',
      );
    }
  }
  return (true, '${audit.length} carets within 1 px');
}

List<ProbeRect> _rects(Object? value, String what) => <ProbeRect>[
  for (final Object? rect in _list(value, what)) _rect(rect, what),
];

ProbeRect _rect(Object? value, String what) {
  final List<Object?> list = _list(value, what);
  return ProbeRect.fromJson(list);
}

_Check _checkSelection(Map<String, Object?> sample) {
  final Map<String, Object?> boxes = _map(sample['boxes'], 'boxes');
  final SelectionCoverage coverage = selectionCoverage(
    selection: _rects(boxes['selection'], 'selection'),
    glyphs: <(ProbeRect, bool)>[
      for (final Object? glyph in _list(boxes['glyphs'], 'glyphs'))
        (
          _rect(_map(glyph, 'glyph')['rect'], 'glyph.rect'),
          _map(glyph, 'glyph')['selected'] == true,
        ),
    ],
    photos: _rects(boxes['photos'] ?? const <Object?>[], 'photos'),
    gutters: _rects(boxes['gutters'] ?? const <Object?>[], 'gutters'),
  );
  final bool pass =
      coverage.missing == 0 && coverage.extra == 0 && coverage.overlapping == 0;
  return (
    pass,
    'missing ${coverage.missing} extra ${coverage.extra} '
        'overlapping ${coverage.overlapping}',
  );
}

_Check _checkClick(Map<String, Object?> sample) {
  final bool pass = clickLandsOnNearerEdge(
    clickX: _num(sample['clickX'], 'clickX'),
    glyphLeft: _num(sample['glyphLeft'], 'glyphLeft'),
    glyphRight: _num(sample['glyphRight'], 'glyphRight'),
    offsetBefore: _int(sample['offsetBefore'], 'offsetBefore'),
    offsetAfter: _int(sample['offsetAfter'], 'offsetAfter'),
    landed: _int(sample['landed'], 'landed'),
  );
  return (pass, 'click at ${sample['clickX']} landed on ${sample['landed']}');
}

_Check _checkVertical(Map<String, Object?> sample) {
  final bool pass = verticalGoalHolds(
    caretX: _num(sample['caretX'], 'caretX'),
    goalX: _num(sample['goalX'], 'goalX'),
    glyphAdvance: _num(sample['glyphAdvance'], 'glyphAdvance'),
    lineShorterThanGoal: _bool(
      sample['lineShorterThanGoal'],
      'lineShorterThanGoal',
    ),
    lineEndX: _num(sample['lineEndX'], 'lineEndX'),
  );
  return (pass, 'caret at ${sample['caretX']} for goal ${sample['goalX']}');
}

_Check _checkPhoto(Map<String, Object?> sample) {
  final Object? rawSide = sample['side'] == 'center'
      ? 'centre'
      : sample['side'];
  final Object? pixelWidth = sample['pixelWidth'];
  final Object? pixelHeight = sample['pixelHeight'];
  final PhotoPlanExpectation plan = expectedPhotoPlan(
    column: _num(sample['column'], 'column'),
    em: _num(sample['em'], 'em'),
    size: _byName(OracleSize.values, sample['size'], 'size'),
    side: _byName(OracleSide.values, rawSide, 'side'),
    validPlacement: _bool(sample['validPlacement'], 'validPlacement'),
    pixelWidth: pixelWidth == null ? null : _int(pixelWidth, 'pixelWidth'),
    pixelHeight: pixelHeight == null ? null : _int(pixelHeight, 'pixelHeight'),
  );
  final List<ProbeRect> rects = _rects(sample['rects'], 'rects');
  if (rects.isEmpty) {
    return (false, 'no photo rects');
  }
  final ProbeRect first = rects.first;
  if ((first.width - plan.width).abs() > 0.5) {
    return (false, 'width ${first.width} for ${plan.width}');
  }
  if (pixelWidth != null &&
      pixelHeight != null &&
      (first.height - plan.height).abs() > 0.5) {
    return (false, 'height ${first.height} for ${plan.height}');
  }
  final int moved = rects.indexWhere(
    (ProbeRect rect) => !rectsMatch(rect, first),
  );
  if (moved >= 0) {
    return (false, 'rect $moved is ${rects[moved]}, not $first');
  }
  final Object? reader = sample['readerRect'];
  if (reader != null && !rectsMatch(_rect(reader, 'readerRect'), first)) {
    return (false, 'reader rect differs from the composer rect');
  }
  final Object? ring = sample['ringDegrees'];
  final Object? tilt = sample['tiltDegrees'];
  if (ring != null &&
      tilt != null &&
      (_num(ring, 'ringDegrees') - _num(tilt, 'tiltDegrees')).abs() > 0.1) {
    return (false, 'ring $ring degrees for tilt $tilt');
  }
  return (true, 'photo geometry holds');
}

_Check _checkFloat(Map<String, Object?> sample) {
  final Object? rawSide = sample['side'] == 'center'
      ? 'centre'
      : sample['side'];
  final bool pass = fragmentsClearFloat(
    float: _rect(sample['floatRect'], 'floatRect'),
    side: _byName(OracleSide.values, rawSide, 'side'),
    em: _num(sample['em'], 'em'),
    fragments: <(double, double)>[
      for (final Object? fragment in _list(sample['fragments'], 'fragments'))
        _doublePair(fragment),
    ],
  );
  return (
    pass,
    pass ? 'text clears the float' : 'text within the float gutter',
  );
}

_Check _checkParity(Map<String, Object?> sample) {
  final List<Object?> composerLines = _list(
    sample['composerLines'],
    'composerLines',
  );
  final List<Object?> viewerLines = _list(sample['viewerLines'], 'viewerLines');
  if (!_deepSubset(composerLines, viewerLines)) {
    return (false, 'visual lines differ');
  }
  final List<Object?> composerTops = _list(
    sample['composerTops'],
    'composerTops',
  );
  final List<Object?> viewerTops = _list(sample['viewerTops'], 'viewerTops');
  if (composerTops.length != viewerTops.length) {
    return (false, 'block counts differ');
  }
  for (int index = 0; index < composerTops.length; index++) {
    final double delta =
        (_num(composerTops[index], 'top') - _num(viewerTops[index], 'top'))
            .abs();
    if (delta > 0.5) {
      return (false, 'block $index top differs by $delta');
    }
  }
  return (true, 'layouts match');
}

_Check _checkToolbar(Map<String, Object?> sample) {
  final ProbeRect toolbar = _rect(sample['toolbar'], 'toolbar');
  final ProbeRect surface = _rect(sample['surface'], 'surface');
  final ProbeRect photo = _rect(sample['photo'], 'photo');
  if (!rectInside(toolbar, surface)) {
    return (false, 'toolbar $toolbar leaves the surface $surface');
  }
  if (!rectsOverlapOrTouch(toolbar, photo, tolerance: 10.5)) {
    return (false, 'toolbar $toolbar is apart from the photo $photo');
  }
  return (true, 'toolbar placed');
}

_Check _checkExpect(Map<String, Object?> sample) {
  final Map<String, Object?> expected = _map(sample['expected'], 'expected');
  final Map<String, Object?> observed = _map(sample['observed'], 'observed');
  for (final MapEntry<String, Object?> entry in expected.entries) {
    if (!observed.containsKey(entry.key) ||
        !_deepSubset(entry.value, observed[entry.key])) {
      return (
        false,
        '${entry.key}: expected ${jsonEncode(entry.value)}, observed '
            '${jsonEncode(observed[entry.key])}',
      );
    }
  }
  return (true, 'as expected');
}

bool _deepSubset(Object? expected, Object? observed) {
  if (expected is Map<String, Object?>) {
    return observed is Map<String, Object?> &&
        expected.entries.every(
          (MapEntry<String, Object?> entry) =>
              observed.containsKey(entry.key) &&
              _deepSubset(entry.value, observed[entry.key]),
        );
  }
  if (expected is List<Object?>) {
    if (observed is! List<Object?> || observed.length != expected.length) {
      return false;
    }
    for (int index = 0; index < expected.length; index++) {
      if (!_deepSubset(expected[index], observed[index])) {
        return false;
      }
    }
    return true;
  }
  if (expected is num) {
    return observed is num && expected == observed;
  }
  return expected == observed;
}

Map<String, Object?> _map(Object? value, String what) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw FormatException('$what is not an object');
}

List<Object?> _list(Object? value, String what) {
  if (value is List<Object?>) {
    return value;
  }
  throw FormatException('$what is not a list');
}

double _num(Object? value, String what) {
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('$what is not a number');
}

int _int(Object? value, String what) {
  if (value is int) {
    return value;
  }
  if (value is double && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$what is not an integer');
}

bool _bool(Object? value, String what) {
  if (value is bool) {
    return value;
  }
  throw FormatException('$what is not a boolean');
}

String _string(Object? value, String what) {
  if (value is String) {
    return value;
  }
  throw FormatException('$what is not a string');
}

(int, int) _intPair(Object? value, String what) {
  final List<Object?> pair = _list(value, what);
  if (pair.length != 2) {
    throw FormatException('$what entry is not [from, to]');
  }
  return (_int(pair[0], what), _int(pair[1], what));
}

(int, int, int) _intTriple(Object? value) {
  final List<Object?> triple = _list(value, 'change');
  if (triple.length != 3) {
    throw const FormatException('a change is [from, to, insertedLength]');
  }
  return (
    _int(triple[0], 'change'),
    _int(triple[1], 'change'),
    _int(triple[2], 'change'),
  );
}

(double, double) _doublePair(Object? value) {
  final List<Object?> pair = _list(value, 'fragment');
  if (pair.length != 2) {
    throw const FormatException('a fragment is [left, right]');
  }
  return (_num(pair[0], 'fragment'), _num(pair[1], 'fragment'));
}

String _verdictText(GateVerdict verdict) => switch (verdict) {
  GateVerdict.pass => 'PASS',
  GateVerdict.fail => 'FAIL',
  GateVerdict.reported => 'REPORTED',
};

const String _usage =
    'usage: dart run tool/probe/lib/gates.dart '
    'list | builds <scenario> | restore-caret <fixture.json> | '
    'evaluate <result.json>';

Map<String, Object?> _readJsonObject(String path) {
  final Object? decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  throw FormatException('$path does not hold a JSON object');
}

Future<void> main(List<String> arguments) async {
  final String command = arguments.isEmpty ? '' : arguments.first;
  if (command == 'list' && arguments.length == 1) {
    for (final String scenario in probeScenarios) {
      stdout.writeln(scenario);
    }
    exitCode = 0;
    return;
  }
  if (command == 'builds' && arguments.length == 2) {
    if (!probeScenarios.contains(arguments[1])) {
      stderr
        ..writeln('unknown scenario: ${arguments[1]}')
        ..writeln(_usage);
      exitCode = 2;
      return;
    }
    for (final ProbeBuild build in buildModesFor(arguments[1])) {
      stdout.writeln(build.name);
    }
    exitCode = 0;
    return;
  }
  if (command == 'restore-caret' && arguments.length == 2) {
    try {
      final OracleNote note = oracleNoteFromFixture(
        _readJsonObject(arguments[1]),
      );
      stdout.writeln(expectedRestoreCaret(note));
      exitCode = 0;
    } on Exception catch (error) {
      stderr.writeln(error);
      exitCode = 2;
    } on ArgumentError catch (error) {
      stderr.writeln(error);
      exitCode = 2;
    }
    return;
  }
  if (command == 'evaluate' && arguments.length == 2) {
    final List<RowOutcome> outcomes;
    try {
      outcomes = evaluateResult(_readJsonObject(arguments[1]));
    } on Exception catch (error) {
      stderr.writeln(error);
      exitCode = 2;
      return;
    } on ArgumentError catch (error) {
      stderr.writeln(error);
      exitCode = 2;
      return;
    }
    _printOutcomes(outcomes);
    final bool blockingFailed = outcomes.any(
      (RowOutcome outcome) =>
          outcome.verdict == GateVerdict.fail &&
          gateRows.firstWhere((GateRow row) => row.id == outcome.row).blocking,
    );
    exitCode = blockingFailed ? 1 : 0;
    return;
  }
  stderr.writeln(_usage);
  exitCode = 2;
}

void _printOutcomes(List<RowOutcome> outcomes) {
  for (final RowOutcome outcome in outcomes) {
    final Object? perNote = outcome.values['perNote'];
    if (outcome.row == 'GP1' && perNote is Map<String, Object?>) {
      for (final MapEntry<String, Object?> entry in perNote.entries) {
        final Map<String, Object?> summary =
            entry.value! as Map<String, Object?>;
        stdout.writeln(
          '${entry.key} p50 ${_ms(summary['p50']! as double)} '
          'p95 ${_ms(summary['p95']! as double)} '
          'max ${_ms(summary['max']! as double)}',
        );
      }
    }
    final Object? reportedOnly = outcome.values['reportedOnly'];
    if (reportedOnly is List<Map<String, Object?>>) {
      for (final Map<String, Object?> sample in reportedOnly) {
        stdout.writeln(
          '${outcome.row} ${outcome.platform.name} ${outcome.build.name} '
          'reported only: ${sample['case'] ?? sample['kind']} '
          '${jsonEncode(sample['observed'] ?? sample['reason'])}',
        );
      }
    }
    final bool blocking = gateRows
        .firstWhere((GateRow row) => row.id == outcome.row)
        .blocking;
    final String marker = !blocking && outcome.verdict != GateVerdict.reported
        ? ' (not blocking)'
        : '';
    stdout.writeln(
      '${outcome.row} ${outcome.platform.name} ${outcome.build.name} '
      '${outcome.measured} ${_verdictText(outcome.verdict)}$marker',
    );
  }
}
