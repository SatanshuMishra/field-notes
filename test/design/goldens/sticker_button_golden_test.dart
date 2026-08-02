@Tags(<String>['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/widgets.dart';

import 'golden_harness.dart';

const String _label = 'Delete everything';
const EdgeInsets _boundaryPadding = EdgeInsets.all(8);

const List<(StickerButtonVariant, String)> _variants =
    <(StickerButtonVariant, String)>[
      (StickerButtonVariant.primary, 'sticker_button_primary'),
      (StickerButtonVariant.secondary, 'sticker_button_secondary'),
      (StickerButtonVariant.danger, 'sticker_button_danger'),
    ];

void _noop() {}

Future<void> _captureButton(
  WidgetTester tester,
  StickerButtonVariant variant,
  String name,
) async {
  pinGoldenSurface(tester);

  await tester.pumpWidget(
    goldenHarness(
      StickerButton(
        label: _label,
        onPressed: _noop,
        variant: variant,
        icon: null,
        labelStyle: null,
      ),
      padding: _boundaryPadding,
    ),
  );

  await expectLater(
    find.byType(RepaintBoundary),
    matchesGoldenFile('images/$name.png'),
  );
}

void main() {
  for (final (StickerButtonVariant variant, String name) in _variants) {
    testWidgets('the ${variant.name} sticker button matches its golden', (
      WidgetTester tester,
    ) async {
      await _captureButton(tester, variant, name);
    });
  }
}
