@Tags(<String>['golden'])
library;

import 'package:field_notes/features/sync/ui/pairing_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

void main() {
  testWidgets('the flower pairing code matches its golden', (
    WidgetTester tester,
  ) async {
    pinGoldenSurface(tester);

    await tester.pumpWidget(
      goldenHarness(
        const PairingQr(
          payload:
              'fieldnotes-pair:https://sync.satanshu.tech#Q2xvdmVyLWZpZWxk',
        ),
      ),
    );

    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('images/pairing_qr_flower.png'),
    );
  });
}
