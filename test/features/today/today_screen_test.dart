import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/today/this_week_garden.dart';
import 'package:field_notes/features/today/today_layout.dart';
import 'package:field_notes/features/today/today_memory.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

CaptureRouteRegistry _allCaptureRoutes() {
  return captureOptions.fold(
    CaptureRouteRegistry.empty,
    (CaptureRouteRegistry registry, CaptureOption option) => registry.withRoute(
      CaptureRoute(
        type: option.type,
        open: (BuildContext context, String date) async => null,
      ),
    ),
  );
}

List<Override> _overrides({List<Entry>? entries}) {
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
      (Ref ref, String date) => Stream<List<Entry>>.value(
        entries ??
            <Entry>[
              todayTestEntry(textContent: 'morning walk'),
            ],
      ),
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
    captureRoutesProvider.overrideWithValue(_allCaptureRoutes()),
  ];
}

List<Override> _manyEntries(int count) {
  return _overrides(
    entries: <Entry>[
      for (int i = 0; i < count; i++)
        todayTestEntry(id: 'entry-$i', textContent: 'log number $i'),
    ],
  );
}

CustomScrollView _feedScrollView(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView).first);

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
    expect(find.text('capture a moment'), findsNothing);
    expect(find.text('on this day'), findsNothing);
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
    expect(find.text("this week's garden"), findsOneWidget);
    expect(find.text('capture a moment'), findsOneWidget);
    expect(find.text('Capture'), findsNothing);
    expect(find.text('Write a note'), findsOneWidget);
    expect(find.text('Record voice'), findsOneWidget);
    expect(find.text('Record video'), findsOneWidget);
    expect(find.text('on this day'), findsOneWidget);
    expect(find.text('memory · 1 year ago'), findsOneWidget);
  });

  testWidgets('the stacked layout scrolls as a cached CustomScrollView',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayScreen(layout: TodayLayout.stacked),
      overrides: _overrides(),
    );

    final ScrollCacheExtent? cache = _feedScrollView(tester).scrollCacheExtent;
    expect(cache, isNotNull);
    expect(cache!.value, greaterThan(0));
    expect(cache, const ScrollCacheExtent.pixels(todayFeedCacheExtent));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rail layout scrolls as a cached CustomScrollView',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      const TodayScreen(layout: TodayLayout.withRail),
      overrides: _overrides(),
      surface: todayDesktopSurface,
    );

    final ScrollCacheExtent? cache = _feedScrollView(tester).scrollCacheExtent;
    expect(cache, isNotNull);
    expect(cache!.value, greaterThan(0));
    expect(cache, const ScrollCacheExtent.pixels(todayFeedCacheExtent));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 50-entry day builds only the cards near the viewport',
      (WidgetTester tester) async {
    const int entryCount = 50;

    for (final TodayLayout layout in TodayLayout.values) {
      await pumpToday(
        tester,
        TodayScreen(layout: layout),
        overrides: _manyEntries(entryCount),
        surface: layout == TodayLayout.withRail
            ? todayDesktopSurface
            : todayPhoneSurface,
      );

      expect(tester.takeException(), isNull);
      final int built = find.byType(EntryCard).evaluate().length;
      expect(built, greaterThan(0), reason: '$layout built nothing');
      expect(built, lessThan(entryCount), reason: '$layout built every card');
    }
  });
}
