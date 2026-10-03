import 'dart:async';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/calendar_weekday_bar.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    retry: (int retryCount, Object error) => null,
    overrides: <Override>[
      weekStartProvider.overrideWithValue(WeekStart.saturday),
      journaledDatesProvider.overrideWith(
        (Ref ref) => Stream<List<String>>.value(const <String>[]),
      ),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets(
    "a Saturday week start puts Saturday in the calendar's first column",
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          CalendarScreen(
            initialMonth: const MonthRef(2026, 7),
            today: DateTime(2026, 7, 15),
            onOpenDay: (BuildContext context, {required String date}) async {},
          ),
          overrides: <Override>[
            daysInMonthProvider(
              year: 2026,
              month: 7,
            ).overrideWith((_) => Stream<List<Day>>.value(const <Day>[])),
          ],
        ),
      );
      await tester.pump();

      final List<Text> headerTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(CalendarWeekdayBar),
              matching: find.byType(Text),
            ),
          )
          .toList();
      final String firstHeaderLabel = headerTexts.first.semanticsLabel!;

      expect(
        firstHeaderLabel,
        weekdayNames(firstWeekday: DateTime.saturday).first,
      );
      expect(
        headerTexts.first.data,
        weekdayHeaders(firstWeekday: DateTime.saturday).first,
      );
    },
  );
}
