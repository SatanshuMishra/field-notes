import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video_test_support.dart';

const List<double> _sheetWidths = <double>[636, 408, 356];

const List<(Duration, String)> _readouts = <(Duration, String)>[
  (Duration.zero, '0:00'),
  (Duration(minutes: 10), '10:00'),
];

Future<Rect> _pumpTopBand(
  WidgetTester tester, {
  required double width,
  required Duration elapsed,
  List<VideoCaptureDevice> devices = fakeVideoDevices,
}) async {
  await tester.pumpWidget(
    videoHarness(
      SizedBox(
        width: width,
        height: 480,
        child: VideoRecorderSheet(
          phase: elapsed == Duration.zero
              ? VideoRecorderPhase.idle
              : VideoRecorderPhase.recording,
          devices: devices,
          selectedDeviceId: devices.isEmpty ? null : devices.first.id,
          elapsed: elapsed,
          onStart: () {},
          onStop: () {},
          onCancel: () {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return tester.getRect(find.byType(VideoRecorderSheet));
}

Rect _pillRect(WidgetTester tester, String readout) {
  return tester.getRect(
    find
        .ancestor(of: find.text(readout), matching: find.byType(DecoratedBox))
        .first,
  );
}

void main() {
  testWidgets('idle phase offers the shutter and shows no recording indicators',
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

    expect(find.byKey(videoShutterKey), findsOneWidget);
    expect(find.byKey(videoCloseKey), findsOneWidget);
    expect(find.text('tap the button to start recording'), findsOneWidget);
    expect(find.byType(Blink), findsNothing);
    expect(find.byType(Toast), findsNothing);
  });

  testWidgets('recording phase shows the preview, blinking dot, and its hint',
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
    expect(find.text('recording… tap pause or stop'), findsOneWidget);

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
    expect(find.text('recording… tap pause or stop'), findsOneWidget);

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

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    await tester.tap(find.byKey(videoCloseKey));
    await tester.pump();

    expect(starts, 1);
    expect(cancels, 1);
  });

  testWidgets('the recording phase shutter invokes onStop',
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

    await tester.tap(find.byKey(videoShutterKey));
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

    expect(find.text('Saving your video…'), findsOneWidget);
    expect(find.byType(Blink), findsNothing);
  });

  testWidgets('the arming phase shows the live preview and the arming hint',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.arming,
          preview: const SizedBox(key: ValueKey('preview'), width: 80, height: 80),
          onStart: () {},
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('preview')), findsOneWidget);
    expect(find.text('Getting the camera ready…'), findsOneWidget);
    expect(find.text('recording… tap pause or stop'), findsNothing);
    expect(find.byType(Blink), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'the denied phase surfaces guidance and the shutter carries the retry',
      (WidgetTester tester) async {
    int retries = 0;

    await tester.pumpWidget(
      videoHarness(
        VideoRecorderSheet(
          phase: VideoRecorderPhase.denied,
          deniedMessage: 'Enable Camera access in System Settings.',
          onStart: () => retries++,
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.text('Enable Camera access in System Settings.'), findsOneWidget);
    expect(find.byKey(videoShutterKey), findsOneWidget);
    expect(find.text('tap the button to start recording'), findsNothing);

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('the timer pill never overlaps the camera picker',
      (WidgetTester tester) async {
    for (final double width in _sheetWidths) {
      for (final (Duration elapsed, String readout) in _readouts) {
        await _pumpTopBand(tester, width: width, elapsed: elapsed);

        final Rect pill = _pillRect(tester, readout);
        final String reason = '${width.toInt()} wide at $readout';
        expect(
          pill.overlaps(tester.getRect(find.text('Camera'))),
          isFalse,
          reason: reason,
        );
        expect(
          pill.overlaps(tester.getRect(find.byType(SettingsSelect<String>))),
          isFalse,
          reason: reason,
        );
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the top band keeps its painted anchors',
      (WidgetTester tester) async {
    for (final double width in _sheetWidths) {
      for (final (Duration elapsed, String readout) in _readouts) {
        final String reason = '${width.toInt()} wide at $readout';

        final Rect bare = await _pumpTopBand(
          tester,
          width: width,
          elapsed: elapsed,
          devices: const <VideoCaptureDevice>[],
        );
        final Rect centred = _pillRect(tester, readout);
        expect(centred.top - bare.top, 16, reason: reason);
        expect(centred.center.dx, closeTo(bare.center.dx, 0.01),
            reason: reason);

        final Rect sheet = await _pumpTopBand(
          tester,
          width: width,
          elapsed: elapsed,
        );
        final Rect pill = _pillRect(tester, readout);
        final Rect select =
            tester.getRect(find.byType(SettingsSelect<String>));
        final Rect close = tester.getRect(find.byKey(videoCloseKey));
        expect(pill.top - sheet.top, 16, reason: reason);
        expect(select.top - sheet.top, 16, reason: reason);
        expect(sheet.right - select.right, 16, reason: reason);
        expect(close.shift(-sheet.topLeft), const Rect.fromLTRB(3, 3, 51, 51),
            reason: reason);
        expect(pill.left, greaterThanOrEqualTo(close.right), reason: reason);
        if (width == 636) {
          expect(pill.center.dx, closeTo(sheet.center.dx, 0.01),
              reason: reason);
        }
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
