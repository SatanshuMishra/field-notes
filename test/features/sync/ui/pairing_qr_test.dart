import 'package:field_notes/features/sync/ui/flower_qr.dart';
import 'package:field_notes/features/sync/ui/pairing_qr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../design/widgets/widget_harness.dart';

const String _payload =
    'fieldnotes-pair:https://sync.satanshu.tech#Q2xvdmVyLWZpZWxk';
const String _otherPayload =
    'fieldnotes-pair:https://sync.satanshu.tech#bWVhZG93LXN3ZWV0';

FlowerQrPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(PairingQr),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as FlowerQrPainter;

void main() {
  testWidgets('the pairing code is a labelled flower code', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(stickerHarness(const PairingQr(payload: _payload)));

    expect(find.bySemanticsLabel(pairingQrLabel), findsOneWidget);
    expect(_painter(tester).code.payload, _payload);
    expect(_painter(tester).code.blooms, isTrue);
    expect(tester.getSize(find.byType(PairingQr)), const Size.square(260));

    semantics.dispose();
  });

  testWidgets('the code is encoded again only when the payload changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(stickerHarness(const PairingQr(payload: _payload)));
    final FlowerQr first = _painter(tester).code;

    await tester.pumpWidget(stickerHarness(const PairingQr(payload: _payload)));
    expect(_painter(tester).code, same(first));

    await tester.pumpWidget(
      stickerHarness(const PairingQr(payload: _otherPayload)),
    );
    expect(_painter(tester).code.payload, _otherPayload);
  });
}
