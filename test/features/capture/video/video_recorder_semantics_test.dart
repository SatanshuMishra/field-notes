import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

void main() {
  testWidgets('the recorder close and shutter controls are labelled buttons', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.idle,
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      ),
    );

    expect(find.bySemanticsLabel('Leave'), findsOneWidget);
    expect(find.bySemanticsLabel('Start recording'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(videoCloseKey)),
      isSemantics(label: 'Leave', isButton: true),
    );
    expect(
      tester.getSemantics(find.byKey(videoShutterKey)),
      isSemantics(label: 'Start recording', isButton: true),
    );

    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.recording,
          onStart: () {},
          onStop: () {},
          onLeave: () {},
          onPause: () {},
          supportsPause: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.bySemanticsLabel('Pause recording'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(videoShutterKey)),
      isSemantics(label: 'Pause recording', isButton: true),
    );
    expect(
      tester.getSemantics(find.byKey(videoDiscardCircleKey)),
      isSemantics(label: 'Let go', isButton: true),
    );
    expect(
      tester.getSemantics(find.byKey(videoSaveCircleKey)),
      isSemantics(label: 'Keep', isButton: true),
    );

    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.recording,
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.getSemantics(find.byKey(videoShutterKey)),
      isSemantics(label: 'Stop and keep', isButton: true),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });
}
