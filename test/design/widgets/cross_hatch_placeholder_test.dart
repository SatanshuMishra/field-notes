import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'widget_harness.dart';

const int _probeWidth = 120;
const int _probeHeight = 90;

CrossHatchPainter _painterOf(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(CrossHatchPlaceholder),
      matching: find.byType(CustomPaint),
    ),
  );
  return paint.painter! as CrossHatchPainter;
}

Future<List<Color>> _edgeColours(
  WidgetTester tester,
  Widget placeholder,
) async {
  await tester.pumpWidget(
    stickerHarness(
      RepaintBoundary(
        child: SizedBox(
          width: _probeWidth.toDouble(),
          height: _probeHeight.toDouble(),
          child: placeholder,
        ),
      ),
    ),
  );

  final RenderRepaintBoundary boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary));
  final ByteData? pixels = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    return image.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  final ByteData rgba = pixels!;

  Color at(int x, int y) {
    final int offset = ((y * _probeWidth) + x) * 4;
    return Color.fromARGB(
      rgba.getUint8(offset + 3),
      rgba.getUint8(offset),
      rgba.getUint8(offset + 1),
      rgba.getUint8(offset + 2),
    );
  }

  return <Color>[
    at(_probeWidth ~/ 2, 0),
    at(0, _probeHeight ~/ 2),
    at(_probeWidth - 1, _probeHeight ~/ 2),
    at(_probeWidth ~/ 2, _probeHeight - 1),
  ];
}

void main() {
  group('CrossHatchPlaceholder', () {
    testWidgets('honours the bounded size it is given',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const SizedBox(
            width: 120,
            height: 90,
            child: CrossHatchPlaceholder(),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(CrossHatchPlaceholder)),
        const Size(120, 90),
      );
    });

    testWidgets('renders a centered child such as an error label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const SizedBox(
            width: 120,
            height: 90,
            child: CrossHatchPlaceholder(child: Text('unreadable')),
          ),
        ),
      );

      expect(find.text('unreadable'), findsOneWidget);
    });

    testWidgets('paints the photo band pair by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const SizedBox(
            width: 120,
            height: 90,
            child: CrossHatchPlaceholder(),
          ),
        ),
      );

      final CrossHatchPainter painter = _painterOf(tester);
      expect(painter.ground, Palette.hatchMid);
      expect(painter.band, Palette.hatchLight);
      expect(painter.bandWidth, 6);
      expect(painter.bandPitch, 12);
    });

    testWidgets('paints the ink outline over the band fill',
        (WidgetTester tester) async {
      expect(
        await _edgeColours(tester, const CrossHatchPlaceholder()),
        everyElement(Palette.ink),
      );
    });

    testWidgets('blends a hatchColor override into the band instead of '
        'painting it at full strength', (WidgetTester tester) async {
      await tester.pumpWidget(
        stickerHarness(
          const SizedBox(
            width: 120,
            height: 90,
            child: CrossHatchPlaceholder(
              background: Palette.dangerSurface,
              hatchColor: Palette.danger,
            ),
          ),
        ),
      );

      final CrossHatchPainter painter = _painterOf(tester);
      expect(painter.ground, Palette.dangerSurface);
      expect(painter.band, isNot(Palette.danger));
      expect(painter.band, isNot(Palette.dangerSurface));
      expect(
        painter.band.computeLuminance(),
        greaterThan(Palette.danger.computeLuminance()),
      );
      expect(
        painter.band.computeLuminance(),
        lessThan(Palette.dangerSurface.computeLuminance()),
      );
    });

    test('CrossHatchPainter repaints only when a band input changes', () {
      const CrossHatchPainter base = CrossHatchPainter(
        ground: Palette.hatchMid,
        band: Palette.hatchLight,
        bandWidth: 6,
        bandPitch: 12,
      );
      const CrossHatchPainter recoloured = CrossHatchPainter(
        ground: Palette.hatchDark,
        band: Palette.hatchMid,
        bandWidth: 6,
        bandPitch: 12,
      );
      const CrossHatchPainter respaced = CrossHatchPainter(
        ground: Palette.hatchMid,
        band: Palette.hatchLight,
        bandWidth: 8,
        bandPitch: 16,
      );
      const CrossHatchPainter identical = CrossHatchPainter(
        ground: Palette.hatchMid,
        band: Palette.hatchLight,
        bandWidth: 6,
        bandPitch: 12,
      );

      expect(base.shouldRepaint(recoloured), isTrue);
      expect(base.shouldRepaint(respaced), isTrue);
      expect(base.shouldRepaint(identical), isFalse);
    });
  });
}
