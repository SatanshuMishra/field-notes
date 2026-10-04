import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/appearance_toggle.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/search/search.dart';
import 'package:field_notes/features/settings/settings.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/today/support/today_harness.dart';
import '../support/app_shell_harness.dart';

const Size _surface = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _headerHeight = _statusBar + 44;

final Finder _gear = find.byKey(const ValueKey<String>('gear-button'));

final Finder _pill = find.byType(StreakPill);

Finder _tab(ShellDestination d) =>
    find.byKey(ValueKey<String>('tab-${d.name}'));

List<Override> _longFeed() => <Override>[
  entriesForDateProvider.overrideWith(
    (Ref ref, String date) => Stream<List<Entry>>.value(<Entry>[
      for (int index = 0; index < 16; index++)
        todayTestEntry(
          id: 'entry-$index',
          textContent: 'A line about the harbour at dusk, number $index',
        ),
    ]),
  ),
  photosForEntryProvider.overrideWith(
    (Ref ref, String entryId) =>
        Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
  ),
  todayMediaResolverProvider.overrideWith(
    (Ref ref) async => const StubMediaResolver(),
  ),
];

Future<void> _pumpPhone(
  WidgetTester tester, {
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = _surface;
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
    ProviderScope(
      overrides: <Override>[...shellOverrides(), ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _open(WidgetTester tester, ShellDestination d) async {
  await tester.tap(
    d == ShellDestination.settings ? _gear : _tab(d),
    warnIfMissed: false,
  );
  await tester.pump();
  await tester.pump();
}

const Map<ShellDestination, Type> _pages = <ShellDestination, Type>{
  ShellDestination.today: TodayScreen,
  ShellDestination.calendar: CalendarScreen,
  ShellDestination.garden: GardenScreen,
  ShellDestination.search: SearchScreen,
  ShellDestination.settings: SettingsScreen,
};

Finder _headerGlass(WidgetTester tester) =>
    find.byWidgetPredicate((Widget widget) {
      if (widget is! GlassSurface) {
        return false;
      }
      final Finder self = find.byWidget(widget);
      if (self.evaluate().isEmpty) {
        return false;
      }
      final Rect rect = tester.getRect(self);
      return rect.top == 0 &&
          rect.left == 0 &&
          rect.width == _surface.width &&
          rect.height == _headerHeight;
    }, description: 'the glass behind the phone header');

ScrollableState _todayScroll(WidgetTester tester) => tester
    .stateList<ScrollableState>(
      find.descendant(
        of: find.byType(TodayScreen),
        matching: find.byType(Scrollable),
      ),
    )
    .firstWhere(
      (ScrollableState state) => state.position.axis == Axis.vertical,
    );

void main() {
  testWidgets(
    'every phone page shows the streak pill and gear in the same header spot',
    (WidgetTester tester) async {
      await _pumpPhone(tester);

      Rect? pillHome;
      Rect? gearHome;
      for (final MapEntry<ShellDestination, Type> page in _pages.entries) {
        await _open(tester, page.key);
        final String reason = page.key.name;
        expect(find.byType(page.value), findsOneWidget, reason: reason);
        expect(_pill, findsOneWidget, reason: reason);
        expect(_gear, findsOneWidget, reason: reason);
        final Rect pill = tester.getRect(_pill);
        final Rect gear = tester.getRect(_gear);
        pillHome ??= pill;
        gearHome ??= gear;
        expect(pill, pillHome, reason: reason);
        expect(gear, gearHome, reason: reason);

        expect(gear.size, const Size.square(44), reason: reason);
        expect(gear.top, _statusBar, reason: reason);
        expect(gear.right, _surface.width - 8, reason: reason);
        expect(pill.height, 30, reason: reason);
        expect(pill.right, gear.left - 2, reason: reason);
        expect(pill.center.dy, gear.center.dy, reason: reason);
        expect(pill.top, greaterThanOrEqualTo(_statusBar), reason: reason);
        expect(pill.bottom, lessThanOrEqualTo(_headerHeight), reason: reason);
        final Rect wordmark = tester.getRect(find.text('field notes'));
        expect(wordmark.left, 18, reason: reason);
        expect(wordmark.top, greaterThanOrEqualTo(_statusBar), reason: reason);
        expect(
          wordmark.bottom,
          lessThanOrEqualTo(_headerHeight),
          reason: reason,
        );
        expect(
          tester.widget<StreakPill>(_pill).form,
          page.key == ShellDestination.garden
              ? StreakPillForm.headerOverScene
              : StreakPillForm.header,
          reason: reason,
        );
      }
    },
  );

  testWidgets(
    'the phone header has no light/dark toggle and the meadow has no streak '
    'card',
    (WidgetTester tester) async {
      await _pumpPhone(tester);

      for (final ShellDestination d in _pages.keys) {
        await _open(tester, d);
        final String reason = d.name;
        expect(find.byType(_pages[d]!), findsOneWidget, reason: reason);
        expect(find.byType(AppearanceToggle), findsNothing, reason: reason);
        expect(find.byKey(appearanceToggleKey), findsNothing, reason: reason);
        expect(
          find.byKey(const ValueKey<String>('streak-card')),
          findsNothing,
          reason: reason,
        );
        expect(find.text('longest streak yet: 0'), findsNothing);
        expect(_pill, findsOneWidget, reason: reason);
      }
    },
  );

  testWidgets('the phone header turns to glass once the page scrolls', (
    WidgetTester tester,
  ) async {
    await _pumpPhone(tester, overrides: _longFeed());
    await tester.pump();

    final ScrollableState feed = _todayScroll(tester);
    expect(feed.position.pixels, 0);
    expect(feed.position.maxScrollExtent, greaterThan(40));
    expect(_headerGlass(tester), findsNothing);

    feed.position.jumpTo(3);
    await tester.pump();
    expect(_headerGlass(tester), findsNothing);

    feed.position.jumpTo(40);
    await tester.pump();
    expect(_headerGlass(tester), findsOneWidget);
    expect(
      find.descendant(
        of: _headerGlass(tester),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<GlassSurface>(_headerGlass(tester)).tone,
      GlassTone.paper,
    );
    expect(
      tester.widget<GlassSurface>(_headerGlass(tester)).tint!.toARGB32(),
      const Color.fromRGBO(239, 226, 206, 0.62).toARGB32(),
    );

    feed.position.jumpTo(0);
    await tester.pump();
    expect(_headerGlass(tester), findsNothing);

    feed.position.jumpTo(40);
    await tester.pump();
    expect(_headerGlass(tester), findsOneWidget);

    await _open(tester, ShellDestination.calendar);
    expect(_headerGlass(tester), findsNothing);

    await _open(tester, ShellDestination.garden);
    expect(_headerGlass(tester), findsOneWidget);
    final GlassSurface meadow = tester.widget<GlassSurface>(
      _headerGlass(tester),
    );
    expect(meadow.tone, GlassTone.scene);
    expect(
      meadow.tint!.toARGB32(),
      const Color.fromRGBO(24, 19, 14, 0.42).toARGB32(),
    );
    expect(
      tester.widget<Text>(find.text('field notes')).style!.color!.toARGB32(),
      const Color(0xFFFFD5DB).toARGB32(),
    );
  });
}
