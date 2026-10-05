import 'dart:ui' as ui;

import 'package:field_notes/app/capture/app_capture_routes.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/phone_flower_month.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/search/search.dart';
import 'package:field_notes/features/search/search_entries_provider.dart';
import 'package:field_notes/features/search/search_field.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/spell_check_availability.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:field_notes/features/today/today_mood_dock.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app/support/app_shell_harness.dart' show FakeJournalRepository;
import '../features/capture/core/capture_test_support.dart'
    show FakeDraftStore, FakeNoteWriter;
import '../features/capture/photo/photo_test_support.dart' show FakePhotoPicker;
import '../features/day_detail/support/day_detail_harness.dart'
    show FakeMediaResolver;
import '../features/notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, FakeNoteMediaStore;
import '../features/search/support/search_harness.dart' show dayOf, entryOf;
import '../features/settings/support/fake_settings_repository.dart';
import '../features/settings/support/recording_reminder_scheduler.dart';
import '../features/sound/support/fake_sound_player.dart';
import '../support/sync_overrides.dart';

const Size _galaxyS24 = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _minimumTarget = 44;
const double _primaryHeight = 48;
const double _tolerance = 0.001;

const String _today = '2026-09-25';
const String _pastDay = '2026-09-21';

final DateTime _now = DateTime(2026, 9, 25, 9, 30);

final List<Entry> _todayEntries = <Entry>[
  for (int index = 0; index < 3; index++)
    Entry(
      id: 'today-$index',
      dayId: 'day-$_today',
      type: EntryType.text,
      textContent: 'The harbour at ${index + 8} o’clock, and the peonies.',
      createdAt: _now.add(Duration(minutes: index)).millisecondsSinceEpoch,
      updatedAt: 0,
    ),
];

List<Override> _overrides(Mood? mood) => <Override>[
  journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
  settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
  journaledDatesProvider.overrideWith(
    (Ref ref) => Stream<List<String>>.value(const <String>[_pastDay]),
  ),
  reminderClockProvider.overrideWithValue(() => _now),
  reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
  spellCheckAvailabilityProvider.overrideWithValue(
    const AsyncValue<SpellCheckAvailability>.data(
      SpellCheckAvailability.available,
    ),
  ),
  soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
  todayClockProvider.overrideWithValue(() => _now),
  streakClockProvider.overrideWithValue(() => _now),
  dayForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<Day?>.value(
      dayOf(date, mood: date == _today ? mood : Mood.happy),
    ),
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
  dayDetailMediaResolverProvider.overrideWith(
    (Ref ref) async => FakeMediaResolver(),
  ),
  notesMediaResolverProvider.overrideWith(
    (Ref ref) async => FakeNoteMediaResolver(const <String, ResolvedMedia>{}),
  ),
  draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
  noteWriterProvider.overrideWith((Ref ref) async => FakeNoteWriter()),
  mediaStoreProvider.overrideWith((Ref ref) async => FakeNoteMediaStore()),
  notePhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
  captureRoutesProvider.overrideWithValue(appCaptureRoutes),
  daysInMonthProvider.overrideWith(
    (Ref ref, ({int year, int month}) month) =>
        Stream<List<Day>>.value(<Day>[dayOf('2026-09-14', mood: Mood.happy)]),
  ),
  allDaysProvider.overrideWith(
    (Ref ref) => Stream<List<Day>>.value(<Day>[
      dayOf('2026-09-24', mood: Mood.grateful),
      dayOf('2026-09-23', mood: Mood.calm),
    ]),
  ),
  searchAllEntriesProvider.overrideWith(
    (Ref ref) => Stream<List<Entry>>.value(<Entry>[
      entryOf(
        dayId: 'day-2026-09-24',
        id: 'search-1',
        textContent: 'The peonies opened by the fence',
        createdAt: DateTime(2026, 9, 24, 9).millisecondsSinceEpoch,
      ),
      entryOf(
        dayId: 'day-2026-09-23',
        id: 'search-2',
        textContent: 'Rain over the peonies and the harbour',
        createdAt: DateTime(2026, 9, 23, 9).millisecondsSinceEpoch,
      ),
    ]),
  ),
  ...syncOffOverrides(),
];

class _PhoneShell extends ConsumerWidget {
  const _PhoneShell({required this.selected, required this.body});

  final ShellDestination selected;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomBarShell(
      destinations: ShellDestination.primary,
      selected: selected,
      onSelect: (ShellDestination destination) {},
      onCapture: () => openCapture(context, ref, date: _today),
      body: body,
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpPhone(
  WidgetTester tester,
  ShellDestination selected,
  Widget body, {
  Mood? mood = Mood.calm,
}) async {
  tester.view.physicalSize = _galaxyS24;
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
        overrides: _overrides(mood),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.android),
          home: _PhoneShell(selected: selected, body: body),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _pumpToday(WidgetTester tester, {Mood? mood = Mood.calm}) =>
    _pumpPhone(tester, ShellDestination.today, const TodayScreen(), mood: mood);

Future<void> _pumpCalendar(WidgetTester tester) =>
    _pumpPhone(tester, ShellDestination.calendar, CalendarScreen(today: _now));

Future<void> _pumpSettings(WidgetTester tester, SettingsTab tab) async {
  await _pumpPhone(tester, ShellDestination.settings, const SettingsScreen());
  await _tap(tester, find.byKey(settingsTabKey(tab)));
}

final Finder _tabBar = find.byType(PhoneBottomBar);
final Finder _moodCard = find.byType(TodayMoodDock);
final Finder _sheetFooter = find.byKey(phoneSheetFooterKey);
final Finder _segments = find.byKey(settingsTabChipsKey);
final Finder _searchField = find.byType(SearchField);
final Finder _monthControls = find.byWidgetPredicate(
  (Widget widget) =>
      widget.key == phoneMonthPreviousKey ||
      widget.key == phoneMonthPickerButtonKey ||
      widget.key == phoneMonthNextKey,
  description: 'the calendar previous, month and next buttons',
);

class _Primary {
  const _Primary(
    this.name,
    this.area, {
    this.count = 1,
    this.textField = false,
  });

  final String name;
  final Finder area;
  final int count;
  final bool textField;
}

final _Primary _tabCells = _Primary('tab cells and +', _tabBar, count: 5);
final _Primary _moodButton = _Primary('mood card button', _moodCard);
final _Primary _footerButtons = _Primary('sheet footer buttons', _sheetFooter);
final _Primary _settingsSegments = _Primary(
  'settings segments',
  _segments,
  count: SettingsTab.values.length,
);
final _Primary _calendarControls = _Primary(
  'calendar previous, month and next',
  _monthControls,
  count: 3,
);
final _Primary _searchBox = _Primary(
  'search field',
  _searchField,
  textField: true,
);

class _Surface {
  const _Surface(this.name, this.open, this.primary);

  final String name;
  final Future<void> Function(WidgetTester tester) open;
  final List<_Primary> primary;
}

final List<_Surface> _surfaces = <_Surface>[
  _Surface('Today with a mood', _pumpToday, <_Primary>[_tabCells, _moodButton]),
  _Surface(
    'Today before a mood',
    (WidgetTester tester) => _pumpToday(tester, mood: null),
    <_Primary>[_tabCells, _moodButton],
  ),
  _Surface('mood sheet', (WidgetTester tester) async {
    await _pumpToday(tester);
    await _tap(tester, find.text(todayMoodDockChangeLabel));
  }, const <_Primary>[]),
  _Surface('change-mood confirm sheet', (WidgetTester tester) async {
    await _pumpToday(tester);
    await _tap(tester, find.text(todayMoodDockChangeLabel));
    await _tap(tester, find.text(Mood.happy.label));
  }, <_Primary>[_footerButtons]),
  _Surface('capture sheet', (WidgetTester tester) async {
    await _pumpToday(tester);
    await _tap(tester, find.byKey(const ValueKey<String>('capture-button')));
  }, const <_Primary>[]),
  _Surface('full-screen composer', (WidgetTester tester) async {
    await _pumpToday(tester);
    await _tap(tester, find.byKey(const ValueKey<String>('capture-button')));
    await _tap(tester, find.text('Write a note'));
  }, const <_Primary>[]),
  _Surface('Log sheet', (WidgetTester tester) async {
    await _pumpToday(tester);
    await _tap(tester, find.byType(CompactLogCard).first);
  }, <_Primary>[_footerButtons]),
  _Surface('delete confirm sheet', (WidgetTester tester) async {
    await _pumpToday(tester);
    await _tap(tester, find.byType(CompactLogCard).first);
    await _tap(tester, find.byKey(logActionsDeleteKey));
  }, <_Primary>[_footerButtons]),
  _Surface('flower month', _pumpCalendar, <_Primary>[
    _tabCells,
    _calendarControls,
  ]),
  _Surface('six-week flower month away from this month', (
    WidgetTester tester,
  ) async {
    await _pumpCalendar(tester);
    await _tap(tester, find.byKey(phoneMonthPreviousKey));
  }, <_Primary>[_tabCells, _calendarControls]),
  _Surface('month and year sheet', (WidgetTester tester) async {
    await _pumpCalendar(tester);
    await _tap(tester, find.byKey(phoneMonthPickerButtonKey));
  }, <_Primary>[_footerButtons]),
  _Surface('Day sheet', (WidgetTester tester) async {
    await _pumpCalendar(tester);
    await _tap(tester, find.byKey(const ValueKey<String>('day-$_pastDay')));
  }, <_Primary>[_footerButtons]),
  _Surface('bottom search', (WidgetTester tester) async {
    await _pumpPhone(tester, ShellDestination.search, const SearchScreen());
    await tester.enterText(find.byType(TextField), 'peonies');
    await _settle(tester);
  }, <_Primary>[_tabCells, _searchBox]),
  for (final SettingsTab tab in SettingsTab.values)
    _Surface(
      'bottom settings, ${tab.label}',
      (WidgetTester tester) => _pumpSettings(tester, tab),
      <_Primary>[_tabCells, _settingsSegments],
    ),
  _Surface('week start sheet', (WidgetTester tester) async {
    await _pumpSettings(tester, SettingsTab.journal);
    await _tap(tester, find.byType(SettingsSelect<WeekStart>));
  }, const <_Primary>[]),
  _Surface('reminder time sheet', (WidgetTester tester) async {
    await _pumpSettings(tester, SettingsTab.remindersSound);
    await _tap(tester, find.byType(SettingsTimeField));
  }, <_Primary>[_footerButtons]),
];

class _Target {
  const _Target({
    required this.label,
    required this.rect,
    required this.size,
    required this.textField,
  });

  final String label;
  final Rect rect;
  final Size size;
  final bool textField;

  @override
  String toString() =>
      '"${label.replaceAll('\n', ' / ')}" ${size.width.toStringAsFixed(1)}'
      'x${size.height.toStringAsFixed(1)}';
}

Iterable<SemanticsNode> _selfAndAncestors(SemanticsNode node) sync* {
  for (
    SemanticsNode? current = node;
    current != null;
    current = current.parent
  ) {
    yield current;
  }
}

Iterable<SemanticsNode> _depthFirst(SemanticsNode node) sync* {
  yield node;
  final List<SemanticsNode> children = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    children.add(child);
    return true;
  });
  for (final SemanticsNode child in children) {
    yield* _depthFirst(child);
  }
}

Iterable<RenderObject> _renderDepthFirst(RenderObject object) sync* {
  yield object;
  final List<RenderObject> children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final RenderObject child in children) {
    yield* _renderDepthFirst(child);
  }
}

Rect _logical(Rect physical, double ratio) => Rect.fromLTRB(
  physical.left / ratio,
  physical.top / ratio,
  physical.right / ratio,
  physical.bottom / ratio,
);

Rect _globalRect(SemanticsNode node, double ratio) => _logical(
  _selfAndAncestors(node).fold(
    node.rect,
    (Rect rect, SemanticsNode current) => switch (current.transform) {
      final Matrix4 transform => MatrixUtils.transformRect(transform, rect),
      null => rect,
    },
  ),
  ratio,
);

Rect _reachableRect(SemanticsNode node, double ratio) => _selfAndAncestors(node)
    .skip(1)
    .fold(_globalRect(node, ratio), (Rect reachable, SemanticsNode ancestor) {
      final Rect bounds = _globalRect(ancestor, ratio);
      return reachable.overlaps(bounds)
          ? reachable.intersect(bounds)
          : Rect.zero;
    });

Map<SemanticsNode, Rect> _wholeRects(RenderView view) {
  final double ratio = view.flutterView.devicePixelRatio;
  final Map<SemanticsNode, Rect> whole = <SemanticsNode, Rect>{};
  for (final RenderObject owner in _renderDepthFirst(view)) {
    if (owner.debugSemantics case final SemanticsNode node) {
      final Rect bounds = _logical(
        MatrixUtils.transformRect(
          owner.getTransformTo(view),
          owner.semanticBounds,
        ),
        ratio,
      );
      whole.update(
        node,
        (Rect other) => other.expandToInclude(bounds),
        ifAbsent: () => bounds,
      );
    }
  }
  return whole;
}

bool _mostlyShown(double shown, double whole) =>
    shown >= whole - _tolerance || shown > whole / 2 + _tolerance;

Size? _hitSize(Rect rect, Rect reachable, Rect? whole) {
  if (whole == null) {
    return reachable.size;
  }
  final bool clipped =
      rect.width < whole.width - _tolerance ||
      rect.height < whole.height - _tolerance;
  if (!clipped) {
    return reachable.size;
  }
  return _mostlyShown(rect.width, whole.width) &&
          _mostlyShown(rect.height, whole.height)
      ? whole.size
      : null;
}

List<_Target> _targets(WidgetTester tester) => <_Target>[
  for (final RenderView view in tester.binding.renderViews)
    ..._viewTargets(view),
];

List<_Target> _viewTargets(RenderView view) {
  final SemanticsNode? root = view.owner?.semanticsOwner?.rootSemanticsNode;
  if (root == null) {
    return const <_Target>[];
  }
  final double ratio = view.flutterView.devicePixelRatio;
  final Map<SemanticsNode, Rect> whole = _wholeRects(view);
  return <_Target>[
    for (final SemanticsNode node in _depthFirst(root))
      if (_interactive(node))
        if (_hitSize(
              _globalRect(node, ratio),
              _reachableRect(node, ratio),
              whole[node],
            )
            case final Size size)
          _Target(
            label: node.getSemanticsData().label,
            rect: _globalRect(node, ratio),
            size: size,
            textField: node.getSemanticsData().flagsCollection.isTextField,
          ),
  ];
}

bool _interactive(SemanticsNode node) {
  if (node.isMergedIntoParent || node.isInvisible) {
    return false;
  }
  final SemanticsData data = node.getSemanticsData();
  final ui.SemanticsFlags flags = data.flagsCollection;
  return !flags.isHidden &&
      (data.hasAction(ui.SemanticsAction.tap) ||
          data.hasAction(ui.SemanticsAction.longPress) ||
          flags.isButton);
}

bool _small(Size size) =>
    size.width < _minimumTarget - _tolerance ||
    size.height < _minimumTarget - _tolerance;

List<String> _primaryGaps(
  WidgetTester tester,
  _Surface surface,
  List<_Target> targets,
) {
  final List<String> gaps = <String>[];
  for (final _Primary primary in surface.primary) {
    final List<Rect> areas = <Rect>[
      for (final Element element in primary.area.evaluate())
        tester.getRect(find.byElementPredicate((Element e) => e == element)),
    ];
    final List<_Target> inside = <_Target>[
      for (final _Target target in targets)
        if ((!primary.textField || target.textField) &&
            areas.any((Rect area) => area.contains(target.rect.center)))
          target,
    ];
    if (inside.length < primary.count) {
      gaps.add(
        '${surface.name}: expected ${primary.count} ${primary.name}, '
        'found $inside',
      );
    }
    for (final _Target target in inside) {
      if (target.size.height < _primaryHeight - _tolerance) {
        gaps.add('${surface.name}: ${primary.name} $target is under 48 tall');
      }
    }
  }
  return gaps;
}

void main() {
  testWidgets(
    'every new phone control meets 44 points and primary controls 48',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<String> gaps = <String>[];
      for (final _Surface surface in _surfaces) {
        await surface.open(tester);
        final List<_Target> targets = _targets(tester);
        expect(targets, isNotEmpty, reason: surface.name);
        gaps.addAll(<String>[
          for (final _Target target in targets)
            if (_small(target.size)) '${surface.name}: $target is under 44x44',
          ..._primaryGaps(tester, surface, targets),
        ]);
      }
      expect(gaps, isEmpty, reason: gaps.join('\n'));
      handle.dispose();
    },
  );
}
