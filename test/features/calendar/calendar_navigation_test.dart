import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpCalendar(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        weekStartProvider.overrideWithValue(WeekStart.sunday),
        daysInMonthProvider.overrideWith(
          (Ref ref, ({int year, int month}) args) =>
              Stream<List<Day>>.value(const <Day>[]),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CalendarScreen(
          initialMonth: const MonthRef(2026, 7),
          today: DateTime(2026, 7, 15),
          onOpenDay: (BuildContext context, {required String date}) async {},
          onOpenToday: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(calendarTitleKey));
  await tester.pumpAndSettle();
  expect(find.byKey(calendarPickerKey), findsOneWidget);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  testWidgets('the title opens a month picker with no fallback underline', (
    WidgetTester tester,
  ) async {
    await _pumpCalendar(tester);

    expect(find.byKey(calendarPickerKey), findsNothing);
    await _openPicker(tester);

    final TextStyle style = DefaultTextStyle.of(
      tester.element(find.text('Jan')),
    ).style;
    expect(style.decoration, isNot(TextDecoration.underline));
    expect(style.decorationStyle, isNot(TextDecorationStyle.double));
  });

  testWidgets('picking a month shows it and closes the picker', (
    WidgetTester tester,
  ) async {
    await _pumpCalendar(tester);
    await _openPicker(tester);

    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.byKey(calendarPickerKey), findsNothing);
  });

  testWidgets('the picker steps years and Back to this week returns', (
    WidgetTester tester,
  ) async {
    await _pumpCalendar(tester);
    await _openPicker(tester);

    await tester.tap(find.bySemanticsLabel('Next year'));
    await tester.pumpAndSettle();
    expect(find.text('2027'), findsOneWidget);

    await tester.tap(find.text('Jan'));
    await tester.pumpAndSettle();
    expect(find.text('January 2027'), findsOneWidget);
    expect(find.byKey(calendarPickerKey), findsNothing);

    await _openPicker(tester);
    await tester.tap(find.text('Back to this week'));
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.byKey(calendarPickerKey), findsNothing);
  });

  testWidgets(
      'This week shows only away from the current month and returns '
      'to it', (WidgetTester tester) async {
    await _pumpCalendar(tester);

    expect(find.byKey(calendarThisWeekKey), findsNothing);

    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.byKey(calendarThisWeekKey), findsOneWidget);

    await tester.tap(find.byKey(calendarThisWeekKey));
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.byKey(calendarThisWeekKey), findsNothing);
  });

  testWidgets('the left and right arrow keys change the month', (
    WidgetTester tester,
  ) async {
    await _pumpCalendar(tester);

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('August 2026'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.text('June 2026'), findsOneWidget);
  });

  testWidgets('T returns to the current month', (WidgetTester tester) async {
    await _pumpCalendar(tester);

    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pump();
    expect(find.text('May 2026'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.keyT);

    expect(find.text('July 2026'), findsOneWidget);
  });

  testWidgets('Escape closes the picker', (WidgetTester tester) async {
    await _pumpCalendar(tester);
    await _openPicker(tester);

    await _press(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(calendarPickerKey), findsNothing);
  });
}
