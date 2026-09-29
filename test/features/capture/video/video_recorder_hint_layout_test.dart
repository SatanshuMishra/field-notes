import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

void main() {
  testWidgets('the hint sits clear of the shutter in every phase', (
    WidgetTester tester,
  ) async {
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

    final double idleShutterTop = tester
        .getRect(find.byKey(videoShutterKey))
        .top;
    expect(
      tester.getRect(find.text(stageIdleStatus)).bottom,
      lessThanOrEqualTo(idleShutterTop - 8),
    );
    expect(
      tester.getRect(find.text('Auto-stops at 30:00.')).bottom,
      lessThanOrEqualTo(idleShutterTop - 8),
    );

    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.recording,
          nudgeMessage: '10 minutes recorded.',
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final double recordingShutterTop = tester
        .getRect(find.byKey(videoShutterKey))
        .top;
    expect(
      tester.getRect(find.text(stageRecordingStatus)).bottom,
      lessThanOrEqualTo(recordingShutterTop - 8),
    );
    expect(
      tester.getRect(find.text('10 minutes recorded.')).bottom,
      lessThanOrEqualTo(recordingShutterTop - 8),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
