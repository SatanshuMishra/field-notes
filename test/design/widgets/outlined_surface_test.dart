import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/design/widgets/outlined_surface.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const double _side = 80;
const double _radius = 20;
const double _borderWidth = 2;
const int _tolerance = 24;
const Color _borderColor = Color(0xFF0033CC);
const Color _childColor = Color(0xFFFFCC00);
const Color _backdrop = Color(0xFFFFFFFF);
const BorderRadius _borderRadius = BorderRadius.all(Radius.circular(_radius));
const Key _boundaryKey = ValueKey<String>('boundary');

Future<void> _pump(WidgetTester tester, Widget surface) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: ColoredBox(
            color: _backdrop,
            child: SizedBox(width: _side, height: _side, child: surface),
          ),
        ),
      ),
    ),
  );
}

Future<Color> _topRightArcPixel(WidgetTester tester) {
  const double centreOffset = _radius - _borderWidth / 2;
  final double angle = math.pi / 4;
  return _pixelAt(
    tester,
    (_side - _radius + centreOffset * math.cos(angle)).floor(),
    (_radius - centreOffset * math.sin(angle)).floor(),
  );
}

Future<Color> _pixelAt(WidgetTester tester, int x, int y) async {
  final RenderRepaintBoundary boundary =
      tester.renderObject(find.byKey(_boundaryKey)) as RenderRepaintBoundary;
  final Color? pixel = await tester.runAsync<Color>(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData data = (await image.toByteData())!;
    final int offset = (y * image.width + x) * 4;
    final Color sampled = Color.fromARGB(
      data.getUint8(offset + 3),
      data.getUint8(offset),
      data.getUint8(offset + 1),
      data.getUint8(offset + 2),
    );
    image.dispose();
    return sampled;
  });
  return pixel!;
}

bool _near(Color actual, Color expected) {
  int channel(double value) => (value * 255).round();
  return (channel(actual.r) - channel(expected.r)).abs() <= _tolerance &&
      (channel(actual.g) - channel(expected.g)).abs() <= _tolerance &&
      (channel(actual.b) - channel(expected.b)).abs() <= _tolerance;
}

void main() {
  testWidgets('OutlinedSurface keeps the outline arc above an opaque child', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      const OutlinedSurface(
        borderRadius: _borderRadius,
        borderColor: _borderColor,
        borderWidth: _borderWidth,
        child: ColoredBox(color: _childColor),
      ),
    );

    expect(_near(await _topRightArcPixel(tester), _borderColor), isTrue);
  });

  testWidgets('a clipped bordered Container loses the outline arc', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: _borderRadius,
          border: Border.all(color: _borderColor, width: _borderWidth),
        ),
        child: const ColoredBox(color: _childColor),
      ),
    );

    expect(_near(await _topRightArcPixel(tester), _childColor), isTrue);
  });

  testWidgets('OutlinedSurface keeps the child size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: OutlinedSurface(
            borderRadius: _borderRadius,
            borderColor: _borderColor,
            borderWidth: _borderWidth,
            child: SizedBox(width: 40, height: 30),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(OutlinedSurface)), const Size(40, 30));
  });

  testWidgets('OutlinedSurface clips the child inside the border band', (
    WidgetTester tester,
  ) async {
    const Color halfBorder = Color(0x800033CC);
    await _pump(
      tester,
      const OutlinedSurface(
        borderRadius: _borderRadius,
        borderColor: halfBorder,
        borderWidth: _borderWidth,
        child: ColoredBox(color: _childColor),
      ),
    );

    final Color bandPixel = await _pixelAt(tester, (_side / 2).floor(), 1);
    final Color overBackdrop = Color.alphaBlend(halfBorder, _backdrop);

    expect(_near(bandPixel, overBackdrop), isTrue);
  });

  testWidgets('OutlinedSurface insets the child by its padding', (
    WidgetTester tester,
  ) async {
    const Key childKey = ValueKey<String>('child');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 100,
            height: 60,
            child: OutlinedSurface(
              borderRadius: _borderRadius,
              borderColor: _borderColor,
              padding: EdgeInsets.all(_borderWidth),
              child: SizedBox.expand(key: childKey),
            ),
          ),
        ),
      ),
    );

    final Rect surface = tester.getRect(find.byType(OutlinedSurface));
    expect(tester.getRect(find.byKey(childKey)), surface.deflate(_borderWidth));
  });
}
