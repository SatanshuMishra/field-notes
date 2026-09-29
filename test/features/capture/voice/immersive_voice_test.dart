import 'dart:async';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart';
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

const Size _sidebarWindow = Size(1280, 800);
const Size _bottomBarWindow = Size(360, 740);
const Key _openKey = ValueKey<String>('open-voice');
const Key _behindKey = ValueKey<String>('behind-button');
const String _date = '2026-09-28';
const String _sidebarIdleStatus = '$stageIdleStatus$stageIdleSidebarTail';
const String _savingStatus = 'Saving your recording…';
const String _letGoToast = 'Let go · nothing was saved';
const String _captureFailure = 'Could not save your entry.';
const Duration _fade = Duration(milliseconds: 600);
const Duration _step = Duration(milliseconds: 50);
const List<TargetPlatform> _layouts = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.android,
];

class _Rig {
  _Rig({required this.recorder, required this.service});

  final FakeVoiceRecorder recorder;
  final FakeCaptureService service;
  final List<String?> results = <String?>[];
  int behindTaps = 0;
}

class _Opener extends StatelessWidget {
  const _Opener({required this.rig});

  final _Rig rig;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TextButton(
          key: _behindKey,
          onPressed: () => rig.behindTaps++,
          child: const Text('Behind'),
        ),
        TextButton(
          key: _openKey,
          onPressed: () async =>
              rig.results.add(await showVoiceComposer(context, _date)),
          child: const Text('Open'),
        ),
      ],
    );
  }
}

Future<_Rig> _openVoice(
  WidgetTester tester, {
  required TargetPlatform platform,
  FakeVoiceRecorder? recorder,
  FakeCaptureService? service,
  bool prompts = false,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = platform == TargetPlatform.macOS
      ? _sidebarWindow
      : _bottomBarWindow;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Rig rig = _Rig(
    recorder: recorder ?? FakeVoiceRecorder(),
    service: service ?? FakeCaptureService(),
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        voiceRecorderProvider.overrideWith((Ref ref) => rig.recorder),
        captureServiceProvider.overrideWith((Ref ref) => rig.service),
        reflectionPromptsEnabledProvider.overrideWithValue(prompts),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(
          body: Center(child: _Opener(rig: rig)),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(_openKey));
  await tester.pump();
  await tester.pump(_fade);
  return rig;
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  debugDefaultTargetPlatformOverride = null;
}

Future<void> _tapOrb(WidgetTester tester) async {
  await tester.tap(find.byKey(voiceRecordButtonKey));
  await tester.pump();
  await tester.pump(_step);
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(_fade);
  await tester.pump(_step);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump(_step);
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
  await tester.pump(_fade);
  await tester.pump(_step);
}

Future<void> _sendSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pump();
  await tester.pump(_fade);
  await tester.pump(_step);
}

String? _status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(recorderStatusTextKey)).data;

Finder _inOrb(Finder matching) =>
    find.descendant(of: find.byKey(voiceRecordButtonKey), matching: matching);

double _orbOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(_inOrb(find.byType(AnimatedOpacity)))
    .opacity;

bool _showsPauseGlyph(WidgetTester tester) => tester
    .widgetList<IconStickerGlyphIcon>(_inOrb(find.byType(IconStickerGlyphIcon)))
    .any((IconStickerGlyphIcon icon) => icon.glyph == IconStickerGlyph.pause);

BreathingGlowMode? _glowMode(WidgetTester tester) {
  final Iterable<BreathingGlow> glows = tester.widgetList<BreathingGlow>(
    find.byType(BreathingGlow),
  );
  return glows.isEmpty ? null : glows.single.mode;
}

void _expectPhase(
  WidgetTester tester, {
  required String status,
  required StagePhase announced,
  required String orbLabel,
  required bool orbEnabled,
  required double opacity,
  required bool pauseGlyph,
  required BreathingGlowMode? glow,
  required bool timer,
}) {
  expect(_status(tester), status);
  final SemanticsNode statusNode = tester.getSemantics(
    find.byKey(recorderStatusTextKey),
  );
  expect(statusNode.label, announced.announcement);
  expect(statusNode.value, status);
  expect(find.bySemanticsLabel(orbLabel), findsOneWidget);
  expect(
    tester.getSemantics(find.byKey(voiceRecordButtonKey)),
    isSemantics(
      label: orbLabel,
      isButton: true,
      hasEnabledState: true,
      isEnabled: orbEnabled,
    ),
  );
  expect(_orbOpacity(tester), opacity);
  expect(_showsPauseGlyph(tester), pauseGlyph);
  expect(
    _inOrb(find.byType(CaptureIcon)),
    pauseGlyph ? findsNothing : findsOneWidget,
  );
  expect(_glowMode(tester), glow);
  expect(find.byKey(recorderTimerKey), timer ? findsOneWidget : findsNothing);
}

void _expectControlEnabled(WidgetTester tester, Key key, bool enabled) {
  expect(
    tester.getSemantics(find.byKey(key)),
    isSemantics(isButton: true, hasEnabledState: true, isEnabled: enabled),
  );
}

void _expectTimerClear(WidgetTester tester) {
  final Rect timer = tester.getRect(find.byKey(recorderTimerKey));
  final Rect status = tester.getRect(find.byKey(recorderStatusTextKey));
  expect(timer.top, greaterThanOrEqualTo(status.bottom));
  expect(timer.overlaps(tester.getRect(find.byKey(voiceOrbZoneKey))), isFalse);
  expect(timer.overlaps(tester.getRect(find.byKey(voiceActionsKey))), isFalse);
  final Finder panel = find.byType(LetGoPanel);
  if (panel.evaluate().isNotEmpty) {
    expect(timer.overlaps(tester.getRect(panel)), isFalse);
  }
}

Finder _anyQuestion() => find.byWidgetPredicate(
  (Widget widget) =>
      widget is Text && reflectionQuestions.contains(widget.data),
);

void main() {
  testWidgets('the voice recorder covers the whole window in both layouts', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in _layouts) {
      final _Rig rig = await _openVoice(tester, platform: platform);
      final Size window = platform == TargetPlatform.macOS
          ? _sidebarWindow
          : _bottomBarWindow;

      expect(find.byType(VoiceRecorderSheet), findsOneWidget);
      expect(tester.getSize(find.byType(VoiceRecorderSheet)), window);
      expect(tester.getTopLeft(find.byType(VoiceRecorderSheet)), Offset.zero);
      expect(find.byType(ComposerShell), findsNothing);

      await tester.tapAt(tester.getCenter(find.byKey(_behindKey)));
      await tester.pump();
      expect(rig.behindTaps, 0);
      expect(find.byType(VoiceRecorderSheet), findsOneWidget);
    }
    await _finish(tester);
  });

  testWidgets(
    'tapping the orb breathes for 4 seconds before recording and a second tap skips the breath',
    (WidgetTester tester) async {
      final _Rig waited = await _openVoice(
        tester,
        platform: TargetPlatform.macOS,
      );
      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      expect(_status(tester), stageBreathingStatus);
      expect(waited.recorder.startCalls, 0);

      await tester.pump(const Duration(milliseconds: 3900));
      expect(waited.recorder.startCalls, 0);
      expect(_status(tester), stageBreathingStatus);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(waited.recorder.startCalls, 1);
      expect(_status(tester), stageRecordingStatus);

      await tester.pump(const Duration(seconds: 5));
      expect(waited.recorder.startCalls, 1);

      final _Rig skipped = await _openVoice(
        tester,
        platform: TargetPlatform.android,
      );
      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      expect(_status(tester), stageBreathingStatus);
      await tester.pump(const Duration(seconds: 1));
      expect(skipped.recorder.startCalls, 0);

      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      expect(skipped.recorder.startCalls, 1);
      expect(_status(tester), stageRecordingStatus);

      await tester.pump(const Duration(seconds: 5));
      expect(skipped.recorder.startCalls, 1);
      await _finish(tester);
    },
  );

  testWidgets('leaving during the breath closes without recording', (
    WidgetTester tester,
  ) async {
    final _Rig left = await _openVoice(tester, platform: TargetPlatform.macOS);
    await tester.tap(find.byKey(voiceRecordButtonKey));
    await tester.pump();
    expect(_status(tester), stageBreathingStatus);

    await _tapAndSettle(tester, find.byKey(voiceCloseKey));
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(VoiceRecorderSheet), findsNothing);
    expect(find.byType(LetGoPanel), findsNothing);
    expect(left.recorder.startCalls, 0);
    expect(left.recorder.cancelCalls, 0);
    expect(left.results, <String?>[null]);

    final _Rig backed = await _openVoice(
      tester,
      platform: TargetPlatform.android,
    );
    await tester.tap(find.byKey(voiceRecordButtonKey));
    await tester.pump();
    expect(_status(tester), stageBreathingStatus);

    await _sendSystemBack(tester);
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(VoiceRecorderSheet), findsNothing);
    expect(backed.recorder.startCalls, 0);
    expect(backed.results, <String?>[null]);
    await _finish(tester);
  });

  testWidgets(
    'voice phases show their status text, orb state and announcement',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final Completer<void> gate = Completer<void>();
      final _Rig rig = await _openVoice(
        tester,
        platform: TargetPlatform.macOS,
        service: FakeCaptureService(gate: gate.future),
      );
      final List<String?> shown = <String?>[];

      _expectPhase(
        tester,
        status: _sidebarIdleStatus,
        announced: StagePhase.idle,
        orbLabel: 'Start recording',
        orbEnabled: true,
        opacity: 1,
        pauseGlyph: false,
        glow: null,
        timer: false,
      );
      shown.add(_status(tester));

      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.pump();
      _expectPhase(
        tester,
        status: stageBreathingStatus,
        announced: StagePhase.breathing,
        orbLabel: 'Start now',
        orbEnabled: true,
        opacity: 1,
        pauseGlyph: false,
        glow: BreathingGlowMode.settle,
        timer: false,
      );
      shown.add(_status(tester));

      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      _expectPhase(
        tester,
        status: stageRecordingStatus,
        announced: StagePhase.recording,
        orbLabel: 'Pause recording',
        orbEnabled: true,
        opacity: 1,
        pauseGlyph: true,
        glow: BreathingGlowMode.breathe,
        timer: true,
      );
      shown.add(_status(tester));

      await _tapOrb(tester);
      _expectPhase(
        tester,
        status: stagePausedStatus,
        announced: StagePhase.paused,
        orbLabel: 'Resume recording',
        orbEnabled: true,
        opacity: 0.55,
        pauseGlyph: false,
        glow: null,
        timer: true,
      );
      shown.add(_status(tester));

      await tester.tap(find.byKey(voiceSavePillKey));
      await tester.pump();
      _expectPhase(
        tester,
        status: _savingStatus,
        announced: StagePhase.saving,
        orbLabel: 'Start recording',
        orbEnabled: false,
        opacity: 0.35,
        pauseGlyph: false,
        glow: null,
        timer: false,
      );
      shown.add(_status(tester));

      expect(shown.toSet(), hasLength(5));

      gate.complete();
      await tester.pump();
      await tester.pump(_fade);
      expect(rig.results, <String?>['entry-1']);
      handle.dispose();
      await _finish(tester);
    },
  );

  testWidgets('Keep this saves the memo and shows Voice memo saved', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Rig recording = await _openVoice(
      tester,
      platform: TargetPlatform.macOS,
    );
    await startVoiceTake(tester);
    expect(find.bySemanticsLabel(voiceKeepLabel), findsOneWidget);

    await _tapAndSettle(tester, find.text(voiceKeepLabel));

    expect(recording.recorder.stopCalls, 1);
    expect(recording.recorder.releaseSavedCalls, 1);
    expect(recording.service.requests, hasLength(1));
    expect(recording.service.requests.single.date, _date);
    expect(recording.results, <String?>['entry-1']);
    expect(find.byType(VoiceRecorderSheet), findsNothing);
    await tester.pump();
    expect(find.text(voiceSavedToastMessage), findsOneWidget);

    final _Rig paused = await _openVoice(
      tester,
      platform: TargetPlatform.android,
    );
    await startVoiceTake(tester);
    await _tapOrb(tester);
    expect(_status(tester), stagePausedStatus);

    await _tapAndSettle(tester, find.text(voiceKeepLabel));

    expect(paused.recorder.stopCalls, 1);
    expect(paused.service.requests, hasLength(1));
    expect(paused.results, <String?>['entry-1']);
    expect(find.text(voiceSavedToastMessage), findsOneWidget);
    handle.dispose();
    await _finish(tester);
  });

  testWidgets('Let it go pauses, asks, and Keep going returns to paused', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in _layouts) {
      final _Rig rig = await _openVoice(tester, platform: platform);
      await startVoiceTake(tester);
      expect(_status(tester), stageRecordingStatus);
      if (platform == TargetPlatform.android) {
        await _tapOrb(tester);
        expect(_status(tester), stagePausedStatus);
      }

      await tester.tap(find.byKey(voiceDiscardPillKey));
      await tester.pump();
      await tester.pump(_step);

      expect(rig.recorder.pauseCalls, 1);
      expect(_status(tester), stagePausedStatus);
      expect(find.byType(LetGoPanel), findsOneWidget);
      expect(find.text(letGoTitle), findsOneWidget);
      expect(find.text(letGoMessage), findsOneWidget);
      expect(find.byKey(voiceDiscardConfirmKey), findsOneWidget);
      expect(find.byKey(voiceSavePillKey), findsNothing);

      await tester.tap(find.text(letGoKeepGoingLabel));
      await tester.pump();
      await tester.pump(_step);

      expect(find.byType(LetGoPanel), findsNothing);
      expect(find.byType(VoiceRecorderSheet), findsOneWidget);
      expect(_status(tester), stagePausedStatus);
      expect(rig.recorder.pauseCalls, 1);
      expect(rig.recorder.resumeCalls, 0);
      expect(rig.recorder.cancelCalls, 0);
      expect(find.byKey(voiceSavePillKey), findsOneWidget);
      expect(rig.results, isEmpty);
    }
    await _finish(tester);
  });

  testWidgets(
    'letting a voice take go discards it and shows the let-go toast',
    (WidgetTester tester) async {
      for (final TargetPlatform platform in _layouts) {
        final _Rig rig = await _openVoice(tester, platform: platform);
        await startVoiceTake(tester);
        await tester.tap(find.byKey(voiceDiscardPillKey));
        await tester.pump();
        await tester.pump(_step);
        expect(find.byType(LetGoPanel), findsOneWidget);

        await _tapAndSettle(tester, find.byKey(voiceDiscardConfirmKey));

        expect(rig.recorder.cancelCalls, 1);
        expect(rig.recorder.stopCalls, 0);
        expect(rig.service.requests, isEmpty);
        expect(rig.results, <String?>[null]);
        expect(find.byType(VoiceRecorderSheet), findsNothing);
        await tester.pump();
        expect(find.text(_letGoToast), findsOneWidget);
        expect(find.text('Recording discarded'), findsNothing);
      }
      await _finish(tester);
    },
  );

  testWidgets('leaving an idle or breathing voice recorder closes it at once', (
    WidgetTester tester,
  ) async {
    final _Rig idle = await _openVoice(tester, platform: TargetPlatform.macOS);
    await tester.tap(find.byKey(voiceCloseKey));
    await tester.pump();
    expect(find.byType(LetGoPanel), findsNothing);
    await tester.pump(_fade);
    await tester.pump(_step);

    expect(find.byType(VoiceRecorderSheet), findsNothing);
    expect(idle.results, <String?>[null]);
    expect(idle.recorder.startCalls, 0);
    expect(idle.recorder.cancelCalls, 0);

    final _Rig breathing = await _openVoice(
      tester,
      platform: TargetPlatform.macOS,
    );
    await tester.tap(find.byKey(voiceRecordButtonKey));
    await tester.pump();
    expect(_status(tester), stageBreathingStatus);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(LetGoPanel), findsNothing);
    await tester.pump(_fade);
    await tester.pump(_step);

    expect(find.byType(VoiceRecorderSheet), findsNothing);
    expect(breathing.results, <String?>[null]);
    await tester.pump(const Duration(seconds: 5));
    expect(breathing.recorder.startCalls, 0);
    expect(breathing.recorder.cancelCalls, 0);
    await _finish(tester);
  });

  testWidgets(
    'saving shows the saving status line and disables every voice control, and a failed save returns with the live message',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final Completer<void> gate = Completer<void>();
      final _Rig saving = await _openVoice(
        tester,
        platform: TargetPlatform.macOS,
        service: FakeCaptureService(gate: gate.future),
      );
      await startVoiceTake(tester);
      await tester.tap(find.byKey(voiceSavePillKey));
      await tester.pump();

      expect(
        tester
            .widget<RecorderStatusLine>(find.byType(RecorderStatusLine))
            .phase,
        StagePhase.saving,
      );
      expect(_status(tester), _savingStatus);
      for (final Key key in <Key>[
        voiceSavePillKey,
        voiceDiscardPillKey,
        voiceRecordButtonKey,
        voiceCloseKey,
      ]) {
        _expectControlEnabled(tester, key, false);
      }

      await tester.tap(find.byKey(voiceSavePillKey));
      await tester.tap(find.byKey(voiceDiscardPillKey));
      await tester.tap(find.byKey(voiceRecordButtonKey));
      await tester.tap(find.byKey(voiceCloseKey));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.pump(_fade);

      expect(find.byType(VoiceRecorderSheet), findsOneWidget);
      expect(find.byType(LetGoPanel), findsNothing);
      expect(_status(tester), _savingStatus);
      expect(saving.recorder.startCalls, 1);
      expect(saving.recorder.stopCalls, 1);
      expect(saving.recorder.pauseCalls, 0);
      expect(saving.recorder.resumeCalls, 0);
      expect(saving.recorder.cancelCalls, 0);
      expect(saving.service.requests, hasLength(1));
      expect(saving.results, isEmpty);

      gate.complete();
      await tester.pump();
      await tester.pump(_fade);
      expect(saving.results, <String?>['entry-1']);

      final _Rig failing = await _openVoice(
        tester,
        platform: TargetPlatform.android,
        service: FakeCaptureService(
          failure: const CaptureException(_captureFailure),
        ),
      );
      await startVoiceTake(tester);
      await _tapOrb(tester);
      expect(_status(tester), stagePausedStatus);

      await tester.tap(find.byKey(voiceSavePillKey));
      await tester.pump();
      await tester.pump(_step);

      expect(_status(tester), stagePausedStatus);
      expect(find.text(_captureFailure), findsOneWidget);
      expect(find.byType(VoiceRecorderSheet), findsOneWidget);
      expect(failing.results, isEmpty);
      _expectControlEnabled(tester, voiceSavePillKey, true);

      await _tapOrb(tester);
      expect(_status(tester), stageRecordingStatus);
      expect(find.text(_captureFailure), findsNothing);

      await tester.tap(find.byKey(voiceSavePillKey));
      await tester.pump();
      await tester.pump(_step);

      expect(_status(tester), stageRecordingStatus);
      expect(find.text(_captureFailure), findsOneWidget);
      expect(failing.service.requests, hasLength(2));
      expect(failing.results, isEmpty);
      handle.dispose();
      await _finish(tester);
    },
  );

  testWidgets(
    'a denied microphone shows the permission message on the full-window surface and stays idle',
    (WidgetTester tester) async {
      for (final TargetPlatform platform in _layouts) {
        final _Rig rig = await _openVoice(
          tester,
          platform: platform,
          recorder: FakeVoiceRecorder(permission: false),
        );
        final String idleStatus = platform == TargetPlatform.macOS
            ? _sidebarIdleStatus
            : stageIdleStatus;

        await _tapOrb(tester);

        expect(find.text(micPermissionMessage), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text(micPermissionMessage),
            matching: find.byType(RecorderSurface),
          ),
          findsOneWidget,
        );
        expect(_status(tester), idleStatus);

        await tester.pump(const Duration(seconds: 5));
        expect(rig.recorder.startCalls, 0);
        expect(_status(tester), idleStatus);
        expect(find.byKey(recorderTimerKey), findsNothing);
        expect(find.byKey(voiceSavePillKey), findsNothing);
      }
      await _finish(tester);
    },
  );

  testWidgets(
    'the voice recorder shows the reflection kicker and question when the setting is on',
    (WidgetTester tester) async {
      for (final TargetPlatform platform in _layouts) {
        await _openVoice(tester, platform: platform, prompts: true);
        expect(find.text(reflectionKicker), findsOneWidget);
        expect(_anyQuestion(), findsOneWidget);

        await _openVoice(tester, platform: platform);
        expect(find.byType(VoiceRecorderSheet), findsOneWidget);
        expect(find.text(reflectionKicker), findsNothing);
        expect(_anyQuestion(), findsNothing);
      }
      await _finish(tester);
    },
  );

  testWidgets('voice keyboard shortcuts drive the recorder', (
    WidgetTester tester,
  ) async {
    final _Rig mac = await _openVoice(tester, platform: TargetPlatform.macOS);

    await _press(tester, LogicalKeyboardKey.space);
    expect(_status(tester), stageBreathingStatus);
    expect(mac.recorder.startCalls, 0);

    await _press(tester, LogicalKeyboardKey.space);
    expect(mac.recorder.startCalls, 1);
    expect(_status(tester), stageRecordingStatus);

    await _press(tester, LogicalKeyboardKey.space);
    expect(mac.recorder.pauseCalls, 1);
    expect(_status(tester), stagePausedStatus);

    await _press(tester, LogicalKeyboardKey.space);
    expect(mac.recorder.resumeCalls, 1);
    expect(_status(tester), stageRecordingStatus);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.byType(LetGoPanel), findsOneWidget);
    expect(mac.recorder.pauseCalls, 2);
    expect(_status(tester), stagePausedStatus);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.byType(LetGoPanel), findsNothing);
    expect(find.byType(VoiceRecorderSheet), findsOneWidget);
    expect(_status(tester), stagePausedStatus);
    expect(mac.recorder.cancelCalls, 0);

    await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.enter);
    expect(mac.recorder.stopCalls, 1);
    expect(mac.results, <String?>['entry-1']);
    expect(find.byType(VoiceRecorderSheet), findsNothing);

    final _Rig phone = await _openVoice(
      tester,
      platform: TargetPlatform.android,
    );
    await _press(tester, LogicalKeyboardKey.space);
    await _press(tester, LogicalKeyboardKey.space);
    expect(phone.recorder.startCalls, 1);
    expect(_status(tester), stageRecordingStatus);

    await _chord(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.enter,
    );
    expect(phone.recorder.stopCalls, 1);
    expect(phone.results, <String?>['entry-1']);
    await _finish(tester);
  });

  testWidgets(
    'voice recorder geometry matches the prototype orb and dark surface',
    (WidgetTester tester) async {
      for (final TargetPlatform platform in _layouts) {
        final bool sidebar = platform == TargetPlatform.macOS;
        await _openVoice(tester, platform: platform);

        final ColoredBox stage = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(RecorderSurface),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(stage.color, const Color(0xFF1C1713));
        expect(
          tester.getSize(find.byKey(voiceRecordButtonKey)),
          Size.square(sidebar ? 124 : 100),
        );
        expect(
          tester.getSize(find.byKey(voiceOrbZoneKey)),
          Size.square(sidebar ? 250 : 184),
        );
        expect(
          tester.getSize(find.byKey(voiceActionsKey)).height,
          greaterThanOrEqualTo(118),
        );

        await startVoiceTake(tester);
        expect(_status(tester), stageRecordingStatus);
        _expectTimerClear(tester);

        await _tapOrb(tester);
        expect(_status(tester), stagePausedStatus);
        _expectTimerClear(tester);

        await tester.tap(find.byKey(voiceDiscardPillKey));
        await tester.pump();
        await tester.pump(_step);
        expect(find.byType(LetGoPanel), findsOneWidget);
        _expectTimerClear(tester);
      }
      await _finish(tester);
    },
  );
}
