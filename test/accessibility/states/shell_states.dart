import 'dart:io';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdPhotoSize;
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/calendar_day_cell.dart';
import 'package:field_notes/features/calendar/widgets/calendar_month_picker.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/search/search_day_tile.dart';
import 'package:field_notes/features/search/search_entries_provider.dart';
import 'package:field_notes/features/search/search_screen.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:field_notes/features/today/today_entry_feed.dart';
import 'package:field_notes/features/today/today_providers.dart';
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
import '../../features/search/support/search_harness.dart' show entryOf;
import '../../features/today/support/today_harness.dart';
import '../../support/photo_line_fixture.dart';
import '../support/a11y_state.dart';

const Size _noteTenPlusSize = Size(1080, 2280);
const double _noteTenPlusRatio = 2.625;

const String _today = '2026-09-25';
const String _voiceMediaId = 'voice-1';
const String _gardenEmptyMessage =
    'Your meadow is waiting. Every day you journal plants a bloom here.';

final DateTime _now = DateTime(2026, 9, 25, 9, 30);
final int _nineThirty = _now.millisecondsSinceEpoch;

DateTime _clock() => _now;

bool _isTab(Widget widget) => switch (widget.key) {
  ValueKey<String>(:final String value) => value.startsWith('tab-'),
  _ => false,
};

final List<A11yStatefulControl> _tabs = <A11yStatefulControl>[
  A11yStatefulControl.finder(
    find.byWidgetPredicate(_isTab),
    A11yStateKind.selected,
  ),
];

final Set<String> _monthLabels = <String>{
  for (int month = 1; month <= 12; month++) monthAbbreviation(month),
};

final Finder _monthCells = find.descendant(
  of: find.byType(CalendarMonthPicker),
  matching: find.byWidgetPredicate(
    (Widget widget) => widget is Text && _monthLabels.contains(widget.data),
  ),
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

List<Override> _gardenOverrides({
  required List<Day> days,
  required List<String> journaled,
}) => <Override>[
  journaledDatesProvider.overrideWith(
    (Ref ref) => Stream<List<String>>.value(journaled),
  ),
  allDaysProvider.overrideWith((Ref ref) => Stream<List<Day>>.value(days)),
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
  Widget home, {
  required List<Override> overrides,
}) async {
  tester.view.physicalSize = _noteTenPlusSize;
  tester.view.devicePixelRatio = _noteTenPlusRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: home,
      ),
    ),
  );
}

Future<void> _pumpShell(WidgetTester tester) async {
  await _pumpApp(tester, const AppShell(), overrides: _shellStateOverrides());
  await tester.pump();
}

Future<void> _pumpFeed(WidgetTester tester) async {
  await _pumpApp(
    tester,
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

Future<void> _pumpCalendar(WidgetTester tester) async {
  await _pumpApp(
    tester,
    Scaffold(body: CalendarScreen(today: _now)),
    overrides: _calendarOverrides(),
  );
  await tester.pump();
}

Future<void> _pumpGarden(
  WidgetTester tester, {
  required List<Day> days,
  required List<String> journaled,
}) async {
  await _pumpApp(
    tester,
    const Scaffold(body: GardenScreen(year: 2026)),
    overrides: _gardenOverrides(days: days, journaled: journaled),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpSearch(WidgetTester tester, String query) async {
  await _pumpApp(
    tester,
    const Scaffold(body: SearchScreen()),
    overrides: _searchOverrides(),
  );
  await tester.pump();
  await tester.enterText(find.byType(TextField), query);
  await tester.pump();
}

final Finder _revealedPill = find.descendant(
  of: find.byKey(logActionsPillKey),
  matching: find.byElementPredicate(
    (Element element) =>
        element is RenderObjectElement &&
        element.renderObject.debugSemantics?.label == logActionsDeleteLabel,
    description: 'a revealed "$logActionsDeleteLabel" button',
  ),
);

final Finder _journaledCell = find.byWidgetPredicate(
  (Widget widget) =>
      widget is CalendarDayCell &&
      widget.key == const ValueKey<String>('day-2026-09-14') &&
      widget.hasEntries,
);

final List<A11yState> shellStates = <A11yState>[
  A11yState(
    id: 'a1-today-empty',
    pump: _pumpShell,
    proof: <A11yProof>[
      A11yProof(find.byKey(const ValueKey<String>('capture-button'))),
    ],
    stateful: _tabs,
  ),
  A11yState(
    id: 'a2-today-feed',
    pump: _pumpFeed,
    proof: <A11yProof>[A11yProof(find.byType(CompactLogCard), count: 5)],
  ),
  A11yState(
    id: 'a3-card-actions',
    pump: (WidgetTester tester) async {
      await _pumpFeed(tester);
      await tester.longPress(find.byType(CompactLogCard).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    },
    proof: <A11yProof>[A11yProof(_revealedPill)],
  ),
  A11yState(
    id: 'a4-calendar-month',
    pump: _pumpCalendar,
    proof: <A11yProof>[
      A11yProof(find.byType(CalendarScreen)),
      A11yProof(_journaledCell),
    ],
  ),
  A11yState(
    id: 'a5-calendar-picker',
    pump: (WidgetTester tester) async {
      await _pumpCalendar(tester);
      await tester.tap(find.byKey(calendarTitleKey));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[A11yProof(find.byType(CalendarMonthPicker))],
    stateful: <A11yStatefulControl>[
      A11yStatefulControl.finder(_monthCells, A11yStateKind.selected),
    ],
  ),
  A11yState(
    id: 'a6-garden-empty',
    pump: (WidgetTester tester) =>
        _pumpGarden(tester, days: const <Day>[], journaled: const <String>[]),
    proof: <A11yProof>[A11yProof(find.text(_gardenEmptyMessage))],
  ),
  A11yState(
    id: 'a7-garden-blooms',
    pump: (WidgetTester tester) => _pumpGarden(
      tester,
      days: <Day>[
        dayOf('2026-09-23'),
        dayOf('2026-09-24', mood: Mood.grateful),
      ],
      journaled: const <String>['2026-09-23', '2026-09-24'],
    ),
    proof: <A11yProof>[A11yProof(find.byType(MoodTallyChips))],
  ),
  A11yState(
    id: 'a8-garden-phone',
    pump: (WidgetTester tester) async {
      await _pumpShell(tester);
      await tester.tap(find.byKey(const ValueKey<String>('tab-garden')));
      await tester.pump();
    },
    proof: <A11yProof>[
      A11yProof(find.byKey(const ValueKey<String>('streak-card'))),
    ],
    stateful: _tabs,
  ),
  A11yState(
    id: 'a9-search-results',
    pump: (WidgetTester tester) => _pumpSearch(tester, 'peonies'),
    proof: <A11yProof>[A11yProof(find.byType(SearchDayTile))],
  ),
  A11yState(
    id: 'a10-search-no-match',
    pump: (WidgetTester tester) => _pumpSearch(tester, 'zzz'),
    proof: <A11yProof>[A11yProof(find.textContaining('No days match'))],
  ),
  A11yState(
    id: 'a11-calendar-next-month',
    pump: (WidgetTester tester) async {
      await _pumpCalendar(tester);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[A11yProof(find.byType(CalendarScreen))],
  ),
];
