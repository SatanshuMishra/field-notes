import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

void main() {
  testWidgets('the voice recorder close and mic controls are labelled buttons',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

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

    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.bySemanticsLabel('Start recording'), findsOneWidget);

    handle.dispose();
  });
}
