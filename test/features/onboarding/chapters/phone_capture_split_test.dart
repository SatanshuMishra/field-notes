import 'package:field_notes/app/app.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/motion/waveform_bob.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/month_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/other_ways_panel.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

const String _kicker = 'a moment';
const String _noteTitle = 'Write a little about today.';
const String _otherTitle = 'Some days are easier said.';
const String _savedHint = 'saved to today ✓';
const String _toast =
    'Voice, video and photos all live on Today. Try them after setup.';

const List<Key> _blocks = <Key>[
  otherWaysSpeakKey,
  otherWaysFilmKey,
  otherWaysSnapKey,
];

const List<Color> _blockFills = <Color>[
  Color(0xFFB8566A),
  Color(0xFF2F2A25),
  Color(0xFF6D876D),
];

const List<Key> _mediaKeys = <Key>[
  momentVoiceKey,
  momentVideoKey,
  momentPhotosKey,
];

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

Future<void> _openMoment(
  WidgetTester tester,
  ProviderContainer container, {
  String note = '',
}) async {
  _controller(container)
    ..plant()
    ..markGrown()
    ..next()
    ..next();
  if (note.isNotEmpty) {
    _controller(container).setNote(note);
  }
  await _rest(tester);
  expect(_running(container).chapter, OnboardingChapter.moment);
}

Future<void> _fling(WidgetTester tester, Finder from, double dx) async {
  await tester.flingFrom(tester.getCenter(from), Offset(dx, 0), 800);
  await _rest(tester);
}

Finder get _cue => find.byKey(onboardingCueKey);

void _expectOnOtherWays(
  WidgetTester tester,
  ProviderContainer container, {
  required String reason,
}) {
  expect(find.text(_otherTitle), findsOneWidget, reason: reason);
  expect(find.text(_noteTitle), findsNothing, reason: reason);
  expect(find.byType(EditableText), findsNothing, reason: reason);
  expect(_running(container).chapter, OnboardingChapter.moment, reason: reason);
  expect(_running(container).draft.showingOtherWays, isTrue, reason: reason);
  expect(
    find.descendant(of: _cue, matching: find.text('swipe to continue')),
    findsOneWidget,
    reason: reason,
  );
}

void _expectOnNote(
  WidgetTester tester,
  ProviderContainer container, {
  required String reason,
}) {
  expect(find.text(_noteTitle), findsOneWidget, reason: reason);
  expect(find.text(_otherTitle), findsNothing, reason: reason);
  expect(find.byType(EditableText), findsOneWidget, reason: reason);
  expect(_running(container).chapter, OnboardingChapter.moment, reason: reason);
  expect(_running(container).draft.showingOtherWays, isFalse, reason: reason);
}

void main() {
  testWidgets('on the phone the swipe bar and note card rise above the '
      'keyboard', (WidgetTester tester) async {
    const double keyboard = 300;
    await _onLayout(ShellLayout.bottomBar, () async {
      final ProviderContainer container = await _pumpApp(
        tester,
        ShellLayout.bottomBar,
      );
      _controller(container).chooseMood(Mood.calm);
      await _openMoment(tester, container);
      await tester.tap(find.byKey(momentFieldKey));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      tester.view.padding = const FakeViewPadding(top: _statusBar);
      await _settle(tester);

      final double above = _phone.height - keyboard;
      final Rect bar = tester.getRect(find.byKey(onboardingControlBarKey));
      expect(bar.bottom, above - 8);
      expect(
        tester.getRect(find.byKey(onboardingCueKey)).bottom,
        lessThanOrEqualTo(above),
      );
      final Rect card = tester.getRect(find.byKey(momentCardKey));
      expect(card.bottom, moreOrLessEquals(bar.top - 4 - 12));
      expect(card.top, greaterThan(_statusBar));

      tester.view.resetViewInsets();
      tester.view.padding = const FakeViewPadding(
        top: _statusBar,
        bottom: _gestureBar,
      );
      await _settle(tester);
      expect(
        tester.getRect(find.byKey(onboardingControlBarKey)).bottom,
        _phone.height - _gestureBar - 8,
      );
      expect(
        tester.getRect(find.byKey(momentCardKey)).bottom,
        moreOrLessEquals(_phone.height - _gestureBar - 72 - 12),
      );
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  });

  testWidgets('the phone note card fills the step without the media tiles', (
    WidgetTester tester,
  ) async {
    await _onLayout(ShellLayout.bottomBar, () async {
      final ProviderContainer container = await _pumpApp(
        tester,
        ShellLayout.bottomBar,
      );
      await _openMoment(tester, container);
      expect(tester.getRect(find.text(_kicker)).top, _statusBar + 48);
      final Rect title = tester.getRect(find.text(_noteTitle));
      final Rect card = tester.getRect(find.byKey(momentCardKey));
      expect(card.top, moreOrLessEquals(title.bottom + 14));
      expect(
        card.bottom,
        moreOrLessEquals(_phone.height - _gestureBar - 72 - 12),
      );
      expect(card.left, 16);
      expect(card.right, _phone.width - 16);
      final Rect bar = tester.getRect(find.byKey(onboardingControlBarKey));
      expect(card.bottom, lessThan(bar.top));

      final Rect field = tester.getRect(find.byKey(momentFieldKey));
      expect(field.top, greaterThan(card.top));
      expect(field.bottom, lessThan(card.bottom));
      expect(field.height, greaterThan(card.height * 0.6));
      final EditableText editable = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(editable.expands, isTrue);
      expect(editable.style.fontSize, 18);
      expect(
        editable.style.fontSize! * editable.style.height!,
        moreOrLessEquals(32),
      );
      expect(editable.strutStyle.fontSize, 18);
      expect(editable.strutStyle.height, moreOrLessEquals(32 / 18));

      _controller(container).setNote('The fog lifted over the harbour');
      await tester.pump(const Duration(milliseconds: 700));
      await _rest(tester);
      expect(find.text(_savedHint), findsOneWidget);
      expect(tester.widget<Text>(find.text(_savedHint)).style?.fontSize, 15);
      expect(find.textContaining('More than one way'), findsNothing);
      expect(find.byKey(momentMediaKey), findsNothing);
      for (final Key key in _mediaKeys) {
        expect(find.byKey(key), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    await _onLayout(ShellLayout.sidebar, () async {
      final ProviderContainer container = await _pumpApp(
        tester,
        ShellLayout.sidebar,
      );
      await _openMoment(tester, container, note: 'The fog lifted');
      await tester.pump(const Duration(seconds: 2));
      await _rest(tester);
      final Rect frame = tester.getRect(find.byType(OnboardingFrame));
      expect(tester.getRect(find.text(_kicker)).top - frame.top, 52);
      expect(find.text(_savedHint), findsOneWidget);
      expect(find.byKey(momentMediaKey), findsOneWidget);
      for (final Key key in _mediaKeys) {
        expect(find.byKey(key), findsOneWidget);
      }
      expect(
        find.text("And there's more than one way to keep a memory."),
        findsOneWidget,
      );
      await _unmount(tester);
    });
  });

  testWidgets(
    'the phone shows Other ways after the note and going back retraces both',
    (WidgetTester tester) async {
      await _onLayout(ShellLayout.bottomBar, () async {
        final ProviderContainer container = await _pumpApp(
          tester,
          ShellLayout.bottomBar,
        );
        await _openMoment(tester, container, note: 'A first line');
        _expectOnNote(tester, container, reason: 'note');

        await _fling(tester, find.text(_noteTitle), -120);
        _expectOnOtherWays(tester, container, reason: 'after the note');
        expect(
          tester.getSemantics(
            find.descendant(
              of: find.byKey(onboardingProgressKey),
              matching: find.bySemanticsLabel('A moment'),
            ),
          ),
          isSemantics(label: 'A moment', isSelected: true),
        );

        final Rect title = tester.getRect(find.text(_otherTitle));
        expect(tester.getRect(find.text(_kicker)).top, _statusBar + 48);
        final List<Rect> blocks = <Rect>[
          for (final Key key in _blocks) tester.getRect(find.byKey(key)),
        ];
        expect(blocks.first.top, moreOrLessEquals(title.bottom + 14));
        expect(
          blocks.last.bottom,
          moreOrLessEquals(_phone.height - _gestureBar - 72 - 12),
        );
        for (final (int index, Rect block) in blocks.indexed) {
          expect(block.left, 12, reason: 'block $index');
          expect(block.right, _phone.width - 12, reason: 'block $index');
          expect(
            block.height,
            moreOrLessEquals(blocks.first.height, epsilon: 1),
            reason: 'block $index',
          );
          if (index > 0) {
            expect(
              block.top - blocks[index - 1].bottom,
              moreOrLessEquals(9),
              reason: 'block $index gap',
            );
          }
          final BoxDecoration face =
              tester
                      .widget<Container>(
                        find
                            .descendant(
                              of: find.byKey(_blocks[index]),
                              matching: find.byType(Container),
                            )
                            .first,
                      )
                      .decoration!
                  as BoxDecoration;
          expect(
            face.color!.toARGB32(),
            _blockFills[index].toARGB32(),
            reason: 'block $index fill',
          );
          expect(
            face.borderRadius,
            const BorderRadius.all(Radius.circular(22)),
          );
        }
        for (final String text in <String>[
          'speak',
          'Say it out loud',
          'On a walk, in the car. Hold it like a call.',
          'film',
          'Point and keep',
          'Flip to the front camera, or turn it off and just talk.',
          'snap',
          'Add a photo',
          'Straight from the camera, or one from earlier.',
          '0:12',
        ]) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
        final WaveformBars wave = tester.widget<WaveformBars>(
          find.descendant(
            of: find.byKey(otherWaysSpeakKey),
            matching: find.byType(WaveformBars),
          ),
        );
        expect(wave.heights, hasLength(14));
        expect(wave.maxHeight, 64);
        expect(wave.animate, isTrue);

        await tester.tap(find.byKey(otherWaysFilmKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_toast), findsOneWidget);
        _expectOnOtherWays(tester, container, reason: 'after a tap');
        await tester.pump(const Duration(milliseconds: 2600));
        expect(find.text(_toast), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(_toast), findsNothing);

        await _fling(tester, find.text(_otherTitle), -120);
        expect(_running(container).chapter, OnboardingChapter.month);
        expect(find.byType(MonthChapter), findsOneWidget);

        await tester.tap(find.byKey(onboardingBackKey));
        await _rest(tester);
        _expectOnOtherWays(tester, container, reason: 'back from Calendar');
        await tester.tap(find.byKey(onboardingBackKey));
        await _rest(tester);
        _expectOnNote(tester, container, reason: 'back from Other ways');

        await _fling(tester, find.text(_noteTitle), -120);
        _expectOnOtherWays(tester, container, reason: 'swiped on again');
        await _fling(tester, find.text(_otherTitle), -120);
        expect(_running(container).chapter, OnboardingChapter.month);
        await _fling(tester, find.text('Give it a few weeks.'), 120);
        _expectOnOtherWays(tester, container, reason: 'swiped back');
        await _fling(tester, find.text(_otherTitle), 120);
        _expectOnNote(tester, container, reason: 'swiped back again');
        await _fling(tester, find.text(_noteTitle), 120);
        expect(_running(container).chapter, OnboardingChapter.day);
        await _unmount(tester);
      });

      await _onLayout(ShellLayout.sidebar, () async {
        final ProviderContainer container = await _pumpApp(
          tester,
          ShellLayout.sidebar,
        );
        await _openMoment(tester, container, note: 'A first line');
        await tester.tap(find.byKey(onboardingPrimaryKey));
        await _rest(tester);
        expect(_running(container).chapter, OnboardingChapter.month);
        expect(find.text(_otherTitle), findsNothing);
        await tester.tap(find.byKey(onboardingBackKey));
        await _rest(tester);
        expect(_running(container).chapter, OnboardingChapter.moment);
        expect(find.text(_noteTitle), findsOneWidget);
        expect(find.text(_otherTitle), findsNothing);
        expect(_running(container).draft.showingOtherWays, isFalse);
        await _unmount(tester);
      });
    },
  );
}
