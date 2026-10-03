import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/reminder_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/week_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/onboarding/onboarding_swipe.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../capture/core/capture_test_support.dart' show FakeNoteWriter;
import '../settings/support/fake_settings_repository.dart';
import '../settings/support/recording_reminder_scheduler.dart';

const Size _phone = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;

const String _momentTitle = 'Write a little about today.';
const String _plantFirst = 'Tap anywhere to plant your seed first.';
const String _writeFirst = 'Write a line or two first.';

typedef _Placed = ({Rect rect, double opacity});

Future<void> _onAndroid(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

List<Override> _overrides() {
  final Set<Object> replaced = <Object>{
    settingsRepositoryProvider,
    reminderSchedulerProvider,
  };
  return <Override>[
    for (final Override override in shellOverrides())
      if (!replaced.contains(override.origin)) override,
    settingsRepositoryProvider.overrideWithValue(
      FakeSettingsRepository(storedValues: false),
    ),
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

Future<void> _rest(WidgetTester tester) async {
  await _settle(tester);
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
}

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = _phone;
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
      key: UniqueKey(),
      overrides: _overrides(),
      child: const FieldNotesApp(),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
}

OnboardingController _controller(ProviderContainer container) =>
    container.read(onboardingControllerProvider.notifier);

OnboardingFlowRunning _running(ProviderContainer container) =>
    container.read(onboardingControllerProvider) as OnboardingFlowRunning;

OnboardingChapter _chapter(ProviderContainer container) =>
    _running(container).chapter;

Offset _middle(WidgetTester tester) =>
    tester.getCenter(find.byType(OnboardingFrame));

Future<void> _fling(WidgetTester tester, Offset from, double dx) async {
  await tester.flingFrom(from, Offset(dx, 0), 800);
  await _settle(tester);
}

Finder get _cue => find.byKey(onboardingCueKey);

Finder _cueReading(String text) =>
    find.descendant(of: _cue, matching: find.text(text));

Rect _rectOf(Element element) {
  final RenderBox box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

double _opacityOf(Element element) {
  double opacity = 1;
  element.visitAncestorElements((Element ancestor) {
    final Widget widget = ancestor.widget;
    if (widget is Opacity) {
      opacity *= widget.opacity;
    } else if (widget is FadeTransition) {
      opacity *= widget.opacity.value;
    }
    return widget is! OnboardingFrame;
  });
  return opacity;
}

List<_Placed> _placed(WidgetTester tester, Finder chapter) => <_Placed>[
  (
    rect: _rectOf(chapter.evaluate().single),
    opacity: _opacityOf(chapter.evaluate().single),
  ),
  for (final Element text
      in find
          .descendant(of: chapter, matching: find.byType(RichText))
          .evaluate())
    (rect: _rectOf(text), opacity: _opacityOf(text)),
];

void _expectAtRest(
  List<_Placed> now,
  List<_Placed> rest, {
  required String reason,
}) {
  expect(now, hasLength(rest.length), reason: reason);
  for (int index = 0; index < rest.length; index++) {
    final _Placed was = rest[index];
    final _Placed is_ = now[index];
    expect(
      is_.rect.left,
      moreOrLessEquals(was.rect.left, epsilon: 0.01),
      reason: '$reason element $index left',
    );
    expect(
      is_.rect.top,
      moreOrLessEquals(was.rect.top, epsilon: 0.01),
      reason: '$reason element $index top',
    );
    expect(
      is_.opacity,
      moreOrLessEquals(was.opacity, epsilon: 0.001),
      reason: '$reason element $index opacity',
    );
  }
}

void _expectSwipeWrappersAtRest(WidgetTester tester, {required String reason}) {
  final Finder wrappers = find.byWidgetPredicate(
    (Widget widget) =>
        widget is OnboardingSwipeContent || widget is OnboardingSwipeLayer,
  );
  expect(wrappers, findsWidgets, reason: reason);
  for (final Element wrapper in wrappers.evaluate()) {
    final Finder own = find.byElementPredicate(
      (Element element) => identical(element, wrapper),
    );
    final Opacity fade = tester.widget<Opacity>(
      find.descendant(of: own, matching: find.byType(Opacity)).first,
    );
    expect(fade.opacity, 1, reason: '$reason wrapper opacity');
    final Transform shift = tester.widget<Transform>(
      find.descendant(of: own, matching: find.byType(Transform)).first,
    );
    expect(
      shift.transform.getTranslation().x,
      0,
      reason: '$reason wrapper shift',
    );
  }
}

void main() {
  testWidgets(
    'a left swipe advances a complete step and a right swipe goes back',
    (WidgetTester tester) async {
      await _onAndroid(() async {
        final ProviderContainer container = await _pumpApp(tester);
        _controller(container)
          ..plant()
          ..markGrown();
        await _settle(tester);
        expect(find.byKey(onboardingPrimaryKey), findsNothing);
        expect(find.text('Begin'), findsNothing);

        await _fling(tester, _middle(tester), -120);
        expect(_chapter(container), OnboardingChapter.day);
        expect(find.byKey(onboardingPrimaryKey), findsNothing);
        expect(find.text('Next'), findsNothing);

        await _fling(tester, _middle(tester), 120);
        expect(_chapter(container), OnboardingChapter.opening);

        await _fling(tester, _middle(tester), -120);
        expect(_chapter(container), OnboardingChapter.day);
        await _fling(tester, _middle(tester), -40);
        expect(_chapter(container), OnboardingChapter.day);
        await _fling(tester, _middle(tester), -120);
        expect(_chapter(container), OnboardingChapter.moment);
        expect(find.byKey(onboardingPrimaryKey), findsNothing);

        await _fling(tester, tester.getCenter(find.text(_momentTitle)), 120);
        expect(_chapter(container), OnboardingChapter.day);
        await _fling(tester, _middle(tester), 40);
        expect(_chapter(container), OnboardingChapter.day);

        await tester.binding.handlePopRoute();
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.opening);
      });
    },
  );

  testWidgets(
    'a blocked swipe springs back with a toast and the cue names what is left',
    (WidgetTester tester) async {
      await _onAndroid(() async {
        final ProviderContainer container = await _pumpApp(tester);
        expect(_chapter(container), OnboardingChapter.opening);
        expect(
          find.descendant(of: _cue, matching: find.byType(RichText)),
          findsOneWidget,
        );
        expect(_cueReading(''), findsOneWidget);
        expect(find.byKey(onboardingCueTrackKey), findsNothing);

        await _fling(tester, _middle(tester), -120);
        expect(_chapter(container), OnboardingChapter.opening);
        expect(_running(container).draft.planted, isFalse);
        expect(find.text(_plantFirst), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2300));
        expect(find.text(_plantFirst), findsNothing);

        _controller(container)
          ..plant()
          ..markGrown()
          ..next()
          ..next();
        await _rest(tester);
        expect(_chapter(container), OnboardingChapter.moment);
        expect(_cueReading('write a line or two'), findsOneWidget);
        expect(find.byKey(onboardingCueTrackKey), findsNothing);

        final Finder title = find.text(_momentTitle);
        final Rect rest = tester.getRect(title);
        final TestGesture gesture = await tester.startGesture(
          tester.getCenter(title),
        );
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump();
        await gesture.moveBy(const Offset(-80, 0));
        await tester.pump();
        expect(
          tester.getRect(title).left,
          moreOrLessEquals(rest.left - 100 * 0.18),
        );
        expect(
          _opacityOf(title.evaluate().single),
          moreOrLessEquals(1 - 100 / 260),
        );

        await gesture.up();
        await tester.pump();
        expect(find.text(_writeFirst), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 400));
        final Rect toast = tester.getRect(find.byKey(onboardingToastKey));
        expect(toast.width, 270);
        expect(toast.center.dx, moreOrLessEquals(_phone.width / 2));
        expect(
          toast.bottom,
          moreOrLessEquals(_phone.height - _gestureBar - 86),
        );
        expect(_chapter(container), OnboardingChapter.moment);
        expect(tester.getRect(title), rest);
        expect(_opacityOf(title.evaluate().single), 1);
        expect(find.text(_writeFirst), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 2000));
        expect(find.text(_writeFirst), findsNothing);
        expect(_chapter(container), OnboardingChapter.moment);
      });
    },
  );

  testWidgets('a cancelled or completed swipe restores every faded element', (
    WidgetTester tester,
  ) async {
    await _onAndroid(() async {
      final ProviderContainer container = await _pumpApp(tester);
      final OnboardingController controller = _controller(container);
      controller.skipToSetup();
      await _rest(tester);
      expect(_chapter(container), OnboardingChapter.theme);
      final Finder theme = find.byType(ThemeChapter);
      final List<_Placed> themeRest = _placed(tester, theme);

      controller.next();
      await _rest(tester);
      expect(_chapter(container), OnboardingChapter.reminder);
      final Finder reminder = find.byType(ReminderChapter);
      final List<_Placed> reminderRest = _placed(tester, reminder);

      controller.next();
      await _rest(tester);
      expect(_chapter(container), OnboardingChapter.week);
      final Finder week = find.byType(WeekChapter);
      final List<_Placed> weekRest = _placed(tester, week);

      final TestGesture gesture = await tester.startGesture(_middle(tester));
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      final List<_Placed> dragged = _placed(tester, week);
      for (int index = 0; index < weekRest.length; index++) {
        expect(
          dragged[index].rect.left,
          moreOrLessEquals(weekRest[index].rect.left - 50 * 0.6),
          reason: 'week element $index mid-drag',
        );
        expect(
          dragged[index].opacity,
          moreOrLessEquals(weekRest[index].opacity * (1 - 50 / 260)),
          reason: 'week element $index mid-drag opacity',
        );
      }

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_chapter(container), OnboardingChapter.week);
      await tester.pump(const Duration(milliseconds: 250));
      _expectAtRest(
        _placed(tester, week),
        weekRest,
        reason: 'week after a short drag',
      );
      _expectSwipeWrappersAtRest(tester, reason: 'week after a short drag');

      await tester.flingFrom(_middle(tester), const Offset(120, 0), 800);
      await tester.pump();
      expect(_chapter(container), OnboardingChapter.reminder);
      _expectSwipeWrappersAtRest(tester, reason: 'reminder as it opens');
      await _rest(tester);
      _expectAtRest(
        _placed(tester, reminder),
        reminderRest,
        reason: 'reminder after swiping back',
      );

      await tester.flingFrom(_middle(tester), const Offset(120, 0), 800);
      await tester.pump();
      expect(_chapter(container), OnboardingChapter.theme);
      _expectSwipeWrappersAtRest(tester, reason: 'theme as it opens');
      await _rest(tester);
      _expectAtRest(
        _placed(tester, theme),
        themeRest,
        reason: 'theme after swiping back',
      );
      _expectSwipeWrappersAtRest(tester, reason: 'theme after swiping back');

      controller.next();
      await _rest(tester);
      controller.next();
      await _rest(tester);
      expect(_chapter(container), OnboardingChapter.week);
      _expectAtRest(
        _placed(tester, week),
        weekRest,
        reason: 'week after returning',
      );
    });
  });

  testWidgets('the capture text field never swipes the page', (
    WidgetTester tester,
  ) async {
    await _onAndroid(() async {
      final ProviderContainer container = await _pumpApp(tester);
      _controller(container)
        ..plant()
        ..markGrown()
        ..next()
        ..next()
        ..setNote('A first line about today');
      await _rest(tester);
      expect(_chapter(container), OnboardingChapter.moment);
      expect(_controller(container).canAdvance, isTrue);
      final Finder field = find.byType(EditableText);
      expect(field, findsOneWidget);
      final Rect area = tester.getRect(find.byKey(momentFieldKey));
      final List<Offset> starts = <Offset>[
        tester.getCenter(field),
        area.center,
        area.bottomCenter - const Offset(0, 12),
      ];

      for (final Offset start in starts) {
        await tester.dragFrom(start, const Offset(-150, 0));
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.moment, reason: '$start');
        expect(field, findsOneWidget, reason: '$start');
        expect(find.text(_writeFirst), findsNothing, reason: '$start');

        await tester.dragFrom(start, const Offset(150, 0));
        await _settle(tester);
        expect(_chapter(container), OnboardingChapter.moment, reason: '$start');
        expect(field, findsOneWidget, reason: '$start');
      }

      await tester.dragFrom(
        tester.getCenter(find.text(_momentTitle)),
        const Offset(-150, 0),
      );
      await _settle(tester);
      expect(field, findsNothing);
    });
  });
}
