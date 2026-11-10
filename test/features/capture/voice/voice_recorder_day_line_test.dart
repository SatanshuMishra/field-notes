import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/video/video_composer.dart';
import 'package:field_notes/features/capture/video/video_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video/video_test_support.dart'
    show CameraOffVoiceRecorder, FakeCaptureService, FakeVideoRecorder;
import 'voice_test_support.dart' show FakeVoiceRecorder;

const Key _openKey = ValueKey<String>('open-recorder');
const String _pastDay = '2026-09-28';
const String _today = '2026-11-10';
const String _pastDateLabel = 'Monday, September 28';
const String _leadPast = 'adding to';
const String _leadToday = 'today';
const String _oldPrivacy = 'only you will hear this';
const Duration _fade = Duration(milliseconds: 600);

enum _Kind { voice, video }

Future<void> _open(
  WidgetTester tester, {
  required _Kind kind,
  required String date,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        todayClockProvider.overrideWithValue(() => DateTime(2026, 11, 10, 9)),
        voiceRecorderProvider.overrideWith(
          (Ref ref) => switch (kind) {
            _Kind.voice => FakeVoiceRecorder(),
            _Kind.video => CameraOffVoiceRecorder(),
          },
        ),
        videoRecorderProvider.overrideWith((Ref ref) => FakeVideoRecorder()),
        captureServiceProvider.overrideWith((Ref ref) => FakeCaptureService()),
        reflectionPromptsEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              key: _openKey,
              onPressed: () => switch (kind) {
                _Kind.voice => showVoiceComposer(context, date),
                _Kind.video => showVideoComposer(context, date),
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_openKey));
  await tester.pump();
  await tester.pump(_fade);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  debugDefaultTargetPlatformOverride = null;
}

void main() {
  testWidgets('the voice recorder for a past day says it is adding to it', (
    WidgetTester tester,
  ) async {
    await _open(tester, kind: _Kind.voice, date: _pastDay);

    expect(find.text(_leadPast), findsOneWidget);
    expect(find.text(_pastDateLabel), findsOneWidget);
    expect(find.textContaining(_oldPrivacy, findRichText: true), findsNothing);
    await _close(tester);
  });

  testWidgets('the voice recorder for today says today', (
    WidgetTester tester,
  ) async {
    await _open(tester, kind: _Kind.voice, date: _today);

    expect(find.text(_leadToday), findsOneWidget);
    expect(find.text(_leadPast), findsNothing);
    expect(find.textContaining(_oldPrivacy, findRichText: true), findsNothing);
    await _close(tester);
  });

  testWidgets('the video recorder for a past day shows the same day line', (
    WidgetTester tester,
  ) async {
    await _open(tester, kind: _Kind.video, date: _pastDay);

    expect(find.text(_leadPast), findsOneWidget);
    expect(find.text(_pastDateLabel), findsOneWidget);
    await _close(tester);
  });
}
