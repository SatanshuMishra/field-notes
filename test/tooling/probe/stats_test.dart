import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../tool/probe/lib/gates.dart';
// ignore: avoid_relative_lib_imports
import '../../../tool/probe/lib/stats.dart';

Map<String, Object?> _keystrokeSample(String note, List<double> buildMs) =>
    <String, Object?>{
      'row': 'GP1',
      'kind': 'keystroke',
      'note': note,
      'timings': <String, Object?>{
        'keystrokes': <Object?>[
          for (final double value in buildMs)
            <String, Object?>{'handlerMs': 0, 'buildMs': value},
        ],
      },
    };

Map<String, Object?> _document(
  String scenario,
  List<Map<String, Object?>> samples,
) => <String, Object?>{
  'scenario': scenario,
  'platform': 'macos',
  'build': 'profile',
  'commit': 'abc',
  'samples': samples,
};

Map<String, Object?> _idleSample({
  bool caretVisible = true,
  int frames = 20,
  String cpuEnd = '0:01.30',
}) => <String, Object?>{
  'row': 'GP4',
  'kind': 'idle',
  'case': 'nothing selected',
  'caretVisible': caretVisible,
  'timings': <String, Object?>{
    'frames': <Object?>[
      for (int index = 0; index < frames; index++)
        <String, Object?>{'buildMs': 1.0, 'rasterMs': 1.0},
    ],
  },
  'windowMs': 10000,
  'cpuStart': '0:01.20',
  'cpuEnd': cpuEnd,
  'cpuFormat': 'ps',
};

RowOutcome _row(List<RowOutcome> outcomes, String id) =>
    outcomes.singleWhere((RowOutcome outcome) => outcome.row == id);

void main() {
  test(
    'p95 is computed per note and janky frames use the refresh interval',
    () {
      final List<double> small = List<double>.filled(100, 1.0);
      final List<double> large = <double>[
        ...List<double>.filled(18, 1.0),
        6.0,
        6.0,
      ];
      final Map<String, TimingSummary> summaries = summarisePerNote(
        <String, List<double>>{'c500-p0': small, 'c50000-p24': large},
      );
      expect(summaries['c500-p0']!.p95, 1.0);
      expect(summaries['c50000-p24']!.p95, 6.0);
      expect(percentile(<double>[...small, ...large], 95), 1.0);

      final List<RowOutcome> failing = evaluateResult(
        _document('perf-keystroke', <Map<String, Object?>>[
          _keystrokeSample('c500-p0', small),
          _keystrokeSample('c50000-p24', large),
        ]),
      );
      final RowOutcome gp1 = _row(failing, 'GP1');
      expect(gp1.verdict, GateVerdict.fail);
      expect(gp1.values['worstNote'], 'c50000-p24');

      final List<double> fixed = <double>[
        ...List<double>.filled(18, 1.0),
        3.0,
        3.0,
      ];
      final List<RowOutcome> passing = evaluateResult(
        _document('perf-keystroke', <Map<String, Object?>>[
          _keystrokeSample('c500-p0', small),
          _keystrokeSample('c50000-p24', fixed),
        ]),
      );
      expect(_row(passing, 'GP1').verdict, GateVerdict.pass);

      final double mac = jankIntervalMs(ProbePlatform.macos, 120);
      expect(mac, closeTo(1000 / 120, 1e-9));
      expect(
        jankIntervalMs(ProbePlatform.android, 60),
        closeTo(2000 / 60, 1e-9),
      );
      expect(
        jankIntervalMs(ProbePlatform.android, 120),
        closeTo(2000 / 120, 1e-9),
      );
      expect(
        isJankyFrame(const FrameSample(buildMs: 8.0, rasterMs: 8.4), mac),
        isTrue,
      );
      expect(
        isJankyFrame(const FrameSample(buildMs: 8.3, rasterMs: 8.3), mac),
        isFalse,
      );
      const FrameSample slow = FrameSample(buildMs: 20, rasterMs: 20);
      expect(isJankyFrame(slow, mac), isTrue);
      expect(
        isJankyFrame(slow, jankIntervalMs(ProbePlatform.android, 60)),
        isFalse,
      );
    },
  );

  test('cpu is a percent of one core over the sample window', () {
    expect(parsePsCpuTime('0:01.20'), const Duration(milliseconds: 1200));
    expect(parsePsCpuTime('1:02:03.45'), const Duration(milliseconds: 3723450));
    expect(
      cpuPercentOfOneCore(
        cpuStart: parsePsCpuTime('0:01.20'),
        cpuEnd: parsePsCpuTime('0:01.30'),
        wall: cpuWindow,
      ),
      1.0,
    );
    expect(
      cpuPercentOfOneCore(
        cpuStart: parsePsCpuTime('0:01.20'),
        cpuEnd: parsePsCpuTime('0:01.35'),
        wall: cpuWindow,
      ),
      1.5,
    );
    const String stat =
        '4242 (ui (probe) x) S 1 4242 0 0 -1 4194624 100 0 0 0 250 50 0 0 20 0 30 0 123';
    const String later =
        '4242 (ui (probe) x) S 1 4242 0 0 -1 4194624 100 0 0 0 255 52 0 0 20 0 30 0 123';
    expect(parseProcStatCpuTime(stat), const Duration(seconds: 3));
    expect(parseProcStatCpuTime(later), const Duration(milliseconds: 3070));
    expect(
      cpuPercentOfOneCore(
        cpuStart: parseProcStatCpuTime(stat),
        cpuEnd: parseProcStatCpuTime(later),
        wall: cpuWindow,
      ),
      closeTo(0.7, 1e-12),
    );
    expect(cpuSettle, const Duration(seconds: 2));
    expect(cpuWindow, const Duration(seconds: 10));

    GateVerdict idle(Map<String, Object?> sample) => _row(
      evaluateResult(_document('perf-idle', <Map<String, Object?>>[sample])),
      'GP4',
    ).verdict;

    expect(idle(_idleSample()), GateVerdict.pass);
    expect(idle(_idleSample(frames: 21)), GateVerdict.fail);
    expect(idle(_idleSample(caretVisible: false, frames: 1)), GateVerdict.fail);
    expect(idle(_idleSample(cpuEnd: '0:01.35')), GateVerdict.fail);
  });

  test('percentile uses the nearest rank on a sorted copy', () {
    final List<double> values = <double>[
      for (int value = 20; value >= 1; value--) value.toDouble(),
    ];
    expect(percentile(values, 95), 19);
    expect(percentile(values, 50), 10);
    expect(percentile(values, 100), 20);
    expect(values.first, 20);
    expect(() => percentile(<double>[], 50), throwsArgumentError);
    expect(() => percentile(values, 0), throwsArgumentError);
    expect(() => percentile(values, 100.5), throwsArgumentError);
    final TimingSummary summary = summarise(values);
    expect(summary.count, 20);
    expect(summary.max, 20);
  });

  test('ps cputime forms parse with days, hours and long minutes', () {
    expect(
      parsePsCpuTime(' 62:03.45\n'),
      const Duration(milliseconds: 3723450),
    );
    expect(parsePsCpuTime('1-00:00:01'), const Duration(days: 1, seconds: 1));
    expect(parsePsCpuTime('0:05'), const Duration(seconds: 5));
    expect(() => parsePsCpuTime('5'), throwsFormatException);
    expect(() => parsePsCpuTime('0:5.1'), throwsFormatException);
    expect(
      parseProcStatCpuTime(
        '1 (a) S 1 1 0 0 -1 0 0 0 0 0 250 50 0',
        clockTicksPerSecond: 1000,
      ),
      const Duration(milliseconds: 300),
    );
    expect(() => parseProcStatCpuTime('1 (a) S 1'), throwsFormatException);
  });

  test('frame rate, janky counts and the clock map', () {
    expect(framesPerSecond(20, const Duration(seconds: 10)), 2.0);
    expect(
      countJankyFrames(const <FrameSample>[
        FrameSample(buildMs: 1, rasterMs: 9),
        FrameSample(buildMs: 1, rasterMs: 1),
        FrameSample(buildMs: 9, rasterMs: 1),
      ], 8.33),
      2,
    );
    final ClockMap clock = ClockMap.fromPairs(const <(int, int)>[
      (1000000, 5000),
      (2000000, 6002),
    ]);
    expect(clock.toProbeMicros(3000000), 7001);
    expect(() => ClockMap.fromPairs(const <(int, int)>[]), throwsArgumentError);
  });
}
