import 'package:field_notes/app/app.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/capture/video/video_test_support.dart';
import '../test/features/capture/voice/voice_test_support.dart';
import 'support/integration_sandbox.dart';

const Duration _step = Duration(milliseconds: 100);
final DateTime _pinnedNow = DateTime(2026, 7, 21, 9, 30);

List<Override> _uiFlowOverrides({
  required IntegrationSandbox sandbox,
  required FakeVoiceRecorder voiceRecorder,
  required FakeVideoRecorder videoRecorder,
}) {
  return <Override>[
    ...sandbox.overrides,
    todayClockProvider.overrideWithValue(() => _pinnedNow),
    voiceRecorderProvider.overrideWithValue(voiceRecorder),
    videoRecorderProvider.overrideWithValue(videoRecorder),
  ];
}

Future<void> _pumpApp(WidgetTester tester, List<Override> overrides) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const FieldNotesApp()),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester, {int times = 4}) async {
  for (int i = 0; i < times; i++) {
    await tester.pump(_step);
  }
}

Future<void> _pickCaptureRow(WidgetTester tester, String optionLabel) async {
  await tester.tap(find.text(optionLabel));
  await tester.pump();
  await _settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'writing a note through the real capture UI shows it in the today feed',
      (WidgetTester tester) async {
    final IntegrationSandbox sandbox = await IntegrationSandbox.create('note');
    addTearDown(sandbox.dispose);

    await _pumpApp(
      tester,
      _uiFlowOverrides(
        sandbox: sandbox,
        voiceRecorder: FakeVoiceRecorder(),
        videoRecorder: FakeVideoRecorder(),
      ),
    );

    await _pickCaptureRow(tester, 'Write a note');
    expect(find.byType(TextComposerSheet), findsOneWidget);

    final String noteText =
        'ui-flow-note-${DateTime.now().microsecondsSinceEpoch}';
    await tester.enterText(find.byType(EditableText), noteText);
    await tester.pump();

    await tester.tap(find.text('Save note'));
    await tester.pump();
    expect(find.text('Saving...'), findsOneWidget);

    await _settle(tester, times: 6);

    expect(find.byType(TextComposerSheet), findsNothing);
    expect(find.byType(NoteBody), findsOneWidget);
    expect(find.text(noteText), findsOneWidget);
  });

  testWidgets(
      'recording voice through the real capture UI shows an entry in the today feed',
      (WidgetTester tester) async {
    final IntegrationSandbox sandbox = await IntegrationSandbox.create('voice');
    addTearDown(sandbox.dispose);

    await _pumpApp(
      tester,
      _uiFlowOverrides(
        sandbox: sandbox,
        voiceRecorder: FakeVoiceRecorder(),
        videoRecorder: FakeVideoRecorder(),
      ),
    );

    await _pickCaptureRow(tester, 'Record voice');
    expect(find.byType(VoiceRecorderSheet), findsOneWidget);

    await tester.tap(find.text('Record'));
    await _settle(tester);
    expect(find.text('Stop & save'), findsOneWidget);

    await tester.tap(find.text('Stop & save'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    await _settle(tester, times: 6);

    expect(find.byType(VoiceRecorderSheet), findsNothing);
    expect(find.byType(VoiceBody), findsOneWidget);
  });

  testWidgets(
      'recording video through the real capture UI shows an entry in the today feed',
      (WidgetTester tester) async {
    final IntegrationSandbox sandbox = await IntegrationSandbox.create('video');
    addTearDown(sandbox.dispose);
    final FakeVideoRecorder videoRecorder = FakeVideoRecorder();

    await _pumpApp(
      tester,
      _uiFlowOverrides(
        sandbox: sandbox,
        voiceRecorder: FakeVoiceRecorder(),
        videoRecorder: videoRecorder,
      ),
    );

    await _pickCaptureRow(tester, 'Record video');
    expect(find.byType(VideoRecorderSheet), findsOneWidget);

    expect(fakeVideoPreview(deviceId: 'built-in-id'), findsOneWidget);
    expect(find.byType(CrossHatchPlaceholder), findsNothing);
    expect(find.byType(CameraPicker), findsOneWidget);
    expect(find.text('Built-in Camera'), findsOneWidget);
    expect(videoRecorder.releaseCalls, 0);

    await tester.tap(find.text('Record'));
    await _settle(tester);
    expect(find.text('Stop & save'), findsOneWidget);

    await tester.tap(find.text('Stop & save'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);

    await _settle(tester, times: 6);

    expect(find.byType(VideoRecorderSheet), findsNothing);
    expect(find.byType(VideoBody), findsOneWidget);
    expect(videoRecorder.releaseCalls, 1);
  });

  testWidgets(
      'switching cameras in the real capture UI re-previews the picked camera '
      'and releases the camera when the sheet is dismissed',
      (WidgetTester tester) async {
    final IntegrationSandbox sandbox =
        await IntegrationSandbox.create('video-picker');
    addTearDown(sandbox.dispose);
    final FakeVideoRecorder videoRecorder = FakeVideoRecorder();

    await _pumpApp(
      tester,
      _uiFlowOverrides(
        sandbox: sandbox,
        voiceRecorder: FakeVoiceRecorder(),
        videoRecorder: videoRecorder,
      ),
    );

    await _pickCaptureRow(tester, 'Record video');
    expect(find.byType(VideoRecorderSheet), findsOneWidget);

    await tester.tap(find.text('Built-in Camera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB Camera'));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(videoRecorder.previewDeviceId, 'usb-id');
    expect(fakeVideoPreview(deviceId: 'usb-id'), findsOneWidget);

    final int releasesBeforeCancel = videoRecorder.releaseCalls;
    await tester.tap(find.text('Cancel'));
    await _settle(tester, times: 6);

    expect(find.byType(VideoRecorderSheet), findsNothing);
    expect(videoRecorder.releaseCalls, releasesBeforeCancel + 1);
  });
}
