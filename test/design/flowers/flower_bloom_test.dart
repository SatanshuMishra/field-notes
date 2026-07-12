import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/mood/mood.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('FlowerBloom', () {
    testWidgets('renders a FlowerPainter at the requested size for every kind',
        (tester) async {
      for (final kind in FlowerKind.values) {
        await tester.pumpWidget(_host(FlowerBloom(kind: kind, size: 72)));
        expect(tester.takeException(), isNull, reason: kind.name);
        expect(
          tester.getSize(find.byType(FlowerBloom)),
          const Size(72, 72),
          reason: kind.name,
        );
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(FlowerBloom),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(paint.painter, isA<FlowerPainter>(), reason: kind.name);
      }
    });

    testWidgets('announces the flower name to the accessibility tree',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const FlowerBloom(kind: FlowerKind.peony)));
      expect(find.bySemanticsLabel('Peony'), findsOneWidget);
      handle.dispose();
    });

    test('forMood maps a mood to its flower and label', () {
      final bloom = FlowerBloom.forMood(Mood.happy);
      expect(bloom.kind, FlowerKind.peony);
      expect(bloom.semanticLabel, 'Happy');
    });

    testWidgets('ambient-only blooms still render without error',
        (tester) async {
      for (final kind in <FlowerKind>[
        FlowerKind.wiltingRose,
        FlowerKind.thistle,
      ]) {
        await tester.pumpWidget(_host(FlowerBloom(kind: kind, size: 64)));
        expect(tester.takeException(), isNull, reason: kind.name);
      }
    });
  });
}
