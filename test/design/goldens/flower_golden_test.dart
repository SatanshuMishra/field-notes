@Tags(<String>['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'golden_harness.dart';

const double _size = 44;

const List<(FlowerKind, String)> _blooms = <(FlowerKind, String)>[
  (FlowerKind.peony, 'flower_peony'),
  (FlowerKind.rose, 'flower_rose'),
  (FlowerKind.sunflower, 'flower_sunflower'),
  (FlowerKind.poppy, 'flower_poppy'),
  (FlowerKind.chrysanthemum, 'flower_chrysanthemum'),
  (FlowerKind.daffodil, 'flower_daffodil'),
  (FlowerKind.lavender, 'flower_lavender'),
  (FlowerKind.aster, 'flower_aster'),
  (FlowerKind.bleedingHeart, 'flower_bleeding_heart'),
  (FlowerKind.redSpiderLily, 'flower_red_spider_lily'),
  (FlowerKind.wiltingRose, 'flower_wilting_rose'),
  (FlowerKind.thistle, 'flower_thistle'),
];

Future<void> _captureBloom(
  WidgetTester tester,
  FlowerKind kind,
  String name,
) async {
  pinGoldenSurface(tester);

  await tester.pumpWidget(
    goldenHarness(FlowerBloom(kind: kind, size: _size)),
  );

  await expectLater(
    find.byType(RepaintBoundary),
    matchesGoldenFile('images/$name.png'),
  );
}

void main() {
  for (final (FlowerKind kind, String name) in _blooms) {
    testWidgets('the ${kind.label} bloom matches its golden', (
      WidgetTester tester,
    ) async {
      await _captureBloom(tester, kind, name);
    });
  }
}
