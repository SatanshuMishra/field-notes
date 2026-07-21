import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

void main() {
  testWidgets('idle phase offers Record and shows no recording indicators',
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

    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byType(Blink), findsNothing);
    expect(find.byType(WaveformBars), findsNothing);
  });

  testWidgets('recording phase shows the blinking dot, waveform, and Stop',
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
    expect(find.text('Stop & save'), findsOneWidget);

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

    await tester.tap(find.text('Record'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(starts, 1);
    expect(cancels, 1);
  });

  testWidgets('the recording phase Stop button invokes onStop',
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

    await tester.tap(find.text('Stop & save'));
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

  testWidgets('the saving phase disables the primary action',
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

    expect(find.text('Saving…'), findsOneWidget);
    expect(find.byType(Blink), findsNothing);
    expect(find.byType(WaveformBars), findsNothing);
  });
}
