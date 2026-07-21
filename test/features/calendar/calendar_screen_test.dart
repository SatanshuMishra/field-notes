import 'dart:async';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    retry: (int retryCount, Object error) => null,
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    ),
  );
}

Day _day(String date, {Mood? mood}) => Day(
      id: 'id-$date',
      date: date,
      mood: mood,
      createdAt: 0,
      updatedAt: 0,
    );

CalendarScreen _screen({
  void Function(String date)? onOpen,
}) {
  return CalendarScreen(
    initialMonth: const MonthRef(2026, 7),
    today: DateTime(2026, 7, 15),
    onOpenDay: (BuildContext context, {required String date}) async {
      onOpen?.call(date);
    },
  );
}

void main() {
  testWidgets('shows the loading message before the month arrives',
      (WidgetTester tester) async {
    final StreamController<List<Day>> controller =
        StreamController<List<Day>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _host(
        _screen(),
        overrides: <Override>[
          daysInMonthProvider(year: 2026, month: 7)
              .overrideWith((_) => controller.stream),
        ],
      ),
    );

    expect(find.text(calendarLoadingMessage), findsOneWidget);
    expect(find.text('July 2026'), findsOneWidget);
  });

  testWidgets('renders the grid with a flower for a mood day',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        _screen(),
        overrides: <Override>[
          daysInMonthProvider(year: 2026, month: 7).overrideWith(
            (_) => Stream<List<Day>>.value(
              <Day>[_day('2026-07-14', mood: Mood.happy)],
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(CalendarGrid), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('day-2026-07-14')), findsOneWidget);
  });

  testWidgets('tapping a day opens Day-detail with that date key',
      (WidgetTester tester) async {
    final List<String> opened = <String>[];
    await tester.pumpWidget(
      _host(
        _screen(onOpen: opened.add),
        overrides: <Override>[
          daysInMonthProvider(year: 2026, month: 7)
              .overrideWith((_) => Stream<List<Day>>.value(const <Day>[])),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('day-2026-07-15')));
    expect(opened, <String>['2026-07-15']);
  });

  testWidgets('next chevron advances to the following month',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        _screen(),
        overrides: <Override>[
          daysInMonthProvider(year: 2026, month: 7)
              .overrideWith((_) => Stream<List<Day>>.value(const <Day>[])),
          daysInMonthProvider(year: 2026, month: 8)
              .overrideWith((_) => Stream<List<Day>>.value(const <Day>[])),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('July 2026'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pump();

    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('July 2026'), findsNothing);
  });

  testWidgets('surfaces a friendly message on error',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        _screen(),
        overrides: <Override>[
          daysInMonthProvider(year: 2026, month: 7)
              .overrideWith((_) => Stream<List<Day>>.error(Exception('boom'))),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(EmptyStatePlaceholder), findsOneWidget);
    expect(find.text(calendarErrorMessage), findsOneWidget);
  });
}
