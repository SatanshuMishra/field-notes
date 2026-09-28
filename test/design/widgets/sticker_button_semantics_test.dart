import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/widgets.dart';

import 'widget_harness.dart';

void main() {
  testWidgets('a sticker button reads its label once',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      stickerHarness(
        StickerButton(label: 'Cancel', onPressed: () {}),
      ),
    );

    // RECEIPTS_ACK='SemanticsNode was not a type; switched to isSemantics matcher, no assertion change'
    expect(
      tester.getSemantics(find.byType(StickerButton)),
      isSemantics(label: 'Cancel', isButton: true),
    );
    handle.dispose();
  });
}
