import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/month_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);

const List<ShellLayout> _layouts = <ShellLayout>[
  ShellLayout.sidebar,
  ShellLayout.bottomBar,
];

const String _finishError = "Couldn't save your choices. Try again.";

Future<void> _onLayout(ShellLayout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = switch (layout) {
    ShellLayout.sidebar => TargetPlatform.macOS,
    ShellLayout.bottomBar => TargetPlatform.android,
  };
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
  ];
}

Future<void> _settle(WidgetTester tester) async {
  for (int frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpApp(
  WidgetTester tester,
  ShellLayout layout, {
  FakeSettingsRepository? settings,
}) async {
  tester.view.physicalSize = switch (layout) {
    ShellLayout.sidebar => _sidebarSurface,
    ShellLayout.bottomBar => _bottomBarSurface,
  };
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: _overrides(
        settings ?? FakeSettingsRepository(storedValues: false),
      ),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  expect(find.byType(OpeningChapter), findsOneWidget);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)));

OnboardingController _controller(WidgetTester tester) =>
    _container(tester).read(onboardingControllerProvider.notifier);

OnboardingChapter _chapter(WidgetTester tester) => (_container(
  tester,
).read(onboardingControllerProvider) as OnboardingFlowRunning).chapter;

void _doTask(OnboardingController controller, OnboardingChapter chapter) {
  switch (chapter) {
    case OnboardingChapter.opening:
      controller
        ..plant()
        ..markGrown();
    case OnboardingChapter.moment:
      controller.setNote('A first line');
    case OnboardingChapter.month:
      controller.setMonthFill(1);
    case OnboardingChapter.year:
      controller.setYearDay(365, scrubbed: false);
    case OnboardingChapter.day ||
        OnboardingChapter.theme ||
        OnboardingChapter.reminder ||
        OnboardingChapter.week ||
        OnboardingChapter.tour:
      return;
  }
}

Future<void> _walkTo(WidgetTester tester, OnboardingChapter target) async {
  final OnboardingController controller = _controller(tester);
  while (_chapter(tester) != target) {
    _doTask(controller, _chapter(tester));
    controller.next();
    await tester.pump();
  }
  await _settle(tester);
}

Future<void> _finishTask(WidgetTester tester) async {
  _doTask(_controller(tester), _chapter(tester));
  await _settle(tester);
}

Finder get _primary => find.byKey(onboardingPrimaryKey);

Finder get _cue => find.byKey(onboardingCueKey);

Finder _cueReading(String text) =>
    find.descendant(of: _cue, matching: find.text(text));

Future<void> _swipe(WidgetTester tester, double dx) async {
  final Rect frame = tester.getRect(find.byType(OnboardingFrame));
  await tester.flingFrom(
    Offset(frame.center.dx, frame.top + 110),
    Offset(dx, 0),
    800,
  );
  await _settle(tester);
}

Finder get _skip => find.byKey(onboardingSkipKey);

Finder _primaryReading(String label) =>
    find.descendant(of: _primary, matching: find.text(label));

Finder _mark(String name) => find.descendant(
  of: find.byKey(onboardingProgressKey),
  matching: find.bySemanticsLabel(name),
);

String _startLabel(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => 'Start journaling',
  ShellLayout.bottomBar => 'Start',
};

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

int Function() _countSystemPops(WidgetTester tester) {
  int pops = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'SystemNavigator.pop') {
        pops++;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return () => pops;
}

void main() {
  testWidgets(
    'the mac primary button reads Begin, then Next, then Start journaling, and hides until the task is done',
    (WidgetTester tester) async {
      await _onLayout(ShellLayout.sidebar, () async {
        await _pumpApp(tester, ShellLayout.sidebar);
        final OnboardingController controller = _controller(tester);

        expect(_primary, findsNothing, reason: 'opening');
        controller.plant();
        await _settle(tester);
        expect(_primary, findsNothing, reason: 'planting');
        controller.markGrown();
        await _settle(tester);
        expect(_primaryReading('Begin'), findsOneWidget);
        expect(find.bySemanticsLabel('Begin'), findsOneWidget);

        await _tap(tester, _primary);
        expect(find.byType(DayChapter), findsOneWidget);
        expect(_primaryReading('Next'), findsOneWidget);

        for (final OnboardingChapter chapter in <OnboardingChapter>[
          OnboardingChapter.moment,
          OnboardingChapter.month,
          OnboardingChapter.year,
        ]) {
          await _tap(tester, _primary);
          expect(_chapter(tester), chapter);
          expect(_primary, findsNothing, reason: '$chapter');
          await _finishTask(tester);
          expect(_primaryReading('Next'), findsOneWidget);
        }

        for (final OnboardingChapter chapter in <OnboardingChapter>[
          OnboardingChapter.theme,
          OnboardingChapter.reminder,
          OnboardingChapter.week,
        ]) {
          await _tap(tester, _primary);
          expect(_chapter(tester), chapter);
          expect(_primaryReading('Next'), findsOneWidget);
        }

        await _tap(tester, _primary);
        expect(find.byType(TourChapter), findsOneWidget);
        expect(
          _primaryReading(_startLabel(ShellLayout.sidebar)),
          findsOneWidget,
        );
        expect(find.text('Next'), findsNothing);
        expect(_cue, findsNothing);
      });
    },
  );

  testWidgets(
    'the phone has no primary button and swipes through every chapter to the tour',
    (WidgetTester tester) async {
      await _onLayout(ShellLayout.bottomBar, () async {
        await _pumpApp(tester, ShellLayout.bottomBar);
        final OnboardingController controller = _controller(tester);
        controller
          ..plant()
          ..markGrown();
        await _settle(tester);
        for (final OnboardingChapter chapter in OnboardingChapter.values) {
          expect(_chapter(tester), chapter);
          expect(_primary, findsNothing, reason: '$chapter');
          expect(find.text('Next'), findsNothing, reason: '$chapter');
          expect(find.text('Begin'), findsNothing, reason: '$chapter');
          if (chapter == OnboardingChapter.tour) {
            break;
          }
          await _finishTask(tester);
          await _swipe(tester, -120);
          if (chapter == OnboardingChapter.moment) {
            expect(_chapter(tester), OnboardingChapter.moment);
            await _swipe(tester, -120);
          }
        }
        expect(find.byType(TourChapter), findsOneWidget);
        expect(_cueReading('swipe to start journaling'), findsOneWidget);
      });
    },
  );

  testWidgets('skip shows only in the story chapters and opens Theme', (
    WidgetTester tester,
  ) async {
    await _onLayout(ShellLayout.sidebar, () async {
      await _pumpApp(tester, ShellLayout.sidebar);
      for (final OnboardingChapter chapter in OnboardingChapter.values) {
        await _walkTo(tester, chapter);
        expect(
          find.descendant(of: _skip, matching: find.text('Skip to setup')),
          chapter.isStory ? findsOneWidget : findsNothing,
          reason: '$chapter',
        );
        if (chapter.isStory) {
          await _finishTask(tester);
          expect(_skip, findsOneWidget, reason: '$chapter done');
        }
      }

      _controller(tester).goTo(OnboardingChapter.moment);
      await _settle(tester);
      await _tap(tester, _skip);
      expect(find.byType(ThemeChapter), findsOneWidget);
      expect(_skip, findsNothing);
    });

    await _onLayout(ShellLayout.bottomBar, () async {
      await _pumpApp(tester, ShellLayout.bottomBar);
      for (final OnboardingChapter chapter in OnboardingChapter.values) {
        await _walkTo(tester, chapter);
        expect(
          find.descendant(of: _skip, matching: find.text('Skip')),
          chapter.isStory ? findsOneWidget : findsNothing,
          reason: '$chapter',
        );
        expect(_primary, findsNothing, reason: '$chapter');
        if (chapter.isStory) {
          await _finishTask(tester);
          expect(_skip, findsOneWidget, reason: '$chapter done');
          expect(_primary, findsNothing, reason: '$chapter done');
        }
      }
      expect(find.text('Skip to setup'), findsNothing);

      await _pumpApp(tester, ShellLayout.bottomBar);
      await _walkTo(tester, OnboardingChapter.month);
      expect(_skip, findsOneWidget);
      await _tap(tester, _skip);
      expect(find.byType(ThemeChapter), findsOneWidget);
      expect(_skip, findsNothing);
    });
  });

  testWidgets('the phone cue names what is left and then says to swipe on', (
    WidgetTester tester,
  ) async {
    await _onLayout(ShellLayout.bottomBar, () async {
      await _pumpApp(tester, ShellLayout.bottomBar);
      final OnboardingController controller = _controller(tester);
      expect(_cueReading(''), findsOneWidget);
      expect(find.byKey(onboardingCueTrackKey), findsNothing);

      controller.plant();
      await _settle(tester);
      expect(_cueReading('growing…'), findsOneWidget);
      expect(find.byKey(onboardingCueTrackKey), findsNothing);
      controller.markGrown();
      await _settle(tester);
      expect(_cueReading('swipe to continue'), findsOneWidget);
      expect(find.byKey(onboardingCueTrackKey), findsOneWidget);

      for (final (OnboardingChapter chapter, String waiting)
          in <(OnboardingChapter, String)>[
            (OnboardingChapter.moment, 'write a line or two'),
            (OnboardingChapter.month, 'drag the slider below'),
            (OnboardingChapter.year, 'let the year grow'),
          ]) {
        await _walkTo(tester, chapter);
        expect(_cueReading(waiting), findsOneWidget, reason: '$chapter');
        expect(find.byKey(onboardingCueTrackKey), findsNothing);
        await _finishTask(tester);
        expect(
          _cueReading('swipe to continue'),
          findsOneWidget,
          reason: '$chapter done',
        );
        expect(find.byKey(onboardingCueTrackKey), findsOneWidget);
      }

      for (final OnboardingChapter chapter in <OnboardingChapter>[
        OnboardingChapter.day,
        OnboardingChapter.theme,
        OnboardingChapter.reminder,
        OnboardingChapter.week,
      ]) {
        if (chapter == OnboardingChapter.day) {
          controller.goTo(chapter);
          await _settle(tester);
        } else {
          await _walkTo(tester, chapter);
        }
        expect(
          _cueReading('swipe to continue'),
          findsOneWidget,
          reason: '$chapter',
        );
      }
      await _walkTo(tester, OnboardingChapter.tour);
      expect(_cueReading('swipe to start journaling'), findsOneWidget);
    });
  });

  testWidgets(
    'back keys, Android back and progress flowers only ever go back',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();

      await _onLayout(ShellLayout.sidebar, () async {
        await _pumpApp(tester, ShellLayout.sidebar);
        for (final OnboardingChapter chapter in OnboardingChapter.values) {
          expect(_mark(chapter.progressName), findsOneWidget);
        }

        await _walkTo(tester, OnboardingChapter.week);
        await _tap(tester, _mark('A day'));
        expect(_chapter(tester), OnboardingChapter.day);
        expect(find.byType(DayChapter), findsOneWidget);
        await _tap(tester, _mark('A day'));
        expect(_chapter(tester), OnboardingChapter.day);
        await _tap(tester, _mark('Week'));
        expect(_chapter(tester), OnboardingChapter.day);
        await _tap(tester, _mark('A month'));
        expect(_chapter(tester), OnboardingChapter.day);
        await _tap(tester, _mark('Opening'));
        expect(_chapter(tester), OnboardingChapter.opening);

        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_chapter(tester), OnboardingChapter.day);
        await _key(tester, LogicalKeyboardKey.enter);
        expect(_chapter(tester), OnboardingChapter.moment);
        _controller(tester).setNote('');
        await _settle(tester);
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_chapter(tester), OnboardingChapter.moment);
        await _key(tester, LogicalKeyboardKey.enter);
        expect(_chapter(tester), OnboardingChapter.moment);
        await _key(tester, LogicalKeyboardKey.numpadEnter);
        expect(_chapter(tester), OnboardingChapter.moment);
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(_chapter(tester), OnboardingChapter.day);
        await _key(tester, LogicalKeyboardKey.numpadEnter);
        expect(_chapter(tester), OnboardingChapter.moment);

        final Finder field = find.descendant(
          of: find.byType(MomentChapter),
          matching: find.byType(EditableText),
        );
        await tester.tap(field);
        await tester.pump();
        await tester.enterText(field, 'hello');
        await _settle(tester);
        expect(_controller(tester).canAdvance, isTrue);
        TextSelection caret() =>
            tester.widget<EditableText>(field).controller.selection;
        expect(caret(), const TextSelection.collapsed(offset: 5));

        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(caret(), const TextSelection.collapsed(offset: 4));
        expect(_chapter(tester), OnboardingChapter.moment);
        await _key(tester, LogicalKeyboardKey.arrowLeft);
        expect(caret(), const TextSelection.collapsed(offset: 3));
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(caret(), const TextSelection.collapsed(offset: 4));
        expect(_chapter(tester), OnboardingChapter.moment);
        await _key(tester, LogicalKeyboardKey.enter);
        expect(_chapter(tester), OnboardingChapter.moment);

        FocusManager.instance.primaryFocus?.unfocus();
        await _settle(tester);
        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_chapter(tester), OnboardingChapter.month);
      });

      await _onLayout(ShellLayout.bottomBar, () async {
        final int Function() pops = _countSystemPops(tester);
        await _pumpApp(tester, ShellLayout.bottomBar);

        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_chapter(tester), OnboardingChapter.opening);
        expect(find.byType(OpeningChapter), findsOneWidget);
        expect(pops(), 0);

        await _walkTo(tester, OnboardingChapter.month);
        expect(find.byType(MonthChapter), findsOneWidget);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_chapter(tester), OnboardingChapter.moment);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_chapter(tester), OnboardingChapter.day);
        await _tap(tester, _mark('Opening'));
        expect(_chapter(tester), OnboardingChapter.opening);
        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_chapter(tester), OnboardingChapter.opening);
        expect(pops(), 0);

        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_chapter(tester), OnboardingChapter.opening);
      });

      semantics.dispose();
    },
  );

  testWidgets(
    'a failed finish shows the error above the primary button or the control bar in the danger ink',
    (WidgetTester tester) async {
      for (final ShellLayout layout in _layouts) {
        await _onLayout(layout, () async {
          await _pumpApp(
            tester,
            layout,
            settings: FakeSettingsRepository(
              storedValues: false,
              writeError: StateError('disk full'),
            ),
          );
          await _walkTo(tester, OnboardingChapter.tour);
          expect(find.text(_finishError), findsNothing);

          if (layout == ShellLayout.sidebar) {
            await _tap(tester, _primary);
          } else {
            await _swipe(tester, -120);
          }

          expect(find.byType(TourChapter), findsOneWidget);
          final Finder error = find.text(_finishError);
          expect(error, findsOneWidget);
          expect(
            tester.widget<Text>(error).style?.color,
            FieldNotesColors.light.dangerInk,
          );
          if (layout == ShellLayout.sidebar) {
            expect(
              tester.getRect(error).bottom,
              lessThanOrEqualTo(tester.getRect(_primary).top),
            );
            expect(_primaryReading(_startLabel(layout)), findsOneWidget);
          } else {
            expect(
              tester.getRect(error).bottom,
              lessThanOrEqualTo(
                tester.getRect(find.byKey(onboardingControlBarKey)).top,
              ),
            );
            expect(_primary, findsNothing);
            expect(_cueReading('swipe to start journaling'), findsOneWidget);
          }
        });
      }
    },
  );

  testWidgets('the map replay shows the tour alone and Done closes it', (
    WidgetTester tester,
  ) async {
    for (final ShellLayout layout in _layouts) {
      await _onLayout(layout, () async {
        await _pumpApp(tester, layout);
        _controller(tester).skipToSetup();
        await _walkTo(tester, OnboardingChapter.tour);
        if (layout == ShellLayout.sidebar) {
          await _tap(tester, _primary);
        } else {
          await _swipe(tester, -120);
        }
        expect(find.byType(OnboardingFrame), findsNothing);

        _controller(tester).showMap();
        await _settle(tester);
        expect(find.byType(TourChapter), findsOneWidget);
        expect(find.byKey(onboardingProgressKey), findsNothing);
        expect(_skip, findsNothing);
        expect(find.byKey(onboardingToggleKey), findsNothing);
        expect(_cue, findsNothing);
        expect(find.byKey(onboardingControlBarKey), findsNothing);
        expect(find.byKey(onboardingBackKey), findsNothing);
        expect(_primaryReading('Done'), findsOneWidget);

        await _swipe(tester, -120);
        expect(find.byType(TourChapter), findsOneWidget);
        expect(
          _container(tester).read(onboardingControllerProvider),
          const OnboardingFlowMap(),
        );

        await _tap(tester, _primary);
        expect(find.byType(OnboardingFrame), findsNothing);
        expect(
          _container(tester).read(onboardingControllerProvider),
          const OnboardingFlowHidden(),
        );
      });
    }
  });
}
