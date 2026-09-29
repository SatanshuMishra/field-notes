import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/state/settings_providers.dart';

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
}
