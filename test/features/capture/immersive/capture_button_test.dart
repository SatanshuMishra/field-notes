import 'package:field_notes/features/capture/immersive/capture_button.dart';
import 'package:field_notes/features/capture/immersive/stage_phase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _fade = Duration(milliseconds: 260);
const Duration _midFade = Duration(milliseconds: 130);
const Duration _pastFade = Duration(milliseconds: 300);
const Color _ink = Color(0xFF112233);

Key _formKey(CaptureButtonForm form) => ValueKey<String>('form-${form.name}');

Widget _face(CaptureButtonForm form, {Duration fade = _fade}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: CaptureButtonFace(
      form: form,
      diameter: 100,
      fade: fade,
      formKey: _formKey,
      base: const ColoredBox(color: _ink),
      core: (BuildContext _, CaptureButtonForm shown) => Text(shown.name),
    ),
  ),
);

double _savingTurns(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find.descendant(
        of: find.byType(CaptureSavingSweep),
        matching: find.byType(RotationTransition),
      ),
    )
    .turns
    .value;

Widget _savingSweep({required bool reduceMotion}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: const Center(
      child: SizedBox.square(
        dimension: 100,
        child: CaptureSavingSweep(color: _ink),
      ),
    ),
  ),
);

void main() {
  test('each stage maps to its own form when the recorder can pause', () {
    expect(
      <CaptureButtonForm>[
        for (final StagePhase stage in StagePhase.values)
          captureButtonForm(stage, canPause: true),
      ],
      <CaptureButtonForm>[
        for (final StagePhase stage in StagePhase.values)
          switch (stage) {
            StagePhase.idle => CaptureButtonForm.ready,
            StagePhase.breathing => CaptureButtonForm.countdown,
            StagePhase.recording => CaptureButtonForm.pause,
            StagePhase.paused => CaptureButtonForm.resume,
            StagePhase.saving => CaptureButtonForm.saving,
          },
      ],
    );
  });

  test('a recorder that cannot pause shows stop while recording', () {
    expect(
      captureButtonForm(StagePhase.recording, canPause: false),
      CaptureButtonForm.stop,
    );
  });

  test('the countdown ring repaints only when what it draws changes', () {
    const CaptureCountdownRingPainter painter = CaptureCountdownRingPainter(
      fraction: 0.5,
      color: _ink,
    );

    expect(
      painter.shouldRepaint(
        const CaptureCountdownRingPainter(fraction: 0.5, color: _ink),
      ),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        const CaptureCountdownRingPainter(fraction: 0.6, color: _ink),
      ),
      isTrue,
    );
  });

  testWidgets('a form change fades the old core out and the new one in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_face(CaptureButtonForm.ready));

    await tester.pumpWidget(_face(CaptureButtonForm.countdown));
    await tester.pump(_midFade);
    expect(find.byKey(_formKey(CaptureButtonForm.ready)), findsOneWidget);
    expect(find.byKey(_formKey(CaptureButtonForm.countdown)), findsOneWidget);

    await tester.pump(_pastFade);
    expect(find.byKey(_formKey(CaptureButtonForm.ready)), findsNothing);
    expect(find.byKey(_formKey(CaptureButtonForm.countdown)), findsOneWidget);
  });

  testWidgets('returning to a form during its own fade does not collide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_face(CaptureButtonForm.ready));
    await tester.pumpWidget(_face(CaptureButtonForm.countdown));
    await tester.pump(_midFade);

    await tester.pumpWidget(_face(CaptureButtonForm.ready));
    await tester.pump(_midFade);
    expect(tester.takeException(), isNull);

    await tester.pump(_pastFade);
    expect(find.byKey(_formKey(CaptureButtonForm.ready)), findsOneWidget);
    expect(find.byKey(_formKey(CaptureButtonForm.countdown)), findsNothing);
  });

  testWidgets('a zero fade swaps the form without a cross-fade', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _face(CaptureButtonForm.ready, fade: Duration.zero),
    );

    await tester.pumpWidget(
      _face(CaptureButtonForm.saving, fade: Duration.zero),
    );
    await tester.pump();

    expect(find.byKey(_formKey(CaptureButtonForm.ready)), findsNothing);
    expect(find.byKey(_formKey(CaptureButtonForm.saving)), findsOneWidget);
  });

  testWidgets('the saving sweep turns', (WidgetTester tester) async {
    await tester.pumpWidget(_savingSweep(reduceMotion: false));
    final double before = _savingTurns(tester);

    await tester.pump(const Duration(milliseconds: 200));

    expect(_savingTurns(tester), isNot(before));
  });

  testWidgets('the saving sweep holds still under reduced motion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_savingSweep(reduceMotion: true));
    final double before = _savingTurns(tester);

    await tester.pump(const Duration(milliseconds: 200));

    expect(_savingTurns(tester), before);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
