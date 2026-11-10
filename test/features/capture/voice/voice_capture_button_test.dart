import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/capture/immersive/capture_button.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'voice_test_support.dart';

const Duration _midFade = Duration(milliseconds: 130);
const Duration _pastFade = Duration(milliseconds: 300);
const Duration _pastDiscMove = Duration(milliseconds: 500);

typedef _OrbLook = ({
  double scale,
  double opacity,
  bool mic,
  bool pause,
  bool ring,
  bool countdownSweep,
  bool savingSweep,
});

const Map<VoiceRecorderPhase, CaptureButtonForm> _formOf =
    <VoiceRecorderPhase, CaptureButtonForm>{
      VoiceRecorderPhase.idle: CaptureButtonForm.ready,
      VoiceRecorderPhase.breathing: CaptureButtonForm.countdown,
      VoiceRecorderPhase.recording: CaptureButtonForm.pause,
      VoiceRecorderPhase.paused: CaptureButtonForm.resume,
      VoiceRecorderPhase.saving: CaptureButtonForm.saving,
    };

const Map<VoiceRecorderPhase, _OrbLook> _expectedLook =
    <VoiceRecorderPhase, _OrbLook>{
      VoiceRecorderPhase.idle: (
        scale: 1,
        opacity: 1,
        mic: true,
        pause: false,
        ring: false,
        countdownSweep: false,
        savingSweep: false,
      ),
      VoiceRecorderPhase.breathing: (
        scale: voiceCountdownCoreScale,
        opacity: 1,
        mic: false,
        pause: false,
        ring: true,
        countdownSweep: true,
        savingSweep: false,
      ),
      VoiceRecorderPhase.recording: (
        scale: 1,
        opacity: 1,
        mic: false,
        pause: true,
        ring: false,
        countdownSweep: false,
        savingSweep: false,
      ),
      VoiceRecorderPhase.paused: (
        scale: 1,
        opacity: voicePausedCoreOpacity,
        mic: true,
        pause: false,
        ring: true,
        countdownSweep: false,
        savingSweep: false,
      ),
      VoiceRecorderPhase.saving: (
        scale: voiceSavingCoreScale,
        opacity: voiceSavingCoreOpacity,
        mic: false,
        pause: false,
        ring: true,
        countdownSweep: false,
        savingSweep: true,
      ),
    };

void _noop() {}

Widget _sheet(
  VoiceRecorderPhase phase, {
  bool asking = false,
  String? errorMessage,
  bool reduceMotion = false,
}) {
  final Widget sheet = VoiceRecorderSheet(
    phase: phase,
    onStart: _noop,
    onStop: _noop,
    onCancel: _noop,
    onPause: _noop,
    onResume: _noop,
    onDiscard: _noop,
    onKeepGoing: _noop,
    onLetGo: _noop,
    asking: asking,
    errorMessage: errorMessage,
    elapsed: const Duration(seconds: 7),
  );
  return voiceSheetHarness(
    reduceMotion
        ? Builder(
            builder: (BuildContext context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: sheet,
            ),
          )
        : sheet,
  );
}

Finder _inOrb(Finder matching) =>
    find.descendant(of: find.byKey(voiceRecordButtonKey), matching: matching);

Finder get _disc => _inOrb(find.byType(AnimatedScale));

Finder _inForm(VoiceRecorderPhase phase, Finder matching) => find.descendant(
  of: find.byKey(voiceOrbFormKey(_formOf[phase]!)),
  matching: matching,
);

bool _isRingBorder(Widget widget) {
  if (widget is! DecoratedBox) {
    return false;
  }
  final Decoration decoration = widget.decoration;
  return decoration is BoxDecoration && decoration.border != null;
}

_OrbLook _lookOf(WidgetTester tester, VoiceRecorderPhase phase) => (
  scale: tester.widget<AnimatedScale>(_disc).scale,
  opacity: tester
      .widget<Opacity>(
        find.descendant(of: _disc, matching: find.byType(Opacity)),
      )
      .opacity,
  mic: tester.any(_inForm(phase, find.byType(CaptureIcon))),
  pause: tester
      .widgetList<IconStickerGlyphIcon>(
        _inForm(phase, find.byType(IconStickerGlyphIcon)),
      )
      .any((IconStickerGlyphIcon icon) => icon.glyph == IconStickerGlyph.pause),
  ring: tester.any(_inForm(phase, find.byWidgetPredicate(_isRingBorder))),
  countdownSweep: tester.any(
    _inForm(phase, find.byType(CaptureCountdownSweep)),
  ),
  savingSweep: tester.any(_inForm(phase, find.byType(CaptureSavingSweep))),
);

Gradient? _discGradient(WidgetTester tester) {
  final Decoration decoration = tester
      .widget<DecoratedBox>(
        find.descendant(of: _disc, matching: find.byType(DecoratedBox)),
      )
      .decoration;
  return (decoration as BoxDecoration).gradient;
}

double _sweepFraction(WidgetTester tester) => tester
    .widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(CaptureCountdownSweep),
        matching: find.byType(CustomPaint),
      ),
    )
    .map((CustomPaint paint) => paint.painter)
    .whereType<CaptureCountdownRingPainter>()
    .single
    .fraction;

double _chrome(WidgetTester tester) => tester
    .widget<RecorderSurface>(find.byType(RecorderSurface))
    .chromeOpacity
    .value;

Future<void> _finish(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

Future<void> _waitForChromeToHide(WidgetTester tester) async {
  await tester.pump(recorderChromeHold);
  await tester.pump(_pastFade);
}

void main() {
  testWidgets('every voice phase shows its own orb form', (
    WidgetTester tester,
  ) async {
    final Set<_OrbLook> seen = <_OrbLook>{};
    Gradient? ready;
    for (final VoiceRecorderPhase phase in VoiceRecorderPhase.values) {
      await tester.pumpWidget(_sheet(phase));
      await tester.pump();
      await tester.pump(_pastDiscMove);

      for (final CaptureButtonForm form in CaptureButtonForm.values) {
        expect(
          find.byKey(voiceOrbFormKey(form)),
          form == _formOf[phase] ? findsOneWidget : findsNothing,
          reason: '$phase $form',
        );
      }
      final _OrbLook look = _lookOf(tester, phase);
      expect(look, _expectedLook[phase], reason: '$phase');
      seen.add(look);

      ready ??= _discGradient(tester);
      expect(_discGradient(tester), ready, reason: '$phase');
    }

    expect(seen, hasLength(VoiceRecorderPhase.values.length));
    await _finish(tester);
  });

  testWidgets('the countdown sweeps its ring around the shrunken core', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_sheet(VoiceRecorderPhase.breathing));
    await tester.pump();
    expect(_sweepFraction(tester), closeTo(0, 0.02));

    await tester.pump(stageBreathDuration ~/ 2);

    expect(_sweepFraction(tester), closeTo(0.5, 0.02));
    expect(tester.widget<AnimatedScale>(_disc).scale, voiceCountdownCoreScale);
    expect(_inOrb(find.byType(CaptureIcon)), findsNothing);
    await _finish(tester);
  });

  testWidgets('the level field and settling glow stay on the orb', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_sheet(VoiceRecorderPhase.breathing));
    await tester.pump();

    expect(find.byType(VoiceLevelField), findsOneWidget);
    expect(find.byType(BreathingGlow), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('a phase change fades the orb core and the status line', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_sheet(VoiceRecorderPhase.idle));
    await tester.pump(_pastFade);

    await tester.pumpWidget(_sheet(VoiceRecorderPhase.breathing));
    await tester.pump(_midFade);

    expect(
      find.byKey(voiceOrbFormKey(CaptureButtonForm.ready)),
      findsOneWidget,
    );
    expect(
      find.byKey(voiceOrbFormKey(CaptureButtonForm.countdown)),
      findsOneWidget,
    );
    expect(find.byType(RecorderStatusLine), findsNWidgets(2));

    await tester.pump(_pastFade);

    expect(find.byKey(voiceOrbFormKey(CaptureButtonForm.ready)), findsNothing);
    expect(find.byType(RecorderStatusLine), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('reduced motion swaps the orb form without a fade', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _sheet(VoiceRecorderPhase.idle, reduceMotion: true),
    );
    await tester.pump();

    await tester.pumpWidget(
      _sheet(VoiceRecorderPhase.breathing, reduceMotion: true),
    );
    await tester.pump();

    expect(find.byKey(voiceOrbFormKey(CaptureButtonForm.ready)), findsNothing);
    expect(tester.widget<AnimatedScale>(_disc).duration, Duration.zero);
    await _finish(tester);
  });

  testWidgets('a saving orb reads as saving and takes no taps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_sheet(VoiceRecorderPhase.saving));
    await tester.pump();

    expect(
      tester.getSemantics(find.byKey(voiceRecordButtonKey)),
      isSemantics(
        label: voiceSavingLabel,
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await _finish(tester);
  });

  testWidgets('while recording the chrome fades and the orb stays', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_sheet(VoiceRecorderPhase.recording));
    await tester.pump();
    expect(_chrome(tester), 1);
    expect(find.byKey(voiceTakeIndicatorKey), findsNothing);

    await _waitForChromeToHide(tester);

    expect(_chrome(tester), 0);
    expect(find.byKey(voiceRecordButtonKey), findsOneWidget);
    expect(
      tester
          .widget<FadeTransition>(find.byKey(voiceTakeIndicatorKey))
          .opacity
          .value,
      1,
    );
    await _finish(tester);
  });

  testWidgets('moving the pointer brings the chrome back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_sheet(VoiceRecorderPhase.recording));
    await tester.pump();
    await _waitForChromeToHide(tester);

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(20, 20));
    await tester.pump();
    await tester.pump(_pastFade);

    expect(_chrome(tester), 1);
    expect(find.byKey(voiceTakeIndicatorKey), findsNothing);
    await mouse.removePointer();
    await _finish(tester);
  });

  testWidgets('the chrome holds through a pause', (WidgetTester tester) async {
    await tester.pumpWidget(_sheet(VoiceRecorderPhase.paused));
    await tester.pump();

    await _waitForChromeToHide(tester);

    expect(_chrome(tester), 1);
    await _finish(tester);
  });

  testWidgets('asking whether to let go brings the chrome back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_sheet(VoiceRecorderPhase.recording));
    await tester.pump();
    await _waitForChromeToHide(tester);

    await tester.pumpWidget(_sheet(VoiceRecorderPhase.recording, asking: true));
    await tester.pump();
    await tester.pump(_pastFade);

    expect(_chrome(tester), 1);
    await _finish(tester);
  });

  testWidgets('an error brings the chrome back', (WidgetTester tester) async {
    await tester.pumpWidget(_sheet(VoiceRecorderPhase.recording));
    await tester.pump();
    await _waitForChromeToHide(tester);

    await tester.pumpWidget(
      _sheet(VoiceRecorderPhase.recording, errorMessage: 'Could not save.'),
    );
    await tester.pump();
    await tester.pump(_pastFade);

    expect(_chrome(tester), 1);
    await _finish(tester);
  });
}
