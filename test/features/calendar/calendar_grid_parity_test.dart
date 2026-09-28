import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/features/calendar/widgets/calendar_day_cell.dart';
import 'package:field_notes/features/calendar/widgets/calendar_weekday_bar.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Day _day(String date, {Mood? mood}) =>
    Day(id: 'id-$date', date: date, mood: mood, createdAt: 0, updatedAt: 0);

Finder _dayCell(String date) => find.byKey(ValueKey<String>('day-$date'));

Future<void> _pumpCalendar(
  WidgetTester tester, {
  List<Day> days = const <Day>[],
  WeekStart weekStart = WeekStart.sunday,
  List<String>? openedDays,
  List<String>? openedToday,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        weekStartProvider.overrideWithValue(weekStart),
        journaledDatesProvider.overrideWith(
          (Ref ref) => Stream<List<String>>.value(const <String>[]),
        ),
        daysInMonthProvider(
          year: 2026,
          month: 7,
        ).overrideWith((_) => Stream<List<Day>>.value(days)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: CalendarScreen(
            initialMonth: const MonthRef(2026, 7),
            today: DateTime(2026, 7, 15),
            onOpenDay: (BuildContext context, {required String date}) async {
              openedDays?.add(date);
            },
            onOpenToday: () => openedToday?.add('today'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Iterable<double> _opacitiesIn(WidgetTester tester, Finder cell) {
  return tester
      .widgetList<Opacity>(
        find.descendant(of: cell, matching: find.byType(Opacity)),
      )
      .map((Opacity opacity) => opacity.opacity);
}

void main() {
  testWidgets('tapping today opens the Today page', (
    WidgetTester tester,
  ) async {
    final List<String> openedDays = <String>[];
    final List<String> openedToday = <String>[];
    await _pumpCalendar(
      tester,
      openedDays: openedDays,
      openedToday: openedToday,
    );

    await tester.tap(_dayCell('2026-07-15'));
    await tester.pump();

    expect(openedToday, hasLength(1));
    expect(openedDays, isEmpty);
  });

  testWidgets('a future day is dimmed and does not respond', (
    WidgetTester tester,
  ) async {
    final List<String> openedDays = <String>[];
    final List<String> openedToday = <String>[];
    await _pumpCalendar(
      tester,
      openedDays: openedDays,
      openedToday: openedToday,
    );

    await tester.tap(_dayCell('2026-07-20'), warnIfMissed: false);
    await tester.pump();

    expect(openedDays, isEmpty);
    expect(openedToday, isEmpty);
    expect(_opacitiesIn(tester, _dayCell('2026-07-20')), contains(0.55));
    expect(_opacitiesIn(tester, _dayCell('2026-07-14')), isNot(contains(0.55)));
  });

  testWidgets('a Monday week start leads the grid and the labels with Monday', (
    WidgetTester tester,
  ) async {
    await _pumpCalendar(tester, weekStart: WeekStart.monday);

    final List<String?> labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(CalendarWeekdayBar),
            matching: find.byType(Text),
          ),
        )
        .map((Text text) => text.data)
        .toList();
    expect(labels, <String>['M', 'T', 'W', 'T', 'F', 'S', 'S']);

    final CalendarDayCell first =
        tester.widgetList<CalendarDayCell>(find.byType(CalendarDayCell)).first;
    expect(first.cell.dateKey, '2026-06-29');
  });

  testWidgets('the current week row is outlined', (WidgetTester tester) async {
    await _pumpCalendar(tester);

    final Color tint = Palette.coral.withValues(alpha: 0.09);
    final Finder tintedRows = find.byWidgetPredicate(
      (Widget widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == tint,
    );
    expect(tintedRows, findsOneWidget);
    expect(
      find.descendant(of: tintedRows, matching: _dayCell('2026-07-15')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tintedRows, matching: _dayCell('2026-07-12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tintedRows, matching: _dayCell('2026-07-19')),
      findsNothing,
    );
  });

  testWidgets(
    'neighbouring-month days show dimmed numbers and follow the tap rule',
    (WidgetTester tester) async {
      final List<String> openedDays = <String>[];
      await _pumpCalendar(
        tester,
        days: <Day>[_day('2026-06-29', mood: Mood.happy)],
        openedDays: openedDays,
      );

      final Finder neighbour = _dayCell('2026-06-29');
      expect(neighbour, findsOneWidget);
      expect(_opacitiesIn(tester, neighbour), contains(0.35));
      expect(
        find.descendant(of: neighbour, matching: find.byType(FlowerBloom)),
        findsNothing,
      );
      expect(
        find.descendant(of: neighbour, matching: find.text('29')),
        findsOneWidget,
      );

      await tester.tap(neighbour);
      await tester.pump();

      expect(openedDays, <String>['2026-06-29']);
    },
  );

  testWidgets(
    'a day with logs and no mood shows the activity dot on the mood surface',
    (WidgetTester tester) async {
      await _pumpCalendar(tester, days: <Day>[_day('2026-07-10')]);

      final Finder cell = _dayCell('2026-07-10');
      expect(
        find.descendant(of: cell, matching: find.byKey(calendarActivityDotKey)),
        findsOneWidget,
      );
      final Iterable<Color?> surfaces = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: cell, matching: find.byType(DecoratedBox)),
          )
          .map(
            (DecoratedBox box) => box.decoration is BoxDecoration
                ? (box.decoration as BoxDecoration).color
                : null,
          );
      expect(surfaces, contains(Palette.cardWarm));
    },
  );
}
