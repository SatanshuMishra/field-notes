import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/audio/cannot_hear_notice.dart';
import 'package:field_notes/features/capture/audio/microphone_glyph.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

class _Calls {
  int starts = 0;
  int stops = 0;
}

Future<void> _pump(
  WidgetTester tester, {
  required VideoRecorderPhase phase,
  required ValueNotifier<MicrophoneHearing> hearing,
  required _Calls calls,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[reflectionPromptsOff()],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: ValueListenableBuilder<MicrophoneHearing>(
            valueListenable: hearing,
            builder:
                (BuildContext context, MicrophoneHearing heard, Widget? _) =>
                    VideoRecorderSheet(
                      phase: phase,
                      hearing: heard,
                      onStart: () => calls.starts++,
                      onStop: () => calls.stops++,
                      onLeave: () {},
                    ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    "the video recorder does not start and shows the can't-hear-you notice",
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final ValueNotifier<MicrophoneHearing> hearing =
          ValueNotifier<MicrophoneHearing>(MicrophoneHearing.cannotHear);
      addTearDown(hearing.dispose);
      final _Calls calls = _Calls();
      await _pump(
        tester,
        phase: VideoRecorderPhase.idle,
        hearing: hearing,
        calls: calls,
      );

      await tester.tap(find.byKey(videoShutterKey), warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(calls.starts, 0);
      expect(find.text(cannotHearMessage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(cannotHearNoticeKey),
          matching: find.byType(MicrophoneGlyph),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(cannotHearNoticeKey),
          matching: find.byKey(cannotHearPointerKey),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(cannotHearNoticeLabel), findsOneWidget);

      hearing.value = MicrophoneHearing.hearing;
      await tester.pump();
      expect(find.byKey(cannotHearNoticeKey), findsNothing);
      await tester.tap(find.byKey(videoShutterKey));
      await tester.pump();
      expect(calls.starts, 1);
      semantics.dispose();
    },
  );

  testWidgets(
    'a video take that loses sound shows the reconnecting warning and keeps recording',
    (WidgetTester tester) async {
      final ValueNotifier<MicrophoneHearing> hearing =
          ValueNotifier<MicrophoneHearing>(MicrophoneHearing.hearing);
      addTearDown(hearing.dispose);
      final _Calls calls = _Calls();
      await _pump(
        tester,
        phase: VideoRecorderPhase.recording,
        hearing: hearing,
        calls: calls,
      );
      expect(find.text(soundLostMessage), findsNothing);

      hearing.value = MicrophoneHearing.lost;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(soundLostMessage), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(soundLostMessage), findsOneWidget);
      expect(find.byKey(videoSaveCircleKey), findsOneWidget);

      await tester.tap(find.byKey(videoSaveCircleKey));
      await tester.pump();
      expect(calls.stops, 1);

      hearing.value = MicrophoneHearing.hearing;
      await tester.pump();
      expect(find.text(soundLostMessage), findsNothing);
    },
  );
}
