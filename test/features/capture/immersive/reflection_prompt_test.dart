import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/app.dart' show AppTextScale;
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';

import '../voice/voice_test_support.dart'
    show FakeCaptureService, FakeVoiceRecorder, startVoiceTake;

const List<String> _questions = <String>[
  'What’s been on your mind today?',
  'What felt heavier than it needed to?',
  'What would you tell a friend in your place?',
  'What do you want to remember about today?',
  'What haven’t you said out loud yet?',
  'What went well that you didn’t stop to notice?',
  'When did you feel most like yourself today?',
];

const String _shuffle = 'Ask me something else';
const String _kicker = 'a question, if you want one';
const String _today = '2026-09-28';
const String _launcher = 'open';
const Key _slotKey = ValueKey<String>('slot');

class _AndroidTwoTimesCurve extends TextScaler {
  const _AndroidTwoTimesCurve();

  static const List<(double, double)> _points = <(double, double)>[
    (0, 0),
    (8, 16),
    (10, 20),
    (12, 24),
    (14, 26),
    (18, 30),
    (20, 34),
    (24, 36),
    (30, 38),
    (100, 100),
  ];

  @override
  double scale(double fontSize) {
    for (int i = 1; i < _points.length; i++) {
      final (double fromLow, double toLow) = _points[i - 1];
      final (double fromHigh, double toHigh) = _points[i];
      if (fontSize <= fromHigh) {
        return toLow +
            (fontSize - fromLow) * (toHigh - toLow) / (fromHigh - fromLow);
      }
    }
    return fontSize;
  }

  @override
  double get textScaleFactor => 2;
}

class _RecordingScaler extends TextScaler {
  _RecordingScaler();

  final List<double> requested = <double>[];

  @override
  double scale(double fontSize) {
    requested.add(fontSize);
    return fontSize;
  }

  @override
  double get textScaleFactor => 1;
}

Widget _prompt({
  required bool enabled,
  required StagePhase phase,
  required TargetPlatform platform,
  int? initialIndex = 0,
  bool showKicker = true,
}) {
  return ProviderScope(
    overrides: <Override>[
      reflectionPromptsEnabledProvider.overrideWithValue(enabled),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        backgroundColor: recorderStageColor,
        body: Center(
          child: ReflectionPrompt(
            key: const ValueKey<String>('prompt'),
            phase: phase,
            showKicker: showKicker,
            initialIndex: initialIndex,
          ),
        ),
      ),
    ),
  );
}

Widget _promptInSlot({
  required StagePhase phase,
  required TargetPlatform platform,
  required Size slot,
  TextScaler? textScaler,
  bool boldText = false,
}) {
  return ProviderScope(
    overrides: <Override>[
      reflectionPromptsEnabledProvider.overrideWithValue(true),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler ?? MediaQuery.textScalerOf(context),
          boldText: boldText,
        ),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: recorderStageColor,
        body: Center(
          child: SizedBox.fromSize(
            key: _slotKey,
            size: slot,
            child: Align(
              alignment: Alignment.topCenter,
              child: ReflectionPrompt(
                phase: phase,
                showKicker: true,
                initialIndex: 2,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openVoice(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size window,
  double textScale = 1,
  TextScaler? ambientScaler,
  FakeVoiceRecorder? recorder,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        voiceRecorderProvider.overrideWith(
          (Ref ref) => recorder ?? FakeVoiceRecorder(),
        ),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
        reflectionPromptsEnabledProvider.overrideWithValue(true),
        textScaleProvider.overrideWithValue(textScale),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        builder: (BuildContext context, Widget? child) {
          final Widget scaled = AppTextScale(child: child!);
          final TextScaler? ambient = ambientScaler;
          return ambient == null
              ? scaled
              : MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: ambient),
                  child: scaled,
                );
        },
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async => showVoiceComposer(context, _today),
                child: const Text(_launcher),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_launcher));
  await tester.pump();
  await tester.pump(immersiveFadeFor(resolveShellLayout(platform)));
}

typedef _Rendered = ({double question, double? kicker, double fit});

double _laidOutFontSize(RenderParagraph paragraph) {
  return paragraph.textScaler.scale(paragraph.text.style!.fontSize!);
}

_Rendered _rendered(WidgetTester tester) {
  final Finder questionText = find.descendant(
    of: find.byKey(reflectionQuestionKey),
    matching: find.byType(RichText),
  );
  final Finder kicker = find.text(_kicker);
  final double fit =
      tester.getRect(questionText).height / tester.getSize(questionText).height;
  return (
    question:
        _laidOutFontSize(tester.renderObject<RenderParagraph>(questionText)) *
        fit,
    kicker: kicker.evaluate().isEmpty
        ? null
        : _laidOutFontSize(tester.renderObject<RenderParagraph>(kicker)) * fit,
    fit: fit,
  );
}

Future<void> _expectEveryQuestion(
  WidgetTester tester,
  void Function(_Rendered rendered, String reason) expectText,
) async {
  final Finder shuffle = find.byKey(reflectionShuffleKey);
  final Finder label = find.text(_shuffle);
  final Set<String> seen = <String>{};
  for (int step = 0; step < _questions.length; step++) {
    final String question = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(reflectionQuestionKey),
            matching: find.byType(Text),
          ),
        )
        .data!;
    seen.add(question);
    expectText(_rendered(tester), question);
    final Rect hitBox = tester.getRect(shuffle);
    expect(hitBox.width, greaterThanOrEqualTo(48), reason: question);
    expect(hitBox.height, greaterThanOrEqualTo(48), reason: question);
    expect(
      tester.getRect(label).height,
      moreOrLessEquals(tester.getSize(label).height, epsilon: 0.01),
      reason: question,
    );
    expect(
      tester.getRect(find.byKey(reflectionQuestionKey)).bottom,
      lessThanOrEqualTo(hitBox.top + 0.5),
      reason: question,
    );
    expect(
      hitBox.bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(voiceOrbZoneKey)).top + 0.5),
      reason: question,
    );
    expect(tester.takeException(), isNull, reason: question);
    await tester.tap(shuffle);
    await tester.pump();
  }
  expect(seen, _questions.toSet());
}

void _expectReflowedAtOrAbove(
  _Rendered rendered,
  String reason, {
  required double question,
  required bool kickerRequired,
}) {
  expect(rendered.question, greaterThanOrEqualTo(question), reason: reason);
  expect(rendered.fit, moreOrLessEquals(1, epsilon: 1e-6), reason: reason);
  final double? kicker = rendered.kicker;
  if (kickerRequired) {
    expect(kicker, isNotNull, reason: reason);
  }
  if (kicker != null) {
    expect(kicker, greaterThanOrEqualTo(12), reason: reason);
  }
}

void _useWindow(WidgetTester tester, TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = platform == TargetPlatform.macOS
      ? const Size(1280, 800)
      : const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('the seven reflection questions are the fixed list, in order', () {
    expect(reflectionQuestions, _questions);
  });

  testWidgets('no question shows when reflection questions are off', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      _useWindow(tester, platform);
      await tester.pumpWidget(
        _prompt(enabled: false, phase: StagePhase.idle, platform: platform),
      );

      for (final String question in _questions) {
        expect(find.text(question), findsNothing);
      }
      expect(find.text(_shuffle), findsNothing);
      expect(find.text(_kicker), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('prompt'))),
        Size.zero,
      );
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'a question and Ask me something else show while idle and the shuffle advances',
    (WidgetTester tester) async {
      _useWindow(tester, TargetPlatform.macOS);
      await tester.pumpWidget(
        _prompt(
          enabled: true,
          phase: StagePhase.idle,
          platform: TargetPlatform.macOS,
          initialIndex: 6,
        ),
      );

      expect(find.text(_questions[6]), findsOneWidget);
      expect(find.text(_kicker), findsOneWidget);
      expect(find.text(_shuffle), findsOneWidget);
      final Size shuffle = tester.getSize(find.byKey(reflectionShuffleKey));
      expect(shuffle.height, greaterThanOrEqualTo(48));
      expect(shuffle.width, greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(reflectionShuffleKey));
      await tester.pump();

      expect(find.text(_questions[0]), findsOneWidget);
      expect(find.text(_questions[6]), findsNothing);

      await tester.tap(find.byKey(reflectionShuffleKey));
      await tester.pump();
      expect(find.text(_questions[1]), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('recording hides the shuffle and fades the question to 45%', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.android);
    await tester.pumpWidget(
      _prompt(
        enabled: true,
        phase: StagePhase.idle,
        platform: TargetPlatform.android,
        initialIndex: 2,
      ),
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1.0,
    );

    for (final StagePhase phase in <StagePhase>[
      StagePhase.recording,
      StagePhase.paused,
      StagePhase.saving,
    ]) {
      await tester.pumpWidget(
        _prompt(
          enabled: true,
          phase: phase,
          platform: TargetPlatform.android,
          initialIndex: 2,
        ),
      );
      await tester.pump(const Duration(milliseconds: 1400));

      expect(find.text(_questions[2]), findsOneWidget, reason: phase.name);
      expect(find.text(_shuffle), findsNothing, reason: phase.name);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.45,
        reason: phase.name,
      );
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('breathing hides the shuffle but keeps the question bright', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    await tester.pumpWidget(
      _prompt(
        enabled: true,
        phase: StagePhase.breathing,
        platform: TargetPlatform.macOS,
      ),
    );

    expect(find.text(_questions[0]), findsOneWidget);
    expect(find.text(_shuffle), findsNothing);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1.0,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a long question wraps to at most three lines in the sidebar', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          reflectionPromptsEnabledProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.macOS),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                child: ReflectionPrompt(
                  phase: StagePhase.idle,
                  showKicker: false,
                  initialIndex: 5,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final Text question = tester.widget<Text>(find.text(_questions[5]));
    expect(question.maxLines, 3);
    expect(question.overflow, TextOverflow.ellipsis);
    expect(
      tester.getSize(find.byKey(reflectionQuestionKey)).width,
      lessThanOrEqualTo(260),
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'the voice recorder keeps Ask me something else full size and grows the question past 22.5 px at the default macOS window',
    (WidgetTester tester) async {
      for (final double textScale in <double>[0.9, 1]) {
        await _openVoice(
          tester,
          platform: TargetPlatform.macOS,
          window: const Size(873, 632),
          textScale: textScale,
        );
        await _expectEveryQuestion(
          tester,
          (_Rendered rendered, String reason) => _expectReflowedAtOrAbove(
            rendered,
            '$reason at $textScale',
            question: 22.5,
            kickerRequired: true,
          ),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'a Large text size keeps every question at 22 px or more, unscaled, at the default macOS window',
    (WidgetTester tester) async {
      await _openVoice(
        tester,
        platform: TargetPlatform.macOS,
        window: const Size(873, 632),
        textScale: 1.15,
      );
      await _expectEveryQuestion(
        tester,
        (_Rendered rendered, String reason) => _expectReflowedAtOrAbove(
          rendered,
          reason,
          question: 22,
          kickerRequired: true,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'a 1.5 text scale hides the kicker and grows every question past 22.5 px at the default macOS window',
    (WidgetTester tester) async {
      await _openVoice(
        tester,
        platform: TargetPlatform.macOS,
        window: const Size(873, 632),
        textScale: 1.5,
      );
      await _expectEveryQuestion(tester, (_Rendered rendered, String reason) {
        expect(rendered.kicker, isNull, reason: reason);
        _expectReflowedAtOrAbove(
          rendered,
          reason,
          question: 22.5,
          kickerRequired: false,
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'at the macOS minimum window height every question stays readable beside a full-size shuffle',
    (WidgetTester tester) async {
      for (final double textScale in <double>[1, 1.15]) {
        await _openVoice(
          tester,
          platform: TargetPlatform.macOS,
          window: const Size(873, 600),
          textScale: textScale,
        );
        await _expectEveryQuestion(
          tester,
          (_Rendered rendered, String reason) => expect(
            rendered.question,
            greaterThanOrEqualTo(12),
            reason: '$reason at $textScale',
          ),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'while recording on a short phone at a 1.5 text scale the question is readable or absent',
    (WidgetTester tester) async {
      await _openVoice(
        tester,
        platform: TargetPlatform.android,
        window: const Size(320, 568),
        textScale: 1.5,
      );
      await startVoiceTake(tester);
      await tester.pump(voiceElapsedTick);

      expect(find.byKey(reflectionShuffleKey), findsNothing);
      if (find.byKey(reflectionQuestionKey).evaluate().isNotEmpty) {
        expect(_rendered(tester).question, greaterThanOrEqualTo(12));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'recording ticks lay the fitted question out again without measuring it at full size',
    (WidgetTester tester) async {
      final _RecordingScaler scaler = _RecordingScaler();
      final FakeVoiceRecorder recorder = FakeVoiceRecorder();
      await _openVoice(
        tester,
        platform: TargetPlatform.macOS,
        window: const Size(873, 632),
        ambientScaler: scaler,
        recorder: recorder,
      );
      await startVoiceTake(tester);
      final double fitted = tester
          .renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(reflectionQuestionKey),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style!
          .fontSize!;
      expect(fitted, lessThan(38));

      scaler.requested.clear();
      for (int tick = 0; tick < 4; tick++) {
        recorder.elapsed += voiceElapsedTick;
        await tester.pump(voiceElapsedTick);
      }

      expect(scaler.requested, contains(fitted));
      expect(scaler.requested, isNot(contains(38)));
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'the voice recorder keeps Ask me something else full size on a short phone',
    (WidgetTester tester) async {
      for (final double textScale in <double>[1, 1.15]) {
        await _openVoice(
          tester,
          platform: TargetPlatform.android,
          window: const Size(320, 568),
          textScale: textScale,
        );
        await _expectEveryQuestion(tester, (_Rendered rendered, String reason) {
          expect(
            rendered.question,
            moreOrLessEquals(18, epsilon: 0.01),
            reason: '$reason at $textScale',
          );
          expect(
            rendered.fit,
            moreOrLessEquals(1, epsilon: 1e-6),
            reason: '$reason at $textScale',
          );
          if (textScale == 1) {
            expect(
              rendered.kicker,
              greaterThan(12.1),
              reason: '$reason shrinks the kicker only as far as it must',
            );
          }
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'in a short slot the text shrinks or drops its kicker while the shuffle keeps full size and the question holds still across phases',
    (WidgetTester tester) async {
      _useWindow(tester, TargetPlatform.macOS);
      for (final Size slot in const <Size>[Size(640, 120), Size(640, 70)]) {
        final String reason = '$slot';
        await tester.pumpWidget(
          _promptInSlot(
            phase: StagePhase.idle,
            platform: TargetPlatform.macOS,
            slot: slot,
          ),
        );
        final Rect slotRect = tester.getRect(find.byKey(_slotKey));
        final Rect idleQuestion = tester.getRect(
          find.byKey(reflectionQuestionKey),
        );
        expect(
          tester.getRect(find.byKey(reflectionShuffleKey)).height,
          48,
          reason: reason,
        );
        expect(
          idleQuestion.bottom,
          lessThanOrEqualTo(slotRect.bottom - 48),
          reason: reason,
        );
        expect(tester.takeException(), isNull, reason: reason);

        await tester.pumpWidget(
          _promptInSlot(
            phase: StagePhase.recording,
            platform: TargetPlatform.macOS,
            slot: slot,
          ),
        );
        expect(find.byKey(reflectionShuffleKey), findsNothing, reason: reason);
        expect(
          tester.getRect(find.byKey(reflectionQuestionKey)),
          idleQuestion,
          reason: reason,
        );
        expect(tester.takeException(), isNull, reason: reason);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'a slot too short for a readable question shows nothing and does not overflow',
    (WidgetTester tester) async {
      _useWindow(tester, TargetPlatform.macOS);
      for (final double height in <double>[40, 48, 52]) {
        for (final StagePhase phase in <StagePhase>[
          StagePhase.idle,
          StagePhase.recording,
        ]) {
          final String reason = '${phase.name} in a $height px slot';
          await tester.pumpWidget(
            _promptInSlot(
              phase: phase,
              platform: TargetPlatform.macOS,
              slot: Size(640, height),
            ),
          );
          expect(
            find.byKey(reflectionShuffleKey),
            findsNothing,
            reason: reason,
          );
          expect(
            find.byKey(reflectionQuestionKey),
            findsNothing,
            reason: reason,
          );
          expect(find.text(_kicker), findsNothing, reason: reason);
          expect(tester.takeException(), isNull, reason: reason);
        }
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'bold text is measured as it renders, so a short slot needs no picture scaling',
    (WidgetTester tester) async {
      _useWindow(tester, TargetPlatform.macOS);
      await tester.pumpWidget(
        _promptInSlot(
          phase: StagePhase.idle,
          platform: TargetPlatform.macOS,
          slot: const Size(640, 120),
          boldText: true,
        ),
      );

      expect(_rendered(tester).fit, moreOrLessEquals(1, epsilon: 1e-6));
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'a question that fits alone at full size keeps exactly its full size',
    (WidgetTester tester) async {
      _useWindow(tester, TargetPlatform.android);
      await tester.pumpWidget(
        _promptInSlot(
          phase: StagePhase.idle,
          platform: TargetPlatform.android,
          slot: const Size(268, 106),
        ),
      );

      final _Rendered rendered = _rendered(tester);
      expect(rendered.kicker, isNull);
      expect(rendered.question, moreOrLessEquals(22, epsilon: 1e-9));
      expect(rendered.fit, moreOrLessEquals(1, epsilon: 1e-6));
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'an Android 2.0 font curve renders the bottom-bar floors at 18 px and 12 px and keeps the kicker at 268x120',
    (WidgetTester tester) async {
      _useWindow(tester, TargetPlatform.android);
      for (final double height in <double>[100, 112, 120]) {
        final String reason = '268x$height';
        await tester.pumpWidget(
          _promptInSlot(
            phase: StagePhase.idle,
            platform: TargetPlatform.android,
            slot: Size(268, height),
            textScaler: const _AndroidTwoTimesCurve(),
          ),
        );
        final _Rendered rendered = _rendered(tester);
        expect(
          rendered.fit,
          moreOrLessEquals(1, epsilon: 1e-6),
          reason: reason,
        );
        expect(
          rendered.question,
          greaterThanOrEqualTo(18 - 0.01),
          reason: reason,
        );
        if (height == 112) {
          expect(
            rendered.question,
            moreOrLessEquals(18, epsilon: 0.01),
            reason: reason,
          );
          expect(
            rendered.kicker,
            moreOrLessEquals(12, epsilon: 0.01),
            reason: reason,
          );
        }
        if (height == 120) {
          expect(rendered.kicker, isNotNull, reason: reason);
        }
        expect(tester.takeException(), isNull, reason: reason);
      }
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
