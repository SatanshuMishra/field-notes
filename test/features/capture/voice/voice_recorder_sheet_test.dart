import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

Widget _platformHarness(TargetPlatform platform, Widget child) {
  return ProviderScope(
    overrides: <Override>[
      reflectionPromptsEnabledProvider.overrideWithValue(false),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

List<String> _orbZoneOrder(WidgetTester tester) {
  return find
      .descendant(
        of: find.byKey(voiceOrbZoneKey),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is BreathingGlow ||
              widget.key == voiceRecordButtonKey ||
              widget.key == voiceCometsKey,
        ),
      )
      .evaluate()
      .map((Element element) {
        final Widget widget = element.widget;
        if (widget is BreathingGlow) {
          return 'settle glow';
        }
        return widget.key == voiceCometsKey ? 'comets' : 'orb';
      })
      .toList();
}

void main() {
  testWidgets(
    'idle phase offers the orb and leave and shows no recording indicators',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        voiceSheetHarness(
          VoiceRecorderSheet(
            phase: VoiceRecorderPhase.idle,
            onStart: () {},
            onStop: () {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.byKey(voiceRecordButtonKey), findsOneWidget);
      expect(find.byKey(voiceCloseKey), findsOneWidget);
      expect(find.byType(BreathingGlow), findsNothing);
      expect(find.byKey(recorderTimerKey), findsNothing);
      expect(find.byKey(voiceSavePillKey), findsNothing);
      expect(find.byType(WaveformBars), findsNothing);
    },
  );

  testWidgets(
    'recording phase shows the breathing glow and the soft timer, with no waveform or label',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        voiceSheetHarness(
          VoiceRecorderSheet(
            phase: VoiceRecorderPhase.recording,
            onStart: () {},
            onStop: () {},
            onCancel: () {},
            elapsed: const Duration(seconds: 7),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(BreathingGlow), findsNothing);
      expect(find.byType(VoiceLevelField), findsOneWidget);
      expect(
        tester.widget<VoiceLevelField>(find.byType(VoiceLevelField)).stage,
        VoiceLevelStage.recording,
      );
      expect(find.byKey(recorderTimerKey), findsOneWidget);
      expect(find.text('0:07'), findsOneWidget);
      expect(find.byType(WaveformBars), findsNothing);
      expect(find.text('RECORDING'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('taps invoke the matching callbacks', (
    WidgetTester tester,
  ) async {
    int starts = 0;
    int cancels = 0;

    await tester.pumpWidget(
      voiceSheetHarness(
        VoiceRecorderSheet(
          phase: VoiceRecorderPhase.idle,
          onStart: () => starts++,
          onStop: () {},
          onCancel: () => cancels++,
        ),
      ),
    );

    await tester.tap(find.byKey(voiceRecordButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(voiceCloseKey));
    await tester.pump();

    expect(starts, 1);
    expect(cancels, 1);
  });

  testWidgets('the recording phase orb pauses and Keep this saves', (
    WidgetTester tester,
  ) async {
    int pauses = 0;
    int stops = 0;
    int discards = 0;

    await tester.pumpWidget(
      voiceSheetHarness(
        VoiceRecorderSheet(
          phase: VoiceRecorderPhase.recording,
          onStart: () {},
          onStop: () => stops++,
          onCancel: () {},
          onPause: () => pauses++,
          onDiscard: () => discards++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(voiceRecordButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(voiceSavePillKey));
    await tester.pump();
    await tester.tap(find.byKey(voiceDiscardPillKey));
    await tester.pump();

    expect(pauses, 1);
    expect(stops, 1);
    expect(discards, 1);
    expect(find.text('Keep this'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an error message renders when provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      voiceSheetHarness(
        VoiceRecorderSheet(
          phase: VoiceRecorderPhase.idle,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
          errorMessage: 'Microphone is off.',
        ),
      ),
    );

    expect(find.text('Microphone is off.'), findsOneWidget);
  });

  testWidgets(
    'the saving phase shows the saving status and no live indicators',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        voiceSheetHarness(
          VoiceRecorderSheet(
            phase: VoiceRecorderPhase.saving,
            onStart: () {},
            onStop: () {},
            onCancel: () {},
          ),
        ),
      );

      expect(find.text('Saving your recording…'), findsOneWidget);
      expect(find.byType(BreathingGlow), findsNothing);
      expect(find.byKey(recorderTimerKey), findsNothing);
      expect(find.byType(WaveformBars), findsNothing);
    },
  );

  testWidgets('asking shows the let-go panel in place of the take actions', (
    WidgetTester tester,
  ) async {
    int keptGoing = 0;
    int letGo = 0;

    await tester.pumpWidget(
      voiceSheetHarness(
        VoiceRecorderSheet(
          phase: VoiceRecorderPhase.paused,
          asking: true,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
          onKeepGoing: () => keptGoing++,
          onLetGo: () => letGo++,
          letGoKey: const ValueKey<String>('let-go'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LetGoPanel), findsOneWidget);
    expect(find.byKey(voiceSavePillKey), findsNothing);

    await tester.tap(find.byKey(voiceKeepGoingKey));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('let-go')));
    await tester.pump();

    expect(keptGoing, 1);
    expect(letGo, 1);
  });

  testWidgets(
    'the comets layer sits above the orb on the desktop from the breath and not when idle or saving',
    (WidgetTester tester) async {
      _useWindow(tester, const Size(1280, 800));
      int starts = 0;
      VoiceRecorderSheet sheet(VoiceRecorderPhase phase) => VoiceRecorderSheet(
        phase: phase,
        onStart: () => starts++,
        onStop: () {},
        onCancel: () {},
      );

      await tester.pumpWidget(
        _platformHarness(TargetPlatform.macOS, sheet(VoiceRecorderPhase.idle)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(voiceCometsKey), findsNothing);
      expect(find.byType(VoiceLevelField), findsNothing);

      await tester.pumpWidget(
        _platformHarness(
          TargetPlatform.macOS,
          sheet(VoiceRecorderPhase.breathing),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(find.byKey(voiceOrbZoneKey)), const Size(250, 250));
      expect(find.byKey(voiceCometsKey), findsOneWidget);
      expect(find.byType(VoiceLevelField), findsOneWidget);
      expect(tester.getSize(find.byKey(voiceCometsKey)), const Size(370, 370));
      expect(
        tester.getCenter(find.byKey(voiceCometsKey)),
        tester.getCenter(find.byKey(voiceRecordButtonKey)),
      );
      expect(_orbZoneOrder(tester), <String>['settle glow', 'orb', 'comets']);

      await tester.tapAt(tester.getCenter(find.byKey(voiceRecordButtonKey)));
      await tester.pump();
      expect(starts, 1);

      await tester.pumpWidget(
        _platformHarness(
          TargetPlatform.macOS,
          sheet(VoiceRecorderPhase.saving),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(voiceCometsKey), findsNothing);
      expect(find.byType(VoiceLevelField), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the comets layer sits above the orb on the phone', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    _useWindow(tester, const Size(384, 832));
    int pauses = 0;

    await tester.pumpWidget(
      _platformHarness(
        TargetPlatform.android,
        VoiceRecorderSheet(
          phase: VoiceRecorderPhase.recording,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
          onPause: () => pauses++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.getSize(find.byKey(voiceOrbZoneKey)), const Size(184, 184));
    expect(find.byKey(voiceCometsKey), findsOneWidget);
    expect(tester.getSize(find.byKey(voiceCometsKey)), const Size(272, 272));
    expect(
      tester.getCenter(find.byKey(voiceCometsKey)),
      tester.getCenter(find.byKey(voiceRecordButtonKey)),
    );
    expect(_orbZoneOrder(tester), <String>['orb', 'comets']);
    expect(
      tester.getSemantics(find.byKey(voiceCometsKey)).id,
      tester.getSemantics(find.byKey(voiceOrbZoneKey)).id,
    );

    await tester.tapAt(tester.getCenter(find.byKey(voiceRecordButtonKey)));
    await tester.pump();
    expect(pauses, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  });
}
