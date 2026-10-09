import 'package:field_notes/features/capture/immersive/recorder_shortcuts.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../video/video_test_support.dart' show videoSheetHarness;
import '../voice/voice_test_support.dart' show voiceSheetHarness;

typedef _VoiceCase = ({
  String name,
  VoiceRecorderPhase phase,
  bool asking,
  bool pausable,
  String hint,
});

typedef _VideoCase = ({
  String name,
  VideoRecorderPhase phase,
  bool supportsPause,
  bool asking,
  bool resumable,
  String hint,
});

const List<_VoiceCase> _voiceCases = <_VoiceCase>[
  (
    name: 'idle',
    phase: VoiceRecorderPhase.idle,
    asking: false,
    pausable: true,
    hint: 'space start · esc leave',
  ),
  (
    name: 'breathing',
    phase: VoiceRecorderPhase.breathing,
    asking: false,
    pausable: true,
    hint: 'space start · esc leave',
  ),
  (
    name: 'recording',
    phase: VoiceRecorderPhase.recording,
    asking: false,
    pausable: true,
    hint: 'space pause · ⌘↩ keep · esc leave',
  ),
  (
    name: 'recording without a pause callback',
    phase: VoiceRecorderPhase.recording,
    asking: false,
    pausable: false,
    hint: '⌘↩ keep · esc leave',
  ),
  (
    name: 'paused',
    phase: VoiceRecorderPhase.paused,
    asking: false,
    pausable: true,
    hint: 'space resume · ⌘↩ keep · esc leave',
  ),
  (
    name: 'asking while recording',
    phase: VoiceRecorderPhase.recording,
    asking: true,
    pausable: true,
    hint: 'esc keep going',
  ),
  (
    name: 'asking while paused',
    phase: VoiceRecorderPhase.paused,
    asking: true,
    pausable: true,
    hint: 'esc keep going',
  ),
  (
    name: 'saving',
    phase: VoiceRecorderPhase.saving,
    asking: false,
    pausable: true,
    hint: '',
  ),
];

const List<_VideoCase> _videoCases = <_VideoCase>[
  (
    name: 'preparing',
    phase: VideoRecorderPhase.preparing,
    supportsPause: false,
    asking: false,
    resumable: true,
    hint: 'esc leave',
  ),
  (
    name: 'idle',
    phase: VideoRecorderPhase.idle,
    supportsPause: false,
    asking: false,
    resumable: true,
    hint: 'space start · esc leave',
  ),
  (
    name: 'breathing',
    phase: VideoRecorderPhase.breathing,
    supportsPause: false,
    asking: false,
    resumable: true,
    hint: 'space start · esc leave',
  ),
  (
    name: 'arming',
    phase: VideoRecorderPhase.arming,
    supportsPause: false,
    asking: false,
    resumable: true,
    hint: 'esc leave',
  ),
  (
    name: 'recording',
    phase: VideoRecorderPhase.recording,
    supportsPause: false,
    asking: false,
    resumable: true,
    hint: '⌘↩ keep · esc leave',
  ),
  (
    name: 'paused',
    phase: VideoRecorderPhase.paused,
    supportsPause: false,
    asking: false,
    resumable: true,
    hint: 'space resume · ⌘↩ keep · esc leave',
  ),
  (
    name: 'asking while recording',
    phase: VideoRecorderPhase.recording,
    supportsPause: false,
    asking: true,
    resumable: true,
    hint: '⌘↩ keep · esc keep going',
  ),
  (
    name: 'saving',
    phase: VideoRecorderPhase.saving,
    supportsPause: false,
    asking: false,
    resumable: true,
    hint: '',
  ),
  (
    name: 'denied',
    phase: VideoRecorderPhase.denied,
    supportsPause: false,
    asking: false,
    resumable: true,
    hint: 'space start · esc leave',
  ),
  (
    name: 'idle',
    phase: VideoRecorderPhase.idle,
    supportsPause: true,
    asking: false,
    resumable: true,
    hint: 'space start · esc leave',
  ),
  (
    name: 'breathing',
    phase: VideoRecorderPhase.breathing,
    supportsPause: true,
    asking: false,
    resumable: true,
    hint: 'space start · esc leave',
  ),
  (
    name: 'recording',
    phase: VideoRecorderPhase.recording,
    supportsPause: true,
    asking: false,
    resumable: true,
    hint: 'space pause · ⌘↩ keep · esc leave',
  ),
  (
    name: 'paused',
    phase: VideoRecorderPhase.paused,
    supportsPause: true,
    asking: false,
    resumable: true,
    hint: 'space resume · ⌘↩ keep · esc leave',
  ),
  (
    name: 'paused without a resume callback',
    phase: VideoRecorderPhase.paused,
    supportsPause: true,
    asking: false,
    resumable: false,
    hint: 'space keep · ⌘↩ keep · esc leave',
  ),
  (
    name: 'asking while paused',
    phase: VideoRecorderPhase.paused,
    supportsPause: true,
    asking: true,
    resumable: true,
    hint: '⌘↩ keep · esc keep going',
  ),
  (
    name: 'saving',
    phase: VideoRecorderPhase.saving,
    supportsPause: true,
    asking: false,
    resumable: true,
    hint: '',
  ),
];

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final TargetPlatformVariant _windows = TargetPlatformVariant.only(
  TargetPlatform.windows,
);

void _sidebarWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<List<String>> _pumpVoice(
  WidgetTester tester, {
  required VoiceRecorderPhase phase,
  bool asking = false,
  bool pausable = true,
  bool dismissable = true,
}) async {
  final List<String> calls = <String>[];
  await tester.pumpWidget(
    voiceSheetHarness(
      VoiceRecorderSheet(
        phase: phase,
        asking: asking,
        onStart: () => calls.add('start'),
        onStop: () => calls.add('stop'),
        onCancel: () => calls.add('cancel'),
        onPause: pausable ? () => calls.add('pause') : null,
        onResume: () => calls.add('resume'),
        onDismiss: dismissable ? () => calls.add('dismiss') : null,
        onKeepGoing: () => calls.add('keep going'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return calls;
}

Future<List<String>> _pumpVideo(
  WidgetTester tester, {
  required VideoRecorderPhase phase,
  bool supportsPause = false,
  bool asking = false,
  bool resumable = true,
}) async {
  final List<String> calls = <String>[];
  await tester.pumpWidget(
    videoSheetHarness(
      VideoRecorderSheet(
        phase: phase,
        asking: asking,
        supportsPause: supportsPause,
        onStart: () => calls.add('start'),
        onStop: () => calls.add('stop'),
        onLeave: () => calls.add('leave'),
        onPause: () => calls.add('pause'),
        onResume: resumable ? () => calls.add('resume') : null,
        onKeepGoing: () => calls.add('keep going'),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return calls;
}

String? _hint(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data;

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
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
}

void main() {
  testWidgets('the idle voice hint offers Space to start, and Space starts', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    final List<String> calls = await _pumpVoice(
      tester,
      phase: VoiceRecorderPhase.idle,
    );

    expect(_hint(tester, voiceKeyHintKey), 'space start · esc leave');

    await _press(tester, LogicalKeyboardKey.space);
    expect(calls, <String>['start']);

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  testWidgets('the voice hint names only the keys live in each state', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    for (final _VoiceCase state in _voiceCases) {
      await _pumpVoice(
        tester,
        phase: state.phase,
        asking: state.asking,
        pausable: state.pausable,
      );
      expect(_hint(tester, voiceKeyHintKey), state.hint, reason: state.name);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  testWidgets('without a dismiss, Esc on the let-go panel leaves and says so', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    final List<String> calls = await _pumpVoice(
      tester,
      phase: VoiceRecorderPhase.paused,
      asking: true,
      dismissable: false,
    );

    expect(_hint(tester, voiceKeyHintKey), 'esc leave');

    await _press(tester, LogicalKeyboardKey.escape);
    expect(calls, <String>['cancel']);

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  testWidgets('Esc while the voice let-go panel is open runs the dismiss', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    final List<String> calls = await _pumpVoice(
      tester,
      phase: VoiceRecorderPhase.paused,
      asking: true,
    );

    expect(_hint(tester, voiceKeyHintKey), 'esc keep going');

    await _press(tester, LogicalKeyboardKey.escape);
    expect(calls, <String>['dismiss']);

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  testWidgets('an empty voice hint keeps its place in the top band', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    await _pumpVoice(tester, phase: VoiceRecorderPhase.idle);
    final Rect idleClose = tester.getRect(find.byKey(voiceCloseKey));
    final Rect idlePrivacy = tester.getRect(find.text(voiceSidebarPrivacyLine));

    await _pumpVoice(tester, phase: VoiceRecorderPhase.saving);

    expect(find.byKey(voiceKeyHintKey), findsOneWidget);
    expect(_hint(tester, voiceKeyHintKey), isEmpty);
    expect(tester.getRect(find.byKey(voiceCloseKey)), idleClose);
    expect(tester.getRect(find.text(voiceSidebarPrivacyLine)), idlePrivacy);

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  testWidgets('the idle video hint offers Space to start, and Space starts', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    for (final bool supportsPause in <bool>[false, true]) {
      final List<String> calls = await _pumpVideo(
        tester,
        phase: VideoRecorderPhase.idle,
        supportsPause: supportsPause,
      );

      expect(
        _hint(tester, videoKeyboardHintKey),
        'space start · esc leave',
        reason: 'supportsPause: $supportsPause',
      );

      await _press(tester, LogicalKeyboardKey.space);
      expect(calls, <String>['start'], reason: 'supportsPause: $supportsPause');
    }

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  testWidgets('the video hint names only the keys live in each state', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    for (final _VideoCase state in _videoCases) {
      await _pumpVideo(
        tester,
        phase: state.phase,
        supportsPause: state.supportsPause,
        asking: state.asking,
        resumable: state.resumable,
      );
      expect(
        _hint(tester, videoKeyboardHintKey),
        state.hint,
        reason: '${state.name}, supportsPause: ${state.supportsPause}',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  testWidgets('Space does nothing while a non-pausing video records', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    final List<String> calls = await _pumpVideo(
      tester,
      phase: VideoRecorderPhase.recording,
    );

    expect(_hint(tester, videoKeyboardHintKey), isNot(contains('space')));

    await _press(tester, LogicalKeyboardKey.space);
    expect(calls, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  testWidgets('Space keeps a paused video that cannot resume', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    final List<String> calls = await _pumpVideo(
      tester,
      phase: VideoRecorderPhase.paused,
      supportsPause: true,
      resumable: false,
    );

    expect(_hint(tester, videoKeyboardHintKey), startsWith('space keep'));

    await _press(tester, LogicalKeyboardKey.space);
    expect(calls, <String>['stop']);

    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: _mac);

  test('the Windows keep hint names ctrl+enter', () {
    expect(
      recorderKeyHint(platform: TargetPlatform.windows, keep: true),
      'ctrl+enter keep',
    );
    expect(
      recorderKeyHint(platform: TargetPlatform.macOS, keep: true),
      '⌘↩ keep',
    );
    expect(
      recorderKeyHint(
        platform: TargetPlatform.windows,
        primary: RecorderPrimaryVerb.pause,
        keep: true,
        leave: RecorderLeaveVerb.leave,
      ),
      'space pause · ctrl+enter keep · esc leave',
    );
  });

  test('the Windows voice keep hint names Control Enter', () {
    expect(
      voiceKeepShortcutHint(TargetPlatform.windows),
      'Shortcut: Control Enter',
    );
    expect(
      voiceKeepShortcutHint(TargetPlatform.macOS),
      'Shortcut: Command Return',
    );
  });

  testWidgets('on Windows the recorders show and take Ctrl+Enter to keep', (
    WidgetTester tester,
  ) async {
    _sidebarWindow(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<String> voiceCalls = await _pumpVoice(
      tester,
      phase: VoiceRecorderPhase.recording,
    );

    expect(
      _hint(tester, voiceKeyHintKey),
      'space pause · ctrl+enter keep · esc leave',
    );
    expect(
      tester.getSemantics(find.byKey(voiceSavePillKey)),
      isSemantics(label: voiceKeepLabel, hint: 'Shortcut: Control Enter'),
    );

    await _chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.enter);
    expect(voiceCalls, isEmpty);

    await _chord(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.enter,
    );
    expect(voiceCalls, <String>['stop']);

    final List<String> videoCalls = await _pumpVideo(
      tester,
      phase: VideoRecorderPhase.recording,
    );

    expect(_hint(tester, videoKeyboardHintKey), 'ctrl+enter keep · esc leave');

    await _chord(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.enter,
    );
    expect(videoCalls, <String>['stop']);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
  }, variant: _windows);
}
