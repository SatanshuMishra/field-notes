@Tags(<String>['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'golden_harness.dart';

const double _enlargement = 3;
const double _columnWidth = 76;
const double _enlargedHeight = 90;
const double _actualHeight = 30;
const double _gap = 6;
const EdgeInsets _bandPadding = EdgeInsets.all(8);

const List<FieldNotesColors> _papers = <FieldNotesColors>[
  FieldNotesColors.light,
  FieldNotesColors.dark,
];

typedef _Shown = ({FlowerKind kind, bool alternate, Size size});

Widget _petal(PetalArt art, Size size, {bool alternate = false}) => CustomPaint(
  painter: PetalPainter(art, alternate: alternate),
  size: size,
);

Widget _column(Mood mood) {
  final PetalArt art = petalArtFor(mood.flower)!;
  final Size wide = art.sizeOn(PetalScreen.wide);
  return SizedBox(
    width: _columnWidth,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: _enlargedHeight,
          child: Center(child: _petal(art, wide * _enlargement)),
        ),
        const SizedBox(height: _gap),
        SizedBox(
          height: _enlargedHeight,
          child: Center(
            child: _petal(art, wide * _enlargement, alternate: true),
          ),
        ),
        const SizedBox(height: _gap),
        SizedBox(
          height: _actualHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _petal(art, wide),
              const SizedBox(width: _gap),
              _petal(art, wide, alternate: true),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _band(FieldNotesColors paper) => ColoredBox(
  color: paper.page,
  child: Padding(
    padding: _bandPadding,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[for (final Mood mood in moodOrder) _column(mood)],
    ),
  ),
);

Widget _sheet() => Column(
  mainAxisSize: MainAxisSize.min,
  children: <Widget>[
    for (final FieldNotesColors paper in _papers) _band(paper),
  ],
);

List<_Shown> _shownFor(Mood mood) {
  final Size wide = petalArtFor(mood.flower)!.sizeOn(PetalScreen.wide);
  return <_Shown>[
    (kind: mood.flower, alternate: false, size: wide * _enlargement),
    (kind: mood.flower, alternate: true, size: wide * _enlargement),
    (kind: mood.flower, alternate: false, size: wide),
    (kind: mood.flower, alternate: true, size: wide),
  ];
}

List<_Shown> _expected() => <_Shown>[
  for (final FieldNotesColors _ in _papers)
    for (final Mood mood in moodOrder) ..._shownFor(mood),
];

void main() {
  testWidgets('the petal sheet matches its golden', (
    WidgetTester tester,
  ) async {
    pinGoldenSurface(tester);

    await tester.pumpWidget(goldenHarness(_sheet()));

    expect(tester.takeException(), isNull);
    expect(<_Shown>[
      for (final CustomPaint paint in tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      ))
        if (paint.painter case final PetalPainter painter)
          (
            kind: painter.art.kind,
            alternate: painter.alternate,
            size: paint.size,
          ),
    ], _expected());
    expect(
      tester.getSize(find.byType(RepaintBoundary)),
      Size(
        _columnWidth * moodOrder.length + _bandPadding.horizontal,
        (_enlargedHeight * 2 +
                _gap * 2 +
                _actualHeight +
                _bandPadding.vertical) *
            _papers.length,
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('images/petal_sheet.png'),
    );
  });
}
