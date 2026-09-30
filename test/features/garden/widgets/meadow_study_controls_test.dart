import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _today = DateTime(2026, 9, 29);
const int _liveMinutes = 14 * 60 + 7;
const int _limit = 365;
const Size _desk = Size(1000, 400);
const Size _phone = Size(390, 400);
const Duration _frame = Duration(milliseconds: 16);
const Duration _thirteenSeconds = Duration(seconds: 13);
const String _replay = 'Replay the year';
const String _planting = 'Planting…';

class _Reports {
  final List<int?> hours = <int?>[];
  final List<(int, bool)> growth = <(int, bool)>[];

  List<int> get points =>
      growth.map(((int, bool) report) => report.$1).toList();
}

Future<_Reports> _pump(
  WidgetTester tester, {
  bool compact = false,
  bool debugControls = false,
  bool reduceMotion = false,
  int? hourMinutes,
  int growthPoint = _limit,
  Size size = _desk,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Reports reports = _Reports();
  int? hour = hourMinutes;
  int growth = growthPoint;
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(
        platform: compact ? TargetPlatform.android : TargetPlatform.macOS,
        brightness: brightness,
      ),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: reduceMotion),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                final int? shown = hour;
                return MeadowStudyControls(
                  compact: compact,
                  hourMinutes: shown,
                  onHour: (int? minutes) {
                    reports.hours.add(minutes);
                    setState(() => hour = minutes);
                  },
                  limit: _limit,
                  daysInYear: 365,
                  year: 2025,
                  growthPoint: growth,
                  onGrowth: (int point, bool growAnimated) {
                    reports.growth.add((point, growAnimated));
                    setState(() => growth = point);
                  },
                  debugControls: debugControls,
                  moment: SkyMoment(
                    instant: _today.add(
                      Duration(minutes: shown ?? _liveMinutes),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  return reports;
}

Offset _on(WidgetTester tester, Key key, double fraction) {
  final Rect track = tester.getRect(find.byKey(key));
  return Offset(
    track.left + 7 + (track.width - 14) * fraction,
    track.center.dy,
  );
}

void _focusSlider(WidgetTester tester, Key key) {
  Focus.of(
    tester.element(
      find.descendant(of: find.byKey(key), matching: find.byType(CustomPaint)),
    ),
  ).requestFocus();
}

void main() {
  testWidgets('the time slider sets the hour and Grown through sets the '
      'growth point', (WidgetTester tester) async {
    final _Reports reports = await _pump(tester, debugControls: true);
    expect(find.text('2:07 PM'), findsOneWidget);
    expect(find.text('Dec 31'), findsOneWidget);

    await tester.tapAt(_on(tester, meadowHourSliderKey, 0.5));
    await tester.pump();
    expect(reports.hours, <int?>[720]);
    expect(find.text('12:00 PM'), findsOneWidget);

    await tester.tapAt(_on(tester, meadowHourSliderKey, 0));
    await tester.pump();
    expect(reports.hours.last, 0);
    expect(find.text('12:00 AM'), findsOneWidget);

    await tester.drag(find.byKey(meadowHourSliderKey), const Offset(800, 0));
    await tester.pump();
    expect(reports.hours.last, 23 * 60 + 57);
    expect(find.text('11:57 PM'), findsOneWidget);

    await tester.tap(find.text('Play the day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Pause'), findsOneWidget);
    await tester.tapAt(_on(tester, meadowHourSliderKey, 0.5));
    await tester.pump();
    final int hourReports = reports.hours.length;
    expect(reports.hours.last, 720);
    await tester.pump(const Duration(milliseconds: 500));
    expect(reports.hours.length, hourReports);
    expect(find.text('Play the day'), findsOneWidget);
    expect(reports.growth, isEmpty);

    await tester.tapAt(_on(tester, meadowGrowthSliderKey, 0.5));
    await tester.pump();
    expect(reports.growth, <(int, bool)>[(183, true)]);
    expect(find.text('Jul 2'), findsOneWidget);

    _focusSlider(tester, meadowGrowthSliderKey);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(reports.points.last, 181);
    expect(find.text('Jun 30'), findsOneWidget);

    await tester.tapAt(_on(tester, meadowGrowthSliderKey, 0));
    await tester.pump();
    expect(reports.growth.last, (1, true));
    expect(find.text('Jan 1'), findsOneWidget);

    await tester.tapAt(_on(tester, meadowGrowthSliderKey, 1));
    await tester.pump();
    expect(reports.growth.last, (_limit, true));
    expect(find.text('Dec 31'), findsOneWidget);
    expect(reports.hours.length, hourReports);
  });

  testWidgets('Replay the year plants the year in thirteen seconds', (
    WidgetTester tester,
  ) async {
    final _Reports reports = await _pump(tester);
    await tester.tap(find.text(_replay));
    await tester.pump();
    expect(reports.growth, <(int, bool)>[(0, true)]);
    expect(find.text(_planting), findsOneWidget);
    expect(find.text(_replay), findsNothing);

    Duration elapsed = Duration.zero;
    Duration lastReport = Duration.zero;
    int seen = reports.growth.length;
    while (elapsed < _thirteenSeconds) {
      await tester.pump(_frame);
      elapsed += _frame;
      if (reports.growth.length > seen) {
        expect(
          elapsed - lastReport,
          lessThanOrEqualTo(const Duration(milliseconds: 60)),
        );
        lastReport = elapsed;
        seen = reports.growth.length;
      }
      if (elapsed < _thirteenSeconds) {
        expect(find.text(_planting), findsOneWidget);
      }
    }

    final List<int> points = reports.points;
    expect(reports.growth.last, (_limit, true));
    expect(points.where((int point) => point == _limit), hasLength(1));
    expect(
      reports.growth.map(((int, bool) report) => report.$2),
      everyElement(isTrue),
    );
    for (int index = 1; index < points.length; index += 1) {
      expect(points[index], greaterThan(points[index - 1]));
    }
    expect(find.text(_replay), findsOneWidget);
    expect(find.text(_planting), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(reports.growth, hasLength(seen));
  });

  testWidgets('moving Grown through stops a replay', (
    WidgetTester tester,
  ) async {
    final _Reports reports = await _pump(tester, compact: true, size: _phone);
    await tester.tap(find.text(_replay));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_planting), findsOneWidget);
    expect(reports.points.last, greaterThan(0));

    await tester.tapAt(_on(tester, meadowGrowthSliderKey, 0.5));
    await tester.pump();
    expect(reports.growth.last, (183, true));
    expect(find.text(_replay), findsOneWidget);
    final int count = reports.growth.length;
    await tester.pump(const Duration(seconds: 13));
    expect(reports.growth, hasLength(count));
  });

  testWidgets('with reduce motion Replay the year plants the year at once', (
    WidgetTester tester,
  ) async {
    final _Reports reports = await _pump(
      tester,
      reduceMotion: true,
      growthPoint: 100,
    );
    await tester.tap(find.text(_replay));
    await tester.pump();
    expect(reports.growth, <(int, bool)>[(_limit, false)]);
    expect(find.text(_replay), findsOneWidget);
    await tester.pump(const Duration(seconds: 13));
    expect(reports.growth, hasLength(1));
  });

  testWidgets('Play the day and Now appear only in debug builds', (
    WidgetTester tester,
  ) async {
    await _pump(tester, hourMinutes: 600);
    expect(find.text('Play the day'), findsNothing);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Now'), findsNothing);
    await _pump(tester, compact: true, size: _phone, hourMinutes: 600);
    expect(find.text('Play the day'), findsNothing);
    expect(find.text('Now'), findsNothing);

    final _Reports reports = await _pump(tester, debugControls: true);
    expect(find.text('Play the day'), findsOneWidget);
    expect(find.text('Now'), findsNothing);

    await tester.tap(find.text('Play the day'));
    await tester.pump();
    expect(reports.hours, <int?>[_liveMinutes]);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 49));
    expect(reports.hours, <int?>[_liveMinutes]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(reports.hours, <int?>[_liveMinutes, _liveMinutes + 3]);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(reports.hours, <int?>[
      _liveMinutes,
      _liveMinutes + 3,
      _liveMinutes + 6,
      _liveMinutes + 9,
    ]);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(reports.hours, hasLength(4));
    expect(find.text('Play the day'), findsOneWidget);

    await tester.tap(find.text('Play the day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(reports.hours.sublist(4), <int?>[
      _liveMinutes + 9,
      _liveMinutes + 12,
    ]);
    await tester.tap(find.text('Now'));
    await tester.pump();
    expect(reports.hours.last, isNull);
    await tester.pump(const Duration(milliseconds: 500));
    expect(reports.hours, hasLength(7));
    expect(find.text('Now'), findsNothing);
    expect(find.text('Play the day'), findsOneWidget);
    expect(find.text('2:07 PM'), findsOneWidget);
  });

  testWidgets('the day player wraps at midnight', (WidgetTester tester) async {
    final _Reports reports = await _pump(
      tester,
      compact: true,
      size: _phone,
      debugControls: true,
      hourMinutes: 1434,
    );
    await tester.tap(find.text('Play the day'));
    await tester.pump();
    for (int tick = 0; tick < 3; tick += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(reports.hours, <int?>[1434, 1437, 0, 3]);
  });

  testWidgets('every control is a labelled 48 by 48 target in both layouts '
      'and themes', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    for (final Brightness brightness in Brightness.values) {
      for (final (bool compact, Size size) in <(bool, Size)>[
        (false, const Size(1600, 400)),
        (false, _desk),
        (false, const Size(420, 400)),
        (true, _phone),
      ]) {
        await _pump(
          tester,
          compact: compact,
          size: size,
          brightness: brightness,
          debugControls: true,
          hourMinutes: 600,
        );
        expect(find.text('Now'), findsOneWidget);
        expect(find.text('Play the day'), findsOneWidget);
        expect(find.text(_replay), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        for (final Key key in <Key>[
          meadowHourSliderKey,
          meadowGrowthSliderKey,
        ]) {
          expect(
            tester.getSize(find.byKey(key)).height,
            greaterThanOrEqualTo(48),
          );
        }
      }
    }
    semantics.dispose();
  });

  testWidgets('the sidebar boxes sit side by side and wrap when narrow', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    expect(
      tester.getRect(find.byKey(meadowGrowthSliderKey)).top,
      tester.getRect(find.byKey(meadowHourSliderKey)).top,
    );
    await _pump(tester, size: const Size(600, 400));
    expect(
      tester.getRect(find.byKey(meadowGrowthSliderKey)).top,
      greaterThan(tester.getRect(find.byKey(meadowHourSliderKey)).bottom),
    );
  });
}
