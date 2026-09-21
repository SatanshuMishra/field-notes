import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

const bool benchOnDevice = bool.fromEnvironment('BENCH_ON_DEVICE');

const String benchRunLabel = String.fromEnvironment(
  'BENCH_RUN_LABEL',
  defaultValue: 'desktop-flutter-test',
);

const String benchDeviceModel = String.fromEnvironment(
  'BENCH_DEVICE_MODEL',
  defaultValue: 'unknown',
);

const String benchDeviceRelease = String.fromEnvironment(
  'BENCH_DEVICE_RELEASE',
  defaultValue: 'unknown',
);

const String benchDeviceSdk = String.fromEnvironment(
  'BENCH_DEVICE_SDK',
  defaultValue: 'unknown',
);

const String benchFlutterVersion = String.fromEnvironment(
  'BENCH_FLUTTER_VERSION',
  defaultValue: 'unknown',
);

const String benchGitSha = String.fromEnvironment(
  'BENCH_GIT_SHA',
  defaultValue: 'unknown',
);

const String benchOutputDir = String.fromEnvironment('BENCH_OUTPUT_DIR');

const String benchOutputPath = 'build/note_perf_bench.json';
const String benchReportKey = 'noteBench';
const String benchScrollFrameKey = 'feedScrollFrames';
const String benchSchema = 'note-perf-bench/1';

const Duration benchFrameInterval = Duration(microseconds: 16667);

const int benchDefaultWarmup = 4;
const int benchDefaultSamples = 30;

String get benchBuildMode {
  if (kReleaseMode) {
    return 'release';
  }
  if (kProfileMode) {
    return 'profile';
  }
  return 'debug';
}

@immutable
class BenchMeasurement {
  const BenchMeasurement({
    required this.id,
    required this.what,
    required this.samplesUs,
    this.extra = const <String, Object?>{},
  });

  final String id;
  final String what;
  final List<int> samplesUs;
  final Map<String, Object?> extra;

  int get count => samplesUs.length;

  double get p50Ms => _millis(_percentileUs(50));

  double get p90Ms => _millis(_percentileUs(90));

  double get p99Ms => _millis(_percentileUs(99));

  double get maxMs => _millis(_percentileUs(100));

  double get meanMs {
    if (samplesUs.isEmpty) {
      return 0;
    }
    final int total = samplesUs.fold<int>(0, (int sum, int us) => sum + us);
    return _millis(total ~/ samplesUs.length);
  }

  int _percentileUs(int percentile) {
    if (samplesUs.isEmpty) {
      return 0;
    }
    final List<int> sorted = List<int>.of(samplesUs)..sort();
    final int rank = (percentile / 100 * sorted.length).ceil();
    return sorted[rank.clamp(1, sorted.length) - 1];
  }

  static double _millis(int micros) =>
      double.parse((micros / 1000).toStringAsFixed(3));

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'what': what,
        'unit': 'ms',
        'samples': count,
        'p50': p50Ms,
        'p90': p90Ms,
        'p99': p99Ms,
        'max': maxMs,
        'mean': meanMs,
        if (extra.isNotEmpty) 'context': extra,
        'samplesUs': samplesUs,
      };

  @override
  String toString() => '$id p50=${p50Ms}ms p90=${p90Ms}ms '
      'p99=${p99Ms}ms max=${maxMs}ms n=$count';
}

class BenchRecorder {
  BenchRecorder._();

  static final BenchRecorder instance = BenchRecorder._();

  final List<BenchMeasurement> _measurements = <BenchMeasurement>[];
  Map<String, Object?> _surface = const <String, Object?>{};

  List<BenchMeasurement> get measurements =>
      List<BenchMeasurement>.unmodifiable(_measurements);

  void describeSurface(Map<String, Object?> surface) {
    _surface = Map<String, Object?>.unmodifiable(surface);
  }

  Future<BenchMeasurement> record(BenchMeasurement measurement) async {
    _measurements
      ..removeWhere((BenchMeasurement held) => held.id == measurement.id)
      ..add(measurement);
    debugPrint('NOTE-PERF-BENCH $measurement');
    await publish();
    return measurement;
  }

  Map<String, Object?> envelope() => <String, Object?>{
        'schema': benchSchema,
        'environment': <String, Object?>{
          'runLabel': benchRunLabel,
          'onDevice': benchOnDevice,
          'deviceModel': benchDeviceModel,
          'osRelease': benchDeviceRelease,
          'osSdk': benchDeviceSdk,
          'operatingSystem': Platform.operatingSystem,
          'operatingSystemVersion': Platform.operatingSystemVersion,
          'flutterVersion': benchFlutterVersion,
          'dartVersion': Platform.version,
          'buildMode': benchBuildMode,
          'gitSha': benchGitSha,
          'recordedAt': DateTime.now().toUtc().toIso8601String(),
        },
        'surface': _surface,
        'measurements': <Map<String, Object?>>[
          for (final BenchMeasurement measurement in _measurements)
            measurement.toJson(),
        ],
      };

  Future<void> publish() async {
    final IntegrationTestWidgetsFlutterBinding binding =
        IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    final Map<String, dynamic> data =
        binding.reportData ??= <String, dynamic>{};
    data[benchReportKey] = envelope();
    if (benchOnDevice) {
      return;
    }
    await _writeLocalCopy(data);
  }

  Future<void> _writeLocalCopy(Map<String, dynamic> data) async {
    final String root =
        benchOutputDir.isEmpty ? Directory.current.path : benchOutputDir;
    final File file = File(p.join(root, benchOutputPath));
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
    } on Object catch (error) {
      debugPrint('NOTE-PERF-BENCH could not write ${file.path}: $error');
    }
  }
}

Future<BenchMeasurement> benchMeasure({
  required String id,
  required String what,
  required Future<Duration> Function() sample,
  int warmup = benchDefaultWarmup,
  int samples = benchDefaultSamples,
  Map<String, Object?> extra = const <String, Object?>{},
}) async {
  for (int i = 0; i < warmup; i++) {
    await sample();
  }
  final List<int> collected = <int>[];
  for (int i = 0; i < samples; i++) {
    collected.add((await sample()).inMicroseconds);
  }
  return BenchRecorder.instance.record(
    BenchMeasurement(
      id: id,
      what: what,
      samplesUs: List<int>.unmodifiable(collected),
      extra: extra,
    ),
  );
}

class BenchClock {
  BenchClock._();

  static Duration _stamp = Duration.zero;

  static Duration tick() {
    _stamp += benchFrameInterval;
    return _stamp;
  }
}

Future<Duration> benchFrame(WidgetTester tester) async {
  final Duration stamp = BenchClock.tick();
  final Stopwatch watch = Stopwatch()..start();
  await tester.pumpBenchmark(stamp);
  watch.stop();
  return watch.elapsed;
}

Future<void> benchFrames(WidgetTester tester, {int count = 4}) async {
  for (int i = 0; i < count; i++) {
    await benchFrame(tester);
  }
}

void useBenchmarkFrames(WidgetTester tester) {
  benchBinding(tester).framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.benchmark;
}

void useLiveFrames(WidgetTester tester) {
  benchBinding(tester).framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
}

IntegrationTestWidgetsFlutterBinding benchBinding(WidgetTester tester) =>
    tester.binding as IntegrationTestWidgetsFlutterBinding;

const Size benchPhoneLogicalSize = Size(393, 851);
const double benchPhoneDevicePixelRatio = 2.75;

void adoptBenchSurface(WidgetTester tester) {
  if (benchOnDevice) {
    return;
  }
  tester.view.devicePixelRatio = benchPhoneDevicePixelRatio;
  tester.view.physicalSize = benchPhoneLogicalSize * benchPhoneDevicePixelRatio;
  addTearDown(tester.view.reset);
}

int benchQuantisedCacheWidth(double logicalWidth, double devicePixelRatio) {
  final double physical = logicalWidth * devicePixelRatio;
  return math.max(64, (physical / 64).ceil() * 64);
}

final GlobalKey<BenchStageState> benchStageKey = GlobalKey<BenchStageState>();

class BenchStage extends StatefulWidget {
  const BenchStage({super.key});

  @override
  State<BenchStage> createState() => BenchStageState();
}

class BenchStageState extends State<BenchStage> {
  Widget _content = const SizedBox.shrink();

  void show(Widget content) => setState(() => _content = content);

  void clear() => setState(() => _content = const SizedBox.shrink());

  @override
  Widget build(BuildContext context) => _content;
}
