import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:flutter/foundation.dart';

const int meadowPlantSheetLimit = 4096;
const int meadowPlantSpritePadding = 2;
const int meadowPlantSpriteBudget = 50000000;
const int meadowPlantSpritePageBudget = 22000000;

const int _bytesPerPixel = 4;
const int _plantsPerBake = 24;
const int _fitSteps = 32;
const double _minimumDensity = 0.05;

class MeadowPlantSprite {
  const MeadowPlantSprite({
    required this.dayIndex,
    required this.sheet,
    required this.source,
    required this.anchor,
    required this.base,
  });

  final int dayIndex;
  final int sheet;
  final Rect source;
  final Offset anchor;
  final Offset base;
}

class MeadowPlantAtlas {
  factory MeadowPlantAtlas(
    MeadowPlants plants, {
    required double density,
    int maxBytes = meadowPlantSpriteBudget,
  }) {
    final List<MeadowPlant> visible = _visible(plants);
    final double fitted = _fittedDensity(visible, density, maxBytes);
    return MeadowPlantAtlas._(density: fitted, layout: _pack(visible, fitted));
  }

  MeadowPlantAtlas._({required this.density, required _Layout layout})
    : _layout = layout,
      _sprites = List<MeadowPlantSprite>.unmodifiable(<MeadowPlantSprite>[
        for (final _Sheet sheet in layout.sheets)
          for (final _Placed placed in sheet.cells) placed.sprite,
      ]),
      _images = List<Image?>.filled(layout.sheets.length, null);

  final double density;
  final _Layout _layout;
  final List<MeadowPlantSprite> _sprites;
  final List<Image?> _images;
  late final Map<int, MeadowPlantSprite> _byDay =
      Map<int, MeadowPlantSprite>.unmodifiable(<int, MeadowPlantSprite>{
        for (final MeadowPlantSprite sprite in _sprites)
          sprite.dayIndex: sprite,
      });
  late final List<List<_Batch>> _batches = <List<_Batch>>[
    for (final _Sheet sheet in _layout.sheets) _batchesOf(sheet.cells),
  ];
  final List<_Chunk> _chunks = <_Chunk>[];
  int _sheet = 0;
  int _next = 0;
  int _largestBake = 0;
  bool _disposed = false;

  List<MeadowPlantSprite> get sprites => _sprites;

  int get sheetCount => _layout.sheets.length;

  bool get isReady => !_disposed && _sheet >= _layout.sheets.length;

  int get imageBytes =>
      <Image>[
        ..._images.nonNulls,
        for (final _Chunk chunk in _chunks) chunk.image,
      ].fold<int>(
        0,
        (int total, Image image) =>
            total + image.width * image.height * _bytesPerPixel,
      );

  @visibleForTesting
  int get debugLargestBake => _largestBake;

  MeadowPlantSprite? spriteOf(int dayIndex) => _byDay[dayIndex];

  Image? imageOf(int sheet) => _images[sheet];

  RSTransform placement(
    MeadowPlantSprite sprite, {
    double rotation = 0,
    double scale = 1,
  }) => RSTransform.fromComponents(
    rotation: rotation,
    scale: scale / density,
    anchorX: sprite.anchor.dx,
    anchorY: sprite.anchor.dy,
    translateX: sprite.base.dx,
    translateY: sprite.base.dy,
  );

  bool step() {
    if (_disposed || _sheet >= _layout.sheets.length) {
      return false;
    }
    final List<_Batch> batches = _batches[_sheet];
    if (_next < batches.length) {
      _chunks.add(_bake(batches[_next]));
      _next++;
      return true;
    }
    _images[_sheet] = _compose(_layout.sheets[_sheet]);
    _releaseChunks();
    _next = 0;
    _sheet++;
    return _sheet < _layout.sheets.length;
  }

  void buildAll() {
    while (step()) {}
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _releaseChunks();
    for (int i = 0; i < _images.length; i++) {
      _images[i]?.dispose();
      _images[i] = null;
    }
  }

  _Chunk _bake(_Batch batch) {
    final Rect bounds = batch.bounds;
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder)
      ..translate(-bounds.left, -bounds.top);
    for (final _Placed placed in batch.cells) {
      _paintCell(canvas, placed);
    }
    final Picture picture = recorder.endRecording();
    final Image image = picture.toImageSync(
      bounds.width.toInt(),
      bounds.height.toInt(),
    );
    picture.dispose();
    _largestBake = math.max(_largestBake, batch.cells.length);
    return _Chunk(image: image, offset: bounds.topLeft);
  }

  Image _compose(_Sheet sheet) {
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint();
    for (final _Chunk chunk in _chunks) {
      canvas.drawImage(chunk.image, chunk.offset, paint);
    }
    final Picture picture = recorder.endRecording();
    final Image image = picture.toImageSync(sheet.width, sheet.height);
    picture.dispose();
    return image;
  }

  void _releaseChunks() {
    for (final _Chunk chunk in _chunks) {
      chunk.image.dispose();
    }
    _chunks.clear();
  }
}

class _Batch {
  _Batch(this.cells)
    : bounds = cells
          .map((_Placed placed) => placed.source)
          .reduce((Rect a, Rect b) => a.expandToInclude(b));

  final List<_Placed> cells;
  final Rect bounds;
}

List<_Batch> _batchesOf(List<_Placed> cells) {
  final List<_Batch> batches = <_Batch>[];
  int start = 0;
  for (int i = 1; i <= cells.length; i++) {
    if (i == cells.length || cells[i].top != cells[start].top) {
      final int parts = (i - start + _plantsPerBake - 1) ~/ _plantsPerBake;
      for (int part = 0; part < parts; part++) {
        batches.add(
          _Batch(
            cells.sublist(
              start + (i - start) * part ~/ parts,
              start + (i - start) * (part + 1) ~/ parts,
            ),
          ),
        );
      }
      start = i;
    }
  }
  return List<_Batch>.unmodifiable(batches);
}

class _Chunk {
  const _Chunk({required this.image, required this.offset});

  final Image image;
  final Offset offset;
}

void _paintCell(Canvas canvas, _Placed placed) {
  final Rect source = placed.source;
  canvas.save();
  canvas.clipRect(source);
  canvas.translate(
    source.left + placed.cell.anchor.dx,
    source.top + placed.cell.anchor.dy,
  );
  canvas.scale(placed.cell.scale);
  paintMeadowPlantArt(canvas, placed.cell.plant.art);
  canvas.restore();
}

List<MeadowPlant> _visible(MeadowPlants plants) => <MeadowPlant>[
  for (final MeadowPlant plant in plants.plants)
    if (!plant.hidden) plant,
];

double _fittedDensity(List<MeadowPlant> plants, double density, int maxBytes) {
  final double wanted = density.isFinite
      ? math.max(density, _minimumDensity)
      : _minimumDensity;
  if (_pack(plants, wanted).fits(maxBytes)) {
    return wanted;
  }
  double low = _minimumDensity;
  double high = wanted;
  for (int i = 0; i < _fitSteps; i++) {
    final double middle = (low + high) / 2;
    if (_pack(plants, middle).fits(maxBytes)) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return low;
}

class _Cell {
  const _Cell({
    required this.plant,
    required this.scale,
    required this.width,
    required this.height,
    required this.anchor,
  });

  factory _Cell.of(MeadowPlant plant, double density) {
    final double scale = plant.scale * density;
    final Rect bounds = plant.art.bounds;
    final int left = (bounds.left * scale).floor();
    final int top = (bounds.top * scale).floor();
    final int right = (bounds.right * scale).ceil();
    final int bottom = (bounds.bottom * scale).ceil();
    return _Cell(
      plant: plant,
      scale: scale,
      width: right - left + meadowPlantSpritePadding * 2,
      height: bottom - top + meadowPlantSpritePadding * 2,
      anchor: Offset(
        (meadowPlantSpritePadding - left).toDouble(),
        (meadowPlantSpritePadding - top).toDouble(),
      ),
    );
  }

  final MeadowPlant plant;
  final double scale;
  final int width;
  final int height;
  final Offset anchor;
}

class _Placed {
  const _Placed({
    required this.cell,
    required this.sheet,
    required this.left,
    required this.top,
  });

  final _Cell cell;
  final int sheet;
  final int left;
  final int top;

  Rect get source => Rect.fromLTWH(
    left.toDouble(),
    top.toDouble(),
    cell.width.toDouble(),
    cell.height.toDouble(),
  );

  MeadowPlantSprite get sprite => MeadowPlantSprite(
    dayIndex: cell.plant.dayIndex,
    sheet: sheet,
    source: source,
    anchor: cell.anchor,
    base: cell.plant.base,
  );
}

class _Sheet {
  const _Sheet({
    required this.width,
    required this.height,
    required this.cells,
  });

  final int width;
  final int height;
  final List<_Placed> cells;

  int get bytes => width * height * _bytesPerPixel;
}

class _Layout {
  const _Layout({required this.sheets, required this.oversized});

  final List<_Sheet> sheets;
  final bool oversized;

  int get bytes =>
      sheets.fold<int>(0, (int total, _Sheet sheet) => total + sheet.bytes);

  bool fits(int maxBytes) => !oversized && bytes <= maxBytes;
}

int _tallestFirst(_Cell a, _Cell b) {
  final int height = b.height.compareTo(a.height);
  if (height != 0) {
    return height;
  }
  final int width = b.width.compareTo(a.width);
  return width != 0 ? width : a.plant.dayIndex.compareTo(b.plant.dayIndex);
}

_Layout _pack(List<MeadowPlant> plants, double density) {
  final List<_Cell> cells = <_Cell>[
    for (final MeadowPlant plant in plants) _Cell.of(plant, density),
  ]..sort(_tallestFirst);
  final bool oversized = cells.any(
    (_Cell cell) =>
        cell.width > meadowPlantSheetLimit ||
        cell.height > meadowPlantSheetLimit,
  );
  final List<_Sheet> sheets = <_Sheet>[];
  List<_Placed> placed = <_Placed>[];
  int x = 0;
  int y = 0;
  int shelf = 0;
  int width = 0;
  for (final _Cell cell in cells) {
    if (x > 0 && x + cell.width > meadowPlantSheetLimit) {
      y += shelf;
      x = 0;
      shelf = 0;
    }
    if (x == 0 && y > 0 && y + cell.height > meadowPlantSheetLimit) {
      sheets.add(
        _Sheet(
          width: width,
          height: y,
          cells: List<_Placed>.unmodifiable(placed),
        ),
      );
      placed = <_Placed>[];
      y = 0;
      width = 0;
    }
    placed.add(_Placed(cell: cell, sheet: sheets.length, left: x, top: y));
    x += cell.width;
    shelf = math.max(shelf, cell.height);
    width = math.max(width, x);
  }
  if (placed.isNotEmpty) {
    sheets.add(
      _Sheet(
        width: width,
        height: y + shelf,
        cells: List<_Placed>.unmodifiable(placed),
      ),
    );
  }
  return _Layout(
    sheets: List<_Sheet>.unmodifiable(sheets),
    oversized: oversized,
  );
}
