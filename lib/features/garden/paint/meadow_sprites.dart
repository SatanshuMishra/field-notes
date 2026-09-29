import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:field_notes/design/flowers/garden_plant_painter.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/domain/models/models.dart';

import '../model/meadow_layout.dart';
import 'grass_tuft_painter.dart';

const int _sheetMaxWidth = 4096;
const int _minimumPad = 2;
const double _artSpill = 0.03;

class MeadowArt {
  const MeadowArt({required this.box, required this.picture});

  final Size box;
  final ui.Picture picture;
}

MeadowArt _record(Size box, void Function(Canvas canvas, Size size) draw) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  draw(Canvas(recorder), box);
  return MeadowArt(box: box, picture: recorder.endRecording());
}

final Map<FlowerKind, MeadowArt> _plantArt =
    Map<FlowerKind, MeadowArt>.unmodifiable(<FlowerKind, MeadowArt>{
      for (final FlowerKind kind in FlowerKind.values)
        kind: _record(
          Size(
            GardenPlantSpec.viewBoxWidth,
            GardenPlantSpec.viewBoxWidth * gardenPlantSpecFor(kind).ratio,
          ),
          GardenPlantPainter(gardenPlantSpecFor(kind)).paint,
        ),
    });

final MeadowArt _sproutArt = _record(
  const Size(
    GardenPlantSpec.viewBoxWidth,
    GardenPlantSpec.viewBoxWidth * sproutRatio,
  ),
  const GardenSproutPainter().paint,
);

final List<MeadowArt> _tuftArt = List<MeadowArt>.unmodifiable(<MeadowArt>[
  for (int variant = 0; variant < grassTuftColours.length; variant++)
    _record(
      const Size(grassTuftViewBox, grassTuftViewBox * grassTuftRatio),
      GrassTuftPainter(variant).paint,
    ),
]);

MeadowArt meadowArtFor(MeadowItem item) => switch (item) {
  MeadowPlant(isSprout: true) => _sproutArt,
  MeadowPlant(:final FlowerKind kind) => _plantArt[kind]!,
  MeadowTuft(:final int variant) => _tuftArt[variant % _tuftArt.length],
};

class MeadowSpriteCell {
  const MeadowSpriteCell({
    required this.source,
    required this.spriteWidth,
    required this.pad,
  });

  final Rect source;
  final double spriteWidth;
  final double pad;
}

class _Planned {
  const _Planned({
    required this.band,
    required this.art,
    required this.spriteWidth,
  });

  final int band;
  final MeadowArt art;
  final int spriteWidth;

  int get pad => _minimumPad + (spriteWidth * _artSpill).ceil();

  int get cellWidth => spriteWidth + 2 * pad;

  int get cellHeight =>
      (spriteWidth * art.box.height / art.box.width).ceil() + 2 * pad;
}

class _Placed {
  const _Placed(this.plan, this.left, this.top);

  final _Planned plan;
  final int left;
  final int top;

  Rect get source => Rect.fromLTWH(
    left.toDouble(),
    top.toDouble(),
    plan.cellWidth.toDouble(),
    plan.cellHeight.toDouble(),
  );
}

int _spriteWidth(
  List<MeadowItem> items,
  MeadowArt art,
  double devicePixelRatio,
) {
  final double widest = items
      .where((MeadowItem item) => meadowArtFor(item) == art)
      .map((MeadowItem item) => item.width)
      .reduce(math.max);
  return math.max(1, (widest * devicePixelRatio).ceil());
}

List<_Planned> _plan(MeadowLayout layout, double devicePixelRatio) =>
    <_Planned>[
      for (final (int band, MeadowBand meadowBand) in layout.bands.indexed)
        for (final MeadowArt art in meadowBand.items.map(meadowArtFor).toSet())
          _Planned(
            band: band,
            art: art,
            spriteWidth: _spriteWidth(meadowBand.items, art, devicePixelRatio),
          ),
    ];

List<_Placed> _pack(List<_Planned> plans) {
  final List<_Planned> tallestFirst = plans.toList()
    ..sort((_Planned a, _Planned b) => b.cellHeight.compareTo(a.cellHeight));
  final List<_Placed> placed = <_Placed>[];
  int left = 0;
  int top = 0;
  int rowHeight = 0;
  for (final _Planned plan in tallestFirst) {
    if (left > 0 && left + plan.cellWidth > _sheetMaxWidth) {
      top += rowHeight;
      left = 0;
      rowHeight = 0;
    }
    placed.add(_Placed(plan, left, top));
    left += plan.cellWidth;
    rowHeight = math.max(rowHeight, plan.cellHeight);
  }
  return placed;
}

class MeadowSprites {
  const MeadowSprites._({required this.image, required this._cells});

  static MeadowSprites build(MeadowLayout layout, double devicePixelRatio) {
    final List<_Placed> placed = _pack(_plan(layout, devicePixelRatio));
    if (placed.isEmpty) {
      return const MeadowSprites._(
        image: null,
        cells: <(int, MeadowArt), MeadowSpriteCell>{},
      );
    }
    final int width = placed
        .map((_Placed cell) => cell.left + cell.plan.cellWidth)
        .reduce(math.max);
    final int height = placed
        .map((_Placed cell) => cell.top + cell.plan.cellHeight)
        .reduce(math.max);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    for (final _Placed cell in placed) {
      final MeadowArt art = cell.plan.art;
      canvas.save();
      canvas.clipRect(cell.source);
      canvas.translate(
        cell.source.left + cell.plan.pad,
        cell.source.top + cell.plan.pad,
      );
      canvas.scale(cell.plan.spriteWidth / art.box.width);
      canvas.drawPicture(art.picture);
      canvas.restore();
    }
    final ui.Picture sheet = recorder.endRecording();
    final ui.Image image = sheet.toImageSync(width, height);
    sheet.dispose();
    return MeadowSprites._(
      image: image,
      cells: Map<(int, MeadowArt), MeadowSpriteCell>.unmodifiable(
        <(int, MeadowArt), MeadowSpriteCell>{
          for (final _Placed cell in placed)
            (cell.plan.band, cell.plan.art): MeadowSpriteCell(
              source: cell.source,
              spriteWidth: cell.plan.spriteWidth.toDouble(),
              pad: cell.plan.pad.toDouble(),
            ),
        },
      ),
    );
  }

  final ui.Image? image;
  final Map<(int, MeadowArt), MeadowSpriteCell> _cells;

  MeadowSpriteCell? cellFor(int band, MeadowArt art) => _cells[(band, art)];

  void dispose() {
    image?.dispose();
  }
}
