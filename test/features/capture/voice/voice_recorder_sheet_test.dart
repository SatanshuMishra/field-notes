import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

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

      expect(
        tester.widget<BreathingGlow>(find.byType(BreathingGlow)).mode,
        BreathingGlowMode.breathe,
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
}
