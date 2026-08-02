@Tags(<String>['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/widgets.dart';

import 'golden_harness.dart';

const double _width = 120;
const double _height = 90;

Future<void> _captureVariant(
  WidgetTester tester,
  CrossHatchVariant variant,
  String name,
) async {
  pinGoldenSurface(tester);

  await tester.pumpWidget(
    goldenHarness(
      CrossHatchPlaceholder(
        variant: variant,
        width: _width,
        height: _height,
      ),
    ),
  );

  await expectLater(
    find.byType(RepaintBoundary),
    matchesGoldenFile('images/$name.png'),
  );
}

void main() {
  testWidgets('the photo cross hatch matches its golden', (
    WidgetTester tester,
  ) async {
    await _captureVariant(
      tester,
      CrossHatchVariant.photo,
      'cross_hatch_photo',
    );
  });

  testWidgets('the video cross hatch matches its golden', (
    WidgetTester tester,
  ) async {
    await _captureVariant(
      tester,
      CrossHatchVariant.video,
      'cross_hatch_video',
    );
  });

  testWidgets('the viewport cross hatch matches its golden', (
    WidgetTester tester,
  ) async {
    await _captureVariant(
      tester,
      CrossHatchVariant.viewport,
      'cross_hatch_viewport',
    );
  });
}
