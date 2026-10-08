import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/glass/glass.dart';

const Color _backdrop = Color(0xFF808080);
const int _canvasWidth = 320;
const int _canvasHeight = 240;
const Rect _glassRect = Rect.fromLTWH(80, 90, 160, 60);
const int _tolerance = 3;

const Key _boundaryKey = Key('glass-boundary');
const Key _contentKey = Key('glass-content');

typedef _Look = ({
  String name,
  Brightness brightness,
  GlassTone tone,
  Color tint,
  Color border,
  Color highlight,
});

const Color _paperLightTint = Color.fromRGBO(255, 250, 240, 0.55);
const Color _paperLightBorder = Color.fromRGBO(255, 255, 255, 0.65);
const Color _paperLightHighlight = Color.fromRGBO(255, 255, 255, 0.75);
const Color _paperDarkTint = Color.fromRGBO(38, 33, 33, 0.58);
const Color _paperDarkBorder = Color.fromRGBO(252, 244, 244, 0.16);
const Color _paperDarkHighlight = Color.fromRGBO(255, 255, 255, 0.08);
const Color _sceneTint = Color.fromRGBO(28, 22, 16, 0.34);
const Color _sceneBorder = Color.fromRGBO(255, 250, 240, 0.22);
const Color _sceneHighlight = Color.fromRGBO(255, 255, 255, 0.18);
const Color _toastTint = Color.fromRGBO(40, 30, 22, 0.62);
const Color _toastBorder = Color.fromRGBO(255, 250, 240, 0.22);
const Color _toastHighlight = Color.fromRGBO(255, 255, 255, 0.16);
const Color _mediaTint = Color.fromRGBO(28, 22, 16, 0.38);
const Color _mediaBorder = Color.fromRGBO(255, 250, 240, 0.22);
const Color _mediaHighlight = Color.fromRGBO(255, 255, 255, 0.16);
const Color _mediaShadow = Color.fromRGBO(0, 0, 0, 0.55);

final class _Pixels {
  const _Pixels(this.bytes);

  final ByteData bytes;

  Color at(int x, int y) {
    final int offset = ((y * _canvasWidth) + x) * 4;
    return Color.fromARGB(
      bytes.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
  }
}

Color _over(Color top, Color bottom) {
  final double alpha = top.a;
  double mix(double upper, double lower) =>
      (upper * alpha) + (lower * (1 - alpha));
  return Color.from(
    alpha: 1,
    red: mix(top.r, bottom.r),
    green: mix(top.g, bottom.g),
    blue: mix(top.b, bottom.b),
  );
}

List<int> _channels(Color colour) {
  final int value = colour.toARGB32();
  return <int>[(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF];
}

void _expectNear(Color actual, Color expected, String reason) {
  expect(
    _channels(actual),
    pairwiseCompare<int, int>(
      _channels(expected),
      (int want, int got) => (want - got).abs() <= _tolerance,
      'within $_tolerance of',
    ),
    reason: reason,
  );
}

ui.ImageFilter _expectedBackdrop({double s = 1.6}) {
  return ui.ImageFilter.compose(
    outer: ColorFilter.matrix(<double>[
      0.213 + 0.787 * s,
      0.715 - 0.715 * s,
      0.072 - 0.072 * s,
      0,
      0,
      0.213 - 0.213 * s,
      0.715 + 0.285 * s,
      0.072 - 0.072 * s,
      0,
      0,
      0.213 - 0.213 * s,
      0.715 - 0.715 * s,
      0.072 + 0.928 * s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]),
    inner: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
  );
}

Future<_Pixels> _paintGlass(
  WidgetTester tester, {
  required Brightness brightness,
  required GlassTone tone,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: fieldNotesTheme(brightness: brightness),
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _boundaryKey,
            child: SizedBox(
              width: _canvasWidth.toDouble(),
              height: _canvasHeight.toDouble(),
              child: ColoredBox(
                color: _backdrop,
                child: Stack(
                  children: <Widget>[
                    Positioned.fromRect(
                      rect: _glassRect,
                      child: GlassSurface(
                        tone: tone,
                        borderRadius: BorderRadius.circular(20),
                        child: const SizedBox.expand(key: _contentKey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  final ByteData? pixels = await tester.runAsync<ByteData?>(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    image.dispose();
    return data;
  });
  return _Pixels(pixels!);
}

void _expectLook(_Pixels pixels, _Look look) {
  final Color tinted = _over(look.tint, _backdrop);
  final int middleX = _glassRect.center.dx.toInt();
  final int middleY = _glassRect.center.dy.toInt();
  final int left = _glassRect.left.toInt();
  final int top = _glassRect.top.toInt();

  _expectNear(
    pixels.at(middleX, middleY),
    tinted,
    '${look.name}: the middle shows the tint over the blurred backdrop',
  );
  _expectNear(
    pixels.at(left, middleY),
    _over(look.border, tinted),
    '${look.name}: the left edge shows the 1-point border',
  );
  _expectNear(
    pixels.at(left + 1, middleY),
    tinted,
    '${look.name}: the border is 1 point wide',
  );
  _expectNear(
    pixels.at(middleX, top),
    _over(look.border, tinted),
    '${look.name}: the top edge shows the border',
  );
  _expectNear(
    pixels.at(middleX, top + 1),
    _over(look.highlight, tinted),
    '${look.name}: the inner top edge shows the 1-point highlight',
  );
  _expectNear(
    pixels.at(middleX, top + 2),
    tinted,
    '${look.name}: the highlight is 1 point tall',
  );
}

void main() {
  testWidgets('glass blurs 18 points and tints for paper, dark and scene', (
    WidgetTester tester,
  ) async {
    const List<_Look> looks = <_Look>[
      (
        name: 'paper in the light theme',
        brightness: Brightness.light,
        tone: GlassTone.paper,
        tint: _paperLightTint,
        border: _paperLightBorder,
        highlight: _paperLightHighlight,
      ),
      (
        name: 'paper in the dark theme',
        brightness: Brightness.dark,
        tone: GlassTone.paper,
        tint: _paperDarkTint,
        border: _paperDarkBorder,
        highlight: _paperDarkHighlight,
      ),
      (
        name: 'scene in the light theme',
        brightness: Brightness.light,
        tone: GlassTone.scene,
        tint: _sceneTint,
        border: _sceneBorder,
        highlight: _sceneHighlight,
      ),
      (
        name: 'scene in the dark theme',
        brightness: Brightness.dark,
        tone: GlassTone.scene,
        tint: _sceneTint,
        border: _sceneBorder,
        highlight: _sceneHighlight,
      ),
    ];

    for (final _Look look in looks) {
      final _Pixels pixels = await _paintGlass(
        tester,
        brightness: look.brightness,
        tone: look.tone,
      );

      final Finder backdrop = find.ancestor(
        of: find.byKey(_contentKey),
        matching: find.byType(BackdropFilter),
      );
      expect(backdrop, findsOneWidget, reason: look.name);
      expect(
        tester.widget<BackdropFilter>(backdrop).filter,
        _expectedBackdrop(),
        reason: '${look.name}: an 18-sigma blur with saturation 1.6',
      );

      final Finder clip = find.ancestor(
        of: backdrop,
        matching: find.byType(ClipRRect),
      );
      expect(clip, findsOneWidget, reason: look.name);
      expect(
        tester.widget<ClipRRect>(clip).borderRadius,
        BorderRadius.circular(20),
        reason: '${look.name}: the glass clips to its radius',
      );

      _expectLook(pixels, look);
    }
  });

  testWidgets('toast glass is the dark smoked tint in either theme', (
    WidgetTester tester,
  ) async {
    for (final Brightness brightness in Brightness.values) {
      final _Pixels pixels = await _paintGlass(
        tester,
        brightness: brightness,
        tone: GlassTone.toast,
      );
      _expectLook(pixels, (
        name: 'toast in the ${brightness.name} theme',
        brightness: brightness,
        tone: GlassTone.toast,
        tint: _toastTint,
        border: _toastBorder,
        highlight: _toastHighlight,
      ));
    }
  });

  testWidgets('paper glass casts its shadow below and not through it', (
    WidgetTester tester,
  ) async {
    debugDisableShadows = false;
    try {
      final _Pixels pixels = await _paintGlass(
        tester,
        brightness: Brightness.light,
        tone: GlassTone.paper,
      );
      final int middleX = _glassRect.center.dx.toInt();
      final int middleY = _glassRect.center.dy.toInt();
      final int backdropRed = _channels(_backdrop).first;

      expect(
        _channels(pixels.at(middleX, _glassRect.bottom.toInt() + 2)).first,
        lessThan(backdropRed - 4),
        reason: 'the shadow darkens the paper just below the glass',
      );
      _expectNear(
        pixels.at(middleX, middleY),
        _over(_paperLightTint, _backdrop),
        'the shadow stays outside, leaving the glass tint clean',
      );
      _expectNear(
        pixels.at(middleX, 20),
        _backdrop,
        'the shadow falls downward, leaving the paper above clean',
      );
    } finally {
      debugDisableShadows = true;
    }
  });

  testWidgets('media glass is the dark glass over media', (
    WidgetTester tester,
  ) async {
    void expectColour(Color actual, Color expected, String reason) {
      expect(actual.toARGB32(), expected.toARGB32(), reason: reason);
    }

    final Finder backdrop = find.ancestor(
      of: find.byKey(_contentKey),
      matching: find.byType(BackdropFilter),
    );
    final Finder shadowPaint = find.ancestor(
      of: find.byKey(_contentKey),
      matching: find.byWidgetPredicate(
        (Widget widget) =>
            widget is CustomPaint &&
            widget.foregroundPainter is GlassShadowPainter,
      ),
    );

    for (final Brightness brightness in Brightness.values) {
      final String name = 'media in the ${brightness.name} theme';
      final GlassColors colors = GlassTone.media.colorsFor(brightness);
      expectColour(colors.tint, _mediaTint, '$name fill');
      expectColour(colors.border, _mediaBorder, '$name border');
      expectColour(colors.highlight, _mediaHighlight, '$name highlight');
      expect(colors.saturation, 1.5, reason: '$name saturation');

      final _Pixels pixels = await _paintGlass(
        tester,
        brightness: brightness,
        tone: GlassTone.media,
      );
      expect(
        tester.widget<BackdropFilter>(backdrop).filter,
        _expectedBackdrop(s: 1.5),
        reason: '$name: an 18-sigma blur with saturation 1.5',
      );

      final GlassShadowPainter painter =
          tester.widget<CustomPaint>(shadowPaint).foregroundPainter!
              as GlassShadowPainter;
      expect(painter.shadows, hasLength(1), reason: '$name: one drop shadow');
      final BoxShadow shadow = painter.shadows.single;
      expectColour(shadow.color, _mediaShadow, '$name shadow colour');
      expect(shadow.offset, const Offset(0, 10), reason: '$name offset');
      expect(shadow.blurRadius, 24, reason: '$name shadow blur');
      expect(shadow.spreadRadius, -12, reason: '$name shadow spread');

      _expectLook(pixels, (
        name: name,
        brightness: brightness,
        tone: GlassTone.media,
        tint: _mediaTint,
        border: _mediaBorder,
        highlight: _mediaHighlight,
      ));
    }

    final List<(GlassTone, Brightness, Color, Color, Color)> rows =
        <(GlassTone, Brightness, Color, Color, Color)>[
          (
            GlassTone.paper,
            Brightness.light,
            _paperLightTint,
            _paperLightBorder,
            _paperLightHighlight,
          ),
          (
            GlassTone.paper,
            Brightness.dark,
            _paperDarkTint,
            _paperDarkBorder,
            _paperDarkHighlight,
          ),
          (
            GlassTone.scene,
            Brightness.light,
            _sceneTint,
            _sceneBorder,
            _sceneHighlight,
          ),
          (
            GlassTone.scene,
            Brightness.dark,
            _sceneTint,
            _sceneBorder,
            _sceneHighlight,
          ),
          (
            GlassTone.toast,
            Brightness.light,
            _toastTint,
            _toastBorder,
            _toastHighlight,
          ),
          (
            GlassTone.toast,
            Brightness.dark,
            _toastTint,
            _toastBorder,
            _toastHighlight,
          ),
        ];

    for (final (
          GlassTone tone,
          Brightness brightness,
          Color tint,
          Color border,
          Color highlight,
        )
        in rows) {
      final String name = '${tone.name} in the ${brightness.name} theme';
      final GlassColors colors = tone.colorsFor(brightness);
      expectColour(colors.tint, tint, '$name tint');
      expectColour(colors.border, border, '$name border');
      expectColour(colors.highlight, highlight, '$name highlight');
      expect(colors.saturation, 1.6, reason: '$name saturation');

      await _paintGlass(tester, brightness: brightness, tone: tone);
      expect(
        tester.widget<BackdropFilter>(backdrop).filter,
        _expectedBackdrop(),
        reason: '$name: an 18-sigma blur with saturation 1.6',
      );
    }

    expect(glassBackdropFilter, _expectedBackdrop());
    expect(glassBackdropFilterAt(1), _expectedBackdrop());
    expect(
      glassBackdropFilterAt(1, saturation: 1.5),
      _expectedBackdrop(s: 1.5),
    );

    final GlassColors resaturated = GlassColors.scene.copyWith(saturation: 1.5);
    expect(resaturated.saturation, 1.5);
    expectColour(resaturated.tint, _sceneTint, 'copyWith keeps the fill');
    expect(resaturated, isNot(GlassColors.scene));
    expect(resaturated.copyWith(saturation: 1.6), GlassColors.scene);
    expect(
      resaturated.copyWith(saturation: 1.6).hashCode,
      GlassColors.scene.hashCode,
    );
  });

  test('glass exposes its colours and soft pill for every tone', () {
    void expectColour(Color actual, Color expected, String reason) {
      expect(actual.toARGB32(), expected.toARGB32(), reason: reason);
    }

    final List<(GlassTone, Brightness, Color, Color, Color, Color)> rows =
        <(GlassTone, Brightness, Color, Color, Color, Color)>[
          (
            GlassTone.paper,
            Brightness.light,
            _paperLightTint,
            _paperLightBorder,
            _paperLightHighlight,
            const Color.fromRGBO(184, 86, 106, 0.13),
          ),
          (
            GlassTone.paper,
            Brightness.dark,
            _paperDarkTint,
            _paperDarkBorder,
            _paperDarkHighlight,
            const Color.fromRGBO(230, 146, 160, 0.2),
          ),
          (
            GlassTone.scene,
            Brightness.light,
            _sceneTint,
            _sceneBorder,
            _sceneHighlight,
            const Color.fromRGBO(255, 250, 240, 0.24),
          ),
          (
            GlassTone.scene,
            Brightness.dark,
            _sceneTint,
            _sceneBorder,
            _sceneHighlight,
            const Color.fromRGBO(255, 250, 240, 0.24),
          ),
          (
            GlassTone.toast,
            Brightness.light,
            _toastTint,
            _toastBorder,
            _toastHighlight,
            const Color.fromRGBO(255, 250, 240, 0.24),
          ),
          (
            GlassTone.toast,
            Brightness.dark,
            _toastTint,
            _toastBorder,
            _toastHighlight,
            const Color.fromRGBO(255, 250, 240, 0.24),
          ),
        ];

    for (final (
          GlassTone tone,
          Brightness brightness,
          Color tint,
          Color border,
          Color highlight,
          Color pill,
        )
        in rows) {
      final String name = '${tone.name} in the ${brightness.name} theme';
      final GlassColors colors = tone.colorsFor(brightness);
      expectColour(colors.tint, tint, '$name tint');
      expectColour(colors.border, border, '$name border');
      expectColour(colors.highlight, highlight, '$name highlight');
      expectColour(colors.pill, pill, '$name pill');
      expectColour(tone.pillFor(brightness), pill, '$name pill by tone');
    }
  });
}
