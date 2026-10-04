import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import 'package:field_notes/design/flowers/garden_art_colors.dart';
import 'package:field_notes/features/garden/scene/meadow_ambience.dart';

typedef MeadowFlyerSway = ({Offset offset, double angle});

const double meadowBeeSize = 20;
const double meadowButterflySize = 26;
const double _viewBox = 24;
const Offset _viewCentre = Offset(12, 12);
const double _wingNarrowest = 0.42;
const double _beeLargest = 0.9;
const double _butterflyLargest = 1.06;
const double _densityFloor = 0.5;
const double _densityCeiling = 4;
const double _glowDensityCeiling = 2;
const double _glowLargest = 5.04;
const double _glowReach = 4.2;
const double _glowSpread = 1.2;
const int _pad = 2;
const int _sheetWidth = 512;

const MeadowFlyerSway _still = (offset: Offset.zero, angle: 0);

const Color _beeWing = Color.fromRGBO(244, 236, 220, 0.85);
const Color _fireflyCore = Color(0xFFFBF0A2);
const Color _fireflyGlow = Color.fromRGBO(248, 232, 140, 0.8);

const List<(Color, Color)> _butterflyColours = <(Color, Color)>[
  (GardenArtColors.butterflyCoral, GardenArtColors.butterflyCoralHind),
  (GardenArtColors.butterflyLilac, GardenArtColors.butterflyLilacHind),
  (Color(0xFFF0CF6A), Color(0xFFD9AB3E)),
  (Color(0xFFF3EFE4), Color(0xFFD8D0BD)),
];

const _Wing _beeLeftWing = _Wing(8, 9, 4.2, 5, -1);
const _Wing _beeRightWing = _Wing(16, 9, 4.2, 5, 1);
const _Wing _foreLeftWing = _Wing(7, 9, 6, 7.5, -1);
const _Wing _hindLeftWing = _Wing(9, 16, 4.4, 5.4, -1);
const _Wing _foreRightWing = _Wing(17, 9, 6, 7.5, 1);
const _Wing _hindRightWing = _Wing(15, 16, 4.4, 5.4, 1);
const Rect _beeBody = Rect.fromLTRB(6, 9.4, 18, 18.6);
const Rect _beeBodyBounds = Rect.fromLTRB(5.5, 8.9, 18.5, 19.1);
const Rect _butterflyBody = Rect.fromLTRB(10.7, 5.5, 13.3, 17.5);

double meadowWingSpread(double wingPhase) {
  final double phase = wingPhase - wingPhase.floorToDouble();
  final bool closing = phase < 0.5;
  final double eased = Curves.easeInOut.transform(
    closing ? phase * 2 : phase * 2 - 1,
  );
  return closing
      ? 1 + (_wingNarrowest - 1) * eased
      : _wingNarrowest + (1 - _wingNarrowest) * eased;
}

class MeadowCreatureArt {
  MeadowCreatureArt._({
    required this._image,
    required this._beeWingSprite,
    required this._beeBodySprite,
    required this._butterflyBodySprite,
    required this._foreWingSprites,
    required this._hindWingSprites,
    required this._glowSprite,
  });

  factory MeadowCreatureArt.build({required double density}) {
    final double wanted = density.isFinite ? density : _densityFloor;
    final double resolved = wanted.clamp(_densityFloor, _densityCeiling);
    final double beeScale = resolved * meadowBeeSize / _viewBox * _beeLargest;
    final double butterflyScale =
        resolved * meadowButterflySize / _viewBox * _butterflyLargest;
    final double glowScale = math.min(resolved, _glowDensityCeiling);
    final List<_Plan> plans = <_Plan>[
      _Plan.shape(
        _beeLeftWing.bounds,
        beeScale,
        (Canvas canvas) =>
            canvas.drawOval(_beeLeftWing.bounds, Paint()..color = _beeWing),
      ),
      _Plan.shape(_beeBodyBounds, beeScale, _paintBeeBody),
      _Plan.shape(
        _butterflyBody,
        butterflyScale,
        (Canvas canvas) => canvas.drawOval(
          _butterflyBody,
          Paint()..color = GardenArtColors.insectBody,
        ),
      ),
      for (final (Color fore, Color _) in _butterflyColours)
        _Plan.shape(
          _foreLeftWing.bounds,
          butterflyScale,
          (Canvas canvas) =>
              canvas.drawOval(_foreLeftWing.bounds, Paint()..color = fore),
        ),
      for (final (Color _, Color hind) in _butterflyColours)
        _Plan.shape(
          _hindLeftWing.bounds,
          butterflyScale,
          (Canvas canvas) =>
              canvas.drawOval(_hindLeftWing.bounds, Paint()..color = hind),
        ),
      _Plan.glow(glowScale),
    ];
    final List<Rect> cells = _pack(plans);
    final int width = cells
        .map((Rect cell) => cell.right)
        .reduce(math.max)
        .ceil();
    final int height = cells
        .map((Rect cell) => cell.bottom)
        .reduce(math.max)
        .ceil();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    for (int i = 0; i < plans.length; i++) {
      canvas.save();
      canvas.clipRect(cells[i]);
      canvas.translate(cells[i].left + _pad, cells[i].top + _pad);
      plans[i].paint(canvas);
      canvas.restore();
    }
    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(width, height);
    picture.dispose();
    final List<_Sprite> sprites = <_Sprite>[
      for (int i = 0; i < plans.length; i++)
        _Sprite(
          source: cells[i],
          scaleX: plans[i].scaleX,
          scaleY: plans[i].scaleY,
        ),
    ];
    final int kinds = _butterflyColours.length;
    return MeadowCreatureArt._(
      image: image,
      beeWingSprite: sprites[0],
      beeBodySprite: sprites[1],
      butterflyBodySprite: sprites[2],
      foreWingSprites: List<_Sprite>.unmodifiable(
        sprites.sublist(3, 3 + kinds),
      ),
      hindWingSprites: List<_Sprite>.unmodifiable(
        sprites.sublist(3 + kinds, 3 + kinds * 2),
      ),
      glowSprite: sprites[3 + kinds * 2],
    );
  }

  final ui.Image _image;
  final _Sprite _beeWingSprite;
  final _Sprite _beeBodySprite;
  final _Sprite _butterflyBodySprite;
  final List<_Sprite> _foreWingSprites;
  final List<_Sprite> _hindWingSprites;
  final _Sprite _glowSprite;

  ui.Image get image => _image;

  int get imageBytes => _image.width * _image.height * 4;

  void paintFlyers(
    Canvas canvas, {
    required List<MeadowFlyerPose> bees,
    required List<MeadowFlyerPose> butterflies,
    required double opacity,
    MeadowFlyerSway Function(MeadowFlyerPose pose)? sway,
  }) {
    final Paint paint = Paint()..filterQuality = FilterQuality.medium;
    for (final MeadowFlyerPose bee in bees) {
      final double alpha = bee.opacity * opacity;
      if (alpha <= 0) {
        continue;
      }
      paint.color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
      final double spread = meadowWingSpread(bee.wingPhase);
      canvas.save();
      _place(canvas, bee, meadowBeeSize, sway?.call(bee) ?? _still);
      _draw(canvas, _beeWingSprite, _beeLeftWing.at(spread), spread, paint);
      _draw(canvas, _beeWingSprite, _beeRightWing.at(spread), spread, paint);
      _draw(canvas, _beeBodySprite, _beeBodyBounds, 1, paint);
      canvas.restore();
    }
    for (final MeadowFlyerPose butterfly in butterflies) {
      final double alpha = butterfly.opacity * opacity;
      if (alpha <= 0) {
        continue;
      }
      paint.color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0));
      final double spread = meadowWingSpread(butterfly.wingPhase);
      final int kind = butterfly.variant % _foreWingSprites.length;
      canvas.save();
      _place(
        canvas,
        butterfly,
        meadowButterflySize,
        sway?.call(butterfly) ?? _still,
      );
      _draw(
        canvas,
        _foreWingSprites[kind],
        _foreLeftWing.at(spread),
        spread,
        paint,
      );
      _draw(
        canvas,
        _hindWingSprites[kind],
        _hindLeftWing.at(spread),
        spread,
        paint,
      );
      _draw(
        canvas,
        _foreWingSprites[kind],
        _foreRightWing.at(spread),
        spread,
        paint,
      );
      _draw(
        canvas,
        _hindWingSprites[kind],
        _hindRightWing.at(spread),
        spread,
        paint,
      );
      _draw(canvas, _butterflyBodySprite, _butterflyBody, 1, paint);
      canvas.restore();
    }
  }

  void paintFireflies(Canvas canvas, List<MeadowFireflyPose> fireflies) {
    final Rect source = _glowSprite.source;
    final List<RSTransform> transforms = <RSTransform>[];
    final List<Rect> rects = <Rect>[];
    final List<Color> colours = <Color>[];
    for (final MeadowFireflyPose firefly in fireflies) {
      if (firefly.opacity <= 0) {
        continue;
      }
      transforms.add(
        RSTransform.fromComponents(
          rotation: 0,
          scale: firefly.size / _glowLargest / _glowSprite.scaleX,
          anchorX: source.width / 2,
          anchorY: source.height / 2,
          translateX: firefly.position.dx,
          translateY: firefly.position.dy,
        ),
      );
      rects.add(source);
      colours.add(
        Color.fromRGBO(255, 255, 255, firefly.opacity.clamp(0.0, 1.0)),
      );
    }
    if (transforms.isEmpty) {
      return;
    }
    canvas.drawAtlas(
      _image,
      transforms,
      rects,
      colours,
      BlendMode.modulate,
      null,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void dispose() {
    _image.dispose();
  }

  void _place(
    Canvas canvas,
    MeadowFlyerPose pose,
    double size,
    MeadowFlyerSway sway,
  ) {
    final double unit = pose.scale * size / _viewBox;
    final double rotation = pose.rotation + sway.angle;
    canvas.translate(
      pose.position.dx + sway.offset.dx,
      pose.position.dy + sway.offset.dy,
    );
    if (rotation != 0) {
      canvas.rotate(rotation);
    }
    canvas.scale(unit * pose.facing, unit);
    canvas.translate(-_viewCentre.dx, -_viewCentre.dy);
  }

  void _draw(
    Canvas canvas,
    _Sprite sprite,
    Rect shape,
    double spread,
    Paint paint,
  ) {
    final double padX = _pad / sprite.scaleX * spread;
    final double padY = _pad / sprite.scaleY;
    canvas.drawImageRect(
      _image,
      sprite.source,
      Rect.fromLTRB(
        shape.left - padX,
        shape.top - padY,
        shape.right + padX,
        shape.bottom + padY,
      ),
      paint,
    );
  }
}

void _paintBeeBody(Canvas canvas) {
  canvas.drawOval(_beeBody, Paint()..color = GardenArtColors.beeBody);
  canvas.drawOval(
    _beeBody,
    Paint()
      ..color = GardenArtColors.beeStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  final Paint stripe = Paint()
    ..color = GardenArtColors.beeStroke
    ..strokeWidth = 1.5;
  canvas.drawLine(const Offset(10, 10.2), const Offset(10, 17.8), stripe);
  canvas.drawLine(const Offset(13, 9.7), const Offset(13, 18.3), stripe);
}

class _Wing {
  const _Wing(this.cx, this.cy, this.rx, this.ry, this.side);

  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final int side;

  Rect get bounds => at(1);

  Rect at(double spread) {
    final double anchor = side < 0 ? cx + rx : cx - rx;
    return Rect.fromCenter(
      center: Offset(anchor + (cx - anchor) * spread, cy),
      width: rx * 2 * spread,
      height: ry * 2,
    );
  }
}

class _Sprite {
  const _Sprite({
    required this.source,
    required this.scaleX,
    required this.scaleY,
  });

  final Rect source;
  final double scaleX;
  final double scaleY;
}

class _Plan {
  const _Plan({
    required this.width,
    required this.height,
    required this.scaleX,
    required this.scaleY,
    required this.paint,
  });

  factory _Plan.shape(
    Rect bounds,
    double scale,
    void Function(Canvas canvas) draw,
  ) {
    final int inner = (bounds.width * scale).ceil();
    final int tall = (bounds.height * scale).ceil();
    final double scaleX = inner / bounds.width;
    final double scaleY = tall / bounds.height;
    return _Plan(
      width: inner + _pad * 2,
      height: tall + _pad * 2,
      scaleX: scaleX,
      scaleY: scaleY,
      paint: (Canvas canvas) {
        canvas.scale(scaleX, scaleY);
        canvas.translate(-bounds.left, -bounds.top);
        draw(canvas);
      },
    );
  }

  factory _Plan.glow(double scale) {
    final double radius = _glowReach * _glowLargest * scale;
    final int side = (radius * 2).ceil();
    return _Plan(
      width: side + _pad * 2,
      height: side + _pad * 2,
      scaleX: scale,
      scaleY: scale,
      paint: (Canvas canvas) {
        final Offset centre = Offset(side / 2, side / 2);
        canvas.drawCircle(
          centre,
          _glowSpread * _glowLargest * scale,
          Paint()
            ..color = _fireflyGlow
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              _glowLargest * scale,
            ),
        );
        canvas.drawCircle(
          centre,
          _glowLargest / 2 * scale,
          Paint()..color = _fireflyCore,
        );
      },
    );
  }

  final int width;
  final int height;
  final double scaleX;
  final double scaleY;
  final void Function(Canvas canvas) paint;
}

List<Rect> _pack(List<_Plan> plans) {
  final int limit = math.max(
    _sheetWidth,
    plans.map((_Plan plan) => plan.width).reduce(math.max),
  );
  final List<int> order = List<int>.generate(plans.length, (int i) => i)
    ..sort((int a, int b) {
      final int byHeight = plans[b].height.compareTo(plans[a].height);
      return byHeight != 0 ? byHeight : a.compareTo(b);
    });
  final List<Rect?> cells = List<Rect?>.filled(plans.length, null);
  int x = 0;
  int y = 0;
  int shelf = 0;
  for (final int index in order) {
    final _Plan plan = plans[index];
    if (x + plan.width > limit) {
      x = 0;
      y += shelf;
      shelf = 0;
    }
    cells[index] = Rect.fromLTWH(
      x.toDouble(),
      y.toDouble(),
      plan.width.toDouble(),
      plan.height.toDouble(),
    );
    x += plan.width;
    shelf = math.max(shelf, plan.height);
  }
  return List<Rect>.unmodifiable(cells.nonNulls);
}
