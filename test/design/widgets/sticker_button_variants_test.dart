import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/face_boxes.dart';
import '../../support/theme_harness.dart';

const String _label = 'Go';
const Color _clear = Color(0x00000000);
const Color _softAccentHover = Color(0x24B8566A);
const Color _keepHoverOnMedia = Color(0xFFFFF4E2);

typedef _Face = ({
  Color? fill,
  Color ink,
  Color edge,
  Color? hoverFill,
  bool lifted,
});

_Face _facePage(StickerButtonVariant variant, FieldNotesColors colors) =>
    switch (variant) {
      StickerButtonVariant.primary => (
        fill: Palette.coral,
        ink: Palette.onAccent,
        edge: colors.line,
        hoverFill: null,
        lifted: true,
      ),
      StickerButtonVariant.secondary => (
        fill: colors.cardWarm,
        ink: colors.ink,
        edge: colors.line,
        hoverFill: null,
        lifted: false,
      ),
      StickerButtonVariant.quiet => (
        fill: null,
        ink: colors.inkSoft,
        edge: _clear,
        hoverFill: colors.ink08,
        lifted: false,
      ),
      StickerButtonVariant.softAccent => (
        fill: null,
        ink: colors.accentInk,
        edge: Palette.coral,
        hoverFill: _softAccentHover,
        lifted: false,
      ),
      StickerButtonVariant.danger => (
        fill: null,
        ink: colors.dangerInk,
        edge: colors.dangerInk,
        hoverFill: null,
        lifted: false,
      ),
      StickerButtonVariant.keep => (
        fill: colors.mediaCta,
        ink: colors.mediaCtaInk,
        edge: _clear,
        hoverFill: colors.mediaCtaHover,
        lifted: false,
      ),
      StickerButtonVariant.stageSoft => (
        fill: null,
        ink: colors.mediaCta,
        edge: colors.mediaCta.withValues(alpha: 0.42),
        hoverFill: colors.mediaCta.withValues(alpha: 0.1),
        lifted: false,
      ),
    };

const List<(String, Brightness, FieldNotesColors)> _themes =
    <(String, Brightness, FieldNotesColors)>[
      ('light', Brightness.light, FieldNotesColors.light),
      ('dark', Brightness.dark, FieldNotesColors.dark),
    ];

Future<void> _pump(
  WidgetTester tester,
  StickerButton button, {
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.macOS,
}) => pumpThemed(
  tester,
  Center(child: button),
  brightness: brightness,
  platform: platform,
);

StickerButton _button(
  StickerButtonVariant variant, {
  StickerGround ground = StickerGround.page,
  TextStyle? labelStyle,
}) => StickerButton(
  label: _label,
  variant: variant,
  ground: ground,
  labelStyle: labelStyle,
  onPressed: () {},
);

BoxDecoration _face(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(StickerButton),
                    matching: faceBoxes(),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

Color? _ink(WidgetTester tester) =>
    tester.widget<Text>(find.text(_label)).style?.color;

Future<void> _hover(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  await mouse.moveTo(tester.getCenter(find.byType(StickerButton)));
  await tester.pump();
}

void _expectSameColor(Color? actual, Color? expected, String reason) {
  if (expected == null) {
    expect(actual, isNull, reason: reason);
    return;
  }
  expect(actual, isNotNull, reason: reason);
  expect(actual!.a, closeTo(expected.a, 0.002), reason: '$reason alpha');
  expect(actual.r, closeTo(expected.r, 0.002), reason: '$reason red');
  expect(actual.g, closeTo(expected.g, 0.002), reason: '$reason green');
  expect(actual.b, closeTo(expected.b, 0.002), reason: '$reason blue');
}

void main() {
  for (final (String name, Brightness brightness, FieldNotesColors colors)
      in _themes) {
    for (final StickerButtonVariant variant in StickerButtonVariant.values) {
      testWidgets('$variant wears its face in $name', (
        WidgetTester tester,
      ) async {
        await _pump(tester, _button(variant), brightness: brightness);
        final _Face expected = _facePage(variant, colors);

        final BoxDecoration face = _face(tester);
        _expectSameColor(face.color, expected.fill, '$variant fill');
        _expectSameColor(_ink(tester), expected.ink, '$variant ink');
        _expectSameColor(
          (face.border! as Border).top.color,
          expected.edge,
          '$variant edge',
        );
        expect((face.border! as Border).top.width, Shapes.outlineWidth);
        expect(face.boxShadow != null, expected.lifted, reason: '$variant');
      });
    }

    for (final StickerButtonVariant variant in <StickerButtonVariant>[
      StickerButtonVariant.quiet,
      StickerButtonVariant.softAccent,
      StickerButtonVariant.keep,
      StickerButtonVariant.stageSoft,
    ]) {
      testWidgets('$variant changes its face under the pointer in $name', (
        WidgetTester tester,
      ) async {
        await _pump(tester, _button(variant), brightness: brightness);
        await _hover(tester);

        _expectSameColor(
          _face(tester).color,
          _facePage(variant, colors).hoverFill,
          '$variant hover fill',
        );
      });
    }

    testWidgets('quiet firms up to full ink under the pointer in $name', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _button(StickerButtonVariant.quiet),
        brightness: brightness,
      );
      expect(_ink(tester), colors.inkSoft);

      await _hover(tester);

      expect(_ink(tester), colors.ink);
    });

    testWidgets('keep stays cream on a media ground in $name', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _button(StickerButtonVariant.keep, ground: StickerGround.media),
        brightness: brightness,
      );

      expect(_face(tester).color, Palette.mediaInk);
      expect(_ink(tester), Palette.mediaGround);

      await _hover(tester);

      expect(_face(tester).color, _keepHoverOnMedia);
    });

    testWidgets('stageSoft draws cream on a media ground in $name', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _button(StickerButtonVariant.stageSoft, ground: StickerGround.media),
        brightness: brightness,
      );

      final BoxDecoration face = _face(tester);
      expect(face.color, isNull);
      expect(_ink(tester), Palette.mediaInk);
      _expectSameColor(
        (face.border! as Border).top.color,
        Palette.mediaInk.withValues(alpha: 0.42),
        'stageSoft edge',
      );
    });
  }

  group('button height floor', () {
    const TextStyle smallLabel = TextStyle(fontSize: 8, height: 1);

    for (final (TargetPlatform platform, double floor)
        in const <(TargetPlatform, double)>[
          (TargetPlatform.macOS, 36),
          (TargetPlatform.windows, 40),
          (TargetPlatform.android, 48),
        ]) {
      for (final StickerButtonVariant variant in <StickerButtonVariant>[
        StickerButtonVariant.quiet,
        StickerButtonVariant.softAccent,
        StickerButtonVariant.keep,
        StickerButtonVariant.stageSoft,
      ]) {
        testWidgets('$variant reaches $floor on $platform', (
          WidgetTester tester,
        ) async {
          await _pump(
            tester,
            _button(variant, labelStyle: smallLabel),
            platform: platform,
          );

          expect(tester.getSize(find.byType(StickerButton)).height, floor);
        });
      }
    }

    for (final StickerButtonVariant variant in <StickerButtonVariant>[
      StickerButtonVariant.primary,
      StickerButtonVariant.secondary,
      StickerButtonVariant.danger,
    ]) {
      testWidgets('$variant keeps today\'s height on every platform', (
        WidgetTester tester,
      ) async {
        final List<double> heights = <double>[];
        for (final TargetPlatform platform in <TargetPlatform>[
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.android,
        ]) {
          await _pump(
            tester,
            _button(variant, labelStyle: smallLabel),
            platform: platform,
          );
          heights.add(tester.getSize(find.byType(StickerButton)).height);
        }

        expect(heights.toSet(), hasLength(1));
        expect(heights.first, lessThan(36));
      });
    }
  });
}
