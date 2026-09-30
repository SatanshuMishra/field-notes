import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_creature_art.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_motion.dart';
import 'package:field_notes/features/garden/render/meadow_plant_atlas.dart';
import 'package:field_notes/features/garden/render/meadow_rays.dart';
import 'package:field_notes/features/garden/scene/meadow_ambience.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart'
    hide MeadowRange;
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter/rendering.dart';

const double meadowDimmedOpacity = 0.2;
const double meadowSpotRadius = 26;

const Rect _world = Rect.fromLTWH(0, 0, meadowWorldWidth, meadowWorldHeight);
const double _faint = 0.004;
const double _degrees = math.pi / 180;
const double _skyMiddleRow = 130;
const double _skyHorizonRow = 292;
const double _sunRadius = 55;
const double _sunReach = _sunRadius * math.sqrt2;
const double _moonRadius = 17;
const double _moonShadeRadius = 17.68;
const double _moonShadeLift = 0.68;
const double _moonShadeEdge = 0.5;
const double _moonGlowSpread = 27;
const double _moonGlowSigma = 15.5;
const double _moonGlowReach = 66;
const Offset _moonLightCentre = Offset(-4.08, -4.76);
const double _moonLightReach = 30.3;
const Offset _milkyCentre = Offset(700, 0);
const Size _milkyBox = Size(1800, 480);
const Size _milkyRadii = Size(828, 124.8);
const Offset _shootingLength = Offset(45, 1);
const double _shootingTilt = -24 * _degrees;
const Rect _shootingTrail = Rect.fromLTWH(-45, -1, 90, 2);
const double _spotReach = meadowSpotRadius * math.sqrt2;
const Offset _vignetteCentre = Offset(700, 268.8);
const Size _vignetteRadii = Size(1120, 576);
const double _pocketStop = 0.68;
const double _fallStop = 0.7;
const Offset _lakeMistCentre = Offset(0.5, 0.55);
const Size _lakeMistRadii = Size(0.5, 0.45);
const Offset _fallMistCentre = Offset(0.5, 0.7);
const double _fallMistOpacity = 0.45;
const double _fallMistFog = 0.5;
const double _captionLeft = 22;
const double _captionBottom = 16;
const double _captionSize = 19;

const Color _sunCore = Color.fromRGBO(255, 242, 204, 0.96);
const Color _milkyLight = Color.fromRGBO(226, 222, 255, 1);
const Color _shootingLight = Color.fromRGBO(255, 252, 235, 0.95);
const Color _spotLight = Color.fromRGBO(255, 246, 220, 0.45);
const Color _vignetteShade = Color.fromRGBO(40, 30, 20, 0.2);
const List<Color> _moonLight = <Color>[
  Color(0xFFFFFDF3),
  Color(0xFFEBE7D6),
  Color(0xFFD8D2BD),
];

String? meadowStageCaption({
  required int year,
  required int growthPoint,
  required int daysInYear,
  required MeadowSceneMode mode,
}) {
  if (mode == MeadowSceneMode.full) {
    return null;
  }
  return growthPoint >= daysInYear ? '$year' : '$year · still growing';
}

class MeadowStagePainter extends CustomPainter {
  MeadowStagePainter({
    required this.layers,
    required this.atlas,
    required this.creatures,
    required this.rays,
    required this.terrain,
    required this.plants,
    required this.palette,
    required this.viewport,
    required this.time,
    required this.animate,
    required this.growthPoint,
    required this.mode,
    this.heaviest,
    this.bees = const <MeadowFlyerPose>[],
    this.butterflies = const <MeadowFlyerPose>[],
    this.fireflies = const <MeadowFireflyPose>[],
    this.growAnimated = false,
    this.reveals = const <int, double>{},
    this.highlight,
    this.previousHighlight,
    this.highlightSince = double.negativeInfinity,
    this.spot,
    this.caption,
    super.repaint,
  });

  final MeadowLayers layers;
  final MeadowPlantAtlas atlas;
  final MeadowCreatureArt creatures;
  final MeadowRays rays;
  final MeadowTerrain terrain;
  final MeadowPlants plants;
  final MeadowPalette palette;
  final MeadowViewport viewport;
  final double time;
  final bool animate;
  final int growthPoint;
  final MeadowSceneMode mode;
  final MeadowWindow? heaviest;
  final List<MeadowFlyerPose> bees;
  final List<MeadowFlyerPose> butterflies;
  final List<MeadowFireflyPose> fireflies;
  final bool growAnimated;
  final Map<int, double> reveals;
  final MeadowRange? highlight;
  final MeadowRange? previousHighlight;
  final double highlightSince;
  final Offset? spot;
  final String? caption;

  double get _now => animate ? time : 0;

  double _phase(double phase) => animate ? phase : 0;

  @override
  void paint(Canvas canvas, Size size) {
    if (!layers.isReady || !atlas.isReady) {
      return;
    }
    final _PaletteShaders shaders = _PaletteShaders.of(palette);
    canvas
      ..save()
      ..translate(viewport.offset.dx, viewport.offset.dy)
      ..scale(viewport.scale)
      ..clipRect(_world);
    _paintSky(canvas, shaders);
    _paintClouds(canvas);
    _paintLandscape(canvas);
    _paintLivingWater(canvas);
    _paintMist(canvas, shaders);
    _paintItems(canvas, shaders);
    creatures.paintFlyers(
      canvas,
      bees: bees,
      butterflies: butterflies,
      opacity: palette.dayLife,
    );
    _paintOverlay(canvas, shaders);
    _paintRays(canvas);
    creatures.paintFireflies(canvas, fireflies);
    _paintSpot(canvas);
    _paintVignette(canvas);
    _paintCaption(canvas);
    canvas.restore();
  }

  void _paintSky(Canvas canvas, _PaletteShaders shaders) {
    canvas.drawRect(_world, Paint()..shader = shaders.sky);
    if (palette.warmGlowColour.a > 0) {
      _drawUnit(
        canvas,
        box: _world,
        centre: palette.warmGlowCentre,
        radii: meadowWarmGlowRadii,
        paint: Paint()..shader = shaders.warmGlow,
      );
    }
    if (palette.milkyOpacity > _faint) {
      canvas
        ..save()
        ..translate(_milkyCentre.dx, _milkyCentre.dy)
        ..rotate(terrain.sky.milkyWayAngle * _degrees)
        ..scale(_milkyRadii.width, _milkyRadii.height)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: _milkyBox.width / _milkyRadii.width,
            height: _milkyBox.height / _milkyRadii.height,
          ),
          Paint()
            ..shader = _milkyWay
            ..color = _opacity(palette.milkyOpacity),
        )
        ..restore();
    }
    if (palette.starsOpacity > _faint) {
      final MeadowImage stars = layers.stars;
      canvas.drawImageRect(
        stars.image,
        stars.source,
        stars.rect,
        _imagePaint(palette.starsOpacity),
      );
      final ({double shift, double opacity}) shooting = meadowShootingStar(
        animate ? time : -meadowShootingDelay,
      );
      final double trail = shooting.opacity * palette.starsOpacity;
      if (trail > _faint) {
        final Offset at = terrain.sky.shootingStar + _shootingLength;
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..rotate(_shootingTilt)
          ..translate(shooting.shift, 0)
          ..drawRect(
            _shootingTrail,
            Paint()
              ..shader = _shootingGradient
              ..color = _opacity(trail),
          )
          ..restore();
      }
    }
    final Offset sun = palette.sunPosition;
    canvas
      ..save()
      ..translate(sun.dx, sun.dy)
      ..drawCircle(Offset.zero, _sunRadius, Paint()..shader = shaders.sun)
      ..restore();
    final Offset moon = palette.moonPosition;
    final Color moonOpacity = _opacity(palette.moonOpacity);
    canvas
      ..save()
      ..translate(moon.dx, moon.dy)
      ..drawCircle(
        Offset.zero,
        _moonGlowReach,
        Paint()
          ..shader = shaders.moonGlow
          ..color = moonOpacity,
      )
      ..drawCircle(
        Offset.zero,
        _moonRadius,
        Paint()
          ..shader = _moonDisc
          ..color = moonOpacity,
      )
      ..drawCircle(
        Offset.zero,
        _moonRadius,
        Paint()
          ..shader = shaders.moonShade
          ..color = moonOpacity,
      )
      ..restore();
  }

  void _paintClouds(Canvas canvas) {
    final Paint paint = _imagePaint(1);
    for (final MeadowCloudImage cloud in layers.clouds) {
      final double drift = meadowCloudDrift(
        _now,
        period: cloud.cloud.period,
        phase: _phase(cloud.cloud.phase),
      );
      canvas.drawImageRect(
        cloud.image.image,
        cloud.image.source,
        cloud.image.rect.shift(Offset(drift, 0)),
        paint,
      );
    }
  }

  void _paintLandscape(Canvas canvas) {
    final Paint paint = _imagePaint(1);
    for (final MeadowLandscapeLayer layer in layers.landscape) {
      switch (layer) {
        case MeadowImageLayer(:final MeadowImage image):
          _drawImage(canvas, image, paint);
        case MeadowFallLayer(
          :final MeadowImage body,
          :final List<MeadowStreakStrip> streaks,
          :final MeadowImage pool,
        ):
          _drawImage(canvas, body, paint);
          for (final MeadowStreakStrip streak in streaks) {
            canvas.drawVertices(
              streak.vertices,
              BlendMode.srcOver,
              Paint()
                ..shader = streak.shaderAt(animate ? time : -streak.delay)
                ..filterQuality = FilterQuality.low,
            );
          }
          _drawImage(canvas, pool, paint);
      }
    }
  }

  void _paintLivingWater(Canvas canvas) {
    final MeadowGroundDressing ground = terrain.ground;
    final List<_WaterMark> marks = <_WaterMark>[];
    final double glintOpacity = palette.glintO;
    if (glintOpacity > _faint) {
      final Offset shift = Offset(palette.glintX, 0);
      marks.add(
        _WaterMark(
          oval: _ovalOf(ground.glare, shift: shift),
          opacity: glintOpacity * MeadowGroundDressing.glareOpacity,
          glint: true,
        ),
      );
      for (final MeadowGlint glint in ground.glints) {
        final double opacity =
            glintOpacity *
            meadowGlint(_now, period: glint.period, phase: _phase(glint.phase));
        if (opacity > _faint) {
          marks.add(
            _WaterMark(
              oval: _ovalOf(glint.ellipse, shift: shift),
              opacity: opacity,
              glint: true,
            ),
          );
        }
      }
    }
    for (final MeadowRipple ripple in ground.ripples) {
      final ({double scale, double opacity}) pose = meadowRipple(
        _now,
        period: ripple.period,
        phase: _phase(ripple.phase),
      );
      if (pose.opacity > _faint) {
        marks.add(
          _WaterMark(
            oval: _ovalOf(ripple.ellipse, scale: pose.scale),
            opacity: pose.opacity,
            glint: false,
            stroke: MeadowRipple.strokeWidth * pose.scale,
          ),
        );
      }
    }
    for (final MeadowFlowMark flow in ground.flows) {
      final ({double shift, double opacity}) pose = meadowFlow(
        _now,
        period: flow.period,
        phase: _phase(flow.phase),
      );
      final double opacity = palette.flowO * pose.opacity;
      if (opacity > _faint) {
        marks.add(
          _WaterMark(
            oval: _ovalOf(flow.ellipse, shift: Offset(0, pose.shift)),
            opacity: opacity,
            glint: false,
          ),
        );
      }
    }
    final List<MeadowImage> water = layers.water;
    if (marks.isEmpty || water.isEmpty) {
      return;
    }
    canvas.saveLayer(
      water
          .map((MeadowImage tile) => tile.rect)
          .reduce((Rect a, Rect b) => a.expandToInclude(b)),
      Paint(),
    );
    for (final _WaterMark mark in marks) {
      final double? stroke = mark.stroke;
      canvas.drawOval(
        mark.oval,
        Paint()
          ..color = _faded(
            mark.glint ? palette.glintC : palette.flowC,
            mark.opacity,
          )
          ..style = stroke == null ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = stroke ?? 0,
      );
    }
    layers.maskToWater(canvas);
    canvas.restore();
  }

  void _paintMist(Canvas canvas, _PaletteShaders shaders) {
    final Rect lake = terrain.sky.lakeMist.shift(
      Offset(meadowMistDrift(_now, period: meadowLakeMistPeriod), 0),
    );
    _drawUnit(
      canvas,
      box: lake,
      centre: _pointIn(lake, _lakeMistCentre),
      radii: Size(
        lake.width * _lakeMistRadii.width,
        lake.height * _lakeMistRadii.height,
      ),
      paint: Paint()
        ..shader = shaders.lakeFog
        ..color = _opacity(palette.fogL),
    );
    final double fallDrift = meadowMistDrift(
      _now,
      period: meadowFallMistPeriod,
    );
    final Paint fall = Paint()
      ..shader = shaders.fallFog
      ..color = _opacity(_fallMistOpacity + palette.fogL * _fallMistFog);
    for (final MeadowFallLayer layer in layers.falls) {
      final Rect box = layer.fall.mist.shift(Offset(fallDrift, 0));
      final Offset centre = _pointIn(box, _fallMistCentre);
      _drawUnit(
        canvas,
        box: box,
        centre: centre,
        radii: _farthestCorner(box, centre),
        paint: fall,
      );
    }
  }

  void _paintItems(Canvas canvas, _PaletteShaders shaders) {
    final _Order order = _Order.of(layers, plants, heaviest);
    final Paint paint = _imagePaint(1);
    for (final _Item item in order.items) {
      switch (item) {
        case _GrassItem(:final MeadowGrassImage band):
          _paintGrass(canvas, band, paint);
        case _SlabItem(:final MeadowTreeSlab slab):
          for (final MeadowImage piece in slab.pieces) {
            _drawImage(canvas, piece, paint);
          }
        case _PlantRun(:final List<MeadowPlant> run):
          _paintPlants(canvas, run);
        case _MistItem(:final MeadowMistPocket pocket):
          _paintPocket(canvas, pocket, shaders);
        case _SpruceItem(:final MeadowSpruceImage spruce):
          _paintSpruce(canvas, spruce);
      }
    }
  }

  void _paintGrass(Canvas canvas, MeadowGrassImage band, Paint paint) {
    if (!band.band.animated) {
      for (final MeadowImage piece in band.pieces) {
        _drawImage(canvas, piece, paint);
      }
      return;
    }
    final double skew = math.tan(
      meadowGrassSkew(_now - _phase(band.band.delay)),
    );
    final Offset origin = Offset(meadowWorldWidth / 2, band.base);
    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..skew(skew, 0)
      ..translate(-origin.dx, -origin.dy);
    for (final MeadowImage piece in band.pieces) {
      _drawImage(canvas, piece, paint);
    }
    canvas.restore();
  }

  void _paintPlants(Canvas canvas, List<MeadowPlant> run) {
    final List<(MeadowPlant, MeadowPlantSprite)> shown =
        <(MeadowPlant, MeadowPlantSprite)>[
          for (final MeadowPlant plant in run)
            if (plant.dayIndex < growthPoint)
              if (atlas.spriteOf(plant.dayIndex)
                  case final MeadowPlantSprite sprite)
                (plant, sprite),
        ];
    int first = 0;
    while (first < shown.length) {
      final int sheet = shown[first].$2.sheet;
      int end = first + 1;
      while (end < shown.length && shown[end].$2.sheet == sheet) {
        end++;
      }
      _drawSprites(canvas, shown.sublist(first, end), sheet);
      first = end;
    }
  }

  void _drawSprites(
    Canvas canvas,
    List<(MeadowPlant, MeadowPlantSprite)> sprites,
    int sheet,
  ) {
    final int count = sprites.length;
    final Float32List transforms = Float32List(count * 4);
    final Float32List rects = Float32List(count * 4);
    final Int32List colours = Int32List(count);
    bool faded = false;
    for (int i = 0; i < count; i++) {
      final (MeadowPlant plant, MeadowPlantSprite sprite) = sprites[i];
      double opacity = _highlightOpacity(plant.dayIndex);
      double scale = 1;
      final double? revealed = reveals[plant.dayIndex];
      if (animate && growAnimated && revealed != null) {
        final ({double scale, double opacity}) grow = meadowGrowIn(
          time - revealed,
        );
        scale = grow.scale;
        opacity *= grow.opacity;
      }
      final RSTransform placement = atlas.placement(
        sprite,
        rotation: meadowSwayAngle(animate ? time - plant.swayPhase : 0),
        scale: scale,
      );
      transforms
        ..[i * 4] = placement.scos
        ..[i * 4 + 1] = placement.ssin
        ..[i * 4 + 2] = placement.tx
        ..[i * 4 + 3] = placement.ty;
      rects
        ..[i * 4] = sprite.source.left
        ..[i * 4 + 1] = sprite.source.top
        ..[i * 4 + 2] = sprite.source.right
        ..[i * 4 + 3] = sprite.source.bottom;
      final int alpha = (opacity.clamp(0.0, 1.0) * 255).round();
      colours[i] = alpha << 24 | 0x00FFFFFF;
      faded = faded || alpha < 255;
    }
    canvas.drawRawAtlas(
      atlas.imageOf(sheet)!,
      transforms,
      rects,
      faded ? colours : null,
      faded ? BlendMode.modulate : null,
      null,
      _imagePaint(1),
    );
  }

  double _highlightOpacity(int day) {
    final double target = _rangeOpacity(highlight, day);
    if (!animate) {
      return target;
    }
    final double progress = meadowFade(
      time - highlightSince,
      meadowHighlightSeconds,
    );
    if (progress >= 1) {
      return target;
    }
    final double from = _rangeOpacity(previousHighlight, day);
    return from + (target - from) * progress;
  }

  double _revealOpacity(int day) {
    final double? revealed = reveals[day];
    if (!animate || revealed == null) {
      return 1;
    }
    return meadowFade(time - revealed, meadowRevealSeconds);
  }

  void _paintPocket(
    Canvas canvas,
    MeadowMistPocket pocket,
    _PaletteShaders shaders,
  ) {
    final MeadowWindow? window = heaviest;
    if (window == null || growthPoint <= window.first) {
      return;
    }
    final double opacity = palette.fogP * _revealOpacity(window.first);
    if (opacity <= _faint) {
      return;
    }
    final Rect box = pocket.bounds.shift(
      Offset(
        meadowMistDrift(
          _now,
          period: pocket.period,
          phase: _phase(pocket.phase),
        ),
        0,
      ),
    );
    _drawUnit(
      canvas,
      box: box,
      centre: box.center,
      radii: _farthestCorner(box, box.center),
      paint: Paint()
        ..shader = shaders.pocketFog
        ..color = _opacity(opacity),
    );
  }

  void _paintSpruce(Canvas canvas, MeadowSpruceImage spruce) {
    final int day = spruce.spruce.day;
    if (growthPoint <= day) {
      return;
    }
    final double opacity = _revealOpacity(day);
    if (opacity <= _faint) {
      return;
    }
    final Offset origin = spruce.swayOrigin;
    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..rotate(meadowCrownAngle(_now))
      ..translate(-origin.dx, -origin.dy);
    _drawImage(canvas, spruce.image, _imagePaint(opacity));
    canvas.restore();
  }

  void _paintOverlay(Canvas canvas, _PaletteShaders shaders) {
    if (palette.overlayAlpha <= _faint) {
      return;
    }
    canvas.saveLayer(_world, Paint());
    _drawUnit(
      canvas,
      box: _world,
      centre: palette.overlayCentre,
      radii: meadowOverlayRadii,
      paint: Paint()..shader = shaders.overlay,
    );
    layers.nightMask.apply(canvas);
    canvas.restore();
  }

  void _paintRays(Canvas canvas) {
    if (palette.raysOpacity <= 0) {
      return;
    }
    final ui.Image image = rays.image;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCircle(center: palette.sunPosition, radius: meadowRaysReach),
      _imagePaint(palette.raysOpacity * meadowRaysBreath(_now)),
    );
  }

  void _paintSpot(Canvas canvas) {
    final Offset? at = spot;
    if (at == null) {
      return;
    }
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..drawCircle(Offset.zero, meadowSpotRadius, Paint()..shader = _spotGlow)
      ..restore();
  }

  void _paintVignette(Canvas canvas) {
    _drawUnit(
      canvas,
      box: _world,
      centre: _vignetteCentre,
      radii: _vignetteRadii,
      paint: Paint()..shader = _vignette,
    );
  }

  void _paintCaption(Canvas canvas) {
    final String? text = caption;
    if (mode == MeadowSceneMode.full || text == null || text.isEmpty) {
      return;
    }
    final ui.Paragraph paragraph = _Caption.of(
      layers,
      text,
      palette.captionColour,
    );
    canvas.drawParagraph(
      paragraph,
      Offset(
        _captionLeft,
        meadowWorldHeight - _captionBottom - paragraph.height,
      ),
    );
  }

  @override
  bool shouldRepaint(MeadowStagePainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.animate != animate ||
      oldDelegate.growthPoint != growthPoint ||
      oldDelegate.palette != palette ||
      oldDelegate.viewport.scale != viewport.scale ||
      oldDelegate.viewport.offset != viewport.offset ||
      !identical(oldDelegate.layers, layers) ||
      !identical(oldDelegate.atlas, atlas) ||
      !identical(oldDelegate.creatures, creatures) ||
      !identical(oldDelegate.rays, rays) ||
      !identical(oldDelegate.terrain, terrain) ||
      !identical(oldDelegate.plants, plants) ||
      !identical(oldDelegate.bees, bees) ||
      !identical(oldDelegate.butterflies, butterflies) ||
      !identical(oldDelegate.fireflies, fireflies) ||
      !identical(oldDelegate.reveals, reveals) ||
      oldDelegate.heaviest != heaviest ||
      oldDelegate.growAnimated != growAnimated ||
      oldDelegate.highlight != highlight ||
      oldDelegate.previousHighlight != previousHighlight ||
      oldDelegate.highlightSince != highlightSince ||
      oldDelegate.spot != spot ||
      oldDelegate.mode != mode ||
      oldDelegate.caption != caption;
}

double _rangeOpacity(MeadowRange? range, int day) =>
    range == null || (day >= range.first && day <= range.last)
    ? 1
    : meadowDimmedOpacity;

Color _opacity(double value) => Color.fromRGBO(0, 0, 0, value.clamp(0.0, 1.0));

Paint _imagePaint(double opacity) => Paint()
  ..color = _opacity(opacity)
  ..filterQuality = FilterQuality.low;

void _drawImage(Canvas canvas, MeadowImage image, Paint paint) {
  canvas.drawImageRect(image.image, image.source, image.rect, paint);
}

Offset _pointIn(Rect box, Offset fraction) => Offset(
  box.left + box.width * fraction.dx,
  box.top + box.height * fraction.dy,
);

Size _farthestCorner(Rect box, Offset centre) => Size(
  math.max(centre.dx - box.left, box.right - centre.dx) * math.sqrt2,
  math.max(centre.dy - box.top, box.bottom - centre.dy) * math.sqrt2,
);

void _drawUnit(
  Canvas canvas, {
  required Rect box,
  required Offset centre,
  required Size radii,
  required Paint paint,
}) {
  canvas
    ..save()
    ..translate(centre.dx, centre.dy)
    ..scale(radii.width, radii.height)
    ..drawRect(
      Rect.fromLTRB(
        (box.left - centre.dx) / radii.width,
        (box.top - centre.dy) / radii.height,
        (box.right - centre.dx) / radii.width,
        (box.bottom - centre.dy) / radii.height,
      ),
      paint,
    )
    ..restore();
}

Rect _ovalOf(
  MeadowEllipse ellipse, {
  Offset shift = Offset.zero,
  double scale = 1,
}) => Rect.fromCenter(
  center: ellipse.centre + shift,
  width: ellipse.radiusX * 2 * scale,
  height: ellipse.radiusY * 2 * scale,
);

class _WaterMark {
  const _WaterMark({
    required this.oval,
    required this.opacity,
    required this.glint,
    this.stroke,
  });

  final Rect oval;
  final double opacity;
  final bool glint;
  final double? stroke;
}

Color _clear(Color colour) => colour.withValues(alpha: 0);

Color _faded(Color colour, double alpha) =>
    colour.withValues(alpha: colour.a * alpha);

ui.Gradient _unitFog(Color fog, double stop) => ui.Gradient.radial(
  Offset.zero,
  1,
  <Color>[fog, _clear(fog)],
  <double>[0, stop],
);

final ui.Gradient _milkyWay = ui.Gradient.radial(
  Offset.zero,
  1,
  <Color>[
    _faded(_milkyLight, 0.22),
    _faded(_milkyLight, 0.06),
    _clear(_milkyLight),
  ],
  <double>[0, 0.5, 1],
);

final ui.Gradient _shootingGradient = ui.Gradient.linear(
  _shootingTrail.centerLeft,
  _shootingTrail.centerRight,
  <Color>[_shootingLight, _clear(_shootingLight)],
);

final ui.Gradient _moonDisc = ui.Gradient.radial(
  _moonLightCentre,
  _moonLightReach,
  _moonLight,
  <double>[0, 0.62, 1],
);

final ui.Gradient _spotGlow = ui.Gradient.radial(
  Offset.zero,
  _spotReach,
  <Color>[_spotLight, _clear(_spotLight)],
  <double>[0, 0.7],
);

final ui.Gradient _vignette = ui.Gradient.radial(
  Offset.zero,
  1,
  <Color>[_clear(_vignetteShade), _clear(_vignetteShade), _vignetteShade],
  <double>[0, 0.62, 1],
);

double _normal(double x) {
  final double t = 1 / (1 + 0.3275911 * x.abs() / math.sqrt2);
  final double poly =
      t *
      (0.254829592 +
          t *
              (-0.284496736 +
                  t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
  final double erf = 1 - poly * math.exp(-x * x / 2);
  return x >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
}

class _PaletteShaders {
  _PaletteShaders(this.palette);

  static final Expando<_PaletteShaders> _cache = Expando<_PaletteShaders>();

  static _PaletteShaders of(MeadowPalette palette) =>
      _cache[palette] ??= _PaletteShaders(palette);

  final MeadowPalette palette;

  late final ui.Gradient sky = ui.Gradient.linear(
    Offset.zero,
    const Offset(0, meadowWorldHeight),
    <Color>[
      palette.skyTop,
      palette.skyMiddle,
      palette.skyHorizon,
      palette.skyHorizon,
    ],
    <double>[
      0,
      _skyMiddleRow / meadowWorldHeight,
      _skyHorizonRow / meadowWorldHeight,
      1,
    ],
  );

  late final ui.Gradient warmGlow = ui.Gradient.radial(Offset.zero, 1, <Color>[
    palette.warmGlowColour,
    _clear(palette.warmGlowColour),
  ]);

  late final ui.Gradient sun = ui.Gradient.radial(
    Offset.zero,
    _sunReach,
    <Color>[
      _sunCore,
      _sunCore,
      palette.sunColour.withValues(alpha: 0.62),
      _clear(palette.sunColour),
    ],
    <double>[0, 0.11, 0.22, 0.7],
  );

  late final ui.Gradient moonGlow = _moonGlowGradient(palette.moonGlowColour);

  late final ui.Gradient moonShade = ui.Gradient.radial(
    Offset(palette.moonShadeOffset * _moonRadius * 2 + _moonShadeLift, 0),
    _moonShadeRadius,
    <Color>[
      palette.moonShadeColour,
      palette.moonShadeColour,
      _clear(palette.moonShadeColour),
    ],
    <double>[0, 1 - _moonShadeEdge / _moonShadeRadius, 1],
  );

  late final ui.Gradient pocketFog = _unitFog(palette.fog, _pocketStop);

  late final ui.Gradient lakeFog = _unitFog(palette.fog, 1);

  late final ui.Gradient fallFog = _unitFog(palette.fog, _fallStop);

  late final ui.Gradient overlay = ui.Gradient.radial(Offset.zero, 1, <Color>[
    palette.overlayColour.withValues(alpha: palette.overlayCentreAlpha),
    palette.overlayColour.withValues(alpha: palette.overlayAlpha),
  ]);
}

ui.Gradient _moonGlowGradient(Color colour) {
  final List<double> radii = <double>[
    _moonRadius,
    for (double radius = 20; radius < _moonGlowReach; radius += 4) radius,
    _moonGlowReach,
  ];
  return ui.Gradient.radial(
    Offset.zero,
    _moonGlowReach,
    <Color>[
      _clear(colour),
      _clear(colour),
      for (final double radius in radii)
        _faded(colour, _normal((_moonGlowSpread - radius) / _moonGlowSigma)),
    ],
    <double>[
      0,
      _moonRadius / _moonGlowReach,
      for (final double radius in radii) radius / _moonGlowReach,
    ],
  );
}

class _Caption {
  const _Caption(this.text, this.colour, this.paragraph);

  static final Expando<_Caption> _cache = Expando<_Caption>();

  static ui.Paragraph of(MeadowLayers layers, String text, Color colour) {
    final _Caption? cached = _cache[layers];
    if (cached != null && cached.text == text && cached.colour == colour) {
      return cached.paragraph;
    }
    final ui.ParagraphBuilder builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontFamily: TypographyTokens.accent,
              fontSize: _captionSize,
              fontWeight: FontWeight.w600,
              maxLines: 1,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: colour,
              fontFamily: TypographyTokens.accent,
              fontSize: _captionSize,
              fontWeight: FontWeight.w600,
            ),
          )
          ..addText(text);
    final ui.Paragraph paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: meadowWorldWidth));
    _cache[layers] = _Caption(text, colour, paragraph);
    return paragraph;
  }

  final String text;
  final Color colour;
  final ui.Paragraph paragraph;
}

sealed class _Item {
  const _Item();
}

final class _GrassItem extends _Item {
  const _GrassItem(this.band);

  final MeadowGrassImage band;
}

final class _SlabItem extends _Item {
  const _SlabItem(this.slab);

  final MeadowTreeSlab slab;
}

final class _PlantRun extends _Item {
  const _PlantRun(this.run);

  final List<MeadowPlant> run;
}

final class _MistItem extends _Item {
  const _MistItem(this.pocket);

  final MeadowMistPocket pocket;
}

final class _SpruceItem extends _Item {
  const _SpruceItem(this.spruce);

  final MeadowSpruceImage spruce;
}

class _Order {
  const _Order({
    required this.plants,
    required this.heaviest,
    required this.items,
  });

  static final Expando<_Order> _cache = Expando<_Order>();

  static _Order of(
    MeadowLayers layers,
    MeadowPlants plants,
    MeadowWindow? heaviest,
  ) {
    final _Order? cached = _cache[layers];
    if (cached != null &&
        identical(cached.plants, plants) &&
        cached.heaviest == heaviest) {
      return cached;
    }
    final _Order order = _Order(
      plants: plants,
      heaviest: heaviest,
      items: _sortedItems(layers, plants, heaviest),
    );
    _cache[layers] = order;
    return order;
  }

  final MeadowPlants plants;
  final MeadowWindow? heaviest;
  final List<_Item> items;
}

List<_Item> _sortedItems(
  MeadowLayers layers,
  MeadowPlants plants,
  MeadowWindow? heaviest,
) {
  final List<(double, Object)> keyed = <(double, Object)>[
    for (final MeadowGrassImage band in layers.grass) (band.sortKey, band),
    for (final MeadowTreeSlab slab in layers.trees) (slab.sortKey, slab),
    for (final MeadowPlant plant in plants.plants)
      if (!plant.hidden) (plant.y, plant),
    if (_pocketKey(plants, heaviest) case final double key)
      for (final MeadowMistPocket pocket in plants.pockets) (key, pocket),
    if (layers.spruce case final MeadowSpruceImage spruce)
      (spruce.sortKey, spruce),
  ];
  final List<int> order = List<int>.generate(keyed.length, (int i) => i)
    ..sort((int a, int b) {
      final int byKey = keyed[a].$1.compareTo(keyed[b].$1);
      return byKey != 0 ? byKey : a.compareTo(b);
    });
  final List<_Item> items = <_Item>[];
  List<MeadowPlant> run = <MeadowPlant>[];
  for (final int index in order) {
    final Object entry = keyed[index].$2;
    if (entry is MeadowPlant) {
      run.add(entry);
      continue;
    }
    if (run.isNotEmpty) {
      items.add(_PlantRun(List<MeadowPlant>.unmodifiable(run)));
      run = <MeadowPlant>[];
    }
    items.add(switch (entry) {
      final MeadowGrassImage band => _GrassItem(band),
      final MeadowTreeSlab slab => _SlabItem(slab),
      final MeadowMistPocket pocket => _MistItem(pocket),
      final MeadowSpruceImage spruce => _SpruceItem(spruce),
      _ => throw StateError('Unknown meadow item $entry'),
    });
  }
  if (run.isNotEmpty) {
    items.add(_PlantRun(List<MeadowPlant>.unmodifiable(run)));
  }
  return List<_Item>.unmodifiable(items);
}

double? _pocketKey(MeadowPlants plants, MeadowWindow? heaviest) {
  if (heaviest == null || plants.pockets.isEmpty) {
    return null;
  }
  final List<double> rows = <double>[
    for (final MeadowPlant plant in plants.plants)
      if (plant.dayIndex >= heaviest.first && plant.dayIndex <= heaviest.last)
        plant.y,
  ];
  if (rows.isEmpty) {
    return null;
  }
  return rows.reduce((double a, double b) => a + b) / rows.length + 8;
}
