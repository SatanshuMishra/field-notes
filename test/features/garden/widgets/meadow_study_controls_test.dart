import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/garden_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
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
        backgroundColor: const Color(0xFF3A4A2E),
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
                  moment: SkyMoment(
                    instant: _today.add(
                      Duration(minutes: shown ?? _liveMinutes),
                    ),
                  ),
                  builder: (BuildContext context, MeadowStudyParts parts) =>
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          parts.panel,
                          const SizedBox(height: 12),
                          if (compact)
                            parts.replay
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[parts.play, parts.replay],
                            ),
                        ],
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
  final double radius = tester.getSize(find.byKey(key)).height >= 48 ? 8 : 7;
  final Rect track = tester.getRect(find.byKey(key));
  return Offset(
    track.left + radius + (track.width - radius * 2) * fraction,
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

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets('the time slider sets the hour and Grown through sets the '
      'growth point', (WidgetTester tester) async {
    final _Reports reports = await _pump(tester);
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

    await tester.tap(find.text(meadowPlayTheDayLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(meadowPauseLabel), findsOneWidget);
    await tester.tapAt(_on(tester, meadowHourSliderKey, 0.5));
    await tester.pump();
    final int hourReports = reports.hours.length;
    expect(reports.hours.last, 720);
    await tester.pump(const Duration(milliseconds: 500));
    expect(reports.hours.length, hourReports);
    expect(find.text(meadowPlayTheDayLabel), findsOneWidget);
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
    await tester.tap(find.byKey(meadowReplayKey));
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

  testWidgets('Play the day runs the shown hour with no debug switch', (
    WidgetTester tester,
  ) async {
    final _Reports reports = await _pump(tester);
    expect(find.text(meadowPlayTheDayLabel), findsOneWidget);
    expect(find.text(meadowNowLabel), findsNothing);

    await tester.tap(find.text(meadowPlayTheDayLabel));
    await tester.pump();
    expect(reports.hours, <int?>[_liveMinutes]);
    expect(find.text(meadowPauseLabel), findsOneWidget);
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

    await tester.tap(find.text(meadowPauseLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(reports.hours, hasLength(4));
    expect(find.text(meadowPlayTheDayLabel), findsOneWidget);

    await tester.tap(find.text(meadowPlayTheDayLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(reports.hours.sublist(4), <int?>[
      _liveMinutes + 9,
      _liveMinutes + 12,
    ]);
    await tester.tap(find.text(meadowPauseLabel));
    await tester.pump();
    expect(find.text(meadowPlayTheDayLabel), findsOneWidget);
  });

  testWidgets('the day player wraps at midnight', (WidgetTester tester) async {
    final _Reports reports = await _pump(tester, hourMinutes: 1434);
    await tester.tap(find.text(meadowPlayTheDayLabel));
    await tester.pump();
    for (int tick = 0; tick < 3; tick += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(reports.hours, <int?>[1434, 1437, 0, 3]);
    await tester.tap(find.text(meadowPauseLabel));
    await tester.pump();
  });

  testWidgets('the phone controls are labelled 48 point targets in both '
      'themes', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    for (final Brightness brightness in Brightness.values) {
      await _pump(
        tester,
        compact: true,
        size: _phone,
        brightness: brightness,
        hourMinutes: 600,
      );
      expect(find.text(_replay), findsOneWidget);
      expect(find.text(meadowPlayTheDayLabel), findsNothing);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (final Key key in <Key>[meadowHourSliderKey, meadowGrowthSliderKey]) {
        expect(tester.getSize(find.byKey(key)).height, 48);
      }
      expect(tester.getSize(find.byKey(meadowReplayKey)).height, 48);
      expect(_styleOf(tester, 'Time of day').fontSize, 11);
      expect(_styleOf(tester, 'Time of day').color!.toARGB32(), isNot(0));
      expect(
        tester.getSize(find.text('Grown through')).width,
        lessThanOrEqualTo(84),
      );
      expect(
        _styleOf(tester, '10:00 AM').color!.toARGB32(),
        meadowCream.toARGB32(),
      );
      expect(_styleOf(tester, '10:00 AM').fontSize, 12);
    }
    semantics.dispose();
  });

  testWidgets('the desktop panel rows and dock pills are labelled in both '
      'themes', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    for (final Brightness brightness in Brightness.values) {
      await _pump(tester, brightness: brightness, hourMinutes: 600);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      for (final Key key in <Key>[meadowHourSliderKey, meadowGrowthSliderKey]) {
        expect(tester.getSize(find.byKey(key)).height, 22);
      }
      expect(tester.getSize(find.byKey(meadowStudyPlayKey)).height, 40);
      expect(tester.getSize(find.byKey(meadowReplayKey)).height, 40);
      expect(_styleOf(tester, 'Time of day').fontSize, 12);
      expect(_styleOf(tester, '10:00 AM').fontSize, 13);
      expect(find.bySemanticsLabel(meadowPlayTheDayLabel), findsOneWidget);
      expect(find.bySemanticsLabel(_replay), findsOneWidget);
    }
    semantics.dispose();
  });
}
