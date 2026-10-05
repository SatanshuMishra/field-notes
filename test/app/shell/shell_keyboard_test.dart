import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/today/today_capture_buttons.dart';
import 'package:field_notes/features/today/this_week_garden.dart';
import 'package:field_notes/features/today/today_memory.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../accessibility/states/capture_states.dart';
import '../../accessibility/states/shell_states.dart';
import '../../accessibility/states/viewer_states.dart';
import '../../accessibility/support/a11y_state.dart';
import '../../features/today/support/today_harness.dart';
import '../../support/sync_overrides.dart';
import '../../support/tab_reach.dart';
import '../app_harness.dart';

const Size _macWindow = Size(1280, 860);

const int _tabPresses = 12;

const int _guardTabPresses = 24;

const List<String> _stateIds = <String>[
  'a1-today-empty',
  'a2-today-feed',
  'a3-card-actions',
  'a6-garden-empty',
  'a7-garden-blooms',
  'a8-garden-phone',
  'a9-search-results',
  'a10-search-no-match',
  'c1-chooser',
  'd1-viewer-todos',
  'd2-viewer-photo',
  'd6-task-toast',
  'd7-day-with-entries',
  'd8-day-empty',
  'd12-mood-set',
  'd15-viewer-middle-entry',
  'd16-day-past-mood',
];

final List<A11yState> _states = <A11yState>[
  ...shellStates,
  ...captureStates,
  ...viewerStates,
];

Future<void> _pumpState(WidgetTester tester, String id) =>
    _states.singleWhere((A11yState state) => state.id == id).pump(tester);

Future<void> _onMacOS(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void _useKeyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

CaptureRouteRegistry _allCaptureRoutes() => captureOptions.fold(
  CaptureRouteRegistry.empty,
  (CaptureRouteRegistry registry, CaptureOption option) => registry.withRoute(
    CaptureRoute(
      type: option.type,
      open: (BuildContext context, String date) async => null,
    ),
  ),
);

List<Override> _todayOverrides() => <Override>[
  todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 20)),
  weekStartProvider.overrideWithValue(WeekStart.sunday),
  allDaysProvider.overrideWith(
    (Ref ref) => Stream<List<Day>>.value(<Day>[
      todayTestDay(date: '2026-07-16', mood: Mood.happy),
      todayTestDay(date: '2026-07-19', mood: Mood.calm),
    ]),
  ),
  dayForDateProvider.overrideWith(
    (Ref ref, String date) =>
        Stream<Day?>.value(todayTestDay(date: date, mood: Mood.calm)),
  ),
  entriesForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<List<Entry>>.value(<Entry>[
      todayTestEntry(textContent: 'morning walk'),
      todayTestEntry(id: 'entry-2', textContent: 'harbour at dusk'),
    ]),
  ),
  entriesForDayProvider.overrideWith(
    (Ref ref, String dayId) => Stream<List<Entry>>.value(const <Entry>[]),
  ),
  photosForEntryProvider.overrideWith(
    (Ref ref, String entryId) =>
        Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
  ),
  todayMediaResolverProvider.overrideWith(
    (Ref ref) async => const StubMediaResolver(),
  ),
  onThisDayMemoryProvider.overrideWith(
    (Ref ref) async => OnThisDayMemory(
      day: todayTestDay(id: 'day-2025', date: '2025-07-19', mood: Mood.happy),
      yearsAgo: 1,
    ),
  ),
  captureRoutesProvider.overrideWithValue(_allCaptureRoutes()),
  ...syncOffOverrides(),
];

Future<void> _pumpMacSidebar(WidgetTester tester) async {
  tester.view.physicalSize = _macWindow;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    appHarness(
      SidebarShell(
        destinations: ShellDestination.primary,
        selected: ShellDestination.today,
        onSelect: (ShellDestination destination) {},
        onSound: () {},
        streak: const SizedBox.shrink(),
        body: const SizedBox.shrink(),
      ),
    ),
  );
}

Future<void> _pumpMacToday(WidgetTester tester) async {
  tester.view.physicalSize = _macWindow;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _todayOverrides(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const Scaffold(body: TodayScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Iterable<RenderObject> _renderDepthFirst(RenderObject object) sync* {
  yield object;
  final List<RenderObject> children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final RenderObject child in children) {
    yield* _renderDepthFirst(child);
  }
}

Set<Rect> _paintedRects(WidgetTester tester) => <Rect>{
  for (final RenderView view in tester.binding.renderViews)
    for (final RenderObject object in _renderDepthFirst(view))
      if (object is RenderBox &&
          object.hasSize &&
          (object is RenderDecoratedBox || object is RenderParagraph))
        MatrixUtils.transformRect(
          object.getTransformTo(null),
          Offset.zero & object.size,
        ),
};

List<double> _scrollOffsets(WidgetTester tester) => <double>[
  for (final ScrollableState state in tester.stateList<ScrollableState>(
    find.byType(Scrollable),
  ))
    if (state.position.hasPixels) state.position.pixels,
];

class _Screen {
  const _Screen(this.name, this.pump, {this.macOS = false});

  final String name;
  final Future<void> Function(WidgetTester tester) pump;
  final bool macOS;
}

final List<_Screen> _screens = <_Screen>[
  for (final String id in _stateIds)
    _Screen(id, (WidgetTester tester) => _pumpState(tester, id)),
  const _Screen('macOS sidebar', _pumpMacSidebar, macOS: true),
  const _Screen('macOS Today', _pumpMacToday, macOS: true),
];

bool _focusIsWithin(Finder finder) {
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  if (focused is! Element) {
    return false;
  }
  final Element target = finder.evaluate().single;
  bool within = identical(focused, target);
  focused.visitAncestorElements((Element ancestor) {
    within = within || identical(ancestor, target);
    return !within;
  });
  return within;
}

void main() {
  group(
    'every tappable shell, day sheet and viewer control is reachable by Tab with a visible ring',
    () {
      for (final String id in _stateIds) {
        testWidgets(id, (WidgetTester tester) async {
          await _pumpState(tester, id);
          await expectEveryTapTargetReachableByTab(tester);
        });
      }
    },
  );

  testWidgets(
    'every tappable macOS sidebar control is reachable by Tab with a visible ring',
    (WidgetTester tester) async {
      await _onMacOS(() async {
        await _pumpMacSidebar(tester);
        await expectEveryTapTargetReachableByTab(tester);
      });
    },
  );

  testWidgets(
    'every tappable control on the macOS Today screen is reachable by Tab with a visible ring',
    (WidgetTester tester) async {
      await _onMacOS(() async {
        await _pumpMacToday(tester);
        expect(find.byType(TodayCaptureButtons), findsOneWidget);
        expect(find.byType(ThisWeekGarden), findsOneWidget);
        await expectEveryTapTargetReachableByTab(tester);
      });
    },
  );

  testWidgets('the focused card shows the focus ring and Enter opens it', (
    WidgetTester tester,
  ) async {
    await _pumpState(tester, 'a2-today-feed');
    _useKeyboardHighlight();
    final Finder card = find.byType(CompactLogCard).first;

    for (int press = 0; press < _tabPresses && !_focusIsWithin(card); press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.pump();

    expect(_focusIsWithin(card), isTrue);
    expect(
      find.descendant(of: card, matching: find.byKey(focusRingKey)),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(LogViewerPanel), findsOneWidget);
  });

  group('keyboard focus moves nothing painted', () {
    for (final _Screen screen in _screens) {
      testWidgets(screen.name, (WidgetTester tester) async {
        Future<void> body() async {
          await screen.pump(tester);
          await tester.pump();
          await tester.pump();
          _useKeyboardHighlight();
          final Set<Rect> unfocused = _paintedRects(tester);
          final List<double> resting = _scrollOffsets(tester);
          int ringed = 0;
          for (int press = 0; press < _guardTabPresses; press++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            ringed += find.byKey(focusRingKey).evaluate().length;
            if (listEquals(_scrollOffsets(tester), resting)) {
              expect(
                unfocused.difference(_paintedRects(tester)),
                isEmpty,
                reason: 'Tab $press',
              );
              continue;
            }
            final Set<Rect> focused = _paintedRects(tester);
            final FocusNode? node = FocusManager.instance.primaryFocus;
            node?.unfocus();
            await tester.pump();
            final Set<Rect> scrolled = _paintedRects(tester);
            node?.requestFocus();
            await tester.pump();
            expect(
              scrolled.difference(focused),
              isEmpty,
              reason: 'Tab $press after the page scrolled',
            );
          }
          expect(ringed, greaterThan(0));
        }

        await (screen.macOS ? _onMacOS(body) : body());
      });
    }
  });

  testWidgets(
    'the viewer keeps its Escape and arrow keys while its Close pill has Tab focus',
    (WidgetTester tester) async {
      await _pumpState(tester, 'd15-viewer-middle-entry');
      _useKeyboardHighlight();
      final Finder close = find.ancestor(
        of: find.text('Close'),
        matching: find.byType(FocusRing),
      );

      for (
        int press = 0;
        press < _tabPresses && !_focusIsWithin(close);
        press++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(_focusIsWithin(close), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('3 of 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('2 of 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(LogViewerPanel), findsNothing);
    },
  );
}
