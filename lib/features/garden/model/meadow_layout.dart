import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart' show listEquals;

import 'package:field_notes/design/flowers/garden_plant_painter.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/domain/models/models.dart';

import 'garden_data.dart';

const double sproutSizeFactor = 0.45;

const double meadowPlantSwayDegrees = 2.2;
const double meadowTuftSwayDegrees = 4;
const double meadowSharpDepth = 0.82;

const int _frontBandTufts = 14;
const int _frontBandTuftsCompact = 7;
const int _tuftVariants = 3;
const int _grassSeedSalt = 0x67726173;

sealed class MeadowItem {
  const MeadowItem({
    required this.dx,
    required this.depth,
    required this.width,
    required this.height,
    required this.bottom,
    required this.opacity,
    required this.blur,
    required this.swayDegrees,
    required this.swayPeriod,
    required this.swayPhase,
  });

  final double dx;
  final double depth;
  final double width;
  final double height;
  final double bottom;
  final double opacity;
  final double blur;
  final double swayDegrees;
  final double swayPeriod;
  final double swayPhase;

  Rect boxIn(Size size) => Rect.fromLTRB(
    dx - width / 2,
    size.height - bottom - height,
    dx + width / 2,
    size.height - bottom,
  );

  bool _sameGeometry(MeadowItem other) =>
      dx == other.dx &&
      depth == other.depth &&
      width == other.width &&
      height == other.height &&
      bottom == other.bottom &&
      opacity == other.opacity &&
      blur == other.blur &&
      swayDegrees == other.swayDegrees &&
      swayPeriod == other.swayPeriod &&
      swayPhase == other.swayPhase;

  int get _geometryHash => Object.hash(
    dx,
    depth,
    width,
    height,
    bottom,
    opacity,
    blur,
    swayDegrees,
    swayPeriod,
    swayPhase,
  );
}

final class MeadowPlant extends MeadowItem {
  const MeadowPlant({
    required this.kind,
    required this.date,
    required this.isSprout,
    required super.dx,
    required super.depth,
    required super.width,
    required super.height,
    required super.bottom,
    required super.opacity,
    required super.blur,
    required super.swayDegrees,
    required super.swayPeriod,
    required super.swayPhase,
  });

  final FlowerKind kind;
  final String date;
  final bool isSprout;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeadowPlant &&
          kind == other.kind &&
          date == other.date &&
          isSprout == other.isSprout &&
          _sameGeometry(other);

  @override
  int get hashCode => Object.hash(kind, date, isSprout, _geometryHash);

  @override
  String toString() =>
      'MeadowPlant(kind: $kind, date: $date, isSprout: $isSprout, '
      'dx: $dx, depth: $depth, width: $width, bottom: $bottom)';
}

final class MeadowTuft extends MeadowItem {
  const MeadowTuft({
    required this.variant,
    required super.dx,
    required super.depth,
    required super.width,
    required super.height,
    required super.bottom,
    required super.opacity,
    required super.blur,
    required super.swayDegrees,
    required super.swayPeriod,
    required super.swayPhase,
  });

  final int variant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeadowTuft && variant == other.variant && _sameGeometry(other);

  @override
  int get hashCode => Object.hash(variant, _geometryHash);

  @override
  String toString() =>
      'MeadowTuft(variant: $variant, dx: $dx, depth: $depth, '
      'width: $width, bottom: $bottom)';
}

class MeadowBand {
  const MeadowBand({
    required this.opacity,
    required this.blur,
    required this.bounds,
    required this.items,
  });

  final double opacity;
  final double blur;
  final Rect bounds;
  final List<MeadowItem> items;
}

class MeadowLayout {
  const MeadowLayout({
    required this.size,
    required this.items,
    required this.bands,
  });

  static const MeadowLayout empty = MeadowLayout(
    size: Size.zero,
    items: <MeadowItem>[],
    bands: <MeadowBand>[],
  );

  final Size size;
  final List<MeadowItem> items;
  final List<MeadowBand> bands;

  List<MeadowPlant> get plants => items.whereType<MeadowPlant>().toList();

  List<MeadowTuft> get tufts => items.whereType<MeadowTuft>().toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeadowLayout &&
          size == other.size &&
          listEquals(items, other.items);

  @override
  int get hashCode => Object.hash(size, Object.hashAll(items));
}

class _MeadowSeed {
  const _MeadowSeed({
    required this.date,
    required this.mood,
    required this.isSprout,
  });

  final String date;
  final Mood? mood;
  final bool isSprout;
}

class _Drift {
  const _Drift(this.x, this.depth);

  final double x;
  final double depth;
}

List<_MeadowSeed> _seedsInDateOrder(
  List<GardenBloomData> blooms,
  List<String> sprouts,
) {
  final List<_MeadowSeed> seeds = <_MeadowSeed>[
    for (final GardenBloomData bloom in blooms)
      _MeadowSeed(date: bloom.date, mood: bloom.mood, isSprout: false),
    for (final String date in sprouts)
      _MeadowSeed(date: date, mood: null, isSprout: true),
  ];
  final List<(int, _MeadowSeed)> ordered = seeds.indexed.toList()
    ..sort(((int, _MeadowSeed) a, (int, _MeadowSeed) b) {
      final int byDate = a.$2.date.compareTo(b.$2.date);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  return <_MeadowSeed>[
    for (final (int, _MeadowSeed) entry in ordered) entry.$2,
  ];
}

double _between(math.Random rng, double from, double to) =>
    from + rng.nextDouble() * (to - from);

_Drift _nextDrift(math.Random rng) =>
    _Drift(_between(rng, 0.03, 0.97), rng.nextDouble());

double _groundLift(double depth, double height, double sink) =>
    (1 - depth) * (height * 0.5) - depth * sink;

MeadowPlant _plant(
  _MeadowSeed seed,
  _Drift drift,
  math.Random rng,
  Size size,
  bool compact,
) {
  final double x = (drift.x + _between(rng, -0.085, 0.085)).clamp(0.015, 0.985);
  final double depth = (drift.depth + _between(rng, -0.25, 0.25)).clamp(
    0.0,
    1.0,
  );
  final double swayPeriod = _between(rng, 3.6, 6);
  final double swayPhase = rng.nextDouble() * swayPeriod;
  final FlowerKind kind = seed.mood?.flower ?? FlowerKind.daffodil;
  final double scale = seed.isSprout ? sproutSizeFactor : 1;
  final double width = (compact ? 38 : 54) * (0.4 + 0.9 * depth) * scale;
  final double ratio = seed.isSprout
      ? sproutRatio
      : gardenPlantSpecFor(kind).ratio;
  return MeadowPlant(
    kind: kind,
    date: seed.date,
    isSprout: seed.isSprout,
    dx: x * size.width,
    depth: depth,
    width: width,
    height: width * ratio,
    bottom: _groundLift(depth, size.height, 6),
    opacity: 0.6 + 0.4 * depth,
    blur: depth <= meadowSharpDepth ? (1 - depth) * 1.7 : 0,
    swayDegrees: meadowPlantSwayDegrees,
    swayPeriod: swayPeriod,
    swayPhase: swayPhase,
  );
}

MeadowTuft _tuft({
  required math.Random rng,
  required double x,
  required double depth,
  required Size size,
  required bool compact,
}) {
  final int variant = rng.nextInt(_tuftVariants);
  final double swayPeriod = _between(rng, 4, 7);
  final double swayPhase = rng.nextDouble() * swayPeriod;
  final double width = (compact ? 24 : 34) * (0.5 + 0.95 * depth);
  return MeadowTuft(
    variant: variant,
    dx: x * size.width,
    depth: depth,
    width: width,
    height: width * 0.9,
    bottom: _groundLift(depth, size.height, 5),
    opacity: math.min(1, 0.55 + 0.45 * depth),
    blur: depth <= meadowSharpDepth ? (1 - depth) * 1.5 : 0,
    swayDegrees: meadowTuftSwayDegrees,
    swayPeriod: swayPeriod,
    swayPhase: swayPhase,
  );
}

List<MeadowTuft> _grass({
  required int seed,
  required int plantCount,
  required Size size,
  required bool compact,
}) {
  final math.Random rng = math.Random(seed ^ _grassSeedSalt);
  final int front = compact ? _frontBandTuftsCompact : _frontBandTufts;
  final List<MeadowTuft> band = <MeadowTuft>[
    for (int i = 0; i < front; i++)
      _tuft(
        rng: rng,
        x: (i + rng.nextDouble() * 0.7) / front,
        depth: _between(rng, 0.9, 1.02),
        size: size,
        compact: compact,
      ),
  ];
  final int scattered = (plantCount * 0.85).round();
  return <MeadowTuft>[
    ...band,
    for (int i = 0; i < scattered; i++)
      _tuft(
        rng: rng,
        x: _between(rng, 0.005, 0.995),
        depth: math.min(1, rng.nextDouble() * 1.02),
        size: size,
        compact: compact,
      ),
  ];
}

int _bandKey(MeadowItem item) => item.depth > meadowSharpDepth
    ? (item.depth > 0.92 ? 11 : 10)
    : math.min(8, (item.depth * 10).floor());

MeadowBand _band(List<MeadowItem> items, Size size) {
  final double opacity =
      items.fold<double>(
        0,
        (double sum, MeadowItem item) => sum + item.opacity,
      ) /
      items.length;
  final double blur =
      items.fold<double>(0, (double sum, MeadowItem item) => sum + item.blur) /
      items.length;
  final Rect union = items
      .map((MeadowItem item) => item.boxIn(size))
      .reduce((Rect a, Rect b) => a.expandToInclude(b));
  final double tallest = items
      .map((MeadowItem item) => item.height)
      .reduce(math.max);
  return MeadowBand(
    opacity: opacity,
    blur: blur,
    bounds: union.inflate(tallest * 0.1 + blur * 3 + 4),
    items: List<MeadowItem>.unmodifiable(items),
  );
}

List<MeadowBand> _bandsOf(List<MeadowItem> items, Size size) {
  final List<int> starts = <int>[
    for (int i = 0; i < items.length; i++)
      if (i == 0 || _bandKey(items[i]) != _bandKey(items[i - 1])) i,
  ];
  return <MeadowBand>[
    for (int run = 0; run < starts.length; run++)
      _band(
        items.sublist(
          starts[run],
          run + 1 < starts.length ? starts[run + 1] : items.length,
        ),
        size,
      ),
  ];
}

MeadowLayout layoutMeadowByDepth({
  required List<GardenBloomData> blooms,
  required Size size,
  required int seed,
  List<String> sprouts = const <String>[],
  bool compact = false,
}) {
  if (size.width <= 0 || size.height <= 0) {
    return MeadowLayout.empty;
  }
  final math.Random rng = math.Random(seed);
  final List<_Drift> moodDrifts = <_Drift>[
    for (int i = 0; i < Mood.values.length; i++) _nextDrift(rng),
  ];
  final _Drift sproutDrift = _nextDrift(rng);
  final List<_MeadowSeed> seeds = _seedsInDateOrder(blooms, sprouts);
  final List<MeadowPlant> plants = <MeadowPlant>[
    for (final _MeadowSeed plant in seeds)
      _plant(
        plant,
        switch (plant.mood) {
          null => sproutDrift,
          final Mood mood => moodDrifts[mood.index],
        },
        rng,
        size,
        compact,
      ),
  ];
  final List<MeadowItem> unordered = <MeadowItem>[
    ...plants,
    ..._grass(
      seed: seed,
      plantCount: plants.length,
      size: size,
      compact: compact,
    ),
  ];
  final List<(int, MeadowItem)> ordered = unordered.indexed.toList()
    ..sort(((int, MeadowItem) a, (int, MeadowItem) b) {
      final int byDepth = a.$2.depth.compareTo(b.$2.depth);
      return byDepth != 0 ? byDepth : a.$1.compareTo(b.$1);
    });
  final List<MeadowItem> items = List<MeadowItem>.unmodifiable(<MeadowItem>[
    for (final (int, MeadowItem) entry in ordered) entry.$2,
  ]);
  return MeadowLayout(
    size: size,
    items: items,
    bands: List<MeadowBand>.unmodifiable(_bandsOf(items, size)),
  );
}
