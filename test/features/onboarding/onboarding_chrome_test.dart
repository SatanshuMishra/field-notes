import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/appearance_toggle.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../capture/core/capture_test_support.dart' show FakeNoteWriter;
import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';

const Size _phone = Size(384, 832);
const Size _mac = Size(1280, 800);
const double _statusBar = 34;
const double _gestureBar = 24;

const Color _meadowBar = Color.fromRGBO(28, 22, 16, 0.38);

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

List<Override> _overrides(FakeSettingsRepository settings) {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(settings),
    reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
    onboardingCountryCodeProvider.overrideWithValue('US'),
    noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  Size surface,
  FakeSettingsRepository settings, {
  bool insets = false,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  if (insets) {
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
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(settings),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
}

OnboardingController _controller(ProviderContainer container) =>
    container.read(onboardingControllerProvider.notifier);

OnboardingChapter _chapter(ProviderContainer container) => (container.read(
  onboardingControllerProvider,
) as OnboardingFlowRunning).chapter;

Finder get _progress => find.byKey(onboardingProgressKey);

Finder get _toggle => find.byKey(onboardingToggleKey);

Finder get _back => find.byKey(onboardingBackKey);

Finder get _skip => find.byKey(onboardingSkipKey);

Finder get _bar => find.byKey(onboardingControlBarKey);

Finder _mark(String name) =>
    find.descendant(of: _progress, matching: find.bySemanticsLabel(name));

Finder _glassIn(Finder finder) =>
    find.descendant(of: finder, matching: find.byType(GlassSurface));

bool _hitTestable(WidgetTester tester, Finder finder) {
  final RenderObject target = tester.renderObject(finder);
  final HitTestResult result = tester.hitTestOnBinding(
    tester.getCenter(finder),
  );
  return result.path.any(
    (HitTestEntry entry) => identical(entry.target, target),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _flipTheme(WidgetTester tester) async {
  await tester.tap(find.byKey(appearanceToggleKey));
  await tester.idle();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'phone progress, skip and toggle sit at the top and the control bar is clear',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _onPlatform(TargetPlatform.android, () async {
        final FakeSettingsRepository settings = FakeSettingsRepository(
          storedValues: false,
        );
        final ProviderContainer container = await _pumpApp(
          tester,
          _phone,
          settings,
          insets: true,
        );
        final OnboardingController controller = _controller(container);

        final Rect pill = tester.getRect(_progress);
        expect(pill.center.dx, moreOrLessEquals(_phone.width / 2));
        expect(pill.center.dy, moreOrLessEquals(_statusBar + 4 + 20));
        expect(pill.top, greaterThanOrEqualTo(_statusBar));
        expect(pill.height, 32);
        expect(_glassIn(_progress), findsOneWidget);
        for (final OnboardingChapter chapter in OnboardingChapter.values) {
          expect(
            tester.getSize(_mark(chapter.progressName)),
            const Size(22, 32),
            reason: chapter.name,
          );
        }

        expect(
          tester.getRect(find.byKey(appearanceToggleKey)),
          const Rect.fromLTWH(8, _statusBar + 2, 44, 44),
        );
        expect(_glassIn(_toggle), findsOneWidget);
        expect(tester.getSize(_glassIn(_toggle)), const Size.square(44));
        expect(_hitTestable(tester, find.byKey(appearanceToggleKey)), isTrue);

        expect(
          tester.getRect(_bar),
          Rect.fromLTWH(12, _phone.height - _gestureBar - 8 - 60, 360, 60),
        );
        expect(_glassIn(_bar), findsNothing);
        expect(_hitTestable(tester, _back), isFalse);

        controller
          ..plant()
          ..markGrown()
          ..next();
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.day);
        expect(_glassIn(_bar), findsNothing);

        final Rect skip = tester.getRect(_skip);
        expect(skip.right, _phone.width - 8);
        expect(skip.top, _statusBar + 4);
        expect(skip.height, 44);
        expect(
          find.descendant(of: _skip, matching: find.text('Skip')),
          findsOneWidget,
        );

        final Rect back = tester.getRect(_back);
        expect(back.size, const Size.square(48));
        expect(back.left, 12 + 8);
        expect(
          back.center.dy,
          moreOrLessEquals(_phone.height - _gestureBar - 8 - 30),
        );
        expect(_hitTestable(tester, _back), isTrue);

        await _tap(tester, _mark('A month'));
        expect(_chapter(container), OnboardingChapter.day);
        await _tap(tester, _mark('Opening'));
        expect(_chapter(container), OnboardingChapter.opening);

        controller
          ..next()
          ..skipToSetup();
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.theme);
        expect(_skip, findsNothing);
        expect(_glassIn(_bar), findsNothing);
        await _tap(tester, _mark('Week'));
        expect(_chapter(container), OnboardingChapter.theme);

        expect(
          Theme.of(tester.element(find.byType(ThemeChapter))).brightness,
          Brightness.light,
        );
        await _flipTheme(tester);
        expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
        expect(
          Theme.of(tester.element(find.byType(ThemeChapter))).brightness,
          Brightness.dark,
        );
        expect(_chapter(container), OnboardingChapter.theme);

        controller.goTo(OnboardingChapter.year);
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.year);
        expect(_glassIn(_bar), findsOneWidget);
        expect(
          tester.widget<GlassSurface>(_glassIn(_bar)).tint!.toARGB32(),
          _meadowBar.toARGB32(),
        );
        expect(tester.getRect(_glassIn(_bar)), tester.getRect(_bar));
      });
      semantics.dispose();
    },
  );

  testWidgets(
    'macOS dots sit top centre with glass Back bottom left and the toggle top left',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        final FakeSettingsRepository settings = FakeSettingsRepository(
          storedValues: false,
        );
        final ProviderContainer container = await _pumpApp(
          tester,
          _mac,
          settings,
        );
        final OnboardingController controller = _controller(container);
        final double top = tester.getRect(find.byType(OnboardingFrame)).top;
        expect(top, shellTitleBarHeight);

        expect(_glassIn(_progress), findsOneWidget);
        final Rect pill = tester.getRect(_glassIn(_progress));
        expect(pill.center.dx, moreOrLessEquals(_mac.width / 2));
        expect(pill.top, top + 8);
        expect(pill.height, 30);
        for (final OnboardingChapter chapter in OnboardingChapter.values) {
          final Size mark = tester.getSize(_mark(chapter.progressName));
          expect(mark.width, greaterThanOrEqualTo(44), reason: chapter.name);
          expect(mark.height, greaterThanOrEqualTo(44), reason: chapter.name);
        }

        expect(_back, findsNothing);
        expect(
          tester.getRect(_glassIn(_toggle)),
          Rect.fromLTWH(18, top + 8, 36, 36),
        );
        final Size target = tester.getSize(find.byKey(appearanceToggleKey));
        expect(target.width, greaterThanOrEqualTo(44));
        expect(target.height, greaterThanOrEqualTo(44));
        expect(_hitTestable(tester, find.byKey(appearanceToggleKey)), isTrue);
        expect(find.byType(AppearanceToggle), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(windowTitleBarKey),
            matching: find.byType(AppearanceToggle),
          ),
          findsNothing,
        );

        expect(_glassIn(_skip), findsOneWidget);
        final Rect skip = tester.getRect(_glassIn(_skip));
        expect(skip.top, top + 8);
        expect(skip.right, _mac.width - 18);
        expect(skip.height, 36);
        expect(tester.getSize(_skip).height, greaterThanOrEqualTo(44));
        expect(
          find.descendant(of: _skip, matching: find.text('Skip to setup')),
          findsOneWidget,
        );

        controller
          ..plant()
          ..markGrown();
        await _settle(tester);
        await _tap(
          tester,
          find.descendant(
            of: find.byKey(onboardingPrimaryKey),
            matching: find.text('Begin'),
          ),
        );
        expect(_chapter(container), OnboardingChapter.day);

        expect(_glassIn(_back), findsOneWidget);
        final Rect back = tester.getRect(_glassIn(_back));
        expect(back.size, const Size.square(46));
        expect(back.left, 28);
        expect(back.bottom, _mac.height - 20);
        final Size backTarget = tester.getSize(_back);
        expect(backTarget.width, greaterThanOrEqualTo(44));
        expect(backTarget.height, greaterThanOrEqualTo(44));
        expect(
          tester
              .widget<Tooltip>(
                find.descendant(of: _back, matching: find.byType(Tooltip)),
              )
              .message,
          'Back (←)',
        );
        await _tap(tester, _back);
        expect(_chapter(container), OnboardingChapter.opening);
        expect(_back, findsNothing);

        await _tap(
          tester,
          find.descendant(
            of: find.byKey(onboardingPrimaryKey),
            matching: find.text('Begin'),
          ),
        );
        expect(_chapter(container), OnboardingChapter.day);
        await tester.tap(
          find.descendant(
            of: find.byKey(onboardingPrimaryKey),
            matching: find.text('Next'),
          ),
        );
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.moment);
        FocusManager.instance.primaryFocus?.unfocus();
        await _settle(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.day);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.moment);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await _settle(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.moment);
        expect(tester.getRect(_glassIn(_back)).left, 28);

        await _flipTheme(tester);
        expect(settings.appearanceWrites, <Appearance>[Appearance.dark]);
        expect(
          Theme.of(tester.element(find.byType(OnboardingFrame))).brightness,
          Brightness.dark,
        );
        expect(_chapter(container), OnboardingChapter.moment);
        expect(
          find.descendant(
            of: find.byKey(windowTitleBarKey),
            matching: find.byType(AppearanceToggle),
          ),
          findsNothing,
        );
      });
    },
  );
}
