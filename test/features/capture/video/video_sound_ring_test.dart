import 'dart:async';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/audio/recorder_input_ring.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const Duration _settle = Duration(milliseconds: 120);
const Size _screen = Size(1280, 800);

class _Sheet {
  _Sheet(this.phase, this.hearing);

  final VideoRecorderPhase phase;
  final MicrophoneHearing hearing;
}

Future<void> _hear(
  WidgetTester tester,
  StreamController<double> levels,
  double level,
) async {
  levels.add(level);
  await tester.pump();
  await tester.pump(_settle);
}

void _expectRingOnInputButtonOnly(WidgetTester tester) {
  final Finder ring = find.byKey(recorderInputRingKey);
  expect(ring, findsOneWidget);
  expect(
    find.ancestor(
      of: find.byKey(recorderInputKey),
      matching: find.byType(RecorderInputRing),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: find.byType(CrossHatchPlaceholder),
      matching: find.byType(RecorderInputRing),
    ),
    findsNothing,
  );
  final Rect button = tester.getRect(find.byKey(recorderInputKey));
  final Rect drawn = tester.getRect(ring);
  expect(drawn, button.inflate(recorderInputRingReach));
  expect(drawn.left, greaterThan(_screen.width / 2));
  expect(drawn.bottom, lessThan(_screen.height / 2));
  expect(drawn.right, lessThanOrEqualTo(_screen.width));
  expect(drawn.top, greaterThanOrEqualTo(0));
}

void main() {
  testWidgets(
    'the video recorder shows the sound ring while its microphone is open',
    (WidgetTester tester) async {
      tester.view.physicalSize = _screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final StreamController<double> levels =
          StreamController<double>.broadcast();
      addTearDown(levels.close);
      final ValueNotifier<_Sheet> sheet = ValueNotifier<_Sheet>(
        _Sheet(VideoRecorderPhase.idle, MicrophoneHearing.hearing),
      );
      addTearDown(sheet.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[reflectionPromptsOff()],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: fieldNotesTheme(platform: TargetPlatform.macOS),
            home: Scaffold(
              body: ValueListenableBuilder<_Sheet>(
                valueListenable: sheet,
                builder: (BuildContext context, _Sheet shown, Widget? _) =>
                    VideoRecorderSheet(
                      phase: shown.phase,
                      hearing: shown.hearing,
                      levels: levels.stream,
                      onStart: () {},
                      onStop: () {},
                      onLeave: () {},
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await _hear(tester, levels, 0.6);
      _expectRingOnInputButtonOnly(tester);

      sheet.value = _Sheet(
        VideoRecorderPhase.recording,
        MicrophoneHearing.hearing,
      );
      await _hear(tester, levels, 0.6);
      _expectRingOnInputButtonOnly(tester);

      sheet.value = _Sheet(
        VideoRecorderPhase.recording,
        MicrophoneHearing.lost,
      );
      await _hear(tester, levels, 0.6);
      expect(find.byKey(recorderInputRingKey), findsNothing);
    },
  );
}
