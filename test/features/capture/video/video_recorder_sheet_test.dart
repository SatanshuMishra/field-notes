import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

void main() {
  testWidgets('idle phase offers Record and shows no recording indicators',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.idle,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byType(Blink), findsNothing);
    expect(find.byType(Toast), findsNothing);
  });

  testWidgets('recording phase shows the preview, blinking dot, and Stop',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.recording,
          preview: const SizedBox(key: ValueKey('preview'), width: 80, height: 80),
          onStart: () {},
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('preview')), findsOneWidget);
    expect(find.byType(Blink), findsOneWidget);
    expect(find.text('Stop & save'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a nudge message surfaces as a non-blocking Toast while recording',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.recording,
          nudgeMessage: '5 minutes in — looking good.',
          onStart: () {},
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Toast), findsOneWidget);
    expect(find.text('5 minutes in — looking good.'), findsOneWidget);
    expect(find.text('Stop & save'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('idle and recording taps invoke the matching callbacks',
      (WidgetTester tester) async {
    int starts = 0;
    int cancels = 0;

    await tester.pumpWidget(
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.idle,
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
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.recording,
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
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.idle,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
          errorMessage: 'Camera is off.',
        ),
      ),
    );

    expect(find.text('Camera is off.'), findsOneWidget);
  });

  testWidgets('the saving phase disables the primary action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.saving,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.text('Saving…'), findsOneWidget);
    expect(find.byType(Blink), findsNothing);
  });
}
