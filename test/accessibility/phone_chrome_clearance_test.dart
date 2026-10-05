import 'package:field_notes/app/app.dart' show AppTextScale;
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/search/search.dart';
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_day_view.dart';
import 'package:field_notes/features/search/search_entries_provider.dart';
import 'package:field_notes/features/search/search_field.dart';
import 'package:field_notes/features/search/search_providers.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:field_notes/features/today/today_mood_dock.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/support/app_shell_harness.dart' show FakeJournalRepository;
import '../features/day_detail/support/day_detail_harness.dart'
    show FakeMediaResolver;
import '../features/search/support/search_harness.dart' show dayOf, entryOf;
import '../features/settings/support/fake_settings_repository.dart';
import '../features/settings/support/recording_reminder_scheduler.dart';
import '../support/sync_overrides.dart';

const List<Size> _phones = <Size>[Size(384, 832), Size(412, 869)];
const double _statusBar = 34;
const double _gestureBar = 24;
const double _tolerance = 0.001;
const int _todayEntryCount = 12;
const int _searchDayCount = 24;
const String _query = 'peonies';

const String _today = '2026-09-25';

final DateTime _now = DateTime(2026, 9, 25, 9, 30);

final double _headerBottom = _statusBar + phoneHeaderBarHeight;

final Finder _headerGlass = find.byKey(
  const ValueKey<String>('phone-header-glass'),
);

String _todayEntryId(int index) => 'today-$index';

final List<Entry> _todayEntries = <Entry>[
  for (int index = 0; index < _todayEntryCount; index++)
    Entry(
      id: _todayEntryId(index),
      dayId: 'day-$_today',
      type: EntryType.text,
      textContent:
          'Log ${index + 1}: the harbour, the ferry and the peonies '
          'along the back fence.',
      createdAt: _now.add(Duration(minutes: index)).millisecondsSinceEpoch,
      updatedAt: 0,
    ),
];

String _searchDate(int day) => '2026-09-${day.toString().padLeft(2, '0')}';

List<Override> _overrides(AppSettings settings) => <Override>[
  journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
  settingsRepositoryProvider.overrideWithValue(
    FakeSettingsRepository(initial: settings),
  ),
  journaledDatesProvider.overrideWith(
    (Ref ref) => Stream<List<String>>.value(const <String>[]),
  ),
  reminderClockProvider.overrideWithValue(() => _now),
  reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
  spellCheckAvailabilityProvider.overrideWithValue(
    const AsyncValue<SpellCheckAvailability>.data(
      SpellCheckAvailability.available,
    ),
  ),
  todayClockProvider.overrideWithValue(() => _now),
  streakClockProvider.overrideWithValue(() => _now),
  dayForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<Day?>.value(dayOf(date, mood: Mood.calm)),
  ),
  entriesForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<List<Entry>>.value(_todayEntries),
  ),
  photosForEntryProvider.overrideWith(
    (Ref ref, String entryId) =>
        Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
  ),
  todayMediaResolverProvider.overrideWith(
    (Ref ref) async => FakeMediaResolver(),
  ),
  allDaysProvider.overrideWith(
    (Ref ref) => Stream<List<Day>>.value(<Day>[
      for (int day = 1; day <= _searchDayCount; day++)
        dayOf(_searchDate(day), mood: Mood.calm),
    ]),
  ),
  searchAllEntriesProvider.overrideWith(
    (Ref ref) => Stream<List<Entry>>.value(<Entry>[
      for (int day = 1; day <= _searchDayCount; day++)
        entryOf(
          dayId: 'day-${_searchDate(day)}',
          id: 'search-$day',
          textContent: 'The $_query opened by the fence on day $day',
          createdAt: DateTime(2026, 9, day, 9).millisecondsSinceEpoch,
        ),
    ]),
  ),
  ...syncOffOverrides(),
];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpPhone(
  WidgetTester tester,
  Size phone,
  ShellDestination selected,
  Widget body, {
  AppSettings settings = AppSettings.defaults,
}) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: ProviderScope(
        retry: (int retryCount, Object error) => null,
        overrides: _overrides(settings),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.android),
          builder: (BuildContext context, Widget? child) =>
              AppTextScale(child: child ?? const SizedBox.shrink()),
          home: BottomBarShell(
            destinations: ShellDestination.primary,
            selected: selected,
            onSelect: (ShellDestination destination) {},
            onCapture: () {},
            body: body,
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

ScrollPosition _positionAround(WidgetTester tester, Finder item) => tester
    .state<ScrollableState>(
      find.ancestor(of: item, matching: find.byType(Scrollable)).first,
    )
    .position;

Future<void> _scrollToEnd(WidgetTester tester, ScrollPosition position) async {
  double reached = -1;
  while (position.pixels != reached) {
    reached = position.maxScrollExtent;
    position.jumpTo(reached);
    await tester.pump();
  }
}

void _expectBetween(
  WidgetTester tester,
  String what,
  Rect item, {
  required double top,
  required double bottom,
}) {
  expect(
    item.top,
    greaterThanOrEqualTo(top - _tolerance),
    reason: '$what starts at ${item.top}, above the header bottom $top',
  );
  expect(
    item.bottom,
    lessThanOrEqualTo(bottom + _tolerance),
    reason: '$what ends at ${item.bottom}, under the chrome top $bottom',
  );
}

void _expectChromeAboveTabBar(WidgetTester tester, String what, Rect chrome) {
  final Rect bar = tester.getRect(find.byType(PhoneBottomBar));
  expect(
    chrome.bottom,
    lessThanOrEqualTo(bar.top + _tolerance),
    reason: '$what ends at ${chrome.bottom}, under the tab bar top ${bar.top}',
  );
}

void _expectHeaderMeasured(WidgetTester tester, String what) {
  expect(
    tester.getRect(_headerGlass).bottom,
    moreOrLessEquals(_headerBottom, epsilon: _tolerance),
    reason: '$what: the scrolled header glass ends at the header bottom',
  );
}

Finder _todayCard(int index) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is CompactLogCard && widget.entry.id == _todayEntryId(index),
  description: 'the card for Today log ${index + 1}',
);

Future<void> _checkToday(WidgetTester tester, Size phone) async {
  final String page = 'Today on $phone';
  await _pumpPhone(tester, phone, ShellDestination.today, const TodayScreen());
  _expectBetween(
    tester,
    '$page first item',
    tester.getRect(find.byType(TodayHeader)),
    top: _headerBottom,
    bottom: double.infinity,
  );
  _expectBetween(
    tester,
    '$page first log',
    tester.getRect(_todayCard(0)),
    top: _headerBottom,
    bottom: double.infinity,
  );
  final ScrollPosition position = _positionAround(
    tester,
    find.byType(TodayHeader),
  );
  expect(position.maxScrollExtent, greaterThan(0), reason: '$page overflows');
  await _scrollToEnd(tester, position);
  _expectHeaderMeasured(tester, page);
  final Rect moodCard = tester.getRect(find.byType(TodayMoodDock));
  _expectBetween(
    tester,
    '$page last log',
    tester.getRect(_todayCard(_todayEntryCount - 1)),
    top: _headerBottom,
    bottom: moodCard.top,
  );
  _expectChromeAboveTabBar(tester, '$page mood card', moodCard);
}

Future<void> _checkSearch(WidgetTester tester, Size phone) async {
  final String page = 'Search on $phone';
  await _pumpPhone(
    tester,
    phone,
    ShellDestination.search,
    const SearchScreen(),
  );
  await tester.enterText(find.byType(TextField), _query);
  await _settle(tester);
  final Rect field = tester.getRect(find.byType(SearchField));
  _expectBetween(
    tester,
    '$page first item',
    tester.getRect(find.text(searchPhoneEyebrow)),
    top: _headerBottom,
    bottom: field.top,
  );
  _expectBetween(
    tester,
    '$page first result',
    tester.getRect(find.byType(SearchDayTile).first),
    top: _headerBottom,
    bottom: double.infinity,
  );
  final List<SearchDayView> results = ProviderScope.containerOf(
    tester.element(find.byType(SearchScreen)),
  ).read(searchResultsProvider);
  expect(results, hasLength(_searchDayCount), reason: page);
  final ScrollPosition position = _positionAround(
    tester,
    find.byType(SearchDayTile).first,
  );
  expect(position.maxScrollExtent, greaterThan(0), reason: '$page overflows');
  await _scrollToEnd(tester, position);
  _expectHeaderMeasured(tester, page);
  final String lastDate = results.last.date;
  _expectBetween(
    tester,
    '$page last result',
    tester.getRect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is SearchDayTile && widget.view.date == lastDate,
        description: 'the result for $lastDate',
      ),
    ),
    top: _headerBottom,
    bottom: field.top,
  );
  _expectChromeAboveTabBar(tester, '$page search field', field);
}

final Finder _settingsRows = find.byWidgetPredicate(
  (Widget widget) => widget is SettingsFieldRow || widget is SyncActionRow,
  description: 'a settings row or a sync action row',
);

Future<void> _checkSettings(WidgetTester tester, Size phone) async {
  bool overflowed = false;
  for (final SettingsTab tab in SettingsTab.values) {
    final String page = 'Settings ${tab.label} in large text on $phone';
    await _pumpPhone(
      tester,
      phone,
      ShellDestination.settings,
      const SettingsScreen(),
      settings: AppSettings.defaults.copyWith(textSize: TextSize.large),
    );
    await tester.tap(find.byKey(settingsTabKey(tab)));
    await _settle(tester);
    final Rect segments = tester.getRect(find.byKey(settingsTabChipsKey));
    _expectBetween(
      tester,
      '$page first item',
      tester.getRect(find.text('preferences')),
      top: _headerBottom,
      bottom: segments.top,
    );
    _expectBetween(
      tester,
      '$page first row',
      tester.getRect(_settingsRows.first),
      top: _headerBottom,
      bottom: double.infinity,
    );
    final ScrollPosition position = _positionAround(
      tester,
      find.byKey(settingsTabContentKey),
    );
    overflowed = overflowed || position.maxScrollExtent > 0;
    await _scrollToEnd(tester, position);
    _expectBetween(
      tester,
      '$page last row',
      tester.getRect(_settingsRows.last),
      top: _headerBottom,
      bottom: segments.top,
    );
    expect(
      tester.getRect(find.byKey(settingsTabContentKey)).bottom,
      lessThanOrEqualTo(segments.top + _tolerance),
      reason: '$page content ends under the segmented bar',
    );
    _expectChromeAboveTabBar(tester, '$page segmented bar', segments);
  }
  expect(overflowed, isTrue, reason: 'no Settings section overflows on $phone');
}

void main() {
  testWidgets(
    'the last Today entry, search result and settings row scroll clear of the floating chrome',
    (WidgetTester tester) async {
      for (final Size phone in _phones) {
        await _checkToday(tester, phone);
        await _checkSearch(tester, phone);
        await _checkSettings(tester, phone);
      }
    },
  );
}
