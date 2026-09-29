import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'package:field_notes/design/flowers/garden_art_colors.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';

import '../model/garden_insect.dart';
import '../model/meadow_layout.dart';
import 'meadow_sprites.dart';

const int skyStarCount = 34;
const double skyStarBand = 0.34;
const double meadowHorizon = 0.29;

const int _starSeedSalt = 771;

class SkyStar {
  const SkyStar({
    required this.x,
    required this.y,
    required this.size,
    required this.period,
    required this.phase,
  });

  final double x;
  final double y;
  final double size;
  final double period;
  final double phase;
}

double _between(math.Random rng, double from, double to) =>
    from + rng.nextDouble() * (to - from);

List<SkyStar> skyStarsFor(int seed) {
  final math.Random rng = math.Random(seed + _starSeedSalt);
  return List<SkyStar>.unmodifiable(<SkyStar>[
    for (int i = 0; i < skyStarCount; i++)
      SkyStar(
        x: rng.nextDouble(),
        y: rng.nextDouble() * 0.9,
        size: _between(rng, 0.8, 2.6),
        period: _between(rng, 2, 5),
        phase: _between(rng, 0, 3),
      ),
  ]);
}

Color _faded(Color colour, double opacity) =>
    colour.withValues(alpha: colour.a * opacity.clamp(0.0, 1.0));

class MeadowPainter extends CustomPainter {
  const MeadowPainter({
    required this.layout,
    required this.sprites,
    required this.sky,
    required this.compact,
    required this.stars,
    required this.fireflies,
    required this.insects,
    required this.animate,
    this.clock,
  }) : super(repaint: clock);

  final MeadowLayout layout;
  final MeadowSprites sprites;
  final SkyScene sky;
  final bool compact;
  final List<SkyStar> stars;
  final List<GardenFirefly> fireflies;
  final List<GardenInsect> insects;
  final bool animate;
  final ValueListenable<Duration>? clock;

  double get elapsedSeconds {
    final Duration? elapsed = clock?.value;
    return animate && elapsed != null ? elapsed.inMicroseconds / 1e6 : 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final double seconds = elapsedSeconds;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _paintSky(canvas, size);
    _paintStars(canvas, size, seconds);
    _paintSun(canvas, size);
    _paintMoon(canvas, size);
    _paintGround(canvas, size);
    _paintHaze(canvas, size);
    _paintSoil(canvas, size);
    _paintMeadow(canvas, size, seconds);
    _paintNight(canvas, size);
    if (animate) {
      _paintFireflies(canvas, size, seconds);
      _paintInsects(canvas, size, seconds);
    }
    canvas.restore();
  }

  void _fillEllipse(
    Canvas canvas, {
    required Rect area,
    required Offset centre,
    required double radiusX,
    required double radiusY,
    required List<Color> colours,
    required List<double> stops,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    if (radiusX <= 0 || radiusY <= 0) {
      return;
    }
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(radiusX, radiusY);
    canvas.drawRect(
      Rect.fromLTRB(
        (area.left - centre.dx) / radiusX,
        (area.top - centre.dy) / radiusY,
        (area.right - centre.dx) / radiusX,
        (area.bottom - centre.dy) / radiusY,
      ),
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 1, colours, stops)
        ..blendMode = blendMode,
    );
    canvas.restore();
  }

  void _paintSky(Canvas canvas, Size size) {
    final Rect card = Offset.zero & size;
    canvas.drawRect(card, Paint()..color = GardenArtColors.meadowPaper);
    canvas.drawRect(
      card,
      Paint()
        ..shader = ui.Gradient.linear(
          card.topCenter,
          card.bottomCenter,
          <Color>[sky.skyTop, sky.skyMiddle, sky.skyHorizon, sky.skyHorizon],
          const <double>[0, 0.18, 0.31, 1],
        ),
    );
    if (sky.warmGlow.a <= 0) {
      return;
    }
    _fillEllipse(
      canvas,
      area: card,
      centre: Offset(sky.warmGlowX * size.width, sky.warmGlowY * size.height),
      radiusX: size.width * 0.6,
      radiusY: size.height * 0.34,
      colours: <Color>[sky.warmGlow, sky.warmGlow.withValues(alpha: 0)],
      stops: const <double>[0, 1],
    );
  }

  void _paintStars(Canvas canvas, Size size, double seconds) {
    if (sky.starsOpacity <= 0) {
      return;
    }
    final double band = size.height * skyStarBand;
    for (final SkyStar star in stars) {
      final double opacity =
          sky.starsOpacity *
          (animate ? glowPulse(seconds + star.phase, star.period) : 1);
      final double radius = star.size / 2;
      final Offset centre = Offset(
        star.x * size.width + radius,
        star.y * band + radius,
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = _faded(GardenArtColors.starGlow, opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = _faded(GardenArtColors.star, opacity),
      );
    }
  }

  void _paintSun(Canvas canvas, Size size) {
    final double diameter = compact ? 56 : 92;
    final Offset centre = Offset(sky.sunX * size.width, sky.sunY * size.height);
    canvas.drawCircle(
      centre,
      diameter / 2,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          diameter / math.sqrt2,
          <Color>[
            GardenArtColors.sunCore,
            GardenArtColors.sunCore,
            sky.sunColour.withValues(alpha: 0.62),
            sky.sunColour.withValues(alpha: 0),
          ],
          const <double>[0, 0.11, 0.22, 0.7],
        ),
    );
  }

  void _paintMoon(Canvas canvas, Size size) {
    if (sky.moonOpacity <= 0) {
      return;
    }
    final double diameter = compact ? 20 : 32;
    final double radius = diameter / 2;
    final Offset centre = Offset(
      sky.moonX * size.width,
      sky.moonY * size.height,
    );
    final double glowRadius = radius + diameter * 0.3;
    final double glowSigma = diameter * 0.45;
    canvas.saveLayer(
      Rect.fromCircle(center: centre, radius: glowRadius + glowSigma * 3),
      Paint()..color = Color.fromRGBO(0, 0, 0, sky.moonOpacity),
    );
    canvas.drawCircle(
      centre,
      glowRadius,
      Paint()
        ..color = GardenArtColors.moonGlow.withValues(alpha: sky.moonGlowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma),
    );
    final Rect disc = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawOval(
      disc,
      Paint()
        ..shader = ui.Gradient.radial(
          disc.topLeft + Offset(diameter * 0.38, diameter * 0.36),
          diameter * math.sqrt(0.62 * 0.62 + 0.64 * 0.64),
          const <Color>[
            GardenArtColors.moonLight,
            GardenArtColors.moonMid,
            GardenArtColors.moonEdge,
          ],
          const <double>[0, 0.62, 1],
        ),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(disc));
    canvas.drawCircle(
      centre.translate(sky.moonShadeOffset * diameter + diameter * 0.02, 0),
      diameter * 0.52,
      Paint()..color = sky.skyTop.withValues(alpha: 0.94),
    );
    canvas.restore();
    canvas.restore();
  }

  void _paintGround(Canvas canvas, Size size) {
    final Rect ground = Rect.fromLTRB(
      0,
      size.height * meadowHorizon,
      size.width,
      size.height,
    );
    canvas.drawRect(
      ground,
      Paint()
        ..shader = ui.Gradient.linear(
          ground.topCenter,
          ground.bottomCenter,
          compact
              ? const <Color>[
                  GardenArtColors.meadowPaperClear,
                  GardenArtColors.meadowPaper,
                  Palette.gardenSky,
                  Palette.gardenMint,
                  Palette.gardenLeaf,
                  GardenArtColors.meadowDeepCompact,
                ]
              : const <Color>[
                  GardenArtColors.meadowPaperClear,
                  GardenArtColors.meadowPaper,
                  Palette.gardenSky,
                  Palette.gardenMint,
                  Palette.gardenLeaf,
                  Palette.gardenStem,
                  Palette.gardenDeep,
                ],
          compact
              ? const <double>[0, 0.06, 0.16, 0.38, 0.63, 1]
              : const <double>[0, 0.06, 0.14, 0.34, 0.57, 0.8, 1],
        ),
    );
  }

  void _paintHaze(Canvas canvas, Size size) {
    if (sky.hazeOpacity <= 0) {
      return;
    }
    final double top = size.height * 0.26;
    final Rect haze = Rect.fromLTRB(
      0,
      top,
      size.width,
      top + (compact ? 64 : 96),
    );
    canvas.drawRect(
      haze,
      Paint()
        ..shader = ui.Gradient.linear(
          haze.topCenter,
          haze.bottomCenter,
          <Color>[
            _faded(GardenArtColors.haze, sky.hazeOpacity),
            GardenArtColors.hazeClear,
          ],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, compact ? 3 : 4),
    );
  }

  void _paintSoil(Canvas canvas, Size size) {
    final Rect soil = Rect.fromLTRB(
      0,
      size.height - (compact ? 40 : 58),
      size.width,
      size.height,
    );
    canvas.drawRect(
      soil,
      Paint()
        ..shader = ui.Gradient.linear(
          soil.topCenter,
          soil.bottomCenter,
          const <Color>[
            GardenArtColors.soilClear,
            Palette.soilLight,
            Palette.soilDark,
          ],
          <double>[0, compact ? 0.5 : 0.46, 1],
        ),
    );
    if (compact) {
      return;
    }
    const double shadeHeight = 26;
    final Rect shade = Rect.fromLTRB(
      0,
      size.height - shadeHeight,
      size.width,
      size.height,
    );
    _fillEllipse(
      canvas,
      area: shade,
      centre: Offset(size.width / 2, shade.top + shadeHeight * 1.2),
      radiusX: size.width * 1.2,
      radiusY: shadeHeight * 1.4,
      colours: const <Color>[
        GardenArtColors.soilShade,
        GardenArtColors.soilShadeClear,
      ],
      stops: const <double>[0, 0.72],
    );
  }

  void _paintMeadow(Canvas canvas, Size size, double seconds) {
    final ui.Image? sheet = sprites.image;
    if (sheet == null) {
      return;
    }
    for (final (int index, MeadowBand band) in layout.bands.indexed) {
      final bool blurred = band.blur > 0.05;
      final bool layered = blurred || band.opacity < 0.999;
      if (layered) {
        canvas.saveLayer(
          band.bounds,
          Paint()
            ..color = Color.fromRGBO(0, 0, 0, band.opacity)
            ..imageFilter = blurred
                ? ui.ImageFilter.blur(
                    sigmaX: band.blur,
                    sigmaY: band.blur,
                    tileMode: TileMode.decal,
                  )
                : null,
        );
      }
      _paintBand(canvas, size, sheet, index, band, seconds);
      if (layered) {
        canvas.restore();
      }
    }
  }

  void _paintBand(
    Canvas canvas,
    Size size,
    ui.Image sheet,
    int index,
    MeadowBand band,
    double seconds,
  ) {
    final List<(MeadowItem, MeadowSpriteCell)> placed =
        <(MeadowItem, MeadowSpriteCell)>[
          for (final MeadowItem item in band.items)
            if (sprites.cellFor(index, meadowArtFor(item))
                case final MeadowSpriteCell cell)
              (item, cell),
        ];
    if (placed.isEmpty) {
      return;
    }
    canvas.drawAtlas(
      sheet,
      <RSTransform>[
        for (final (MeadowItem item, MeadowSpriteCell cell) in placed)
          _placement(item, cell, size, seconds),
      ],
      <Rect>[
        for (final (MeadowItem _, MeadowSpriteCell cell) in placed) cell.source,
      ],
      null,
      null,
      null,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  RSTransform _placement(
    MeadowItem item,
    MeadowSpriteCell cell,
    Size size,
    double seconds,
  ) {
    final double sway = animate
        ? -item.swayDegrees *
              math.cos(
                2 * math.pi * (seconds + item.swayPhase) / item.swayPeriod,
              )
        : 0;
    return RSTransform.fromComponents(
      rotation: sway * math.pi / 180,
      scale: item.width / cell.spriteWidth,
      anchorX: cell.pad + cell.spriteWidth / 2,
      anchorY: cell.pad + cell.spriteWidth * item.height / item.width,
      translateX: item.dx,
      translateY: size.height - item.bottom,
    );
  }

  void _paintNight(Canvas canvas, Size size) {
    final Color? tint = sky.warmTint;
    if (sky.moonPoolAlpha <= 0 && sky.nightEdgeAlpha <= 0 && tint == null) {
      return;
    }
    final Rect area = Rect.fromLTRB(
      0,
      size.height * meadowHorizon,
      size.width,
      size.height,
    );
    final Offset centre = Offset(
      sky.moonX * size.width,
      area.top - area.height * 0.25,
    );
    if (tint != null) {
      canvas.saveLayer(area, Paint()..blendMode = BlendMode.multiply);
    }
    _fillEllipse(
      canvas,
      area: area,
      centre: centre,
      radiusX: size.width * 0.75,
      radiusY: area.height * 1.3,
      colours: <Color>[sky.moonPool, sky.nightEdge],
      stops: const <double>[0, 0.8],
      blendMode: tint == null ? BlendMode.multiply : BlendMode.srcOver,
    );
    if (tint != null) {
      canvas.drawRect(area, Paint()..color = tint);
      canvas.restore();
    }
  }

  void _paintFireflies(Canvas canvas, Size size, double seconds) {
    if (sky.firefliesOpacity <= 0) {
      return;
    }
    for (final GardenFirefly firefly in fireflies) {
      final double opacity = sky.firefliesOpacity * firefly.glowAt(seconds);
      final Offset centre =
          Offset(
            firefly.anchor.dx * size.width + 2,
            firefly.anchor.dy * size.height + 2,
          ) +
          firefly.driftAt(seconds);
      canvas.drawCircle(
        centre,
        4,
        Paint()
          ..color = _faded(GardenArtColors.fireflyGlow, opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        centre,
        2,
        Paint()..color = _faded(GardenArtColors.firefly, opacity),
      );
    }
  }

  void _paintInsects(Canvas canvas, Size size, double seconds) {
    final double opacity = sky.dayLifeOpacity;
    if (opacity <= 0 || insects.isEmpty) {
      return;
    }
    final bool layered = opacity < 0.999;
    if (layered) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }
    final double spread = wingSpreadAt(seconds);
    for (final GardenInsect insect in insects) {
      final FlightPose pose = insect.poseAt(seconds);
      final double half = insect.size / 2;
      canvas.save();
      canvas.translate(
        insect.anchor.dx * size.width + half + pose.offset.dx,
        insect.anchor.dy * size.height + half + pose.offset.dy,
      );
      canvas.rotate(pose.turnDegrees * math.pi / 180);
      canvas.translate(-half, -half);
      canvas.scale(insect.size / 24);
      switch (insect.kind) {
        case GardenInsectKind.butterfly:
          _paintButterfly(canvas, insect, spread);
        case GardenInsectKind.bee:
          _paintBee(canvas, spread);
      }
      canvas.restore();
    }
    if (layered) {
      canvas.restore();
    }
  }

  Rect _wing(
    double cx,
    double cy,
    double rx,
    double ry,
    double hinge,
    double spread,
  ) => Rect.fromCenter(
    center: Offset(hinge + (cx - hinge) * spread, cy),
    width: rx * 2 * spread,
    height: ry * 2,
  );

  void _paintButterfly(Canvas canvas, GardenInsect insect, double spread) {
    final Paint fore = Paint()..color = insect.wing;
    final Paint hind = Paint()..color = insect.hindWing;
    canvas.drawOval(_wing(7, 9, 6, 7.5, 13, spread), fore);
    canvas.drawOval(_wing(9, 16, 4.4, 5.4, 13.4, spread), hind);
    canvas.drawOval(_wing(17, 9, 6, 7.5, 11, spread), fore);
    canvas.drawOval(_wing(15, 16, 4.4, 5.4, 10.6, spread), hind);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 11.5), width: 2.6, height: 12),
      Paint()..color = GardenArtColors.insectBody,
    );
  }

  void _paintBee(Canvas canvas, double spread) {
    final Paint wing = Paint()..color = GardenArtColors.beeWing;
    canvas.drawOval(_wing(8, 9, 4.2, 5, 12.2, spread), wing);
    canvas.drawOval(_wing(16, 9, 4.2, 5, 11.8, spread), wing);
    final Rect body = Rect.fromCenter(
      center: const Offset(12, 14),
      width: 12,
      height: 9.2,
    );
    canvas.drawOval(body, Paint()..color = GardenArtColors.beeBody);
    final Paint stroke = Paint()
      ..color = GardenArtColors.beeStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawOval(body, stroke);
    final Paint stripe = Paint()
      ..color = GardenArtColors.beeStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(10, 10.2), const Offset(10, 17.8), stripe);
    canvas.drawLine(const Offset(13, 9.7), const Offset(13, 18.3), stripe);
  }

  @override
  bool shouldRepaint(covariant MeadowPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.sprites != sprites ||
      oldDelegate.sky != sky ||
      oldDelegate.compact != compact ||
      oldDelegate.stars != stars ||
      oldDelegate.fireflies != fireflies ||
      oldDelegate.insects != insects ||
      oldDelegate.animate != animate ||
      oldDelegate.clock != clock;
}
