import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/today/this_week_garden.dart';
import 'package:field_notes/features/today/today_layout.dart';
import 'package:field_notes/features/today/today_memory.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

List<Override> _overrides() {
  return <Override>[
    todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 20)),
    weekStartProvider.overrideWithValue(WeekStart.sunday),
    allDaysProvider.overrideWith(
      (Ref ref) => Stream<List<Day>>.value(<Day>[
        todayTestDay(date: '2026-07-19', mood: Mood.calm),
      ]),
    ),
    dayForDateProvider.overrideWith(
      (Ref ref, String date) => Stream<Day?>.value(
        todayTestDay(date: date, mood: Mood.calm),
      ),
    ),
    entriesForDateProvider.overrideWith(
      (Ref ref, String date) => Stream<List<Entry>>.value(<Entry>[
        todayTestEntry(textContent: 'morning walk'),
      ]),
    ),
    entriesForDayProvider.overrideWith(
      (Ref ref, String dayId) => Stream<List<Entry>>.value(const <Entry>[]),
    ),
    photosForEntryProvider.overrideWith(
      (Ref ref, String entryId) =>
          Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
    ),
    todayMediaResolverProvider
        .overrideWith((Ref ref) async => const StubMediaResolver()),
    onThisDayMemoryProvider.overrideWith(
      (Ref ref) async => OnThisDayMemory(
        day: todayTestDay(id: 'day-2025', date: '2025-07-19', mood: Mood.happy),
        yearsAgo: 1,
      ),
    ),
    captureRoutesProvider.overrideWithValue(CaptureRouteRegistry.empty),
  ];
}

void main() {
  testWidgets('stacked layout shows greeting, date, mood banner and feed',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayScreen(layout: TodayLayout.stacked),
      overrides: _overrides(),
    );

    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.text('Feeling Calm today'), findsOneWidget);
    expect(find.text('change'), findsOneWidget);
    expect(find.text('morning walk'), findsOneWidget);

    expect(find.byType(ThisWeekGarden), findsNothing);
    expect(find.text('Quick capture'), findsNothing);
    expect(find.text('On this day'), findsNothing);
  });

  testWidgets('rail layout adds this-week garden, capture buttons and memory',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayScreen(layout: TodayLayout.withRail),
      overrides: _overrides(),
      surface: todayDesktopSurface,
    );

    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('morning walk'), findsOneWidget);

    expect(find.byType(ThisWeekGarden), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Quick capture'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('On this day'), findsOneWidget);
    expect(find.text('1 year ago'), findsOneWidget);
  });
}
