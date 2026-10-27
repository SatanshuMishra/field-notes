import 'dart:io';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdPhotoSize;
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/calendar_chevron_button.dart';
import 'package:field_notes/features/calendar/widgets/calendar_day_cell.dart';
import 'package:field_notes/features/calendar/widgets/calendar_month_picker.dart';
import 'package:field_notes/features/calendar/widgets/month_year_sheet.dart';
import 'package:field_notes/features/calendar/widgets/phone_flower_month.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_entries_provider.dart';
import 'package:field_notes/features/search/search_field.dart';
import 'package:field_notes/features/search/search_screen.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/today/today_entry_feed.dart';
import 'package:field_notes/features/today/today_mood_dock.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show shellOverrides;
import '../../features/entry_cards/support/entry_cards_harness.dart'
    show blobOf;
import '../../features/entry_cards/support/fake_audio_player.dart';
import '../../features/garden/support/garden_harness.dart' show dayOf;
import '../../features/notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, prefixOf;
import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/search/support/search_harness.dart' show entryOf;
import '../../features/today/support/today_harness.dart';
import '../../support/photo_line_fixture.dart';
import '../support/a11y_state.dart';

const String _today = '2026-09-25';
const String _voiceMediaId = 'voice-1';
const String _gardenEmptyMessage =
    'Your meadow is waiting. Every day you journal plants a bloom here.';
const String _searchEmptyMessage =
    'No days yet. Start journaling and your days appear here.';
const String _searchErrorMessage = 'Your days could not be loaded right now.';

final DateTime _now = DateTime(2026, 9, 25, 9, 30);
final int _nineThirty = _now.millisecondsSinceEpoch;

DateTime _clock() => _now;

final DateTime _skyNow = DateTime.utc(2026, 9, 25, 15, 30);

List<Override> _skyOverrides() => <Override>[
  skyClockProvider.overrideWithValue(() => _skyNow),
  skyLocationProvider.overrideWith(
    (Ref ref) async =>
        resolveSkyLocation('America/Edmonton', const Duration(hours: -6)),
  ),
];

bool _isTab(Widget widget) => switch (widget.key) {
  ValueKey<String>(:final String value) => value.startsWith('tab-'),
  _ => false,
};

final List<A11yStatefulControl> _tabs = <A11yStatefulControl>[
  A11yStatefulControl.finder(
    find.byWidgetPredicate(_isTab),
    A11yStateKind.selected,
    count: 4,
  ),
];

bool _isRailItem(Widget widget) => switch (widget.key) {
  ValueKey<String>(:final String value) => value.startsWith('rail-'),
  _ => false,
};

final List<A11yStatefulControl> _railItems = <A11yStatefulControl>[
  A11yStatefulControl.finder(
    find.byWidgetPredicate(_isRailItem),
    A11yStateKind.selected,
    count: 4,
  ),
];

final Set<String> _monthLabels = <String>{
  for (int month = 1; month <= 12; month++) monthAbbreviation(month),
};

Finder _monthCellsIn(Type picker) => find.descendant(
  of: find.byType(picker),
  matching: find.byWidgetPredicate(
    (Widget widget) => widget is Text && _monthLabels.contains(widget.data),
  ),
);

final Finder _headerStreakPill = find.byWidgetPredicate(
  (Widget widget) =>
      widget is StreakPill && widget.form == StreakPillForm.header,
  description: 'the header streak pill',
);

final Finder _sceneStreakPill = find.byWidgetPredicate(
  (Widget widget) =>
      widget is StreakPill && widget.form == StreakPillForm.headerOverScene,
  description: 'the header streak pill over the Meadow',
);

final Finder _sceneTabBar = find.byWidgetPredicate(
  (Widget widget) => widget is PhoneBottomBar && widget.overScene,
  description: 'the floating tab bar over the Meadow',
);

final Finder _phoneSearchField = find.byWidgetPredicate(
  (Widget widget) =>
      widget is SearchField && widget.variant == SearchFieldVariant.phone,
  description: 'the phone search field',
);

final Finder _desktopSearchField = find.byWidgetPredicate(
  (Widget widget) =>
      widget is SearchField && widget.variant == SearchFieldVariant.standard,
  description: 'the desktop search field',
);

final List<Day> _septemberDays = <Day>[
  dayOf('2026-09-07', mood: Mood.calm),
  dayOf('2026-09-14', mood: Mood.happy),
  dayOf('2026-09-21'),
  dayOf('2026-09-24', mood: Mood.grateful),
];

const List<String> _journaledDates = <String>[
  '2026-09-07',
  '2026-09-14',
  '2026-09-21',
  '2026-09-24',
];

Entry _atNineThirty(Entry entry) => Entry(
  id: entry.id,
  dayId: entry.dayId,
  type: entry.type,
  textContent: entry.textContent,
  mediaId: entry.mediaId,
  thumbnailMediaId: entry.thumbnailMediaId,
  durationMs: entry.durationMs,
  createdAt: _nineThirty,
  updatedAt: _nineThirty,
);

final List<Entry> _feedEntries = <Entry>[
  todayTestEntry(
    id: 'entry-1',
    textContent:
        'morning walk\n${mdPhotoLine(photoIdA, size: MdPhotoSize.small)}',
  ),
  todayTestEntry(
    id: 'entry-2',
    textContent: '- [ ] water the peonies\n- [x] buy seed packets',
  ),
  todayTestEntry(
    id: 'entry-3',
    textContent:
        'The peonies finally opened along the back fence. I stood there '
        'with my coffee for a long while and watched the bees work the '
        'blooms, then walked the long way round to the harbour to see the '
        'ferry come in under a low grey sky that never quite broke into rain.',
  ),
  todayTestEntry(
    id: 'entry-4',
    type: EntryType.voice,
    textContent: null,
    mediaId: _voiceMediaId,
    durationMs: 42000,
  ),
  todayTestEntry(
    id: 'entry-5',
    type: EntryType.video,
    textContent: null,
    mediaId: 'vid',
    durationMs: 4000,
  ),
].map(_atNineThirty).toList(growable: false);

MediaResolver _feedResolver() => FakeNoteMediaResolver(<String, ResolvedMedia>{
  prefixOf(photoIdA): availablePhoto(photoIdA),
  _voiceMediaId: ResolvedMedia.available(
    blob: blobOf(
      id: _voiceMediaId,
      relPath: '$_voiceMediaId.m4a',
      kind: MediaKind.audio,
    ),
    file: File(
      '${Directory.systemTemp.path}/field-notes-absent/$_voiceMediaId.m4a',
    ),
  ),
});

List<Override> _shellStateOverrides() => <Override>[
  ...shellOverrides(),
  todayClockProvider.overrideWithValue(_clock),
  streakClockProvider.overrideWithValue(_clock),
  ..._skyOverrides(),
];

List<Override> _feedOverrides() => <Override>[
  entriesForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<List<Entry>>.value(_feedEntries),
  ),
  photosForEntryProvider.overrideWith(
    (Ref ref, String entryId) =>
        Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
  ),
  todayMediaResolverProvider.overrideWith((Ref ref) async => _feedResolver()),
  todayAudioPlayerFactoryProvider.overrideWithValue(FakeEntryAudioPlayer.new),
];

List<Override> _calendarOverrides() => <Override>[
  weekStartProvider.overrideWithValue(WeekStart.sunday),
  journaledDatesProvider.overrideWith(
    (Ref ref) => Stream<List<String>>.value(_journaledDates),
  ),
  daysInMonthProvider.overrideWith(
    (Ref ref, ({int year, int month}) args) =>
        Stream<List<Day>>.value(_septemberDays),
  ),
];

List<Override> _emptyCalendarOverrides() => <Override>[
  weekStartProvider.overrideWithValue(WeekStart.sunday),
  journaledDatesProvider.overrideWith(
    (Ref ref) => Stream<List<String>>.value(const <String>[]),
  ),
  daysInMonthProvider.overrideWith(
    (Ref ref, ({int year, int month}) args) =>
        Stream<List<Day>>.value(const <Day>[]),
  ),
];

final Set<Object?> _journalProviders = <Object?>{
  journaledDatesProvider,
  journalEntryCountsProvider,
};

List<Override> _emptyShellOverrides() => <Override>[
  for (final Override override in _shellStateOverrides())
    if (!_journalProviders.contains(override.origin)) override,
  journaledDatesProvider.overrideWith(
    (Ref ref) => Stream<List<String>>.value(const <String>[]),
  ),
  journalEntryCountsProvider.overrideWith(
    (Ref ref) => Stream<Map<String, int>>.value(const <String, int>{}),
  ),
  allDaysProvider.overrideWith(
    (Ref ref) => Stream<List<Day>>.value(const <Day>[]),
  ),
];

List<Override> _gardenOverrides({
  required List<Day> days,
  required List<String> journaled,
}) => <Override>[
  journaledDatesProvider.overrideWith(
    (Ref ref) => Stream<List<String>>.value(journaled),
  ),
  journalEntryCountsProvider.overrideWith(
    (Ref ref) => Stream<Map<String, int>>.value(<String, int>{
      for (final String date in journaled) date: 1,
    }),
  ),
  settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
  allDaysProvider.overrideWith((Ref ref) => Stream<List<Day>>.value(days)),
  ..._skyOverrides(),
];

List<Override> _searchOverrides() => <Override>[
  allDaysProvider.overrideWith(
    (Ref ref) => Stream<List<Day>>.value(<Day>[
      dayOf('2026-09-24', mood: Mood.grateful),
      dayOf('2026-09-23', mood: Mood.calm),
    ]),
  ),
  searchAllEntriesProvider.overrideWith(
    (Ref ref) => Stream<List<Entry>>.value(<Entry>[
      entryOf(
        dayId: 'id-2026-09-24',
        id: 'entry-1',
        textContent: 'The peonies opened by the fence',
        createdAt: _nineThirty,
      ),
      entryOf(
        dayId: 'id-2026-09-23',
        id: 'entry-2',
        textContent: 'Rain over the harbour',
        createdAt: _nineThirty,
      ),
    ]),
  ),
];

Future<void> _pumpApp(
  WidgetTester tester,
  A11yVariant variant,
  Widget home, {
  required List<Override> overrides,
  A11yWindow? window,
}) async {
  variant.useWindow(tester, window);
  await tester.pumpWidget(
    ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: variant.theme,
        builder: variant.scaleText,
        home: home,
      ),
    ),
  );
}

Future<void> _pumpShell(WidgetTester tester, A11yVariant variant) async {
  await _pumpApp(
    tester,
    variant,
    const AppShell(),
    overrides: _shellStateOverrides(),
  );
  await tester.pump();
}

Future<void> _pumpFeed(WidgetTester tester, A11yVariant variant) async {
  await _pumpApp(
    tester,
    variant,
    const Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.all(20),
              sliver: TodayEntryFeed(date: _today),
            ),
          ],
        ),
      ),
    ),
    overrides: _feedOverrides(),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCalendar(WidgetTester tester, A11yVariant variant) async {
  await _pumpApp(
    tester,
    variant,
    Scaffold(body: CalendarScreen(today: _now)),
    overrides: _calendarOverrides(),
  );
  await tester.pump();
}

Future<void> pumpMacCalendar(WidgetTester tester) async {
  await _pumpApp(
    tester,
    const A11yVariant(platform: TargetPlatform.macOS),
    Scaffold(body: CalendarScreen(today: _now)),
    overrides: _calendarOverrides(),
    window: a11yPhoneWindow,
  );
  await tester.pump();
}

bool _meadowReady(WidgetTester tester) {
  final Finder stage = find.byType(MeadowStage);
  return stage.evaluate().isNotEmpty &&
      tester.state<MeadowStageState>(stage).debugIsReady;
}

Future<void> _waitForMeadow(WidgetTester tester) async {
  for (int i = 0; i < 6000 && !_meadowReady(tester); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Future<void> _pumpGarden(
  WidgetTester tester,
  A11yVariant variant, {
  required List<Day> days,
  required List<String> journaled,
}) async {
  await _pumpApp(
    tester,
    variant,
    const Scaffold(body: GardenScreen()),
    overrides: _gardenOverrides(days: days, journaled: journaled),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpEmptyShell(WidgetTester tester, A11yVariant variant) async {
  await _pumpApp(
    tester,
    variant,
    const AppShell(),
    overrides: _emptyShellOverrides(),
  );
  await tester.pump();
}

Future<void> _pumpEmptyCalendar(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _pumpApp(
    tester,
    variant,
    Scaffold(body: CalendarScreen(today: _now)),
    overrides: _emptyCalendarOverrides(),
  );
  await tester.pump();
}

Future<void> _pumpSearchOf(
  WidgetTester tester,
  A11yVariant variant, {
  required Stream<List<Day>> Function() days,
}) async {
  await _pumpApp(
    tester,
    variant,
    const Scaffold(body: SearchScreen()),
    overrides: <Override>[
      allDaysProvider.overrideWith((Ref ref) => days()),
      searchAllEntriesProvider.overrideWith(
        (Ref ref) => Stream<List<Entry>>.value(const <Entry>[]),
      ),
    ],
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpSearch(WidgetTester tester, A11yVariant variant) async {
  await _pumpApp(
    tester,
    variant,
    const Scaffold(body: SearchScreen()),
    overrides: _searchOverrides(),
  );
  await tester.pump();
}

A11yPumpBody _searchFor(String query) =>
    (WidgetTester tester, A11yVariant variant) async {
      await _pumpSearch(tester, variant);
      await tester.enterText(find.byType(TextField), query);
      await tester.pump();
    };

final Finder _revealedPill = find.descendant(
  of: find.byKey(logActionsPillKey),
  matching: find.byElementPredicate(
    (Element element) =>
        element is RenderObjectElement &&
        element.renderObject.debugSemantics?.label == logActionsDeleteLabel,
    description: 'a revealed "$logActionsDeleteLabel" button',
  ),
);

final Finder _journaledCell = find.descendant(
  of: find.byKey(const ValueKey<String>('day-2026-09-21')),
  matching: find.byKey(phoneMonthDotKey),
);

final Finder _todayCell = find.descendant(
  of: find.byKey(const ValueKey<String>('day-$_today')),
  matching: find.byKey(phoneMonthTodayPillKey),
);

final Finder _desktopJournaledCell = find.descendant(
  of: find.byKey(const ValueKey<String>('day-2026-09-21')),
  matching: find.byKey(calendarActivityDotKey),
);

final Finder _desktopTodayCell = find.byWidgetPredicate(
  (Widget widget) =>
      widget is CalendarDayCell &&
      widget.isToday &&
      widget.key == const ValueKey<String>('day-$_today'),
  description: 'the desktop calendar cell for today',
);

final Finder _nextMonthChevron = find.byWidgetPredicate(
  (Widget widget) =>
      widget is CalendarChevronButton &&
      widget.direction == ChevronDirection.next,
  description: 'the next month chevron',
);

Future<void> _pumpCalendarPicker(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _pumpCalendar(tester, variant);
  await tester.tap(
    find.byKey(variant.desktop ? calendarTitleKey : phoneMonthPickerButtonKey),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCalendarNextMonth(
  WidgetTester tester,
  A11yVariant variant,
) async {
  await _pumpCalendar(tester, variant);
  await tester.tap(
    variant.desktop ? _nextMonthChevron : find.byKey(phoneMonthNextKey),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpGardenTab(WidgetTester tester, A11yVariant variant) async {
  await _pumpShell(tester, variant);
  await tester.tap(
    find.byKey(
      ValueKey<String>(variant.desktop ? 'rail-garden' : 'tab-garden'),
    ),
  );
  await tester.pump();
  await _waitForMeadow(tester);
}

final A11yPumpBody _searchResults = _searchFor('peonies');

final A11yPumpBody _searchNoMatch = _searchFor('zzz');

final List<A11yState> shellStates = <A11yState>[
  A11yState(
    id: 'a1-today-empty',
    platforms: const <TargetPlatform>{TargetPlatform.android},
    pump: _pumpShell,
    proof: <A11yProof>[
      A11yProof(find.byKey(const ValueKey<String>('capture-button'))),
      A11yProof(find.byType(PhoneBottomBar)),
      A11yProof(_headerStreakPill),
      A11yProof(find.text(todayMoodDockChooseLabel)),
    ],
    stateful: _tabs,
  ),
  A11yState(
    id: 'a2-today-feed',
    pump: _pumpFeed,
    proof: <A11yProof>[A11yProof(find.byType(CompactLogCard), count: 4)],
  ),
  A11yState(
    id: 'a3-card-actions',
    pump: (WidgetTester tester, A11yVariant variant) async {
      await _pumpFeed(tester, variant);
      await tester.longPress(find.byType(CompactLogCard).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    },
    proof: <A11yProof>[A11yProof(_revealedPill)],
  ),
  ...a11yInBothLayouts(
    id: 'a4-calendar-month',
    desktopId: 'a4-calendar-month-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpCalendar,
      proof: <A11yProof>[
        A11yProof(find.byType(PhoneFlowerMonth)),
        A11yProof(_journaledCell),
        A11yProof(_todayCell),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpCalendar,
      proof: <A11yProof>[
        A11yProof(find.byType(CalendarGrid)),
        A11yProof(_desktopJournaledCell),
        A11yProof(_desktopTodayCell),
      ],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'a5-calendar-picker',
    desktopId: 'a5-calendar-picker-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpCalendarPicker,
      proof: <A11yProof>[
        A11yProof(
          find.descendant(
            of: find.byType(PhoneSheet),
            matching: find.byType(MonthYearSheet),
          ),
        ),
        A11yProof(find.byKey(monthYearBackKey)),
      ],
      stateful: <A11yStatefulControl>[
        A11yStatefulControl.finder(
          _monthCellsIn(MonthYearSheet),
          A11yStateKind.selected,
        ),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpCalendarPicker,
      proof: <A11yProof>[
        A11yProof(find.byKey(calendarPickerKey)),
        A11yProof(find.text('Back to this week')),
      ],
      stateful: <A11yStatefulControl>[
        A11yStatefulControl.finder(
          _monthCellsIn(CalendarMonthPicker),
          A11yStateKind.selected,
        ),
      ],
    ),
  ),
  A11yState(
    id: 'a6-garden-empty',
    pump: (WidgetTester tester, A11yVariant variant) async {
      await _pumpGarden(
        tester,
        variant,
        days: const <Day>[],
        journaled: const <String>[],
      );
      await _waitForMeadow(tester);
    },
    proof: <A11yProof>[A11yProof(find.text(_gardenEmptyMessage))],
  ),
  A11yState(
    id: 'a7-garden-blooms',
    pump: (WidgetTester tester, A11yVariant variant) async {
      await _pumpGarden(
        tester,
        variant,
        days: <Day>[
          dayOf('2026-09-23'),
          dayOf('2026-09-24', mood: Mood.grateful),
        ],
        journaled: const <String>['2026-09-23', '2026-09-24'],
      );
      await _waitForMeadow(tester);
    },
    proof: <A11yProof>[
      A11yProof(find.byType(MeadowStage)),
      A11yProof(find.byKey(meadowTimeButtonKey)),
      A11yProof(find.byKey(meadowDetailsButtonKey)),
    ],
  ),
  ...a11yInBothLayouts(
    id: 'a8-garden-phone',
    desktopId: 'a8-garden-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpGardenTab,
      proof: <A11yProof>[A11yProof(_sceneStreakPill), A11yProof(_sceneTabBar)],
      stateful: _tabs,
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpGardenTab,
      proof: <A11yProof>[
        A11yProof(find.byKey(sidebarRailKey)),
        A11yProof(find.byType(MeadowStage)),
      ],
      stateful: _railItems,
    ),
  ),
  ...a11yInBothLayouts(
    id: 'a9-search-results',
    desktopId: 'a9-search-results-sidebar',
    phone: A11yLayoutHalf(
      pump: _searchResults,
      proof: <A11yProof>[
        A11yProof(find.byType(SearchDayTile)),
        A11yProof(_phoneSearchField),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _searchResults,
      proof: <A11yProof>[
        A11yProof(find.byType(SearchDayTile)),
        A11yProof(_desktopSearchField),
      ],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'a10-search-no-match',
    desktopId: 'a10-search-no-match-sidebar',
    phone: A11yLayoutHalf(
      pump: _searchNoMatch,
      proof: <A11yProof>[
        A11yProof(find.textContaining('No days match')),
        A11yProof(_phoneSearchField),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _searchNoMatch,
      proof: <A11yProof>[
        A11yProof(find.textContaining('No days match')),
        A11yProof(_desktopSearchField),
      ],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'a11-calendar-next-month',
    desktopId: 'a11-calendar-next-month-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpCalendarNextMonth,
      proof: <A11yProof>[
        A11yProof(find.byType(PhoneFlowerMonth)),
        A11yProof(find.byKey(phoneThisMonthKey)),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpCalendarNextMonth,
      proof: <A11yProof>[
        A11yProof(find.byType(CalendarGrid)),
        A11yProof(find.byKey(calendarThisWeekKey)),
      ],
    ),
  ),
  A11yState(
    id: 'a12-calendar-empty',
    pump: _pumpEmptyCalendar,
    proof: <A11yProof>[
      A11yProof(find.byType(CalendarScreen)),
      A11yProof(find.text('September 2026')),
    ],
  ),
  A11yState(
    id: 'a13-search-empty',
    pump: (WidgetTester tester, A11yVariant variant) => _pumpSearchOf(
      tester,
      variant,
      days: () => Stream<List<Day>>.value(const <Day>[]),
    ),
    proof: <A11yProof>[
      A11yProof(find.byType(SearchField)),
      A11yProof(find.text(_searchEmptyMessage)),
    ],
  ),
  A11yState(
    id: 'a14-meadow-empty',
    platforms: const <TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.windows,
    },
    pump: (WidgetTester tester, A11yVariant variant) async {
      await _pumpEmptyShell(tester, variant);
      await tester.tap(find.byKey(const ValueKey<String>('rail-garden')));
      await tester.pump();
      await _waitForMeadow(tester);
    },
    proof: <A11yProof>[
      A11yProof(find.byKey(sidebarRailKey)),
      A11yProof(find.text(_gardenEmptyMessage)),
    ],
  ),
  A11yState(
    id: 'a15-today-empty-sidebar',
    platforms: const <TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.windows,
    },
    pump: _pumpEmptyShell,
    proof: <A11yProof>[
      A11yProof(find.byKey(sidebarRailKey)),
      A11yProof(find.byType(TodayScreen)),
    ],
  ),
  A11yState(
    id: 'a16-search-error',
    pump: (WidgetTester tester, A11yVariant variant) => _pumpSearchOf(
      tester,
      variant,
      days: () => Stream<List<Day>>.error(
        const FileSystemException('journal unreadable'),
      ),
    ),
    proof: <A11yProof>[
      A11yProof(find.byType(SearchField)),
      A11yProof(find.text(_searchErrorMessage)),
    ],
  ),
];
