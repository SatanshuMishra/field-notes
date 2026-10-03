import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/design/glass/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _boundaryKey = ValueKey<String>('glass-group-boundary');
const Size _canvas = Size(620, 200);
const double _stripe = 7;
const Size _panel = Size(100, 80);
const double _panelTop = 50;
const List<double> _panelLefts = <double>[40, 260, 480];
const int _maxChannelDelta = 2;

const List<Color> _stripeColours = <Color>[
  Color(0xFFE4572E),
  Color(0xFF17BEBB),
  Color(0xFFFFC914),
  Color(0xFF2E282A),
  Color(0xFF76B041),
];

class _StripesPainter extends CustomPainter {
  const _StripesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (int index = 0; index * _stripe < size.width; index++) {
      canvas.drawRect(
        Rect.fromLTWH(index * _stripe, 0, _stripe, size.height),
        Paint()..color = _stripeColours[index % _stripeColours.length],
      );
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) => false;
}

Widget _scene({required bool shared}) {
  final Widget panels = Stack(
    children: <Widget>[
      const Positioned.fill(child: CustomPaint(painter: _StripesPainter())),
      for (final double left in _panelLefts)
        Positioned(
          left: left,
          top: _panelTop,
          width: _panel.width,
          height: _panel.height,
          child: const GlassSurface(
            tone: GlassTone.scene,
            borderRadius: BorderRadius.zero,
            grouped: true,
            child: SizedBox.expand(),
          ),
        ),
    ],
  );
  return MaterialApp(
    home: Center(
      child: RepaintBoundary(
        key: _boundaryKey,
        child: SizedBox.fromSize(
          size: _canvas,
          child: shared ? BackdropGroup(child: panels) : panels,
        ),
      ),
    ),
  );
}

Future<Uint8List> _capture(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  final Uint8List? pixels = await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData? data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return pixels!;
}

Set<BackdropKey?> _keys(WidgetTester tester) => tester
    .renderObjectList<RenderBackdropFilter>(find.byType(BackdropFilter))
    .map((RenderBackdropFilter filter) => filter.backdropKey)
    .toSet();

int _redRange(Uint8List pixels, {required int row, required double from}) {
  final List<int> reds = <int>[
    for (int x = from.toInt() + 10; x < from.toInt() + _panel.width - 10; x++)
      pixels[(row * _canvas.width.toInt() + x) * 4],
  ];
  return reds.reduce((int a, int b) => a > b ? a : b) -
      reds.reduce((int a, int b) => a < b ? a : b);
}

void main() {
  testWidgets('grouped glass panels render the same pixels as separate ones', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_scene(shared: true));
    final Set<BackdropKey?> sharedKeys = _keys(tester);
    expect(sharedKeys, hasLength(1));
    expect(sharedKeys.single, isNotNull);
    final Uint8List grouped = await _capture(tester);

    await tester.pumpWidget(_scene(shared: false));
    expect(_keys(tester), <BackdropKey?>{null});
    final Uint8List separate = await _capture(tester);

    expect(grouped.length, separate.length);
    final int row = (_panelTop + _panel.height / 2).toInt();
    final double gap = _panelLefts.first + _panel.width + 20;
    expect(
      _redRange(grouped, row: row, from: _panelLefts[1]),
      lessThan(_redRange(grouped, row: row, from: gap) ~/ 4),
    );
    int worst = 0;
    for (int index = 0; index < grouped.length; index++) {
      final int delta = (grouped[index] - separate[index]).abs();
      if (delta > worst) {
        worst = delta;
      }
    }
    expect(worst, lessThanOrEqualTo(_maxChannelDelta));
  });
}
