import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/video/camera_picker.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video/video_test_support.dart';
import '../voice/voice_test_support.dart' show FakeVoiceRecorder;

enum _Recorder { voice, video }

const String _date = '2026-09-28';
const String _openLabel = 'open';
const Size _desktopWindow = Size(1280, 800);
const Size _minimumWindow = Size(873, 600);
const Size _phoneWindow = Size(384, 832);
const Rect _trafficLights = Rect.fromLTRB(0, 0, 78, 42);
const Rect _captionButtons = Rect.fromLTRB(1142, 0, 1280, 42);
const Rect _titleStrip = Rect.fromLTRB(0, 0, 1280, 42);

Future<void> _openRecorder(
  WidgetTester tester, {
  required _Recorder recorder,
  required TargetPlatform platform,
  required Size window,
  bool questions = false,
  FakeViewPadding? padding,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  if (padding != null) {
    tester.view.padding = padding;
  }
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        videoRecorderProvider.overrideWith((Ref ref) => FakeVideoRecorder()),
        voiceRecorderProvider.overrideWith(
          (Ref ref) => recorder == _Recorder.video
              ? CameraOffVoiceRecorder()
              : FakeVoiceRecorder(),
        ),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
        reflectionPromptsEnabledProvider.overrideWithValue(questions),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: TextButton(
                onPressed: () => switch (recorder) {
                  _Recorder.voice => showVoiceComposer(context, _date),
                  _Recorder.video => showVideoComposer(context, _date),
                },
                child: const Text(_openLabel),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_openLabel));
  await tester.pump();
  await tester.pump(immersiveFadeFor(resolveShellLayout(platform)));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  debugDefaultTargetPlatformOverride = null;
}

List<String> _recordWindowCalls(WidgetTester tester) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowChannel,
    (MethodCall call) async {
      calls.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      null,
    ),
  );
  return calls;
}

List<Finder> _videoRowControls() => <Finder>[
  find.byKey(videoCloseKey),
  find.byType(CameraPicker),
  find.byKey(videoCameraKey),
  find.byKey(recorderInputKey),
];

void _expectNoControlIn(WidgetTester tester, List<Finder> controls, Rect zone) {
  final RenderObject band = tester.renderObject(find.byKey(recorderTopBandKey));
  for (final Finder control in controls) {
    expect(control, findsOneWidget);
    final Rect rect = tester.getRect(control);
    expect(rect.overlaps(zone), isFalse, reason: '$control at $rect');
  }
  for (double x = zone.left + 1; x < zone.right; x += 8) {
    for (double y = zone.top + 1; y < zone.bottom; y += 8) {
      final Offset point = Offset(x, y);
      final List<HitTestTarget> hits = tester
          .hitTestOnBinding(point)
          .path
          .map((HitTestEntry entry) => entry.target)
          .toList();
      expect(hits, contains(band), reason: '$point');
      for (final Finder control in controls) {
        expect(
          hits,
          isNot(contains(tester.renderObject(control))),
          reason: '$control at $point',
        );
      }
    }
  }
}

void main() {
  testWidgets(
    'the macOS video recorder keeps its controls below the traffic lights',
    (WidgetTester tester) async {
      await _openRecorder(
        tester,
        recorder: _Recorder.video,
        platform: TargetPlatform.macOS,
        window: _desktopWindow,
      );
      expect(find.byType(VideoRecorderSheet), findsOneWidget);

      expect(tester.getRect(find.byKey(recorderTopBandKey)), _titleStrip);
      final List<String> calls = _recordWindowCalls(tester);
      await tester.drag(find.byKey(recorderTopBandKey), const Offset(60, 20));
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, <String>[startDragMethod]);

      final Rect close = tester.getRect(find.byKey(videoCloseKey));
      expect(close.top, greaterThanOrEqualTo(42));
      expect(close.left, 18);
      expect(tester.getRect(find.byKey(recorderInputKey)).right, 1262);
      expect(
        tester.getRect(find.byKey(videoCameraKey)).right,
        lessThanOrEqualTo(tester.getRect(find.byKey(recorderInputKey)).left),
      );
      _expectNoControlIn(tester, _videoRowControls(), _trafficLights);

      await _close(tester);
    },
  );

  testWidgets(
    'the Windows video recorder keeps its controls below the caption buttons',
    (WidgetTester tester) async {
      await _openRecorder(
        tester,
        recorder: _Recorder.video,
        platform: TargetPlatform.windows,
        window: _desktopWindow,
      );
      expect(find.byType(VideoRecorderSheet), findsOneWidget);

      final Rect close = tester.getRect(find.byKey(videoCloseKey));
      expect(close.top, greaterThanOrEqualTo(42));
      expect(close.left, 18);
      expect(tester.getRect(find.byKey(recorderInputKey)).right, 1262);
      expect(
        tester.getRect(find.byKey(videoCameraKey)).right,
        lessThanOrEqualTo(tester.getRect(find.byKey(recorderInputKey)).left),
      );
      _expectNoControlIn(tester, _videoRowControls(), _captionButtons);

      await _close(tester);
    },
  );

  testWidgets('the macOS voice recorder keeps Leave below the traffic lights', (
    WidgetTester tester,
  ) async {
    await _openRecorder(
      tester,
      recorder: _Recorder.voice,
      platform: TargetPlatform.macOS,
      window: _desktopWindow,
    );
    expect(find.byType(VoiceRecorderSheet), findsOneWidget);

    final Rect close = tester.getRect(find.byKey(voiceCloseKey));
    expect(close.top, greaterThanOrEqualTo(42));
    expect(close.left, 18);
    expect(tester.getRect(find.byKey(recorderTopBandKey)), _titleStrip);
    _expectNoControlIn(tester, <Finder>[
      find.byKey(voiceCloseKey),
      find.byKey(recorderInputKey),
    ], _trafficLights);

    await _close(tester);
  });

  testWidgets(
    'the macOS voice recorder keeps its question 108 px from the top at the minimum window',
    (WidgetTester tester) async {
      await _openRecorder(
        tester,
        recorder: _Recorder.voice,
        platform: TargetPlatform.macOS,
        window: _minimumWindow,
        questions: true,
      );
      expect(find.byType(VoiceRecorderSheet), findsOneWidget);

      expect(
        tester.getRect(find.byKey(voiceCloseKey)).top,
        greaterThanOrEqualTo(42),
      );
      final Finder prompt = find.descendant(
        of: find.byType(VoiceRecorderSheet),
        matching: find.byType(ReflectionPrompt),
      );
      expect(prompt, findsOneWidget);
      expect(tester.getRect(prompt).top, 108);
      expect(find.byKey(reflectionQuestionKey), findsOneWidget);

      await _close(tester);
    },
  );

  testWidgets(
    'the macOS video recorder keeps its question 34 px below the moved controls at the minimum window',
    (WidgetTester tester) async {
      await _openRecorder(
        tester,
        recorder: _Recorder.video,
        platform: TargetPlatform.macOS,
        window: _minimumWindow,
        questions: true,
      );
      expect(find.byType(VideoRecorderSheet), findsOneWidget);

      expect(tester.getRect(find.byKey(videoCloseKey)).bottom, 90);
      final Finder prompt = find.descendant(
        of: find.byType(VideoRecorderSheet),
        matching: find.byType(ReflectionPrompt),
      );
      expect(prompt, findsOneWidget);
      expect(tester.getRect(prompt).top, 124);
      expect(find.byKey(reflectionQuestionKey), findsOneWidget);

      await _close(tester);
    },
  );

  testWidgets(
    'the phone video recorder band keeps its place under the status bar',
    (WidgetTester tester) async {
      await _openRecorder(
        tester,
        recorder: _Recorder.video,
        platform: TargetPlatform.android,
        window: _phoneWindow,
        padding: const FakeViewPadding(top: 24),
      );
      expect(find.byType(VideoRecorderSheet), findsOneWidget);

      final Rect close = tester.getRect(find.byKey(videoCloseKey));
      expect(close.center.dy, 52);
      expect(close.left, 8);
      expect(find.byKey(recorderTopBandKey), findsNothing);

      await _close(tester);
    },
  );
}
