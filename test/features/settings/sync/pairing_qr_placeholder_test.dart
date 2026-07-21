import 'package:field_notes/features/settings/sync/pairing_qr_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/settings_harness.dart';

void main() {
  testWidgets('renders a labelled, non-interactive pairing code',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      useWideSurface(tester);
      await tester.pumpWidget(
        settingsFeatureHarness(const PairingQrPlaceholder()),
      );

      expect(find.byType(PairingQrPlaceholder), findsOneWidget);
      expect(
        find.bySemanticsLabel('Device pairing code'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PairingQrPlaceholder),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    } finally {
      handle.dispose();
    }
  });

  testWidgets('sizes itself to the requested edge length',
      (WidgetTester tester) async {
    useWideSurface(tester);
    await tester.pumpWidget(
      settingsFeatureHarness(const PairingQrPlaceholder(size: 120)),
    );

    final Size size = tester.getSize(find.byType(PairingQrPlaceholder));

    expect(size.width, 120);
    expect(size.height, 120);
  });

  test('the painter repaints only when its configuration changes', () {
    const PairingQrPainter painter = PairingQrPainter();

    expect(painter.shouldRepaint(const PairingQrPainter()), isFalse);
    expect(painter.shouldRepaint(const PairingQrPainter(modules: 11)), isTrue);
  });
}
