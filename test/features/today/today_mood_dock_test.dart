import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/mood/mood.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:field_notes/features/today/today_mood_dock.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../mood/support/mood_harness.dart' as mood_harness;
import '../sound/support/fake_sound_player.dart';
import 'support/today_harness.dart';

const Size _phone = Size(384, 832);
const Size _desktop = Size(1280, 900);
const double _statusBar = 34;
const double _gestureBar = 24;

final DateTime _evening = DateTime(2026, 7, 19, 20);

final Finder _dock = find.byType(TodayMoodDock);

Override _todayMood(Mood? mood) => dayForDateProvider.overrideWith(
  (Ref ref, String date) =>
      Stream<Day?>.value(todayTestDay(date: date, mood: mood)),
);

List<Override> _todayOverrides(Mood? mood) => <Override>[
  todayClockProvider.overrideWithValue(() => _evening),
  _todayMood(mood),
  todayMediaResolverProvider.overrideWith(
    (Ref ref) async => const StubMediaResolver(),
  ),
];

void _useSurface(WidgetTester tester, TargetPlatform platform) {
  final bool phone = platform == TargetPlatform.android;
  tester.view.physicalSize = phone ? _phone : _desktop;
  tester.view.devicePixelRatio = 1;
  if (phone) {
    tester.view.padding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: _statusBar,
      bottom: _gestureBar,
    );
  } else {
    tester.view.resetPadding();
    tester.view.resetViewPadding();
  }
  addTearDown(tester.view.reset);
}

Future<void> _pumpShell(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
  Mood? mood = Mood.calm,
}) async {
  _useSurface(tester, platform);
  await tester.pumpWidget(
    KeyedSubtree(
      key: UniqueKey(),
      child: ProviderScope(
        overrides: <Override>[...shellOverrides(), ..._todayOverrides(mood)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: platform),
          home: const AppShell(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Rect _hitRect(WidgetTester tester, String label) => tester.getRect(
  find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .first,
);

Rect _visualRect(WidgetTester tester, String label) => tester.getRect(
  find
      .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
      .first,
);

void main() {
  testWidgets('the phone Today mood card floats just above the tab bar', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    expect(_dock, findsOneWidget);
    final Rect card = tester.getRect(_dock);
    expect(card.left, 12);
    expect(card.right, _phone.width - 12);
    expect(card.height, 60);
    expect(card.bottom, _phone.height - _gestureBar - 80);
    expect(
      card.bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(PhoneBottomBar)).top),
    );
    expect(
      find.ancestor(of: _dock, matching: find.byType(Scrollable)),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(CustomScrollView), matching: _dock),
      findsNothing,
    );
    expect(find.byType(MoodBannerForDate), findsNothing);

    final GlassSurface glass = tester.widget<GlassSurface>(
      find.descendant(of: _dock, matching: find.byType(GlassSurface)),
    );
    expect(glass.tone, GlassTone.paper);
    expect(glass.borderRadius, BorderRadius.circular(20));
    expect(
      tester.getSize(
        find.descendant(of: _dock, matching: find.byType(FlowerBloom)),
      ),
      const Size(36, 36),
    );
    expect(
      find.descendant(of: _dock, matching: find.text('Feeling Calm')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _dock,
        matching: find.text("${Mood.calm.flower.label} · today's bloom"),
      ),
      findsOneWidget,
    );
    expect(_visualRect(tester, 'Change').height, 42);
    expect(_hitRect(tester, 'Change').height, greaterThanOrEqualTo(48));
  });

  testWidgets('tapping Change opens the mood sheet', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    expect(find.byType(MoodPickerSheet), findsNothing);
    await tester.tap(find.descendant(of: _dock, matching: find.text('Change')));
    await _settle(tester);

    expect(find.byType(PhoneSheet), findsOneWidget);
    expect(find.byType(MoodPickerSheet), findsOneWidget);

    await _pumpShell(tester, mood: null);

    expect(
      find.descendant(of: _dock, matching: find.text('How are you feeling?')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _dock,
        matching: find.text("tap to plant today's bloom"),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _dock, matching: find.text('Change')),
      findsNothing,
    );
    expect(
      find.descendant(of: _dock, matching: find.byType(FlowerBloom)),
      findsNothing,
    );
    expect(_visualRect(tester, 'Choose').height, 42);
    expect(_hitRect(tester, 'Choose').height, greaterThanOrEqualTo(48));

    await tester.tap(find.descendant(of: _dock, matching: find.text('Choose')));
    await _settle(tester);

    expect(find.byType(MoodPickerSheet), findsOneWidget);
  });

  testWidgets('macOS Today keeps the inline mood banner', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await _pumpShell(tester, platform: TargetPlatform.macOS);

      expect(_dock, findsNothing);
      final Finder banner = find.byType(MoodBannerForDate);
      expect(banner, findsOneWidget);
      expect(
        find.descendant(of: find.byType(CustomScrollView), matching: banner),
        findsOneWidget,
      );
      expect(find.text('Feeling Calm today'), findsOneWidget);
      final Rect bannerRect = tester.getRect(banner);
      expect(
        bannerRect.top,
        greaterThan(tester.getRect(find.byType(TodayHeader)).bottom),
      );
      expect(
        bannerRect.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(TodayFeedEyebrow)).top),
      );
      expect(activeToastLift, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the phone Today greeting starts below the header', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester);

    final ScrollableState feed = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(feed.position.pixels, 0);
    final double headerBottom = _statusBar + phoneHeaderBarHeight;
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('gear-button'))).bottom,
      lessThanOrEqualTo(headerBottom),
    );
    expect(
      tester.getRect(find.text('Good evening')).top,
      greaterThanOrEqualTo(headerBottom),
    );
    expect(
      tester.getRect(find.byType(TodayHeader)).top,
      greaterThanOrEqualTo(headerBottom),
    );
  });

  testWidgets(
    'a toast shown from another route sits above the Today mood card',
    (WidgetTester tester) async {
      await _pumpShell(tester);

      expect(activeToastLift, 80);
      final Rect card = tester.getRect(_dock);
      BuildContext? routeContext;
      Navigator.of(tester.element(find.byType(TodayScreen))).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            routeContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      showTransientToast(routeContext!, 'Saved to Today');
      await _settle(tester);

      final Rect toast = tester.getRect(find.byType(Toast));
      expect(toast.bottom, _phone.height - _gestureBar - 164);
      expect(toast.bottom, lessThanOrEqualTo(card.top));

      await tester.pump(kToastLifetime);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(activeToastLift, 0);
    },
  );

  testWidgets('choosing on the card plants the mood through the shared flow', (
    WidgetTester tester,
  ) async {
    _useSurface(tester, TargetPlatform.android);
    final mood_harness.FakeJournalRepository journal =
        mood_harness.FakeJournalRepository(
          initialDay: mood_harness.testDay(mood: null),
        );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          journalRepositoryProvider.overrideWithValue(journal),
          appSettingsProvider.overrideWith(
            (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
          ),
          soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
          todayClockProvider.overrideWithValue(() => _evening),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.android),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: TodayMoodDock(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    expect(journal.moodWrites, <({String date, Mood? mood})>[
      (date: '2026-07-19', mood: Mood.calm),
    ]);
    expect(find.text('Feeling Calm'), findsOneWidget);
    final Finder planted = find.text(
      'Mood planted · ${Mood.calm.flower.label}',
    );
    expect(planted, findsOneWidget);
    expect(
      tester.getRect(find.byType(Toast)).bottom,
      _phone.height - _gestureBar - 164,
    );

    journal.setMoodError = StateError('disk full');
    await tester.pump(kToastLifetime);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();
    expect(find.text("Change today's bloom?"), findsOneWidget);
    await tester.tap(find.text('Change mood'));
    await tester.pumpAndSettle();

    expect(journal.moodWrites, hasLength(1));
    expect(find.text(moodSaveFailedMessage), findsOneWidget);
    await tester.pump(kToastLifetime);
    await tester.pumpAndSettle();
  });
}
