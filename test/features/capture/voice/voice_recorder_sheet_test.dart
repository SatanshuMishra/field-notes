import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

void main() {
  testWidgets('idle phase offers the mic button and shows no recording indicators',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      voiceHarness(
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
    expect(find.byType(Blink), findsNothing);
    expect(find.byType(WaveformBars), findsNothing);
  });

  testWidgets('recording phase shows the blinking dot and the live waveform',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      voiceHarness(
        VoiceRecorderSheet(
          phase: VoiceRecorderPhase.recording,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Blink), findsOneWidget);
    expect(find.byType(WaveformBars), findsOneWidget);
    expect(find.text('RECORDING'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('taps invoke the matching callbacks',
      (WidgetTester tester) async {
    int starts = 0;
    int cancels = 0;

    await tester.pumpWidget(
      voiceHarness(
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

  testWidgets('the recording phase mic button invokes onStop',
      (WidgetTester tester) async {
    int stops = 0;

    await tester.pumpWidget(
      voiceHarness(
        VoiceRecorderSheet(
          phase: VoiceRecorderPhase.recording,
          onStart: () {},
          onStop: () => stops++,
          onCancel: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(voiceRecordButtonKey));
    await tester.pump();

    expect(stops, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an error message renders when provided',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      voiceHarness(
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

  testWidgets('the saving phase shows the saving hint and no live indicators',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      voiceHarness(
        VoiceRecorderSheet(
          phase: VoiceRecorderPhase.saving,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.text('Saving your recording…'), findsOneWidget);
    expect(find.byType(Blink), findsNothing);
    expect(find.byType(WaveformBars), findsNothing);
  });
}
