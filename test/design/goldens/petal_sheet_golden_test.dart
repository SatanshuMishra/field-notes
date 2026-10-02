@Tags(<String>['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'golden_harness.dart';

const double _bloomSize = 88;
const double _enlargement = 10;
const double _petalCell = 100;
const double _gap = 16;
const int _columns = 2;
const EdgeInsets _cellPadding = EdgeInsets.all(8);

Widget _pair(Mood mood) {
  final PetalArt art = petalArtFor(mood.flower)!;
  return Padding(
    padding: _cellPadding,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FlowerBloom(kind: mood.flower, size: _bloomSize),
        const SizedBox(width: _gap),
        SizedBox.square(
          dimension: _petalCell,
          child: Center(
            child: CustomPaint(
              painter: PetalPainter(art),
              size: art.size * _enlargement,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _sheet() => ColoredBox(
  color: FieldNotesColors.light.cardLight,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (int row = 0; row < moodOrder.length; row += _columns)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final Mood mood in moodOrder.skip(row).take(_columns))
              _pair(mood),
          ],
        ),
    ],
  ),
);

void main() {
  testWidgets('the petal sheet shows each flower beside its petal', (
    WidgetTester tester,
  ) async {
    pinGoldenSurface(tester);

    await tester.pumpWidget(goldenHarness(_sheet()));

    expect(
      tester
          .widgetList<FlowerBloom>(find.byType(FlowerBloom))
          .map((FlowerBloom bloom) => bloom.kind),
      <FlowerKind>[for (final Mood mood in moodOrder) mood.flower],
    );
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((CustomPaint paint) => paint.painter)
          .whereType<PetalPainter>()
          .map((PetalPainter painter) => painter.art.kind),
      <FlowerKind>[for (final Mood mood in moodOrder) mood.flower],
    );
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('images/petal_sheet.png'),
    );
  });
}
