import 'package:field_notes/features/garden/model/meadow_year_replay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _fourSeconds = Duration(seconds: 4);
const Duration _frame = Duration(milliseconds: 16);
const int _limit = 365;

Future<void> _pumpFor(WidgetTester tester, Duration span) async {
  Duration elapsed = Duration.zero;
  while (elapsed < span) {
    await tester.pump(_frame);
    elapsed += _frame;
  }
}

void main() {
  testWidgets('the year replay grows to the limit over its duration, stops, '
      'and jumps with reduce motion', (WidgetTester tester) async {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final List<(int, bool)> reports = <(int, bool)>[];
      final MeadowYearReplay replay = MeadowYearReplay(
        vsync: tester,
        duration: _fourSeconds,
        onGrowth: (int point, bool animated) => reports.add((point, animated)),
      );
      try {
        expect(replay.playing, isFalse);
        replay.start(limit: _limit, reduceMotion: false);
        expect(replay.playing, isTrue);
        expect(reports, <(int, bool)>[(0, true)]);

        await tester.pump();
        Duration elapsed = Duration.zero;
        Duration? reachedLimit;
        while (elapsed < _fourSeconds) {
          await tester.pump(_frame);
          elapsed += _frame;
          if (elapsed == const Duration(seconds: 2)) {
            expect(reports.last, (182, true));
          }
          if (reachedLimit == null && reports.last.$1 == _limit) {
            reachedLimit = elapsed;
          }
          if (elapsed < _fourSeconds) {
            expect(replay.playing, isTrue);
          }
        }
        expect(reachedLimit, _fourSeconds);
        expect(replay.playing, isFalse);
        expect(reports.last, (_limit, true));
        final List<int> points = reports
            .map(((int, bool) report) => report.$1)
            .toList();
        expect(points.first, 0);
        expect(points.where((int point) => point == _limit), hasLength(1));
        for (int index = 1; index < points.length; index += 1) {
          expect(points[index], greaterThan(points[index - 1]));
        }
        expect(
          reports.map(((int, bool) report) => report.$2),
          everyElement(isTrue),
        );
        final int finished = reports.length;
        await _pumpFor(tester, const Duration(seconds: 1));
        expect(reports, hasLength(finished));

        replay.start(limit: _limit, reduceMotion: false);
        await tester.pump();
        await _pumpFor(tester, const Duration(seconds: 1));
        final List<(int, bool)> replayed = reports.sublist(finished);
        expect(replay.playing, isTrue);
        expect(replayed.first, (0, true));
        expect(replayed.last.$1, greaterThan(0));
        expect(replayed.last.$1, lessThan(_limit));
        replay.stop();
        expect(replay.playing, isFalse);
        final int stopped = reports.length;
        await _pumpFor(tester, _fourSeconds);
        expect(reports, hasLength(stopped));

        replay.start(limit: _limit, reduceMotion: true);
        expect(reports.sublist(stopped), <(int, bool)>[(_limit, false)]);
        expect(replay.playing, isFalse);
        await _pumpFor(tester, _fourSeconds);
        expect(reports.sublist(stopped), <(int, bool)>[(_limit, false)]);
      } finally {
        replay.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    }
  });
}
