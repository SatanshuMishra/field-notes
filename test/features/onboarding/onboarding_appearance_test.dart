import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../settings/support/fake_settings_repository.dart';

const Size _sidebarSurface = Size(1200, 900);
const Size _bottomBarSurface = Size(400, 800);

const String _beginLabel = 'Let’s begin';
const String _welcomeHeadline = 'A journal of days.';
const String _kicker = 'look & feel';
const String _title = 'Light or dark?';
const String _sidebarNote =
    'Preview it on the journal behind. Change anytime in Settings.';
const String _bottomBarNote = 'Preview it above. Change anytime in Settings.';
const String _failure = 'Could not save your appearance.';
const Color _lightPage = Color(0xFFD9CBB2);
const Color _darkPage = Color(0xFF0E0C0A);

const List<(Appearance, String, String)> _options =
    <(Appearance, String, String)>[
      (Appearance.light, 'Light', 'warm paper'),
      (Appearance.dark, 'Dark', 'evening ink'),
      (Appearance.system, 'System', 'match device'),
    ];

class _FailingAppearance extends FakeSettingsRepository {
  _FailingAppearance() : super(storedValues: false);

  @override
  Future<void> setAppearance(Appearance value) async {
    throw StateError('disk full');
  }
}

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

Future<FakeSettingsRepository> _pumpToAppearance(
  WidgetTester tester, {
  required Size surface,
  FakeSettingsRepository? settings,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final FakeSettingsRepository repository =
      settings ?? FakeSettingsRepository(storedValues: false);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (override.origin != settingsRepositoryProvider) override,
        settingsRepositoryProvider.overrideWithValue(repository),
      ],
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  expect(find.text(_welcomeHeadline), findsOneWidget);
  await _tap(tester, find.text(_beginLabel));
  expect(find.byType(OnboardingAppearance), findsOneWidget);
  return repository;
}

Finder _option(Appearance appearance) =>
    find.byKey(onboardingAppearanceOptionKey(appearance));

void _expectSelected(WidgetTester tester, Appearance selected) {
  for (final (Appearance appearance, String label, String sublabel)
      in _options) {
    expect(
      tester.getSemantics(_option(appearance)),
      isSemantics(
        label: '$label, $sublabel',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: appearance == selected,
      ),
      reason: '$appearance',
    );
  }
}

ThemeData _appTheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AppShell)));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)));

void _expectTexts({required bool sidebar}) {
  expect(find.text(_kicker), findsOneWidget);
  expect(find.text(_title), findsOneWidget);
  expect(find.text(_sidebarNote), sidebar ? findsOneWidget : findsNothing);
  expect(find.text(_bottomBarNote), sidebar ? findsNothing : findsOneWidget);
  for (final (Appearance _, String label, String sublabel) in _options) {
    expect(find.text(label), findsOneWidget);
    expect(find.text(sublabel), findsOneWidget);
  }
  expect(find.text('Continue'), findsOneWidget);
}

void main() {
  testWidgets(
    'desktop step docks over the visible app with the stored look selected',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        await _pumpToAppearance(tester, surface: _sidebarSurface);

        final Rect card = tester.getRect(find.byKey(onboardingAppearanceKey));
        expect(card.bottom, _sidebarSurface.height - 24);
        expect(card.left, shellSidebarWidth + 49);
        expect(card.width, 560);
        expect(find.byType(SidebarShell), findsOneWidget);
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(find.byKey(onboardingCardKey), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        final Rect today = tester.getRect(find.byType(TodayScreen));
        expect(today.top, lessThan(card.top));
        for (final Element box
            in find
                .descendant(
                  of: find.byType(OnboardingAppearance),
                  matching: find.byWidgetPredicate(
                    (Widget widget) =>
                        widget is DecoratedBox ||
                        widget is ColoredBox ||
                        widget is CustomPaint,
                  ),
                )
                .evaluate()) {
          final RenderBox render = box.renderObject! as RenderBox;
          final Rect painted = render.localToGlobal(Offset.zero) & render.size;
          expect(card.inflate(1).contains(painted.topLeft), isTrue);
          expect(card.inflate(1).contains(painted.bottomRight), isTrue);
        }
        _expectTexts(sidebar: true);
        expect(find.text('Back'), findsOneWidget);
        expect(find.text('↵ to continue'), findsOneWidget);
        _expectSelected(tester, Appearance.light);

        await tester.tapAt(
          tester.getCenter(find.byKey(const ValueKey<String>('rail-calendar'))),
        );
        await _settle(tester);
        expect(
          _container(tester).read(shellNavigationProvider),
          ShellDestination.today,
        );
        expect(find.byType(OnboardingAppearance), findsOneWidget);
      });
    },
  );

  testWidgets('tapping Dark saves it and turns the app behind dark', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      final FakeSettingsRepository settings = await _pumpToAppearance(
        tester,
        surface: _sidebarSurface,
      );
      expect(_appTheme(tester).scaffoldBackgroundColor, _lightPage);

      await _tap(tester, _option(Appearance.dark));

      expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
      expect(_appTheme(tester).brightness, Brightness.dark);
      expect(_appTheme(tester).scaffoldBackgroundColor, _darkPage);
      expect(
        FieldNotesColors.of(tester.element(find.byType(AppShell))).panelTop,
        FieldNotesColors.dark.panelTop,
      );
      expect(find.byType(OnboardingAppearance), findsOneWidget);
      _expectSelected(tester, Appearance.dark);
    });
  });

  testWidgets('Enter and Esc continue and the left arrow goes back', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      final FakeSettingsRepository settings = await _pumpToAppearance(
        tester,
        surface: _sidebarSurface,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(find.byType(OnboardingAppearance), findsNothing);
      expect(find.byKey(tourCardKey), findsOneWidget);

      await _tap(tester, find.byKey(tourBackKey));
      expect(find.byType(OnboardingAppearance), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(OnboardingAppearance), findsNothing);
      expect(find.byKey(tourCardKey), findsOneWidget);

      await _tap(tester, find.byKey(tourBackKey));
      expect(find.byType(OnboardingAppearance), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.byType(OnboardingAppearance), findsNothing);
      expect(find.byKey(tourCardKey), findsOneWidget);

      await _tap(tester, find.byKey(tourBackKey));
      expect(find.byType(OnboardingAppearance), findsOneWidget);

      Focus.of(
        tester.element(
          find
              .descendant(
                of: _option(Appearance.dark),
                matching: find.byType(ExcludeSemantics),
              )
              .first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
      expect(find.byType(OnboardingAppearance), findsOneWidget);
      expect(find.byKey(tourCardKey), findsNothing);
      _expectSelected(tester, Appearance.dark);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _settle(tester);
      expect(find.byType(OnboardingAppearance), findsNothing);
      expect(find.byKey(tourCardKey), findsNothing);
      expect(find.text(_welcomeHeadline), findsOneWidget);
    });
  });

  testWidgets('phone step is a bottom sheet with a square Back', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.android, () async {
      await _pumpToAppearance(tester, surface: _bottomBarSurface);

      final Rect sheet = tester.getRect(find.byKey(onboardingAppearanceKey));
      expect(sheet.left, 0);
      expect(sheet.right, _bottomBarSurface.width);
      expect(sheet.bottom, _bottomBarSurface.height);
      expect(sheet.top, greaterThan(_bottomBarSurface.height / 3));
      expect(find.byType(BottomBarShell), findsOneWidget);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byKey(onboardingPageKey), findsNothing);

      final Rect handle = tester.getRect(
        find.byKey(onboardingAppearanceHandleKey),
      );
      expect(handle.size, const Size(36, 4));
      expect(handle.center.dx, sheet.center.dx);

      final Rect back = tester.getRect(find.byKey(onboardingAppearanceBackKey));
      expect(back.size, const Size(48, 48));
      expect(back.left, sheet.left + 16);
      expect(find.text('Back'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(onboardingAppearanceBackKey),
          matching: find.byIcon(Icons.chevron_left_rounded),
        ),
        findsOneWidget,
      );

      final Rect proceed = tester.getRect(
        find.byKey(onboardingAppearanceContinueKey),
      );
      expect(proceed.height, 48);
      expect(proceed.left, back.right + 10);
      expect(proceed.right, sheet.right - 16);
      expect(proceed.top, back.top);

      final Rect light = tester.getRect(_option(Appearance.light));
      final Rect dark = tester.getRect(_option(Appearance.dark));
      final Rect system = tester.getRect(_option(Appearance.system));
      expect(light.top, dark.top);
      expect(dark.top, system.top);
      expect(dark.left, light.right + 7);
      expect(system.left, dark.right + 7);

      _expectTexts(sidebar: false);
      expect(find.text('↵ to continue'), findsNothing);
      _expectSelected(tester, Appearance.light);
    });
  });

  testWidgets('a failed save shows the failure toast', (
    WidgetTester tester,
  ) async {
    await _onPlatform(TargetPlatform.macOS, () async {
      await _pumpToAppearance(
        tester,
        surface: _sidebarSurface,
        settings: _FailingAppearance(),
      );

      await tester.tap(_option(Appearance.dark));
      await tester.pump();
      await tester.pump();

      expect(find.text(_failure), findsOneWidget);
      expect(find.byType(OnboardingAppearance), findsOneWidget);
      _expectSelected(tester, Appearance.light);
      await _settle(tester);
      expect(_appTheme(tester).brightness, Brightness.light);
      expect(_appTheme(tester).scaffoldBackgroundColor, _lightPage);
      await tester.pump(const Duration(seconds: 5));
      await _settle(tester);
    });
  });
}
