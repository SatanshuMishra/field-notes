import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'video/video_test_support.dart' as video;
import 'voice/voice_test_support.dart' as voice;

const MethodChannel _stayAwake = MethodChannel('field_notes/stay_awake');

List<String> _recordStayAwakeCalls() {
  final List<String> calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_stayAwake, (MethodCall call) async {
        calls.add(call.method);
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_stayAwake, null),
  );
  return calls;
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.open});

  final void Function(BuildContext context) open;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => open(context),
      child: const Text('open'),
    );
  }
}

Widget _voiceApp(voice.FakeVoiceRecorder recorder) {
  return ProviderScope(
    overrides: <Override>[
      voiceRecorderProvider.overrideWith((Ref ref) => recorder),
      captureServiceProvider.overrideWith(
        (Ref ref) => voice.FakeCaptureService(),
      ),
      reflectionPromptsEnabledProvider.overrideWithValue(false),
    ],
    child: voice.voiceHarness(
      _Trigger(open: (BuildContext context) {
        showVoiceComposer(context, '2026-10-11');
      }),
    ),
  );
}

Widget _videoApp(video.FakeVideoRecorder recorder) {
  return ProviderScope(
    overrides: <Override>[
      videoRecorderProvider.overrideWith((Ref ref) => recorder),
      captureServiceProvider.overrideWith(
        (Ref ref) => video.FakeCaptureService(),
      ),
      video.reflectionPromptsOff(),
    ],
    child: video.videoHarness(
      _Trigger(open: (BuildContext context) {
        showVideoComposer(context, '2026-10-11');
      }),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('a voice take holds the device awake until it is kept', (
    WidgetTester tester,
  ) async {
    final List<String> calls = _recordStayAwakeCalls();
    await tester.pumpWidget(_voiceApp(voice.FakeVoiceRecorder()));
    await _open(tester);
    expect(calls, isEmpty);

    await tester.tap(find.byKey(voiceRecordButtonKey));
    await tester.pump();
    expect(calls, <String>['hold']);

    await tester.tap(find.byKey(voiceRecordButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(voiceRecordButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, <String>['hold']);

    await tester.tap(find.byKey(voiceSavePillKey));
    await _settle(tester);
    expect(calls, <String>['hold', 'release']);

    await _closeApp(tester);
    expect(calls, <String>['hold', 'release']);
  });

  testWidgets('letting a voice take go releases the device', (
    WidgetTester tester,
  ) async {
    final List<String> calls = _recordStayAwakeCalls();
    await tester.pumpWidget(_voiceApp(voice.FakeVoiceRecorder()));
    await _open(tester);
    await voice.startVoiceTake(tester);
    expect(calls, <String>['hold']);

    await tester.tap(find.byKey(voiceDiscardPillKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(voiceDiscardConfirmKey));
    await _settle(tester);
    expect(calls, <String>['hold', 'release']);

    await _closeApp(tester);
  });

  testWidgets('closing the app in the middle of a voice take releases the '
      'device', (WidgetTester tester) async {
    final List<String> calls = _recordStayAwakeCalls();
    await tester.pumpWidget(_voiceApp(voice.FakeVoiceRecorder()));
    await _open(tester);
    await voice.startVoiceTake(tester);
    expect(calls, <String>['hold']);

    await _closeApp(tester);
    expect(calls, <String>['hold', 'release']);
  });

  testWidgets('a video take holds the device awake until it is saved', (
    WidgetTester tester,
  ) async {
    final List<String> calls = _recordStayAwakeCalls();
    await tester.pumpWidget(_videoApp(video.FakeVideoRecorder()));
    await _open(tester);
    expect(calls, isEmpty);

    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    await tester.tap(find.byKey(videoShutterKey));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(calls, <String>['hold']);

    await tester.tap(find.byKey(videoShutterKey));
    await _settle(tester);
    expect(calls, <String>['hold', 'release']);

    await _closeApp(tester);
    expect(calls, <String>['hold', 'release']);
  });

  testWidgets('a voice take that fails to start releases the device', (
    WidgetTester tester,
  ) async {
    final List<String> calls = _recordStayAwakeCalls();
    await tester.pumpWidget(
      _voiceApp(
        voice.FakeVoiceRecorder(
          startError: const VoiceRecorderException('The microphone is busy.'),
        ),
      ),
    );
    await _open(tester);
    await voice.startVoiceTake(tester);
    expect(find.text('The microphone is busy.'), findsOneWidget);
    expect(calls, <String>['hold', 'release']);

    await _closeApp(tester);
    expect(calls, <String>['hold', 'release']);
  });

  testWidgets('a video take that fails to start releases the device', (
    WidgetTester tester,
  ) async {
    final List<String> calls = _recordStayAwakeCalls();
    await tester.pumpWidget(
      _videoApp(
        video.FakeVideoRecorder(
          startError: const VideoRecorderException('The camera is busy.'),
        ),
      ),
    );
    await _open(tester);
    await tester.tap(find.byKey(videoShutterKey));
    await tester.pump();
    await tester.tap(find.byKey(videoShutterKey));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('The camera is busy.'), findsOneWidget);
    expect(calls, <String>['hold', 'release']);

    await _closeApp(tester);
    expect(calls, <String>['hold', 'release']);
  });

  testWidgets('opening and closing the voice recorder without a take never '
      'holds the device', (WidgetTester tester) async {
    final List<String> calls = _recordStayAwakeCalls();
    await tester.pumpWidget(_voiceApp(voice.FakeVoiceRecorder()));
    await _open(tester);
    await tester.tap(find.byKey(voiceCloseKey));
    await _settle(tester);

    await _closeApp(tester);
    expect(calls, isEmpty);
  });

  testWidgets('opening and closing the video recorder without a take never '
      'holds the device', (WidgetTester tester) async {
    final List<String> calls = _recordStayAwakeCalls();
    await tester.pumpWidget(_videoApp(video.FakeVideoRecorder()));
    await _open(tester);
    await tester.tap(find.byKey(videoCloseKey));
    await _settle(tester);

    await _closeApp(tester);
    expect(calls, isEmpty);
  });
}
