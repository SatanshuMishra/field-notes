import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const List<double> _sheetWidths = <double>[636, 408, 356];
const List<double> _sidebarWidths = <double>[860, 1024, 1280];

const List<VideoRecorderPhase> _bandPhases = <VideoRecorderPhase>[
  VideoRecorderPhase.idle,
  VideoRecorderPhase.recording,
];

Future<Rect> _pumpTopBand(
  WidgetTester tester, {
  required double width,
  required VideoRecorderPhase phase,
  List<VideoCaptureDevice> devices = fakeVideoDevices,
}) async {
  await tester.pumpWidget(
    videoSheetHarness(
      SizedBox(
        width: width,
        height: 480,
        child: VideoRecorderSheet(
          phase: phase,
          devices: devices,
          selectedDeviceId: devices.isEmpty ? null : devices.first.id,
          elapsed: const Duration(minutes: 10),
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return tester.getRect(find.byType(VideoRecorderSheet));
}

Rect _chipRect(WidgetTester tester) =>
    tester.getRect(find.byKey(videoSelfViewKey));

void main() {
  testWidgets(
    'idle phase offers the shutter and shows no recording indicators',
    (WidgetTester tester) async {
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

      expect(find.byKey(videoShutterKey), findsOneWidget);
      expect(find.byKey(videoCloseKey), findsOneWidget);
      expect(find.text(stageIdleStatus), findsOneWidget);
      expect(find.text('Auto-stops at 30:00.'), findsOneWidget);
      expect(find.byType(Blink), findsNothing);
      expect(find.byKey(recorderTimerKey), findsNothing);
      expect(find.byType(Toast), findsNothing);
      expect(find.byKey(videoDiscardCircleKey), findsNothing);
      expect(find.byKey(videoSaveCircleKey), findsNothing);
    },
  );

  testWidgets('recording phase shows the preview, blinking dot, and its hint', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.recording,
          preview: const SizedBox(
            key: ValueKey('preview'),
            width: 80,
            height: 80,
          ),
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const ValueKey('preview')), findsOneWidget);
    expect(find.byType(Blink), findsOneWidget);
    expect(find.text(stageRecordingStatus), findsOneWidget);
    expect(find.byKey(recorderTimerKey), findsOneWidget);
    expect(find.text('Auto-stops at 30:00.'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a nudge message surfaces as a non-blocking line while recording',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        videoSheetHarness(
          VideoRecorderSheet(
            phase: VideoRecorderPhase.recording,
            nudgeMessage: '5 minutes in — looking good.',
            onStart: () {},
            onStop: () {},
            onLeave: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('5 minutes in — looking good.'), findsOneWidget);
      expect(find.byType(Toast), findsNothing);
      expect(find.text(stageRecordingStatus), findsOneWidget);
      expect(
        tester.getRect(find.text('5 minutes in — looking good.')).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(RecorderStatusLine)).bottom,
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('idle and recording taps invoke the matching callbacks', (
    WidgetTester tester,
  ) async {
    int starts = 0;
    int leaves = 0;

    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.idle,
          onStart: () => starts++,
          onStop: () {},
          onLeave: () => leaves++,
        ),
      ),
    );

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    await tester.tap(find.byKey(videoCloseKey));
    await tester.pump();

    expect(starts, 1);
    expect(leaves, 1);
  });

  testWidgets('the recording phase shutter invokes onStop', (
    WidgetTester tester,
  ) async {
    int stops = 0;

    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.recording,
          onStart: () {},
          onStop: () => stops++,
          onLeave: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();

    expect(stops, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an error message renders when provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.idle,
          onStart: () {},
          onStop: () {},
          onLeave: () {},
          errorMessage: 'Camera is off.',
        ),
      ),
    );

    expect(find.text('Camera is off.'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Camera is off.')).style?.color,
      const Color(0xFFE58D9C),
    );
  });

  testWidgets('the saving phase disables the primary action', (
    WidgetTester tester,
  ) async {
    int calls = 0;

    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.saving,
          onStart: () => calls++,
          onStop: () => calls++,
          onLeave: () => calls++,
        ),
      ),
    );

    expect(find.text('Saving your video…'), findsOneWidget);
    expect(find.byType(Blink), findsNothing);

    await tester.tap(find.byKey(videoShutterKey));
    await tester.tap(find.byKey(videoCloseKey));
    await tester.pump();
    expect(calls, 0);
  });

  testWidgets('the arming phase shows the live preview and the arming hint', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      videoSheetHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.arming,
          preview: const SizedBox(
            key: ValueKey('preview'),
            width: 80,
            height: 80,
          ),
          onStart: () {},
          onStop: () {},
          onLeave: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('preview')), findsOneWidget);
    expect(find.text('Getting the camera ready…'), findsOneWidget);
    expect(find.text(stageRecordingStatus), findsNothing);
    expect(find.byType(Blink), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the denied phase surfaces guidance and the shutter carries the retry',
    (WidgetTester tester) async {
      int retries = 0;

      await tester.pumpWidget(
        videoSheetHarness(
          VideoRecorderSheet(
            phase: VideoRecorderPhase.denied,
            deniedMessage: 'Enable Camera access in System Settings.',
            onStart: () => retries++,
            onStop: () {},
            onLeave: () {},
          ),
        ),
      );

      expect(
        find.text('Enable Camera access in System Settings.'),
        findsOneWidget,
      );
      expect(find.byKey(videoShutterKey), findsOneWidget);
      expect(find.text(stageIdleStatus), findsNothing);

      await tester.tap(find.byKey(videoShutterKey));
      await tester.pump();

      expect(retries, 1);
    },
  );

  testWidgets('the soft timer never overlaps the camera controls', (
    WidgetTester tester,
  ) async {
    for (final double width in _sheetWidths) {
      for (final VideoRecorderPhase phase in _bandPhases) {
        final String reason = '${width.toInt()} wide while ${phase.name}';
        await _pumpTopBand(tester, width: width, phase: phase);
        expect(tester.takeException(), isNull, reason: reason);

        final Finder flip = find.byKey(videoFlipCameraKey);
        final Finder timer = find.byKey(recorderTimerKey);
        expect(find.byType(CameraPicker), findsNothing, reason: reason);
        if (phase == VideoRecorderPhase.idle) {
          expect(flip, findsOneWidget, reason: reason);
          expect(timer, findsNothing, reason: reason);
          expect(
            tester.getRect(flip).overlaps(_chipRect(tester)),
            isFalse,
            reason: reason,
          );
        } else {
          expect(flip, findsNothing, reason: reason);
          expect(
            tester.getRect(timer).overlaps(_chipRect(tester)),
            isFalse,
            reason: reason,
          );
        }
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the top band keeps its painted anchors', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      final bool sidebar = platform == TargetPlatform.macOS;
      final double inset = sidebar ? 18 : 8;
      final double leaveLeft = sidebar ? windowButtonsClearance : 8;
      for (final double width in sidebar ? _sidebarWidths : _sheetWidths) {
        final String reason = '${platform.name} ${width.toInt()} wide';

        final Rect sheet = await _pumpTopBand(
          tester,
          width: width,
          phase: VideoRecorderPhase.idle,
        );
        expect(tester.takeException(), isNull, reason: reason);
        final Rect close = tester.getRect(find.byKey(videoCloseKey));
        final Rect chip = _chipRect(tester);
        final Finder switcher = sidebar
            ? find.byType(CameraPicker)
            : find.byKey(videoFlipCameraKey);
        final Rect picker = tester.getRect(switcher);
        expect(close.left - sheet.left, leaveLeft, reason: reason);
        expect(close.height, greaterThanOrEqualTo(48), reason: reason);
        expect(sheet.right - chip.right, inset, reason: reason);
        expect(chip.height, greaterThanOrEqualTo(48), reason: reason);
        expect(picker.right, lessThanOrEqualTo(chip.left), reason: reason);
        expect(picker.left, greaterThanOrEqualTo(close.right), reason: reason);
        expect(chip.center.dy, closeTo(close.center.dy, 0.01), reason: reason);
        expect(
          picker.center.dy,
          closeTo(close.center.dy, 0.01),
          reason: reason,
        );

        final Rect bare = await _pumpTopBand(
          tester,
          width: width,
          phase: VideoRecorderPhase.idle,
          devices: const <VideoCaptureDevice>[],
        );
        expect(switcher, findsNothing, reason: reason);
        expect(bare.right - _chipRect(tester).right, inset, reason: reason);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
