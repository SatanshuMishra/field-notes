import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

const Duration _elapsed = Duration(minutes: 1, seconds: 5);
const String _elapsedText = '1:05';
const String _savingText = 'Saving your recording…';

Future<void> _pumpLine(
  WidgetTester tester, {
  required StagePhase phase,
  required bool inline,
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        backgroundColor: recorderStageColor,
        body: Center(
          child: RecorderStatusLine(
            phase: phase,
            elapsed: _elapsed,
            savingText: _savingText,
            inline: inline,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _useWindow(WidgetTester tester, TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = platform == TargetPlatform.macOS
      ? const Size(1280, 800)
      : const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('each stage phase shows its own status text and announcement', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    final SemanticsHandle semantics = tester.ensureSemantics();
    const Map<StagePhase, String> expectedText = <StagePhase, String>{
      StagePhase.idle: 'Tap when you’re ready. There’s no wrong way to say it.',
      StagePhase.breathing: 'Breathe in… and slowly out.',
      StagePhase.recording: 'I’m listening. Take your time.',
      StagePhase.paused: 'Paused. Nothing’s lost.',
      StagePhase.saving: _savingText,
    };
    const Map<StagePhase, String> expectedAnnouncement = <StagePhase, String>{
      StagePhase.idle: 'Ready to record',
      StagePhase.breathing: 'Breathing before recording',
      StagePhase.recording: 'Recording',
      StagePhase.paused: 'Paused',
      StagePhase.saving: 'Saving',
    };

    final Set<String> shown = <String>{};
    for (final StagePhase phase in StagePhase.values) {
      await _pumpLine(tester, phase: phase, inline: false);
      final Text status = tester.widget<Text>(
        find.byKey(recorderStatusTextKey),
      );
      expect(status.data, expectedText[phase], reason: phase.name);
      shown.add(status.data!);
      expect(
        tester.getSemantics(find.byKey(recorderStatusTextKey)),
        isSemantics(
          label: expectedAnnouncement[phase],
          value: expectedText[phase],
          isLiveRegion: true,
        ),
        reason: phase.name,
      );
    }
    expect(shown, hasLength(StagePhase.values.length));

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pumpLine(
      tester,
      phase: StagePhase.idle,
      inline: false,
      platform: TargetPlatform.android,
    );
    expect(
      tester.widget<Text>(find.byKey(recorderStatusTextKey)).data,
      'Tap when you’re ready.',
    );

    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the soft timer shows only while recording or paused', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS);
    for (final bool inline in <bool>[false, true]) {
      for (final StagePhase phase in StagePhase.values) {
        await _pumpLine(tester, phase: phase, inline: inline);
        final bool shows =
            phase == StagePhase.recording || phase == StagePhase.paused;
        expect(
          find.text(_elapsedText),
          shows ? findsOneWidget : findsNothing,
          reason: '${phase.name} inline: $inline',
        );
      }
    }

    await _pumpLine(tester, phase: StagePhase.recording, inline: false);
    final Rect stackedStatus = tester.getRect(
      find.byKey(recorderStatusTextKey),
    );
    final Rect stackedTimer = tester.getRect(find.text(_elapsedText));
    expect(stackedTimer.top, greaterThanOrEqualTo(stackedStatus.bottom));

    await _pumpLine(tester, phase: StagePhase.paused, inline: true);
    final Rect inlineStatus = tester.getRect(find.byKey(recorderStatusTextKey));
    final Rect inlineTimer = tester.getRect(find.text(_elapsedText));
    expect(inlineTimer.left, greaterThanOrEqualTo(inlineStatus.right));
    expect(inlineTimer.center.dy, closeTo(inlineStatus.center.dy, 8));
    expect(find.byKey(recorderStatusDotKey), findsOneWidget);
    expect(
      tester.getRect(find.byKey(recorderStatusDotKey)).right,
      lessThanOrEqualTo(inlineStatus.left),
    );

    final Text timer = tester.widget<Text>(find.text(_elapsedText));
    expect(timer.style?.color, const Color(0xFFB7A58C));
    expect(timer.style?.fontSize, 12);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the timer is not inside the live region', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.android);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpLine(
      tester,
      phase: StagePhase.recording,
      inline: false,
      platform: TargetPlatform.android,
    );

    final SemanticsNode status = tester.getSemantics(
      find.byKey(recorderStatusTextKey),
    );
    final SemanticsNode timer = tester.getSemantics(find.text(_elapsedText));
    expect(identical(status, timer), isFalse);
    expect(timer, isNot(isSemantics(isLiveRegion: true)));

    semantics.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
