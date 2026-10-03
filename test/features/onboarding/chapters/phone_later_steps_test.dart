import 'dart:async';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/onboarding/chapters/month_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/reminder_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/sample_year.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/week_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/year_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../app/support/app_shell_harness.dart';
import '../../capture/core/capture_test_support.dart' show FakeNoteWriter;
import '../../settings/support/fake_settings_repository.dart';
import '../../settings/support/recording_reminder_scheduler.dart';

const Size _phone = Size(384, 832);
const Size _mac = Size(1280, 800);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _controlBarReserve = 72;
const double _phoneTitleTop = _statusBar + 48;
const double _macTitleTop = 52;
const int _meadowFrames = 6000;

const String _monthKicker = 'a month';
const String _monthTitle = 'Give it a few weeks.';
const String _monthCue = 'drag to see the weeks ahead';
const String _yearKicker = 'a year';
const String _yearTitle = 'This is roughly what a year of you looks like.';
const String _yearCaption =
    'every flower is a day · drag the meadow to look around';
const String _laterKicker = 'and you';
const String _themeTitle = 'Daylight or lamplight?';
const String _reminderTitle = 'When should we check in?';
const String _weekTitle = 'Your week starts on…';
const String _privacy = 'Your stories stay private, on this device.';

const Color _cream = Color(0xFFFBF3E4);
const Color _shadeTop = Color.fromRGBO(20, 14, 8, 0.55);

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

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  ShellLayout layout,
) async {
  final bool phone = layout == ShellLayout.bottomBar;
  tester.view.physicalSize = phone ? _phone : _mac;
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

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

OnboardingController _controller(ProviderContainer container) =>
    container.read(onboardingControllerProvider.notifier);

OnboardingFlowRunning _running(ProviderContainer container) =>
    container.read(onboardingControllerProvider) as OnboardingFlowRunning;

Future<void> _openMonth(
  WidgetTester tester,
  ProviderContainer container,
) async {
  _controller(container)
    ..plant()
    ..markGrown()
    ..next()
    ..next()
    ..setNote('A first line about today')
    ..next();
  await _rest(tester);
  expect(_running(container).chapter, OnboardingChapter.month);
}

Future<void> _openYear(WidgetTester tester, ProviderContainer container) async {
  await _openMonth(tester, container);
  _controller(container)
    ..setMonthFill(1)
    ..next();
  await _rest(tester);
  expect(_running(container).chapter, OnboardingChapter.year);
  final MeadowStageState stage = tester.state<MeadowStageState>(
    find.byType(MeadowStage),
  );
  for (int frame = 0; frame < _meadowFrames && !stage.debugIsReady; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump();
  }
  expect(stage.debugIsReady, isTrue, reason: 'the meadow never finished');
  await tester.pump();
}

Future<void> _openLater(
  WidgetTester tester,
  ProviderContainer container,
  OnboardingChapter chapter,
) async {
  _controller(container).skipToSetup();
  await _rest(tester);
  for (
    int step = 0;
    step < 2 && _running(container).chapter.index < chapter.index;
    step++
  ) {
    unawaited(_controller(container).next());
    await _rest(tester);
  }
  expect(_running(container).chapter, chapter);
}

Future<void> _growWholeYear(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pump(const Duration(seconds: 12));
  await tester.pump();
  expect(_running(container).draft.yearDay, sampleYearDays);
}

TextStyle _style(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style!;

Rect _bar(WidgetTester tester) =>
    tester.getRect(find.byKey(onboardingControlBarKey));

Rect _card(WidgetTester tester, Key row) => tester.getRect(
  find.ancestor(of: find.byKey(row), matching: find.byType(Container)).first,
);

void _expectPhoneHeading(
  WidgetTester tester,
  String kicker,
  String title, {
  required String reason,
}) {
  expect(
    tester.getRect(find.text(kicker)).top,
    _phoneTitleTop,
    reason: '$reason kicker top',
  );
  final TextStyle kickerStyle = _style(tester, find.text(kicker));
  expect(kickerStyle.fontFamily, TypographyTokens.accent, reason: reason);
  expect(kickerStyle.fontSize, 18, reason: reason);
  final TextStyle titleStyle = _style(tester, find.text(title));
  expect(titleStyle.fontFamily, TypographyTokens.serif, reason: reason);
  expect(titleStyle.fontSize, 28, reason: reason);
  expect(titleStyle.height, 1.08, reason: reason);
}

void _expectCardAtBottom(
  WidgetTester tester,
  Rect card, {
  required double clearance,
  required String reason,
}) {
  final Rect bar = _bar(tester);
  expect(card.left, 16, reason: '$reason card left');
  expect(card.right, _phone.width - 16, reason: '$reason card right');
  expect(
    card.bottom,
    moreOrLessEquals(
      _phone.height - _gestureBar - _controlBarReserve - clearance,
    ),
    reason: '$reason card bottom',
  );
  expect(card.bottom, lessThan(bar.top), reason: '$reason above the bar');
}

void _expectCentredBetween(
  Rect inner,
  double top,
  double bottom, {
  required String reason,
}) {
  expect(
    inner.center.dy,
    moreOrLessEquals((top + bottom) / 2, epsilon: 0.5),
    reason: '$reason centred vertically',
  );
  expect(
    inner.center.dx,
    moreOrLessEquals(_phone.width / 2, epsilon: 0.5),
    reason: '$reason centred horizontally',
  );
  expect(inner.top, greaterThan(top), reason: '$reason below the title');
  expect(inner.bottom, lessThan(bottom), reason: '$reason above the card');
}

int _linesAt(RenderParagraph paragraph, double width) {
  final TextPainter painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: width);
  final int lines = painter.computeLineMetrics().length;
  painter.dispose();
  return lines;
}

void main() {
  testWidgets(
    'the phone calendar step has larger cells and the slider at the bottom',
    (WidgetTester tester) async {
      await _onLayout(ShellLayout.bottomBar, () async {
        final ProviderContainer container = await _pumpApp(
          tester,
          ShellLayout.bottomBar,
        );
        await _openMonth(tester, container);
        _expectPhoneHeading(tester, _monthKicker, _monthTitle, reason: 'month');

        final OnboardingDraft draft = _running(container).draft;
        final DateTime today = DateTime.parse(draft.entryDate);
        final int lastDay = DateTime(today.year, today.month + 1, 0).day;
        final List<Rect> days = <Rect>[
          for (int day = 1; day <= lastDay; day++)
            tester.getRect(find.byKey(monthDayKey(day))),
        ];
        for (final (int index, Rect day) in days.indexed) {
          expect(day.size, const Size(44, 50), reason: 'day ${index + 1}');
        }
        for (int index = 1; index < days.length; index++) {
          if (days[index].top == days[index - 1].top) {
            expect(
              days[index].left - days[index - 1].right,
              moreOrLessEquals(5),
              reason: 'gap before day ${index + 1}',
            );
          }
        }
        expect(days[7].top - days[0].top, moreOrLessEquals(55));
        final Rect letters = tester.getRect(find.byKey(monthLettersKey));
        expect(letters.width, moreOrLessEquals(7 * 44 + 6 * 5));
        expect(letters.height, 18);
        expect(letters.center.dx, moreOrLessEquals(_phone.width / 2));
        for (final Text letter in tester.widgetList<Text>(
          find.descendant(
            of: find.byKey(monthLettersKey),
            matching: find.byType(Text),
          ),
        )) {
          expect(letter.style!.fontSize, 10);
        }
        final Finder dayOne = find.descendant(
          of: find.byKey(monthDayKey(1)),
          matching: find.text('1'),
        );
        expect(_style(tester, dayOne).fontSize, 9);
        expect(
          tester
              .widget<FlowerBloom>(
                find.descendant(
                  of: find.byKey(monthDayKey(today.day)),
                  matching: find.byType(FlowerBloom),
                ),
              )
              .size,
          30,
        );

        final Finder name = find.text(monthName(today.month));
        final TextStyle nameStyle = _style(tester, name);
        expect(nameStyle.fontFamily, TypographyTokens.serif);
        expect(nameStyle.fontSize, 20);
        final Finder count = find.textContaining('flower');
        final TextStyle countStyle = _style(tester, count);
        expect(countStyle.fontFamily, TypographyTokens.sans);
        expect(countStyle.fontSize, 12);

        final Rect slider = tester.getRect(find.byKey(monthSliderKey));
        final Rect bar = _bar(tester);
        expect(slider.height, 36);
        expect(slider.bottom, lessThan(bar.top));
        expect(bar.top - slider.bottom, lessThanOrEqualTo(24));
        expect(slider.left, greaterThanOrEqualTo(14));
        expect(slider.right, lessThanOrEqualTo(_phone.width - 14));
        final Finder cue = find.text(_monthCue);
        final TextStyle cueStyle = _style(tester, cue);
        expect(cueStyle.fontFamily, TypographyTokens.accent);
        expect(cueStyle.fontSize, 18);
        final Finder value = find.text('drag to look ahead →');
        final TextStyle valueStyle = _style(tester, value);
        expect(valueStyle.fontFamily, TypographyTokens.accent);
        expect(valueStyle.fontSize, 15);
        expect(
          valueStyle.color!.toARGB32(),
          FieldNotesColors.of(tester.element(find.byType(MonthChapter)))
              .accentInk
              .toARGB32(),
        );
        final Rect cueRect = tester.getRect(cue);
        expect(cueRect.bottom, lessThanOrEqualTo(slider.top));
        expect(slider.top - cueRect.bottom, lessThan(12));

        final double spaceTop = tester.getRect(find.text(_monthTitle)).bottom;
        final double spaceBottom = cueRect.top - 8;
        final double blockTop = tester.getRect(name).top;
        final double blockBottom = days
            .map((Rect day) => day.bottom)
            .reduce((double a, double b) => a > b ? a : b);
        expect(
          (blockTop + blockBottom) / 2,
          moreOrLessEquals((spaceTop + spaceBottom) / 2, epsilon: 1),
        );

        await tester.tapAt(Offset(slider.left + 40, slider.top - 3));
        await tester.pump();
        expect(
          _running(container).draft.monthFill,
          greaterThan(0),
          reason: 'the slider reaches a little above its track',
        );
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });
    },
  );

  testWidgets(
    'the phone meadow step is full-bleed with its scrubber above the control bar',
    (WidgetTester tester) async {
      await _onLayout(ShellLayout.bottomBar, () async {
        final ProviderContainer container = await _pumpApp(
          tester,
          ShellLayout.bottomBar,
        );
        await _openYear(tester, container);
        expect(tester.getRect(find.byType(MeadowStage)), Offset.zero & _phone);
        expect(tester.getRect(find.text(_yearKicker)).top, _phoneTitleTop);
        final TextStyle titleStyle = _style(tester, find.text(_yearTitle));
        expect(titleStyle.fontSize, 28);
        expect(titleStyle.height, 1.08);
        expect(titleStyle.color!.toARGB32(), _cream.toARGB32());
        expect(titleStyle.shadows, isNotEmpty);
        final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          find.text(_yearTitle),
        );
        final int lines = _linesAt(paragraph, paragraph.size.width);
        expect(lines, greaterThan(1));
        expect(_linesAt(paragraph, _phone.width - 40), lines);
        expect(paragraph.size.width, lessThan(_phone.width - 40));
        expect(
          _linesAt(paragraph, paragraph.size.width - 8),
          greaterThan(lines),
          reason: 'the title wraps balanced, as narrow as its lines allow',
        );

        final Finder shade = find.descendant(
          of: find.byType(YearChapter),
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).gradient is LinearGradient,
          ),
        );
        expect(shade, findsOneWidget);
        expect(tester.getRect(shade), const Rect.fromLTWH(0, 0, 384, 220));
        final LinearGradient fade =
            (tester.widget<DecoratedBox>(shade).decoration as BoxDecoration)
                    .gradient!
                as LinearGradient;
        expect(fade.colors.first.toARGB32(), _shadeTop.toARGB32());
        expect(fade.colors.last.a, 0);

        final Finder panel = find.ancestor(
          of: find.byKey(yearSliderKey),
          matching: find.byType(GlassSurface),
        );
        expect(panel, findsOneWidget);
        expect(
          tester.widget<GlassSurface>(panel).borderRadius,
          const BorderRadius.all(Radius.circular(20)),
        );
        final Rect glass = tester.getRect(panel);
        final Rect bar = _bar(tester);
        expect(glass.left, 12);
        expect(
          glass.bottom,
          moreOrLessEquals(
            _phone.height - _gestureBar - _controlBarReserve - 12,
          ),
        );
        expect(glass.bottom, lessThan(bar.top));
        expect(bar.top - glass.bottom, lessThanOrEqualTo(20));
        expect(tester.getRect(find.byKey(yearSliderKey)).height, 32);

        final Rect replay = tester.getRect(find.byKey(yearReplayKey));
        expect(replay.size, const Size(52, 52));
        expect(replay.left - glass.right, moreOrLessEquals(8));
        expect(replay.right, _phone.width - 12);
        expect(replay.center.dy, moreOrLessEquals(glass.center.dy));
        expect(
          find.descendant(
            of: find.byKey(yearReplayKey),
            matching: find.byType(GlassSurface),
          ),
          findsOneWidget,
        );
        final TextStyle month = _style(
          tester,
          find.descendant(
            of: panel,
            matching: find.text(
              yearMonthLabel(_running(container).draft.yearDay),
            ),
          ),
        );
        expect(month.fontFamily, TypographyTokens.accent);
        expect(month.fontSize, 20);
        expect(month.fontWeight, FontWeight.w700);
        expect(month.color!.toARGB32(), _cream.toARGB32());
        final TextStyle count = _style(
          tester,
          find.descendant(of: panel, matching: find.textContaining(' days')),
        );
        expect(count.fontSize, 11);
        expect(find.text(_yearCaption), findsNothing);

        await _growWholeYear(tester, container);
        final Finder caption = find.text(_yearCaption);
        expect(caption, findsOneWidget);
        final TextStyle captionStyle = _style(tester, caption);
        expect(captionStyle.fontFamily, TypographyTokens.accent);
        expect(captionStyle.fontSize, 17);
        expect(captionStyle.color!.toARGB32(), _cream.toARGB32());
        final Rect captionRect = tester.getRect(caption);
        expect(captionRect.bottom, lessThan(glass.top));
        expect(
          captionRect.center.dx,
          moreOrLessEquals(_phone.width / 2, epsilon: 0.5),
        );
        expect(tester.getRect(panel), glass);
        expect(
          tester.getSemantics(find.byKey(yearReplayKey)),
          isSemantics(
            label: 'Replay the year',
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });
    },
  );

  testWidgets(
    'theme, reminder and week previews fill the middle with options at the bottom',
    (WidgetTester tester) async {
      await _onLayout(ShellLayout.bottomBar, () async {
        final ProviderContainer container = await _pumpApp(
          tester,
          ShellLayout.bottomBar,
        );
        await _openLater(tester, container, OnboardingChapter.theme);
        _expectPhoneHeading(tester, _laterKicker, _themeTitle, reason: 'theme');
        final Rect themeCard = _card(tester, themeChoiceKey(Appearance.light));
        expect(
          themeCard.contains(
            tester.getCenter(find.byKey(themeChoiceKey(Appearance.system))),
          ),
          isTrue,
        );
        _expectCardAtBottom(tester, themeCard, clearance: 14, reason: 'theme');
        final Rect preview = tester.getRect(find.byKey(themePreviewKey));
        expect(preview.width, moreOrLessEquals(130 * 1.4));
        expect(preview.height, moreOrLessEquals(200 * 1.4));
        _expectCentredBetween(
          preview,
          tester.getRect(find.text(_themeTitle)).bottom,
          themeCard.top,
          reason: 'theme preview',
        );

        await _openLater(tester, container, OnboardingChapter.reminder);
        _expectPhoneHeading(
          tester,
          _laterKicker,
          _reminderTitle,
          reason: 'reminder',
        );
        final Rect reminderCard = _card(
          tester,
          reminderChoiceKey(ReminderChoice.morning),
        );
        expect(
          reminderCard.contains(
            tester.getCenter(find.byKey(reminderChoiceKey(ReminderChoice.off))),
          ),
          isTrue,
        );
        _expectCardAtBottom(
          tester,
          reminderCard,
          clearance: 14,
          reason: 'reminder',
        );
        final Finder timeFinder = find.byKey(reminderTimeKey);
        final TextStyle timeStyle = _style(tester, timeFinder);
        expect(timeStyle.fontFamily, TypographyTokens.serif);
        expect(timeStyle.fontSize, 72);
        expect(
          timeStyle.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        final Rect time = tester.getRect(timeFinder);
        final Rect notification = tester.getRect(
          find.byKey(reminderPreviewKey),
        );
        expect(time.height, moreOrLessEquals(72));
        expect(notification.height, moreOrLessEquals(64));
        expect(notification.top - time.bottom, moreOrLessEquals(18));
        _expectCentredBetween(
          time.expandToInclude(notification),
          tester.getRect(find.text(_reminderTitle)).bottom,
          reminderCard.top,
          reason: 'reminder time and notification',
        );

        await _openLater(tester, container, OnboardingChapter.week);
        _expectPhoneHeading(tester, _laterKicker, _weekTitle, reason: 'week');
        final Rect weekCard = _card(tester, weekChoiceKey(WeekStart.sunday));
        expect(
          weekCard.contains(
            tester.getCenter(find.byKey(weekChoiceKey(WeekStart.saturday))),
          ),
          isTrue,
        );
        final Rect privacy = tester.getRect(find.byKey(weekPrivacyKey));
        expect(privacy.top - weekCard.bottom, moreOrLessEquals(12));
        expect(
          privacy.bottom,
          moreOrLessEquals(
            _phone.height - _gestureBar - _controlBarReserve - 12,
          ),
        );
        expect(privacy.bottom, lessThan(_bar(tester).top));
        expect(weekCard.left, 16);
        expect(weekCard.right, _phone.width - 16);
        final TextStyle privacyStyle = _style(tester, find.text(_privacy));
        expect(privacyStyle.fontFamily, TypographyTokens.sans);
        expect(privacyStyle.fontSize, 12);
        final Rect strip = tester.getRect(find.byKey(weekStripKey));
        expect(strip.width, moreOrLessEquals(259 * 1.3));
        expect(strip.height, moreOrLessEquals(84 * 1.3));
        _expectCentredBetween(
          strip,
          tester.getRect(find.text(_weekTitle)).bottom,
          weekCard.top,
          reason: 'week strip',
        );
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });

      await _onLayout(ShellLayout.sidebar, () async {
        final ProviderContainer container = await _pumpApp(
          tester,
          ShellLayout.sidebar,
        );
        double titleTop(String kicker) =>
            tester.getRect(find.text(kicker)).top -
            tester.getRect(find.byType(OnboardingFrame)).top;

        await _openMonth(tester, container);
        expect(titleTop(_monthKicker), _macTitleTop, reason: 'calendar');
        _controller(container)
          ..setMonthFill(1)
          ..next();
        await _rest(tester);
        expect(_running(container).chapter, OnboardingChapter.year);
        expect(titleTop(_yearKicker), _macTitleTop, reason: 'meadow');

        for (final (OnboardingChapter chapter, String title)
            in <(OnboardingChapter, String)>[
              (OnboardingChapter.theme, _themeTitle),
              (OnboardingChapter.reminder, _reminderTitle),
              (OnboardingChapter.week, _weekTitle),
            ]) {
          await _openLater(tester, container, chapter);
          expect(find.text(title), findsOneWidget, reason: chapter.name);
          expect(titleTop(_laterKicker), _macTitleTop, reason: chapter.name);
        }
        await _unmount(tester);
      });
    },
  );

  testWidgets('the calendar slider and the meadow never swipe the page', (
    WidgetTester tester,
  ) async {
    await _onLayout(ShellLayout.bottomBar, () async {
      final ProviderContainer container = await _pumpApp(
        tester,
        ShellLayout.bottomBar,
      );
      await _openMonth(tester, container);
      _controller(container).setMonthFill(0.5);
      await _rest(tester);
      expect(_controller(container).canAdvance, isTrue);

      await tester.dragFrom(
        tester.getCenter(find.byKey(monthSliderKey)),
        const Offset(-150, 0),
      );
      await _rest(tester);
      expect(_running(container).chapter, OnboardingChapter.month);
      final double leftward = _running(container).draft.monthFill;
      expect(leftward, lessThan(0.5), reason: 'the slider took the drag');

      await tester.dragFrom(
        tester.getCenter(find.byKey(monthSliderKey)),
        const Offset(150, 0),
      );
      await _rest(tester);
      expect(_running(container).chapter, OnboardingChapter.month);
      expect(_running(container).draft.monthFill, greaterThan(leftward));

      await tester.dragFrom(
        tester.getCenter(find.text(_monthCue)),
        const Offset(150, 0),
      );
      await _rest(tester);
      expect(_running(container).chapter, OnboardingChapter.month);

      await tester.dragFrom(
        tester.getCenter(find.text(_monthTitle)),
        const Offset(150, 0),
      );
      await _rest(tester);
      expect(
        _running(container).chapter,
        OnboardingChapter.moment,
        reason: 'a drag on the title still swipes back',
      );
      await _unmount(tester);

      final ProviderContainer meadow = await _pumpApp(
        tester,
        ShellLayout.bottomBar,
      );
      await _openYear(tester, meadow);
      await _growWholeYear(tester, meadow);
      expect(_controller(meadow).canAdvance, isTrue);
      expect(find.text(yearDragHint), findsOneWidget);

      await tester.dragFrom(
        tester.getCenter(find.byType(MeadowStage)),
        const Offset(-160, 0),
      );
      await _rest(tester);
      expect(_running(meadow).chapter, OnboardingChapter.year);
      expect(
        find.text(yearDragHint),
        findsNothing,
        reason: 'the meadow took the drag',
      );

      await tester.dragFrom(
        tester.getCenter(find.byType(MeadowStage)),
        const Offset(160, 0),
      );
      await _rest(tester);
      expect(_running(meadow).chapter, OnboardingChapter.year);

      await tester.dragFrom(
        tester.getCenter(find.byKey(yearSliderKey)),
        const Offset(-160, 0),
      );
      await _rest(tester);
      expect(_running(meadow).chapter, OnboardingChapter.year);
      expect(_running(meadow).draft.yearScrubbed, isTrue);

      await tester.flingFrom(
        tester.getCenter(find.byKey(onboardingCueKey)),
        const Offset(-120, 0),
        800,
      );
      await _rest(tester);
      expect(
        _running(meadow).chapter,
        OnboardingChapter.theme,
        reason: 'a swipe on the control bar still leaves the meadow',
      );
      await _unmount(tester);
    });
  });
}
