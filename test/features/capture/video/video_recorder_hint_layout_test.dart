import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

void main() {
  testWidgets('the hint sits clear of the shutter in every phase',
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

    expect(
      tester.getRect(find.text('tap the button to start recording')).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(videoShutterKey)).top - 8,
      ),
    );

    await tester.pumpWidget(
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.recording,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      tester.getRect(find.text('recording… tap pause or stop')).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(videoShutterKey)).top - 8,
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
