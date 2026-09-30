import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/bloom_part_painter.dart';
import 'package:field_notes/design/flowers/flower_palette.dart';
import 'package:field_notes/design/flowers/garden_plant_geometry.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';

const Rect meadowPlantBox = Rect.fromLTRB(-100, -290, 100, 2);

const List<Color> _leafGreens = <Color>[
  FlowerColors.gardenLeafDeep,
  FlowerColors.gardenLeafBright,
  FlowerColors.gardenLeafPale,
  FlowerColors.gardenLeafDusk,
  Color(0xFF88A55A),
];
const Color _calmLeafPale = Color(0xFF9FB07A);
const Color _clear = Color(0x00000000);
const double _veinOpacity = 0.8;
const double _degrees = math.pi / 180;
const double _turn = math.pi * 2;

const Map<FlowerKind, (Offset, Offset)> _headAnchors =
    <FlowerKind, (Offset, Offset)>{
      FlowerKind.peony: (Offset(50, 92), Offset(50, 78)),
      FlowerKind.sunflower: (Offset(50, 84), Offset(50, 56)),
      FlowerKind.rose: (Offset(50, 98), Offset(50, 74)),
      FlowerKind.daffodil: (Offset(50, 66), Offset(50, 60)),
      FlowerKind.chrysanthemum: (Offset(50, 88), Offset(50, 64)),
      FlowerKind.redSpiderLily: (Offset(50, 64), Offset(50, 58)),
      FlowerKind.poppy: (Offset(50, 72), Offset(50, 62)),
    };

class MeadowColourShift {
  const MeadowColourShift({
    this.hue = 0,
    this.saturation = 0,
    this.lightness = 0,
  });

  static const MeadowColourShift none = MeadowColourShift();

  final double hue;
  final double saturation;
  final double lightness;

  bool get isNone => hue == 0 && saturation == 0 && lightness == 0;

  Color apply(Color colour) {
    if (isNone) {
      return colour;
    }
    final double r = colour.r;
    final double g = colour.g;
    final double b = colour.b;
    final double high = math.max(r, math.max(g, b));
    final double low = math.min(r, math.min(g, b));
    double h = 0;
    double s = 0;
    final double l = (high + low) / 2;
    if (high != low) {
      final double d = high - low;
      s = l > 0.5 ? d / (2 - high - low) : d / (high + low);
      h = high == r
          ? (g - b) / d + (g < b ? 6 : 0)
          : high == g
          ? (b - r) / d + 2
          : (r - g) / d + 4;
      h /= 6;
    }
    final double hue = (h + this.hue / 360 + 1) % 1;
    final double sat = (s + saturation).clamp(0.0, 1.0);
    final double light = (l + lightness).clamp(0.0, 1.0);
    final double q = light < 0.5
        ? light * (1 + sat)
        : light + sat - light * sat;
    final double p = 2 * light - q;
    double channel(double x) {
      final double t = (x + 1) % 1;
      if (t < 1 / 6) {
        return p + (q - p) * 6 * t;
      }
      if (t < 0.5) {
        return q;
      }
      if (t < 2 / 3) {
        return p + (q - p) * (2 / 3 - t) * 6;
      }
      return p;
    }

    int byte(double v) => (v * 255).round();
    return sat == 0
        ? Color.fromARGB(byte(colour.a), byte(light), byte(light), byte(light))
        : Color.fromARGB(
            byte(colour.a),
            byte(channel(hue + 1 / 3)),
            byte(channel(hue)),
            byte(channel(hue - 1 / 3)),
          );
  }

  @override
  bool operator ==(Object other) =>
      other is MeadowColourShift &&
      other.hue == hue &&
      other.saturation == saturation &&
      other.lightness == lightness;

  @override
  int get hashCode => Object.hash(hue, saturation, lightness);

  @override
  String toString() =>
      'MeadowColourShift(hue: $hue, saturation: $saturation, '
      'lightness: $lightness)';
}

class MeadowPlantTransform {
  const MeadowPlantTransform({
    this.translation = Offset.zero,
    this.rotation = 0,
    this.scale = 1,
    this.anchor = Offset.zero,
  });

  static const MeadowPlantTransform identity = MeadowPlantTransform();

  final Offset translation;
  final double rotation;
  final double scale;
  final Offset anchor;

  bool get isIdentity =>
      translation == Offset.zero &&
      rotation == 0 &&
      scale == 1 &&
      anchor == Offset.zero;

  Offset apply(Offset point) {
    final double x = (point.dx - anchor.dx) * scale;
    final double y = (point.dy - anchor.dy) * scale;
    final double c = math.cos(rotation * _degrees);
    final double s = math.sin(rotation * _degrees);
    return Offset(
      translation.dx + x * c - y * s,
      translation.dy + x * s + y * c,
    );
  }

  void applyTo(Canvas canvas) {
    canvas.translate(translation.dx, translation.dy);
    if (rotation != 0) {
      canvas.rotate(rotation * _degrees);
    }
    if (scale != 1) {
      canvas.scale(scale);
    }
    if (anchor != Offset.zero) {
      canvas.translate(-anchor.dx, -anchor.dy);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is MeadowPlantTransform &&
      other.translation == translation &&
      other.rotation == rotation &&
      other.scale == scale &&
      other.anchor == anchor;

  @override
  int get hashCode => Object.hash(translation, rotation, scale, anchor);
}

sealed class MeadowPlantLayer {
  const MeadowPlantLayer(this.transform);

  final MeadowPlantTransform transform;
}

final class MeadowPlantShape extends MeadowPlantLayer {
  const MeadowPlantShape(
    this.part, [
    super.transform = MeadowPlantTransform.identity,
  ]);

  final BloomPart part;
}

final class MeadowHeadPlacement extends MeadowPlantLayer {
  const MeadowHeadPlacement({
    required this.kind,
    required this.parts,
    required MeadowPlantTransform transform,
  }) : super(transform);

  final FlowerKind kind;
  final List<BloomPart> parts;

  double get scale => transform.scale;
}

class MeadowPlantArt {
  const MeadowPlantArt({
    required this.layers,
    required this.heads,
    required this.shift,
    required this.nodDegrees,
    required this.bounds,
  });

  final List<MeadowPlantLayer> layers;
  final List<Offset> heads;
  final MeadowColourShift shift;
  final double nodDegrees;
  final Rect bounds;

  List<MeadowPlantShape> get shapes =>
      List<MeadowPlantShape>.unmodifiable(layers.whereType<MeadowPlantShape>());

  List<MeadowHeadPlacement> get placements =>
      List<MeadowHeadPlacement>.unmodifiable(
        layers.whereType<MeadowHeadPlacement>(),
      );
}

MeadowPlantArt buildMeadowPlantArt({
  required Mood? mood,
  required int entries,
  required double valence,
  required MeadowRandom random,
  double driftHue = 0,
  double driftLightness = 0,
}) {
  final double height =
      (0.9 + 0.07 * math.min(entries, 3)) * random.between(0.94, 1.06);
  final double hue = driftHue + random.between(-3, 3);
  final double saturation = random.between(-0.05, 0.03);
  final double lightness = driftLightness + random.between(-0.02, 0.02);
  final _Grower grower = _Grower.start(
    random,
    shift: MeadowColourShift(
      hue: hue,
      saturation: saturation,
      lightness: lightness,
    ),
    height: height,
    entries: entries,
    heavy: valence < 0,
  );
  final _Growth growth = switch (mood) {
    Mood.happy => grower.happy(),
    Mood.warm => grower.warm(),
    Mood.love => grower.love(),
    Mood.grateful => grower.grateful(),
    Mood.hopeful => grower.hopeful(),
    Mood.anxious => grower.anxious(),
    Mood.tired => grower.tired(),
    Mood.sad => grower.sad(),
    Mood.angry => grower.angry(),
    Mood.calm => grower.calm(),
    null => grower.sprout(),
  };
  final List<MeadowPlantLayer> layers = List<MeadowPlantLayer>.unmodifiable(
    growth.layers,
  );
  return MeadowPlantArt(
    layers: layers,
    heads: List<Offset>.unmodifiable(growth.heads),
    shift: grower.shift,
    nodDegrees: grower.nod,
    bounds: _artBounds(layers),
  );
}

void paintMeadowPlantArt(Canvas canvas, MeadowPlantArt art) {
  final Color Function(Color)? recolour = art.shift.isNone
      ? null
      : art.shift.apply;
  canvas.save();
  canvas.clipRect(meadowPlantBox);
  for (final MeadowPlantLayer layer in art.layers) {
    final bool moved = !layer.transform.isIdentity;
    if (moved) {
      canvas.save();
      layer.transform.applyTo(canvas);
    }
    switch (layer) {
      case MeadowPlantShape():
        _shapePainter.paintOne(canvas, layer.part);
      case MeadowHeadPlacement():
        final GardenPlantSpec spec = gardenPlantSpecFor(layer.kind);
        BloomPartPainter(
          strokeColor: spec.strokeColor,
          strokeWidth: spec.strokeWidth,
          recolour: recolour,
        ).paintAll(canvas, layer.parts);
    }
    if (moved) {
      canvas.restore();
    }
  }
  canvas.restore();
}

const BloomPartPainter _shapePainter = BloomPartPainter(
  strokeColor: _clear,
  strokeWidth: 0,
);

enum _LeafKind { strap, lobed, broad }

typedef _Growth = ({List<MeadowPlantLayer> layers, List<Offset> heads});

typedef _Head = (MeadowHeadPlacement, Offset);

Offset _rotated(Offset v, double degrees) {
  final double c = math.cos(degrees * _degrees);
  final double s = math.sin(degrees * _degrees);
  return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
}

final class _Stem {
  _Stem(double height, double lean, double curve)
    : control1 = Offset(curve, -height * 0.38),
      control2 = Offset(lean * 0.6 - curve * 0.4, -height * 0.74),
      tip = Offset(lean, -height);

  final Offset control1;
  final Offset control2;
  final Offset tip;

  Offset at(double t) {
    final double u = 1 - t;
    final double a = 3 * u * u * t;
    final double b = 3 * u * t * t;
    final double c = t * t * t;
    return Offset(
      a * control1.dx + b * control2.dx + c * tip.dx,
      a * control1.dy + b * control2.dy + c * tip.dy,
    );
  }

  double angle(double t) {
    final double u = 1 - t;
    final double dx =
        3 * u * u * control1.dx +
        6 * u * t * (control2.dx - control1.dx) +
        3 * t * t * (tip.dx - control2.dx);
    final double dy =
        3 * u * u * control1.dy +
        6 * u * t * (control2.dy - control1.dy) +
        3 * t * t * (tip.dy - control2.dy);
    return math.atan2(dx, -dy) / _degrees;
  }

  List<BloomCmd> get commands => <BloomCmd>[
    const BloomMoveTo(0, 0),
    BloomCubicTo(
      control1.dx,
      control1.dy,
      control2.dx,
      control2.dy,
      tip.dx,
      tip.dy,
    ),
  ];
}

final class _Grower {
  const _Grower._({
    required this.random,
    required this.shift,
    required this.height,
    required this.entries,
    required this.stemColour,
    required this.lean,
    required this.side,
    required this.nod,
  });

  factory _Grower.start(
    MeadowRandom random, {
    required MeadowColourShift shift,
    required double height,
    required int entries,
    required bool heavy,
  }) {
    final Color stemBase = random.next() < 0.5
        ? FlowerColors.gardenStemDeep
        : FlowerColors.gardenStemMid;
    final Color stemColour = MeadowColourShift(
      lightness: random.between(-0.025, 0.025),
    ).apply(stemBase);
    final double lean = random.between(-1, 1);
    final int side = lean >= 0 ? 1 : -1;
    final double nod = heavy ? side * random.between(5, 13) : 0;
    return _Grower._(
      random: random,
      shift: shift,
      height: height,
      entries: entries,
      stemColour: stemColour,
      lean: lean,
      side: side,
      nod: nod,
    );
  }

  final MeadowRandom random;
  final MeadowColourShift shift;
  final double height;
  final int entries;
  final Color stemColour;
  final double lean;
  final int side;
  final double nod;

  bool get secondBloom => entries >= 3;

  double rr(double a, double b) => random.between(a, b);

  Color leafGreen() {
    final Color base = _leafGreens[random.nextInt(_leafGreens.length)];
    return MeadowColourShift(
      hue: shift.hue * 0.25,
      lightness: rr(-0.03, 0.03),
    ).apply(base);
  }

  MeadowPlantShape line(
    List<BloomCmd> commands,
    double width, [
    Color? colour,
  ]) => MeadowPlantShape(
    BloomShape(
      commands: commands,
      strokeColor: colour ?? stemColour,
      strokeWidth: width,
    ),
  );

  MeadowPlantShape branch(Offset from, Offset tip, double width) =>
      line(<BloomCmd>[
        BloomMoveTo(from.dx, from.dy),
        BloomQuadTo(
          (from.dx + tip.dx) / 2,
          tip.dy + (from.dy - tip.dy) * 0.2,
          tip.dx,
          tip.dy,
        ),
      ], width);

  List<MeadowPlantShape> leaf(
    Offset at,
    double angle,
    double length,
    double width,
    _LeafKind kind, {
    double petiole = 0,
    Color? fill,
  }) {
    final Color body = fill ?? leafGreen();
    final MeadowPlantTransform blade = MeadowPlantTransform(
      translation: at,
      rotation: angle,
      anchor: Offset(0, petiole),
    );
    return <MeadowPlantShape>[
      if (petiole > 0)
        MeadowPlantShape(
          BloomShape(
            commands: <BloomCmd>[
              const BloomMoveTo(0, 0),
              BloomLineTo(0, -petiole),
            ],
            strokeColor: stemColour,
            strokeWidth: 2,
          ),
          MeadowPlantTransform(translation: at, rotation: angle),
        ),
      MeadowPlantShape(
        BloomShape(
          commands: _leafOutline(length, width, kind),
          close: true,
          fill: body,
          strokeColor: FlowerColors.gardenLeafStroke,
          strokeWidth: 1.7,
        ),
        blade,
      ),
      MeadowPlantShape(
        BloomShape(
          commands: <BloomCmd>[
            const BloomMoveTo(0, -1),
            BloomQuadTo(
              width * 0.1,
              -length * 0.5,
              kind == _LeafKind.strap ? width * 1.3 : 0,
              -length * 0.9,
            ),
          ],
          strokeColor: FlowerColors.gardenLeafStroke.withValues(
            alpha: _veinOpacity,
          ),
          strokeWidth: 1,
        ),
        blade,
      ),
    ];
  }

  _Head head(FlowerKind kind, Offset tip, double angle, [double scale = 1]) {
    final (Offset anchor, Offset centre) = _headAnchors[kind]!;
    final MeadowPlantTransform transform = MeadowPlantTransform(
      translation: tip,
      rotation: angle,
      scale: scale,
      anchor: anchor,
    );
    return (
      MeadowHeadPlacement(
        kind: kind,
        parts: gardenBloomHeadParts(kind),
        transform: transform,
      ),
      transform.apply(centre),
    );
  }

  _Head daisy(Offset centre, double petalLength, double discRadius) => (
    MeadowHeadPlacement(
      kind: FlowerKind.aster,
      parts: asterDaisy(0, 0, petalLength, discRadius),
      transform: MeadowPlantTransform(translation: centre),
    ),
    centre,
  );

  _Growth withSecond(
    List<MeadowPlantLayer> layers,
    List<Offset> heads,
    FlowerKind kind,
    _Stem stem, {
    required (double, double) at,
    required (double, double) reach,
    required (double, double) rise,
    required double width,
    required (double, double) tilt,
    required double scale,
  }) {
    if (!secondBloom) {
      return (layers: layers, heads: heads);
    }
    final Offset from = stem.at(rr(at.$1, at.$2));
    final int turn = -side;
    final double dx = turn * rr(reach.$1, reach.$2);
    final Offset tip = Offset(from.dx + dx, from.dy - rr(rise.$1, rise.$2));
    final (MeadowHeadPlacement bloom, Offset centre) = head(
      kind,
      tip,
      turn * rr(tilt.$1, tilt.$2),
      scale,
    );
    return (
      layers: <MeadowPlantLayer>[...layers, branch(from, tip, width), bloom],
      heads: <Offset>[...heads, centre],
    );
  }

  _Growth finishWith(
    _Growth growth,
    FlowerKind kind,
    _Stem stem,
    double angle,
  ) {
    final (MeadowHeadPlacement bloom, Offset centre) = head(
      kind,
      stem.tip,
      angle,
    );
    return (
      layers: <MeadowPlantLayer>[...growth.layers, bloom],
      heads: <Offset>[...growth.heads, centre],
    );
  }

  _Growth happy() {
    final double h = rr(86, 116) * height;
    final _Stem stem = _Stem(h, lean * 16, rr(-10, 10));
    final int count = 2 + (random.next() < 0.5 ? 1 : 0);
    final List<MeadowPlantLayer> layers = <MeadowPlantLayer>[
      line(stem.commands, 4.4),
    ];
    for (int i = 0; i < count; i++) {
      final double t = rr(0.16, 0.55);
      final Offset at = stem.at(t);
      final int turn = (i.isOdd ? 1 : -1) * side;
      final double angle = stem.angle(t) + turn * rr(55, 80);
      final double length = rr(28, 40);
      final double width = rr(11, 15);
      layers.addAll(leaf(at, angle, length, width, _LeafKind.lobed));
    }
    final _Growth growth = withSecond(
      layers,
      <Offset>[],
      FlowerKind.peony,
      stem,
      at: (0.45, 0.6),
      reach: (20, 28),
      rise: (26, 36),
      width: 2.6,
      tilt: (14, 26),
      scale: 0.55,
    );
    return finishWith(
      growth,
      FlowerKind.peony,
      stem,
      stem.angle(1) * 0.6 + rr(-7, 7) + nod,
    );
  }

  _Growth warm() {
    final double h = rr(128, 170) * height;
    final _Stem stem = _Stem(h, lean * 10, rr(-8, 8));
    final int count = 3 + (random.next() < 0.4 ? 1 : 0);
    final List<MeadowPlantLayer> layers = <MeadowPlantLayer>[
      line(stem.commands, 5.4),
    ];
    for (int i = 0; i < count; i++) {
      final double t = 0.2 + i * (0.42 / count) + rr(0, 0.06);
      final Offset at = stem.at(t);
      final int turn = (i.isOdd ? 1 : -1) * side;
      final double length = rr(34, 48) * (1 - i * 0.08);
      final double angle = stem.angle(t) + turn * rr(58, 78);
      final double width = length * rr(0.42, 0.52);
      final double petiole = rr(5, 9);
      layers.addAll(
        leaf(at, angle, length, width, _LeafKind.broad, petiole: petiole),
      );
    }
    final _Growth growth = withSecond(
      layers,
      <Offset>[],
      FlowerKind.sunflower,
      stem,
      at: (0.5, 0.62),
      reach: (22, 30),
      rise: (28, 40),
      width: 3.2,
      tilt: (10, 22),
      scale: 0.5,
    );
    return finishWith(
      growth,
      FlowerKind.sunflower,
      stem,
      stem.angle(1) * 0.5 + rr(-10, 10) + nod * 0.6,
    );
  }

  _Growth love() {
    final double h = rr(92, 122) * height;
    final _Stem stem = _Stem(h, lean * 14, rr(-9, 9));
    final List<MeadowPlantLayer> layers = <MeadowPlantLayer>[
      line(stem.commands, 4),
    ];
    const List<double> thorns = <double>[0.3, 0.52, 0.72];
    for (int i = 0; i < thorns.length; i++) {
      if (random.next() < 0.25) {
        continue;
      }
      final Offset p = stem.at(thorns[i]);
      final int turn = i.isOdd ? 1 : -1;
      layers.add(
        MeadowPlantShape(
          BloomShape(
            commands: <BloomCmd>[
              BloomMoveTo(p.dx, p.dy),
              BloomLineTo(p.dx + turn * 7, p.dy - 2),
              BloomLineTo(p.dx + turn * 2, p.dy - 6),
            ],
            close: true,
            fill: stemColour,
            strokeWidth: 0,
          ),
        ),
      );
    }
    final List<double> sprays = <double>[rr(0.26, 0.4), rr(0.5, 0.64)];
    for (int i = 0; i < sprays.length; i++) {
      final double t = sprays[i];
      final Offset p = stem.at(t);
      final int turn = (i.isOdd ? 1 : -1) * side;
      final double a = stem.angle(t) + turn * rr(58, 72);
      Offset along(double y) => p + _rotated(Offset(0, y), a);
      layers.add(
        MeadowPlantShape(
          BloomShape(
            commands: const <BloomCmd>[BloomMoveTo(0, 0), BloomLineTo(0, -28)],
            strokeColor: stemColour,
            strokeWidth: 1.8,
          ),
          MeadowPlantTransform(translation: p, rotation: a),
        ),
      );
      final double first = rr(11, 14);
      layers.addAll(leaf(along(-12), a - 48, first, 5, _LeafKind.broad));
      final double second = rr(11, 14);
      layers.addAll(leaf(along(-12), a + 48, second, 5, _LeafKind.broad));
      final double tilt = rr(-8, 8);
      final double last = rr(13, 16);
      layers.addAll(leaf(along(-27), a + tilt, last, 5.6, _LeafKind.broad));
    }
    final _Growth growth = withSecond(
      layers,
      <Offset>[],
      FlowerKind.rose,
      stem,
      at: (0.5, 0.64),
      reach: (16, 24),
      rise: (22, 32),
      width: 2.4,
      tilt: (14, 26),
      scale: 0.5,
    );
    return finishWith(
      growth,
      FlowerKind.rose,
      stem,
      stem.angle(1) * 0.6 + rr(-8, 8) + nod,
    );
  }

  _Growth grateful() {
    final double h = rr(82, 110) * height;
    final _Stem stem = _Stem(h, lean * 12, rr(-8, 8));
    final int count = 2 + (random.next() < 0.5 ? 1 : 0);
    final List<MeadowPlantLayer> layers = <MeadowPlantLayer>[
      line(stem.commands, 4.2),
    ];
    for (int i = 0; i < count; i++) {
      final double t = rr(0.18, 0.55);
      final Offset at = stem.at(t);
      final int turn = (i.isOdd ? 1 : -1) * side;
      final double angle = stem.angle(t) + turn * rr(58, 80);
      final double length = rr(24, 34);
      final double width = rr(10, 13);
      layers.addAll(leaf(at, angle, length, width, _LeafKind.lobed));
    }
    final _Growth growth = withSecond(
      layers,
      <Offset>[],
      FlowerKind.chrysanthemum,
      stem,
      at: (0.45, 0.6),
      reach: (20, 28),
      rise: (24, 34),
      width: 2.6,
      tilt: (12, 24),
      scale: 0.6,
    );
    return finishWith(
      growth,
      FlowerKind.chrysanthemum,
      stem,
      stem.angle(1) * 0.6 + rr(-8, 8) + nod,
    );
  }

  _Growth hopeful() {
    final double h = rr(116, 150) * height;
    final _Stem stem = _Stem(h, lean * 12, rr(-6, 6));
    final int count = 2 + (random.next() < 0.5 ? 1 : 0);
    final List<MeadowPlantLayer> layers = <MeadowPlantLayer>[];
    for (int i = 0; i < count; i++) {
      final int turn = i.isOdd ? 1 : -1;
      final Offset at = Offset(rr(-3, 3), 0);
      final double angle = turn * rr(3, 14);
      final double length = h * rr(0.55, 0.88);
      final double width = turn * rr(3.4, 4.6);
      layers.addAll(leaf(at, angle, length, width, _LeafKind.strap));
    }
    layers.add(line(stem.commands, 3.8));
    final List<Offset> heads = <Offset>[];
    if (secondBloom) {
      final double shorter = h * rr(0.72, 0.85);
      final double leanBack = -side * rr(10, 18);
      final _Stem second = _Stem(shorter, leanBack, rr(-5, 5));
      final (MeadowHeadPlacement bloom, Offset centre) = head(
        FlowerKind.daffodil,
        second.tip,
        second.angle(1) - side * rr(8, 20) + nod,
        0.82,
      );
      layers.addAll(<MeadowPlantLayer>[line(second.commands, 3.2), bloom]);
      heads.add(centre);
    }
    return finishWith(
      (layers: layers, heads: heads),
      FlowerKind.daffodil,
      stem,
      stem.angle(1) + side * rr(8, 22) + nod,
    );
  }

  _Growth anxious() {
    final double h = rr(112, 146) * height;
    final _Stem stem = _Stem(h, lean * 10, rr(-6, 6));
    final List<MeadowPlantLayer> leaves = <MeadowPlantLayer>[];
    for (int i = 0; i < 3; i++) {
      final double t = rr(0.12, 0.42);
      final Offset at = stem.at(t);
      final int turn = i.isOdd ? 1 : -1;
      final double angle = stem.angle(t) + turn * rr(50, 70);
      final double length = rr(15, 22);
      final double width = rr(3.6, 4.6);
      leaves.addAll(leaf(at, angle, length, width, _LeafKind.broad));
    }
    final int count = 1 + (random.next() * 2.4).floor() + (secondBloom ? 1 : 0);
    final List<MeadowPlantLayer> branches = <MeadowPlantLayer>[];
    final List<MeadowPlantLayer> daisies = <MeadowPlantLayer>[];
    final List<Offset> heads = <Offset>[];
    for (int i = 0; i < count; i++) {
      final Offset from = stem.at(rr(0.42, 0.74));
      final int turn = (i.isOdd ? -1 : 1) * side;
      final double dx = turn * rr(16, 30);
      final Offset tip = Offset(from.dx + dx, from.dy - rr(28, 48));
      branches.add(branch(from, tip, 2.4));
      final (MeadowHeadPlacement bloom, Offset centre) = daisy(
        tip,
        rr(7.5, 9),
        4.2,
      );
      daisies.add(bloom);
      heads.add(centre);
    }
    final (MeadowHeadPlacement main, Offset centre) = daisy(
      stem.tip,
      rr(10, 11.5),
      5.3,
    );
    return (
      layers: <MeadowPlantLayer>[
        line(stem.commands, 3.2),
        ...leaves,
        ...branches,
        ...daisies,
        main,
      ],
      heads: <Offset>[...heads, centre],
    );
  }

  _Growth tired() {
    final double h = rr(132, 170) * height;
    final _Stem stem = _Stem(h, lean * 22, rr(-14, 14));
    final int count = 4 + random.nextInt(3);
    final List<MeadowPlantLayer> layers = <MeadowPlantLayer>[];
    for (int i = 0; i < count; i++) {
      final int turn = i.isOdd ? 1 : -1;
      final double y0 = -rr(4, 16);
      final double cx = turn * rr(9, 14);
      final double cy = y0 - rr(0, 8);
      final double ex = turn * rr(18, 26);
      final double ey = y0 - rr(4, 16);
      layers.add(
        line(
          <BloomCmd>[BloomMoveTo(0, y0), BloomQuadTo(cx, cy, ex, ey)],
          1.9,
          leafGreen(),
        ),
      );
    }
    layers.add(line(stem.commands, 2.9));
    if (random.next() < 0.55 || secondBloom) {
      final Offset from = stem.at(rr(0.5, 0.64));
      final int turn = -side;
      final double dx = turn * rr(12, 20);
      final Offset tip = Offset(from.dx + dx, from.dy - rr(30, 46));
      layers.addAll(<MeadowPlantLayer>[
        branch(from, tip, 2.2),
        MeadowPlantShape(
          BloomOval(
            cx: tip.dx,
            cy: tip.dy + 5,
            rx: 5.6,
            ry: 8,
            rotationDeg: turn * rr(20, 40),
            pivotX: tip.dx,
            pivotY: tip.dy,
            fill: FlowerColors.gardenLeafPale,
            strokeColor: FlowerColors.gardenLeafStroke,
            strokeWidth: 1.6,
          ),
        ),
      ]);
    }
    return finishWith(
      (layers: layers, heads: <Offset>[]),
      FlowerKind.poppy,
      stem,
      stem.angle(1) * 0.8 + rr(-8, 8) + nod * 1.3,
    );
  }

  _Growth sad() {
    final int dir = side;
    final double h = rr(100, 132) * height;
    final Offset p0 = Offset(dir * rr(10, 16), -h);
    final Offset p1 = Offset(dir * rr(26, 32), -h * 1.04);
    final Offset p2 = Offset(dir * rr(40, 46), -h * 0.9);
    final double p3x = dir * rr(48, 56);
    final Offset p3 = Offset(p3x, -h * rr(0.7, 0.78));
    Offset arch(double t) {
      final double u = 1 - t;
      final double a = u * u * u;
      final double b = 3 * u * u * t;
      final double c = 3 * u * t * t;
      final double d = t * t * t;
      return Offset(
        a * p0.dx + b * p1.dx + c * p2.dx + d * p3.dx,
        a * p0.dy + b * p1.dy + c * p2.dy + d * p3.dy,
      );
    }

    final List<double> spots = <double>[rr(0.1, 0.2), rr(0.26, 0.4)];
    final List<MeadowPlantLayer> layers = <MeadowPlantLayer>[];
    for (int i = 0; i < spots.length; i++) {
      final double t = spots[i];
      final int turn = i.isOdd ? 1 : -1;
      final double angle = turn * rr(55, 75);
      final double length = rr(26, 34);
      final double width = rr(11, 14);
      layers.addAll(
        leaf(
          Offset(-dir * 2 * t, -h * t),
          angle,
          length,
          width,
          _LeafKind.lobed,
        ),
      );
    }
    layers.add(
      line(<BloomCmd>[
        const BloomMoveTo(0, 0),
        BloomCubicTo(-dir * 4, -h * 0.5, dir * 2, -h * 0.95, p0.dx, p0.dy),
        BloomCubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy),
      ], 3.2),
    );
    final int count = 4 + (random.next() * 2.2).floor() + (secondBloom ? 1 : 0);
    final List<Offset> heads = <Offset>[];
    for (int k = 0; k < count; k++) {
      final Offset p = arch(0.12 + k * (0.84 / (count - 1)));
      final double size = 8.4 - k * 0.55;
      layers.addAll(<MeadowPlantLayer>[
        line(
          <BloomCmd>[
            BloomMoveTo(p.dx, p.dy),
            BloomQuadTo(p.dx, p.dy + 5, p.dx, p.dy + size * 1.1),
          ],
          1.6,
          FlowerColors.gardenStemMid,
        ),
        MeadowHeadPlacement(
          kind: FlowerKind.bleedingHeart,
          parts: pendantHeart(0, 0, size),
          transform: MeadowPlantTransform(
            translation: Offset(p.dx, p.dy + size * 1.1),
          ),
        ),
      ]);
      heads.add(Offset(p.dx, p.dy + size * 1.7));
    }
    return (layers: layers, heads: heads);
  }

  _Growth angry() {
    final double h = rr(118, 156) * height;
    final _Stem stem = _Stem(h, lean * 8, rr(-5, 5));
    final List<MeadowPlantLayer> layers = <MeadowPlantLayer>[];
    final List<Offset> heads = <Offset>[];
    if (secondBloom) {
      final double shorter = h * rr(0.7, 0.82);
      final double leanBack = -side * rr(12, 20);
      final _Stem second = _Stem(shorter, leanBack, rr(-4, 4));
      final (MeadowHeadPlacement bloom, Offset centre) = head(
        FlowerKind.redSpiderLily,
        second.tip,
        second.angle(1) * 0.5 + rr(-10, 10),
        0.8,
      );
      layers.addAll(<MeadowPlantLayer>[
        line(second.commands, 2.8, FlowerColors.gardenScape),
        bloom,
      ]);
      heads.add(centre);
    }
    layers.add(line(stem.commands, 3.2, FlowerColors.gardenScape));
    return finishWith(
      (layers: layers, heads: heads),
      FlowerKind.redSpiderLily,
      stem,
      stem.angle(1) * 0.5 + rr(-10, 10) + nod * 0.6,
    );
  }

  _Growth calm() {
    final int count = 3 + (random.next() * 2.5).floor() + (secondBloom ? 1 : 0);
    final List<MeadowPlantLayer> leaves = <MeadowPlantLayer>[];
    for (int i = 0; i < 4; i++) {
      final int turn = i.isOdd ? 1 : -1;
      final Offset at = Offset(rr(-3, 3), 0);
      final double angle = turn * rr(6, 32);
      final double length = rr(24, 34);
      final double width = rr(3.4, 4.4);
      final Color fill = random.next() < 0.5
          ? FlowerColors.gardenLeafDusk
          : _calmLeafPale;
      leaves.addAll(
        leaf(at, angle, length, width, _LeafKind.broad, fill: fill),
      );
    }
    final List<MeadowPlantLayer> stems = <MeadowPlantLayer>[];
    final List<MeadowPlantLayer> spikes = <MeadowPlantLayer>[];
    final List<Offset> heads = <Offset>[];
    for (int i = 0; i < count; i++) {
      final double bx = rr(-4, 4);
      final double spread = (i - (count - 1) / 2) * rr(8, 12);
      final double tx = bx + spread + lean * 8 + rr(-4, 4);
      final double ty = -rr(96, 132) * height;
      final double cx = (bx + tx) / 2 + rr(-5, 5);
      final double cy = ty * 0.5;
      stems.add(
        line(
          <BloomCmd>[BloomMoveTo(bx, 0), BloomQuadTo(cx, cy, tx, ty)],
          2.5,
          FlowerColors.gardenStemMid,
        ),
      );
      final double dx = tx - cx;
      final double dy = ty - cy;
      final double length = math.sqrt(dx * dx + dy * dy);
      final double ux = dx / length;
      final double uy = dy / length;
      final double a = math.atan2(ux, -uy) / _degrees;
      final int florets = 5 + (random.next() * 2.5).floor();
      spikes.add(
        MeadowHeadPlacement(
          kind: FlowerKind.lavender,
          parts: List<BloomPart>.unmodifiable(<BloomPart>[
            for (int k = 0; k < florets; k++)
              BloomOval(
                cx: tx + ux * k * 6.2 + (k.isOdd ? 0.8 : -0.8),
                cy: ty + uy * k * 6.2,
                rx: 3.1 - k * 0.12,
                ry: 4.2 - k * 0.14,
                rotationDeg: a,
                pivotX: tx + ux * k * 6.2 + (k.isOdd ? 0.8 : -0.8),
                pivotY: ty + uy * k * 6.2,
                fill: k.isOdd
                    ? FlowerColors.lavenderFloret
                    : FlowerColors.lavenderFloretDeep,
                strokeColor: FlowerColors.lavenderStroke,
                strokeWidth: 1,
              ),
          ]),
          transform: MeadowPlantTransform.identity,
        ),
      );
      heads.add(Offset(tx + ux * 14, ty + uy * 14));
    }
    return (
      layers: <MeadowPlantLayer>[...leaves, ...stems, ...spikes],
      heads: heads,
    );
  }

  _Growth sprout() {
    final MeadowPlantShape shoot = line(
      const <BloomCmd>[BloomMoveTo(0, 0), BloomQuadTo(1.5, -9, 0, -18)],
      2.2,
      FlowerColors.gardenStemMid,
    );
    final List<MeadowPlantShape> left = leaf(
      const Offset(0, -15),
      -62,
      rr(9, 11),
      4.2,
      _LeafKind.broad,
    );
    final List<MeadowPlantShape> right = leaf(
      const Offset(0, -16.5),
      58,
      rr(10, 12),
      4.6,
      _LeafKind.broad,
    );
    return (
      layers: <MeadowPlantLayer>[shoot, ...left, ...right],
      heads: const <Offset>[Offset(0, -18)],
    );
  }
}

List<BloomCmd> _leafOutline(double l, double w, _LeafKind kind) =>
    switch (kind) {
      _LeafKind.strap => <BloomCmd>[
        const BloomMoveTo(0, 0),
        BloomCubicTo(w, -l * 0.35, w * 0.7, -l * 0.7, w * 1.6, -l),
        BloomCubicTo(-w * 0.2, -l * 0.72, -w, -l * 0.36, 0, 0),
      ],
      _LeafKind.lobed => <BloomCmd>[
        const BloomMoveTo(0, 0),
        BloomCubicTo(
          w * 0.7,
          -l * 0.08,
          w * 1.05,
          -l * 0.3,
          w * 0.8,
          -l * 0.48,
        ),
        BloomCubicTo(w, -l * 0.62, w * 0.62, -l * 0.86, 0, -l),
        BloomCubicTo(-w * 0.62, -l * 0.86, -w, -l * 0.62, -w * 0.8, -l * 0.48),
        BloomCubicTo(-w * 1.05, -l * 0.3, -w * 0.7, -l * 0.08, 0, 0),
      ],
      _LeafKind.broad => <BloomCmd>[
        const BloomMoveTo(0, 0),
        BloomCubicTo(w, -l * 0.2, w * 0.85, -l * 0.72, 0, -l),
        BloomCubicTo(-w * 0.85, -l * 0.72, -w, -l * 0.2, 0, 0),
      ],
    };

Rect _artBounds(List<MeadowPlantLayer> layers) {
  final Rect? all = layers
      .map(_layerBounds)
      .nonNulls
      .fold<Rect?>(null, (Rect? a, Rect b) => a?.expandToInclude(b) ?? b);
  return all == null ? Rect.zero : all.intersect(meadowPlantBox);
}

Rect? _layerBounds(MeadowPlantLayer layer) => switch (layer) {
  MeadowPlantShape() => _partBounds(layer.part, layer.transform, 0),
  MeadowHeadPlacement() =>
    layer.parts
        .map(
          (BloomPart part) => _partBounds(
            part,
            layer.transform,
            gardenPlantSpecFor(layer.kind).strokeWidth,
          ),
        )
        .fold<Rect?>(null, (Rect? a, Rect b) => a?.expandToInclude(b) ?? b),
};

Rect _partBounds(BloomPart part, MeadowPlantTransform t, double width) {
  final Rect outline = switch (part) {
    BloomDisc() => Rect.fromCircle(
      center: t.apply(Offset(part.cx, part.cy)),
      radius: part.r * t.scale,
    ),
    BloomOval() => _ovalBounds(
      Offset(part.cx, part.cy),
      part.rx,
      part.ry,
      part.rotationDeg,
      Offset(part.pivotX, part.pivotY),
      t,
    ),
    BloomOvalRing() => List<Rect>.generate(
      part.count,
      (int i) => _ovalBounds(
        Offset(part.cx, part.cy),
        part.rx,
        part.ry,
        part.startDeg + part.stepDeg * i,
        Offset(part.pivotX, part.pivotY),
        t,
      ),
    ).reduce((Rect a, Rect b) => a.expandToInclude(b)),
    BloomShape() => _around(_shapeExtremes(part.commands, t)),
  };
  return outline.inflate((part.strokeWidth ?? width) / 2 * t.scale);
}

Rect _ovalBounds(
  Offset centre,
  double rx,
  double ry,
  double degrees,
  Offset pivot,
  MeadowPlantTransform t,
) {
  final Offset moved = t.apply(pivot + _rotated(centre - pivot, degrees));
  final double angle = (degrees + t.rotation) * _degrees;
  final double a = rx * t.scale;
  final double b = ry * t.scale;
  final double c = math.cos(angle);
  final double s = math.sin(angle);
  final double halfWidth = math.sqrt(a * a * c * c + b * b * s * s);
  final double halfHeight = math.sqrt(a * a * s * s + b * b * c * c);
  return Rect.fromCenter(
    center: moved,
    width: halfWidth * 2,
    height: halfHeight * 2,
  );
}

Rect _around(Iterable<Offset> points) {
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
  for (final Offset p in points) {
    left = math.min(left, p.dx);
    top = math.min(top, p.dy);
    right = math.max(right, p.dx);
    bottom = math.max(bottom, p.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

Iterable<Offset> _shapeExtremes(
  List<BloomCmd> commands,
  MeadowPlantTransform t,
) sync* {
  Offset current = Offset.zero;
  for (final BloomCmd command in commands) {
    switch (command) {
      case BloomMoveTo():
        current = Offset(command.x, command.y);
        yield t.apply(current);
      case BloomLineTo():
        current = Offset(command.x, command.y);
        yield t.apply(current);
      case BloomQuadTo():
        final Offset end = Offset(command.x, command.y);
        yield* _curveExtremes(<Offset>[
          t.apply(current),
          t.apply(Offset(command.cx, command.cy)),
          t.apply(end),
        ]);
        current = end;
      case BloomCubicTo():
        final Offset end = Offset(command.x, command.y);
        yield* _curveExtremes(<Offset>[
          t.apply(current),
          t.apply(Offset(command.c1x, command.c1y)),
          t.apply(Offset(command.c2x, command.c2y)),
          t.apply(end),
        ]);
        current = end;
      case BloomArcTo():
        final Offset end = Offset(command.x, command.y);
        yield t.apply(end);
        yield* _arcExtremes(current, command, t);
        current = end;
    }
  }
}

Offset _bezier(List<Offset> p, double s) {
  final double u = 1 - s;
  if (p.length == 3) {
    return p[0] * (u * u) + p[1] * (2 * u * s) + p[2] * (s * s);
  }
  return p[0] * (u * u * u) +
      p[1] * (3 * u * u * s) +
      p[2] * (3 * u * s * s) +
      p[3] * (s * s * s);
}

Iterable<double> _roots(double a, double b, double c) sync* {
  if (a.abs() < 1e-12) {
    if (b.abs() > 1e-12) {
      yield -c / b;
    }
    return;
  }
  final double discriminant = b * b - 4 * a * c;
  if (discriminant < 0) {
    return;
  }
  final double root = math.sqrt(discriminant);
  yield (-b + root) / (2 * a);
  yield (-b - root) / (2 * a);
}

Iterable<double> _axisTurns(List<double> v) {
  if (v.length == 3) {
    return _roots(0, 2 * (v[0] - 2 * v[1] + v[2]), 2 * (v[1] - v[0]));
  }
  return _roots(
    3 * (-v[0] + 3 * v[1] - 3 * v[2] + v[3]),
    6 * (v[0] - 2 * v[1] + v[2]),
    3 * (v[1] - v[0]),
  );
}

Iterable<Offset> _curveExtremes(List<Offset> p) sync* {
  yield p.first;
  yield p.last;
  final Iterable<double> turns = <double>[
    ..._axisTurns(<double>[for (final Offset q in p) q.dx]),
    ..._axisTurns(<double>[for (final Offset q in p) q.dy]),
  ];
  for (final double s in turns) {
    if (s > 0 && s < 1) {
      yield _bezier(p, s);
    }
  }
}

double _wrap(double angle) => ((angle % _turn) + _turn) % _turn;

Iterable<Offset> _arcExtremes(
  Offset from,
  BloomArcTo arc,
  MeadowPlantTransform t,
) sync* {
  double rx = arc.rx.abs();
  double ry = arc.ry.abs();
  final double hx = (from.dx - arc.x) / 2;
  final double hy = (from.dy - arc.y) / 2;
  if (rx == 0 || ry == 0 || (hx == 0 && hy == 0)) {
    return;
  }
  final double reach = hx * hx / (rx * rx) + hy * hy / (ry * ry);
  if (reach > 1) {
    rx *= math.sqrt(reach);
    ry *= math.sqrt(reach);
  }
  final double numerator =
      rx * rx * ry * ry - rx * rx * hy * hy - ry * ry * hx * hx;
  final double denominator = rx * rx * hy * hy + ry * ry * hx * hx;
  final double sign = arc.largeArc != arc.clockwise ? 1 : -1;
  final double k = sign * math.sqrt(math.max(0, numerator / denominator));
  final double cx = k * rx * hy / ry;
  final double cy = -k * ry * hx / rx;
  final Offset centre = Offset(
    cx + (from.dx + arc.x) / 2,
    cy + (from.dy + arc.y) / 2,
  );
  final double ux = (hx - cx) / rx;
  final double uy = (hy - cy) / ry;
  final double vx = (-hx - cx) / rx;
  final double vy = (-hy - cy) / ry;
  final double start = math.atan2(uy, ux);
  double sweep = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
  if (!arc.clockwise && sweep > 0) {
    sweep -= _turn;
  } else if (arc.clockwise && sweep < 0) {
    sweep += _turn;
  }
  final Offset moved = t.apply(centre);
  final double a = rx * t.scale;
  final double b = ry * t.scale;
  final double phi = t.rotation * _degrees;
  final double c = math.cos(phi);
  final double s = math.sin(phi);
  final double xTurn = math.atan2(-b * s, a * c);
  final double yTurn = math.atan2(b * c, a * s);
  for (final double theta in <double>[
    xTurn,
    xTurn + math.pi,
    yTurn,
    yTurn + math.pi,
  ]) {
    final double along = sweep >= 0
        ? _wrap(theta - start)
        : _wrap(start - theta);
    if (along <= sweep.abs()) {
      final double ex = a * math.cos(theta);
      final double ey = b * math.sin(theta);
      yield moved + Offset(ex * c - ey * s, ex * s + ey * c);
    }
  }
}
