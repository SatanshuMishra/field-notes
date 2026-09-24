import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

const Key _childKey = ValueKey<String>('note-column-child');

class _StepTextScaler extends TextScaler {
  const _StepTextScaler();

  @override
  double scale(double fontSize) => fontSize >= 16 ? fontSize * 1.25 : fontSize;

  @override
  double get textScaleFactor => 1.0;
}

const Size _surface = Size(1200, 800);

Future<void> _pump(
  WidgetTester tester, {
  required double parentWidth,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = _surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: parentWidth, child: child),
        ),
      ),
    ),
  );
}

Widget _probe() => const SizedBox(key: _childKey, height: 40);

void main() {
  group('NoteColumn', () {
    testWidgets('fills a wide parent inside a full-width scope', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        parentWidth: 1100,
        child: NoteMeasureScope(
          fillsWidth: true,
          child: NoteColumn(child: _probe()),
        ),
      );

      expect(tester.getSize(find.byKey(_childKey)).width, 1100);
    });

    testWidgets('the default column cap is forty five em', (
      WidgetTester tester,
    ) async {
      await _pump(tester, parentWidth: 1000, child: NoteColumn(child: _probe()));

      expect(
        tester.getSize(find.byKey(_childKey)).width,
        45 * TypographyTokens.noteBody.fontSize!,
      );
      expect(tester.getSize(find.byKey(_childKey)).width, 720);
      expect(NoteColumn.measureEm, 45);
    });

    testWidgets('takes the parent width when the parent is narrower', (
      WidgetTester tester,
    ) async {
      await _pump(tester, parentWidth: 360, child: NoteColumn(child: _probe()));

      expect(tester.getSize(find.byKey(_childKey)).width, 360);
    });

    testWidgets('centres its child inside the wider parent', (
      WidgetTester tester,
    ) async {
      await _pump(tester, parentWidth: 800, child: NoteColumn(child: _probe()));

      final Rect child = tester.getRect(find.byKey(_childKey));
      expect(child.left, 40);
      expect(child.right, 760);
      expect(child.top, 0);
    });

    testWidgets('shrink-wraps its height to the child', (
      WidgetTester tester,
    ) async {
      await _pump(tester, parentWidth: 800, child: NoteColumn(child: _probe()));

      expect(tester.getSize(find.byType(NoteColumn)).height, 40);
    });

    testWidgets('widens the clamp by the horizontal inset it is given', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        parentWidth: 800,
        child: NoteColumn(horizontalInset: 30, child: _probe()),
      );

      expect(tester.getSize(find.byKey(_childKey)).width, 750);
    });

    testWidgets('tracks the ambient text scaler, not the raw token', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        parentWidth: 1200,
        textScaler: const TextScaler.linear(1.5),
        child: NoteColumn(child: _probe()),
      );

      expect(tester.getSize(find.byKey(_childKey)).width, 45 * 16 * 1.5);
    });

    testWidgets('measures em through scale(fontSize), never scale(1) * size', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        parentWidth: 1000,
        textScaler: const _StepTextScaler(),
        child: NoteColumn(child: _probe()),
      );

      expect(const _StepTextScaler().scale(1) * 16, 16);
      expect(tester.getSize(find.byKey(_childKey)).width, 45 * 20);
    });

    testWidgets('exposes the same em and measure it lays out with', (
      WidgetTester tester,
    ) async {
      late BuildContext captured;
      await _pump(
        tester,
        parentWidth: 1000,
        textScaler: const TextScaler.linear(1.15),
        child: Builder(
          builder: (BuildContext context) {
            captured = context;
            return NoteColumn(child: _probe());
          },
        ),
      );

      expect(NoteColumn.emOf(captured), 16 * 1.15);
      expect(
        NoteColumn.measureOf(captured),
        tester.getSize(find.byKey(_childKey)).width,
      );
      expect(tester.getSize(find.byKey(_childKey)).width, closeTo(828, 1e-9));
    });
  });
}
