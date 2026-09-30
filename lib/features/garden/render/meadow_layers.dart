import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';
import 'package:flutter/foundation.dart';

const int meadowLayerBudget = 40000000;
const int meadowLayerPageBudget = 22000000;

const int _bytesPerPixel = 4;
const int _fitSteps = 32;
const double _minimumDensity = 0.05;
const double _edge = 2;
const double _grassGap = 40;
const double _streamRows = 48;
const double _treeGap = 16;
const double _treeReach = 0.3;
const double _slabRows = 12;
const double _slabSpill = 2;
const double _slabKeyLift = 2.5;
const double _mountainFloor = 350;
const double _waterFloor = 640;
const double _groundGradientTop = 300;
const double _bankBlur = 1.2;
const double _reflectionBlurX = 1.8;
const double _reflectionBlurY = 0.8;
const double _reflectionOpacity = 0.72;
const double _reflectionLift = 3;
const double _reflectionFade = 80;
const double _fresnelReach = 70;
const double _waterStopShare = 0.7;
const double _deepOpacity = 0.32;
const double _shallowOpacity = 0.42;
const double _blurReach = 4;
const double _streakTravel = 28;
const int _spriteSheetWidth = 1024;
const int _spritePad = 2;
const double _rippleStroke = 0.9;

const Color _white = Color(0xFFFFFFFF);
const Color _black = Color(0xFF000000);
const Color _outerBank = Color(0xFF66753F);
const double _outerBankOpacity = 0.32;
const Color _bankStrip = Color(0xFF857A52);
const double _bankStripOpacity = 0.62;

const List<double> _reflectionStops = <double>[0, 0.6, 1];
const List<double> _reflectionAlphas = <double>[1, 0.7, 0];
const List<double> _fresnelStops = <double>[0, 0.55, 1];
const List<double> _fresnelAlphas = <double>[0.12, 0.5, 0.9];

const Rect _world = Rect.fromLTWH(0, 0, meadowWorldWidth, meadowWorldHeight);

class MeadowImage {
  const MeadowImage({required this.image, required this.rect});

  final Image image;
  final Rect rect;

  Rect get source =>
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
}

class MeadowStreakStrip {
  const MeadowStreakStrip({
    required this.tile,
    required this.vertices,
    required this.seconds,
    required this.delay,
    required this.travel,
    required this.pixelsPerUnit,
  });

  final Image tile;
  final Vertices vertices;
  final double seconds;
  final double delay;
  final double travel;
  final double pixelsPerUnit;

  Shader shaderAt(double time) {
    final double cycle = (time + delay) / seconds;
    final double shift =
        (travel * (cycle - cycle.floorToDouble()) * pixelsPerUnit) %
        tile.height;
    return ImageShader(
      tile,
      TileMode.clamp,
      TileMode.repeated,
      _affine(1, 0, 0, 1, 0, shift),
      filterQuality: FilterQuality.low,
    );
  }
}

sealed class MeadowLandscapeLayer {
  const MeadowLandscapeLayer();
}

class MeadowImageLayer extends MeadowLandscapeLayer {
  const MeadowImageLayer(this.image);

  final MeadowImage image;
}

class MeadowFallLayer extends MeadowLandscapeLayer {
  const MeadowFallLayer({
    required this.fall,
    required this.body,
    required this.streaks,
    required this.pool,
  });

  final MeadowFall fall;
  final MeadowImage body;
  final List<MeadowStreakStrip> streaks;
  final MeadowImage pool;
}

class MeadowGrassImage {
  const MeadowGrassImage({required this.band, required this.pieces});

  final MeadowGrassBand band;
  final List<MeadowImage> pieces;

  double get sortKey => band.sortKey;

  double get base => band.top + band.height;
}

class MeadowTreeSlab {
  const MeadowTreeSlab({
    required this.sortKey,
    required this.bounds,
    required this.pieces,
  });

  final double sortKey;
  final Rect bounds;
  final List<MeadowImage> pieces;
}

class MeadowSpruceImage {
  const MeadowSpruceImage({required this.spruce, required this.image});

  static const double swayRow = 0.96;

  final MeadowOldSpruce spruce;
  final MeadowImage image;

  double get sortKey => spruce.y;

  Offset get swayOrigin => Offset(
    image.rect.center.dx,
    spruce.y + spruce.frameAtOrigin.top + spruce.frameAtOrigin.height * swayRow,
  );
}

class MeadowCloudImage {
  const MeadowCloudImage({required this.cloud, required this.image});

  final MeadowCloud cloud;
  final MeadowImage image;
}

class MeadowSprite {
  const MeadowSprite({required this.source, required this.anchor});

  final Rect source;
  final Offset anchor;
}

class MeadowWaterSprites {
  const MeadowWaterSprites({
    required this.image,
    required this.density,
    required this.glare,
    required this.glints,
    required this.flows,
    required this.ripples,
  });

  final Image image;
  final double density;
  final MeadowSprite glare;
  final List<MeadowSprite> glints;
  final List<MeadowSprite> flows;
  final List<MeadowSprite> ripples;

  RSTransform place(MeadowSprite sprite, Offset centre, {double scale = 1}) =>
      RSTransform.fromComponents(
        rotation: 0,
        scale: scale / density,
        anchorX: sprite.anchor.dx,
        anchorY: sprite.anchor.dy,
        translateX: centre.dx,
        translateY: centre.dy,
      );
}

class MeadowLandMask {
  const MeadowLandMask({
    required this.image,
    required this.rect,
    required this.filter,
  });

  final Image image;
  final Rect rect;
  final ColorFilter filter;

  void apply(Canvas canvas) {
    canvas
      ..save()
      ..clipRect(rect)
      ..saveLayer(rect, Paint()..blendMode = BlendMode.dstIn)
      ..drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rect,
        Paint()
          ..colorFilter = filter
          ..filterQuality = FilterQuality.low,
      )
      ..restore()
      ..restore();
    canvas.drawRect(
      Rect.fromLTRB(
        rect.left - meadowWorldWidth,
        rect.top - meadowWorldHeight,
        rect.right + meadowWorldWidth,
        rect.top,
      ),
      Paint()..blendMode = BlendMode.clear,
    );
  }
}

class MeadowLayers {
  MeadowLayers({
    required MeadowTerrain terrain,
    required List<MeadowGrassBand> grass,
    required this.density,
  }) : _terrain = terrain,
       _plan = _Plan(terrain, grass),
       _items = _mountainItems(terrain.mountains) {
    _frames = _plan.frames(density);
    _steps = List<void Function()>.unmodifiable(<void Function()>[
      _buildMountainBase,
      _buildNearPack,
      _buildFarPack,
      _buildFogPack,
      _buildGround,
      for (int i = 0; i < _plan.water.length; i++) ...<void Function()>[
        () => _buildWaterTop(i),
        () => _buildWaterPack(i),
        () => _buildWaterShape(i),
      ],
      for (int i = 0; i < _plan.falls.length; i++) () => _buildFall(i),
      for (int i = 0; i < _plan.grass.length; i++) () => _buildGrass(i),
      for (int i = 0; i < _plan.slabs.length; i++) () => _buildSlab(i),
      if (_plan.spruce != null) _buildSpruce,
      _buildStars,
      _buildClouds,
      _buildSprites,
    ]);
    _waterTops = List<Image?>.filled(_plan.water.length, null);
    _waterPacks = List<Image?>.filled(_plan.water.length, null);
    _waterImages = List<Image?>.filled(_plan.water.length, null);
    _fallParts = List<_FallParts?>.filled(_plan.falls.length, null);
    _grassImages = List<MeadowGrassImage?>.filled(_plan.grass.length, null);
    _slabImages = List<MeadowTreeSlab?>.filled(_plan.slabs.length, null);
    _cloudImages = List<Image?>.filled(terrain.sky.clouds.length, null);
    _pieces = List<(_Piece, int)>.unmodifiable(<(_Piece, int)>[
      (_Piece.mountains, 0),
      for (int i = 0; i < _waterImages.length; i++) (_Piece.water, i),
      for (int i = 0; i < _fallParts.length; i++) (_Piece.fall, i),
      for (int i = 0; i < _cloudImages.length; i++) (_Piece.cloud, i),
    ]);
    _drawn = List<List<Object>?>.filled(_pieces.length, null);
    _stale = List<bool>.filled(_pieces.length, false);
  }

  static int bytesAt({
    required MeadowTerrain terrain,
    required List<MeadowGrassBand> grass,
    required double density,
  }) => _Plan(terrain, grass).frames(density).bytes;

  static double fitDensity({
    required MeadowTerrain terrain,
    required List<MeadowGrassBand> grass,
    required double density,
    required int maxBytes,
  }) {
    final _Plan plan = _Plan(terrain, grass);
    if (plan.frames(density).bytes <= maxBytes) {
      return density;
    }
    double low = _minimumDensity;
    double high = density;
    for (int i = 0; i < _fitSteps; i++) {
      final double middle = (low + high) / 2;
      if (plan.frames(middle).bytes <= maxBytes) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }

  final double density;
  final MeadowTerrain _terrain;
  final _Plan _plan;
  final List<_Item> _items;
  late final _Frames _frames;
  late final List<void Function()> _steps;
  final _Paths _paths = _Paths();
  final Set<Image> _held = <Image>{};
  int _next = 0;
  int _geometryRecordings = 0;
  bool _disposed = false;
  MeadowPalette? _palette;
  late final List<(_Piece, int)> _pieces;
  late final List<List<Object>?> _drawn;
  late final List<bool> _stale;
  int _last = -1;
  int _revision = 0;

  Image? _mountainBase;
  Image? _nearPack;
  Image? _farPack;
  Image? _fogPack;
  Image? _mountainImage;
  Image? _groundImage;
  late final List<Image?> _waterTops;
  late final List<Image?> _waterPacks;
  late final List<Image?> _waterImages;
  late final List<_FallParts?> _fallParts;
  late final List<MeadowGrassImage?> _grassImages;
  late final List<MeadowTreeSlab?> _slabImages;
  MeadowSpruceImage? _spruceImage;
  Image? _starImage;
  late final List<Image?> _cloudImages;
  MeadowWaterSprites? _sprites;

  int get geometryRecordings => _geometryRecordings;

  int get imageBytes => _held.fold<int>(
    0,
    (int total, Image image) =>
        total + image.width * image.height * _bytesPerPixel,
  );

  bool get isBuilt => _next >= _steps.length;

  bool get isReady => !_disposed && isBuilt && !_drawn.contains(null);

  bool get isRecolouring => !_disposed && isBuilt && _nextPiece() != null;

  int get revision => _revision;

  MeadowImage get mountains =>
      MeadowImage(image: _mountainImage!, rect: _frames.mountain.rect);

  MeadowImage get ground =>
      MeadowImage(image: _groundImage!, rect: _frames.ground.rect);

  List<MeadowImage> get water => List<MeadowImage>.unmodifiable(<MeadowImage>[
    for (int i = 0; i < _frames.water.length; i++)
      MeadowImage(image: _waterImages[i]!, rect: _frames.water[i].rect),
  ]);

  List<MeadowFallLayer> get falls =>
      List<MeadowFallLayer>.unmodifiable(<MeadowFallLayer>[
        for (int i = 0; i < _plan.falls.length; i++)
          _fallParts[i]!.layer(_plan.falls[i].fall, _frames.falls[i]),
      ]);

  List<MeadowLandscapeLayer> get landscape =>
      List<MeadowLandscapeLayer>.unmodifiable(<MeadowLandscapeLayer>[
        MeadowImageLayer(mountains),
        ...falls,
        MeadowImageLayer(ground),
        for (final MeadowImage image in water) MeadowImageLayer(image),
      ]);

  List<MeadowGrassImage> get grass =>
      List<MeadowGrassImage>.unmodifiable(_grassImages.nonNulls);

  List<MeadowTreeSlab> get trees =>
      List<MeadowTreeSlab>.unmodifiable(_slabImages.nonNulls);

  MeadowSpruceImage? get spruce => _spruceImage;

  MeadowImage get stars =>
      MeadowImage(image: _starImage!, rect: _frames.stars.rect);

  List<MeadowCloudImage> get clouds =>
      List<MeadowCloudImage>.unmodifiable(<MeadowCloudImage>[
        for (int i = 0; i < _cloudImages.length; i++)
          MeadowCloudImage(
            cloud: _terrain.sky.clouds[i],
            image: MeadowImage(
              image: _cloudImages[i]!,
              rect: _frames.clouds[i].rect,
            ),
          ),
      ]);

  MeadowWaterSprites get sprites => _sprites!;

  MeadowLandMask get nightMask => MeadowLandMask(
    image: _farPack!,
    rect: _frames.mountain.rect,
    filter: _channel(_nightChannel, _white, 1),
  );

  void maskToWater(Canvas canvas) {
    final Paint mask = Paint()
      ..blendMode = BlendMode.dstIn
      ..filterQuality = FilterQuality.low;
    canvas.save();
    for (final MeadowImage tile in water) {
      canvas
        ..drawImageRect(tile.image, tile.source, tile.rect, mask)
        ..clipRect(tile.rect, clipOp: ClipOp.difference, doAntiAlias: false);
    }
    canvas
      ..drawPaint(Paint()..blendMode = BlendMode.clear)
      ..restore();
  }

  bool step() {
    if (_disposed) {
      return false;
    }
    if (isBuilt) {
      _drawNext();
    } else {
      _steps[_next]();
      _next++;
      if (isBuilt) {
        _paths.clear();
      }
    }
    return !isBuilt || isRecolouring;
  }

  void buildAll() {
    while (step()) {}
  }

  void recolour(MeadowPalette palette) {
    if (_disposed) {
      return;
    }
    _palette = palette;
    for (int i = 0; i < _pieces.length; i++) {
      final List<Object>? drawn = _drawn[i];
      if (drawn != null &&
          !listEquals(drawn, _colours(_pieces[i].$1, palette))) {
        _stale[i] = true;
      }
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final Image image in _held) {
      image.dispose();
    }
    _held.clear();
    for (final _FallParts? parts in _fallParts) {
      parts?.dispose();
    }
    _paths.clear();
  }

  @visibleForTesting
  Image drawMountainsDirectly(MeadowPalette palette) {
    _geometryRecordings++;
    final _Frame frame = _frames.mountain;
    final _Tint tint = _paletteTint(palette);
    final Image image = _rasterise(frame, (Canvas canvas) {
      _toWorld(canvas, frame);
      for (final _Item item in _items) {
        switch (item) {
          case _Range() || _Shapes():
            _drawFixed(canvas, item, tint);
          case _Fog(:final MeadowFogBand band):
            _drawFogBand(
              canvas,
              band,
              palette.fog,
              palette.fogV * band.strength,
            );
          case _Facets(:final MeadowFacets facets):
            for (final (List<MeadowOutline>, double, double) side
                in <(List<MeadowOutline>, double, double)>[
                  (facets.left, palette.litL, palette.shL),
                  (facets.right, palette.litR, palette.shR),
                ]) {
              _drawFacetFill(canvas, frame, side.$1, palette.lit, side.$2, (
                facets.litTop,
                facets.litBottom,
              ));
              _drawFacetFill(canvas, frame, side.$1, palette.shade, side.$3, (
                facets.shadeTop,
                facets.shadeBottom,
              ));
            }
        }
      }
    });
    return image;
  }

  Image _keep(Image image) {
    _held.add(image);
    return image;
  }

  void _release(Image? image) {
    if (image != null && _held.remove(image)) {
      image.dispose();
    }
  }

  Image _record(_Frame frame, void Function(Canvas canvas) paint) {
    _geometryRecordings++;
    return _keep(
      _rasterise(frame, (Canvas canvas) {
        _toWorld(canvas, frame);
        paint(canvas);
      }),
    );
  }

  void _buildMountainBase() {
    final _Tint tint = _paletteTint(_horizonPalettes.black);
    _mountainBase = _record(_frames.mountain, (Canvas canvas) {
      for (final _Item item in _items) {
        if (item is _Range || item is _Shapes) {
          _drawFixed(canvas, item, tint);
        }
      }
    });
  }

  void _buildNearPack() {
    final _Frame frame = _frames.mountain;
    final int facets = _items.indexWhere((_Item item) => item is _Facets);
    final _Tint grey = _greyTint(_horizonPalettes.weights);
    _nearPack = _record(frame, (Canvas canvas) {
      _packBase(canvas, frame.rect);
      _intoChannel(canvas, frame.rect, _horizonChannel, ratio: true, () {
        for (final _Item item in _items) {
          if (item is _Range || item is _Shapes) {
            _drawFixed(canvas, item, grey);
          }
        }
      });
      _intoChannel(canvas, frame.rect, _highLeftChannel, () {
        _drawOverlayMask(canvas, frame, facets, left: true);
      });
      _intoChannel(canvas, frame.rect, _highRightChannel, () {
        _drawOverlayMask(canvas, frame, facets, left: false);
      });
    });
  }

  void _buildFarPack() {
    final _Frame frame = _frames.mountain;
    final int facets = _items.lastIndexWhere((_Item item) => item is _Facets);
    _farPack = _record(frame, (Canvas canvas) {
      _packBase(canvas, frame.rect);
      _intoChannel(canvas, frame.rect, _massifLeftChannel, () {
        _drawOverlayMask(canvas, frame, facets, left: true);
      });
      _intoChannel(canvas, frame.rect, _massifRightChannel, () {
        _drawOverlayMask(canvas, frame, facets, left: false);
      });
      _intoChannel(canvas, frame.rect, _nightChannel, () {
        final Path land = Path();
        for (final List<Offset> outline in _terrain.sky.nightClip) {
          land.addPolygon(outline, true);
        }
        canvas.drawPath(land, Paint()..color = _white);
      });
    });
  }

  void _buildFogPack() {
    final _Frame frame = _frames.fog;
    final List<int> fogs = <int>[
      for (int i = 0; i < _items.length; i++)
        if (_items[i] is _Fog) i,
    ];
    _fogPack = _record(frame, (Canvas canvas) {
      _packBase(canvas, frame.rect);
      for (int channel = 0; channel < _fogChannels; channel++) {
        _intoChannel(canvas, frame.rect, channel, () {
          _drawOverlayMask(canvas, frame, fogs[channel], left: true);
        });
      }
    });
  }

  void _drawOverlayMask(
    Canvas canvas,
    _Frame frame,
    int index, {
    required bool left,
  }) {
    switch (_items[index]) {
      case _Fog(:final MeadowFogBand band):
        _drawFogBand(canvas, band, _white, 1);
      case _Facets(:final MeadowFacets facets):
        final Paint paint = Paint()..color = _white;
        for (final MeadowOutline outline in left ? facets.left : facets.right) {
          canvas.drawPath(_paths.of(outline), paint);
        }
      case _Range() || _Shapes():
        break;
    }
    canvas.saveLayer(frame.rect, Paint()..blendMode = BlendMode.dstOut);
    final Set<MeadowRange> covered = <MeadowRange>{};
    for (final _Item item in _items.skip(index + 1)) {
      switch (item) {
        case _Range(:final MeadowRange range):
          covered.add(range);
          _drawFixed(canvas, item, _whiteTint);
        case _Shapes(:final MeadowRange? inside)
            when inside == null || !covered.contains(inside):
          _drawFixed(canvas, item, _whiteTint);
        case _Shapes() || _Fog() || _Facets():
          break;
      }
    }
    canvas.restore();
  }

  void _drawFixed(Canvas canvas, _Item item, _Tint tint) {
    switch (item) {
      case _Range(:final MeadowRange range):
        canvas.drawPath(
          _paths.polygon(range, range.outline),
          Paint()
            ..shader = Gradient.linear(
              Offset(0, range.gradientTop),
              Offset(0, range.gradientBottom),
              <Color>[tint(range.topRole, null), tint(range.bottomRole, null)],
            ),
        );
      case _Shapes(:final List<MeadowShape> shapes, :final List<Offset>? clip):
        canvas.save();
        if (clip != null) {
          canvas.clipPath(_paths.polygon(clip, clip));
        }
        final bool layered = item.opacity < 1;
        if (layered) {
          canvas.saveLayer(
            null,
            Paint()..color = Color.fromRGBO(0, 0, 0, item.opacity),
          );
        }
        for (final MeadowShape shape in shapes) {
          _drawShape(canvas, shape, tint);
        }
        if (layered) {
          canvas.restore();
        }
        canvas.restore();
      case _Fog() || _Facets():
        break;
    }
  }

  void _drawShape(
    Canvas canvas,
    MeadowShape shape,
    _Tint tint, {
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    final Color colour = tint(shape.role, shape.colour);
    final Paint paint = Paint()
      ..color = colour.withValues(alpha: colour.a * shape.opacity)
      ..blendMode = blendMode;
    final double? width = shape.strokeWidth;
    if (width != null) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = shape.rounded ? StrokeCap.round : StrokeCap.butt
        ..strokeJoin = shape.rounded ? StrokeJoin.round : StrokeJoin.miter;
    }
    canvas.drawPath(_paths.shape(shape), paint);
  }

  void _drawShapes(Canvas canvas, Iterable<MeadowShape> shapes, _Tint tint) {
    for (final MeadowShape shape in shapes) {
      _drawShape(canvas, shape, tint);
    }
  }

  void _drawFogBand(
    Canvas canvas,
    MeadowFogBand band,
    Color colour,
    double opacity,
  ) {
    canvas.drawRect(
      band.rect,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, band.rect.top),
          Offset(0, band.rect.bottom),
          <Color>[
            for (final double alpha in MeadowFogBand.opacities)
              colour.withValues(alpha: colour.a * alpha * opacity),
          ],
          MeadowFogBand.stops,
        ),
    );
  }

  void _drawFacetFill(
    Canvas canvas,
    _Frame frame,
    List<MeadowOutline> outlines,
    Color colour,
    double opacity,
    (double, double) fade,
  ) {
    if (opacity <= 0 || outlines.isEmpty) {
      return;
    }
    canvas.saveLayer(
      frame.rect,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    final Paint paint = Paint()
      ..shader = Gradient.linear(
        Offset(0, fade.$1),
        Offset(0, fade.$2),
        <Color>[colour, colour.withValues(alpha: 0)],
      );
    for (final MeadowOutline outline in outlines) {
      canvas.drawPath(_paths.of(outline), paint);
    }
    canvas.restore();
  }

  void _buildGround() {
    final MeadowGroundDressing ground = _terrain.ground;
    final MeadowWater water = _terrain.water;
    final _Frame frame = _frames.ground;
    _groundImage = _record(frame, (Canvas canvas) {
      canvas.drawPath(
        _paths.polygon(ground.groundOutline, ground.groundOutline),
        Paint()
          ..shader = Gradient.linear(
            const Offset(0, _groundGradientTop),
            const Offset(0, meadowWorldHeight),
            <Color>[
              for (final MeadowGradientStop stop in ground.groundStops)
                stop.colour,
            ],
            <double>[
              for (final MeadowGradientStop stop in ground.groundStops)
                stop.offset,
            ],
          ),
      );
      _drawShapes(canvas, ground.mottles, _ownTint);
      _blurred(canvas, frame, _bankBlur, () {
        final Paint bank = Paint()
          ..color = _outerBank.withValues(alpha: _outerBankOpacity);
        canvas
          ..drawPath(_paths.band(water.outerLeft, water.bankLeft), bank)
          ..drawPath(_paths.band(water.bankRight, water.outerRight), bank);
        _drawShapes(canvas, ground.wetShore, _ownTint);
      });
      final Paint strip = Paint()
        ..color = _bankStrip.withValues(alpha: _bankStripOpacity);
      canvas
        ..drawPath(_paths.band(water.bankLeft, water.edgeLeft), strip)
        ..drawPath(_paths.band(water.edgeRight, water.bankRight), strip);
      _drawShapes(canvas, ground.pebbles, _ownTint);
      _drawWaterside(canvas);
    });
  }

  void _drawWaterside(Canvas canvas) {
    final MeadowGroundDressing ground = _terrain.ground;
    _drawShape(canvas, ground.farShore, _ownTint);
    _drawShapes(canvas, ground.streamEdges, _ownTint);
    _drawShapes(canvas, ground.stones, _ownTint);
    _drawShapes(canvas, ground.reeds, _ownTint);
  }

  void _buildWaterTop(int index) {
    _waterTops[index] = _record(_frames.water[index], _drawWaterside);
  }

  void _buildWaterPack(int index) {
    final MeadowWater water = _terrain.water;
    final _Frame frame = _frames.water[index];
    _waterPacks[index] = _record(frame, (Canvas canvas) {
      final Paint white = Paint()..color = _white;
      _packBase(canvas, frame.rect);
      _intoChannel(canvas, frame.rect, _deepChannel, () {
        _blurred(canvas, frame, _bankBlur, () {
          canvas.drawPath(
            _paths.band(water.innerLeft, water.innerRight),
            white,
          );
        });
      });
      _intoChannel(canvas, frame.rect, _shallowChannel, () {
        _blurred(canvas, frame, _bankBlur, () {
          canvas
            ..drawPath(_paths.band(water.edgeLeft, water.halfLeft), white)
            ..drawPath(_paths.band(water.halfRight, water.edgeRight), white);
        });
      });
      _intoChannel(canvas, frame.rect, _rippleChannel, () {
        _drawShapes(canvas, _terrain.ground.lakeRipples, _whiteTint);
      });
    });
  }

  void _buildWaterShape(int index) {
    final MeadowWater water = _terrain.water;
    _waterImages[index] = _record(_frames.water[index], (Canvas canvas) {
      final Paint white = Paint()..color = _white;
      canvas
        ..drawPath(_paths.polygon(water.lakeOutline, water.lakeOutline), white)
        ..drawPath(_paths.band(water.edgeLeft, water.edgeRight), white);
    });
  }

  void _buildFall(int index) {
    final _FallPlan plan = _plan.falls[index];
    final _FallFrames frames = _frames.falls[index];
    final MeadowFall fall = plan.fall;
    final List<MeadowShape> sheet = fall.sheet;
    final Image body = _record(frames.body, (Canvas canvas) {
      _packBase(canvas, frames.body.rect);
      _intoChannel(canvas, frames.body.rect, _sheetChannel, () {
        _drawShape(canvas, sheet.first, _whiteTint);
        for (final MeadowShape shape in sheet.skip(1)) {
          _drawShape(canvas, shape, _whiteTint, blendMode: BlendMode.dstOut);
        }
      });
      _intoChannel(canvas, frames.body.rect, _glossChannel, () {
        _drawShapes(canvas, sheet.skip(1), _whiteTint);
      });
    });
    final Image pool = _record(frames.pool, (Canvas canvas) {
      _drawShape(canvas, fall.pool, _whiteTint);
    });
    final List<Image> tiles = <Image>[
      for (int i = 0; i < fall.streaks.length; i++)
        _recordStreakTile(fall.streaks[i], frames.streaks[i]),
    ];
    _fallParts[index] = _FallParts(
      bodyPack: body,
      pool: pool,
      tiles: tiles,
      vertices: <Vertices>[
        for (int i = 0; i < fall.streaks.length; i++)
          _streakVertices(fall.centreLine, frames.streaks[i]),
      ],
    );
  }

  Image _recordStreakTile(MeadowStreak streak, _StreakFrame frame) {
    _geometryRecordings++;
    final MeadowShape shape = streak.shape;
    final double radius = frame.stroke * frame.density / 2;
    final double along = frame.stroke / 2 * frame.pixelsPerUnit;
    final double dash = shape.dash.first * frame.pixelsPerUnit;
    final double centre = frame.width / 2;
    return _keep(
      _rasterise(frame.frame, (Canvas canvas) {
        final Paint paint = Paint()
          ..color = _white.withValues(alpha: shape.opacity);
        for (final double shift in <double>[
          -frame.height.toDouble(),
          0,
          frame.height.toDouble(),
        ]) {
          canvas.drawRRect(
            RRect.fromLTRBXY(
              centre - radius,
              shift - along,
              centre + radius,
              shift + dash + along,
              radius,
              along,
            ),
            paint,
          );
        }
      }),
    );
  }

  Vertices _streakVertices(List<Offset> line, _StreakFrame frame) {
    final double half = frame.width / frame.density / 2;
    final List<Offset> positions = <Offset>[];
    final List<Offset> texture = <Offset>[];
    double travelled = 0;
    for (int i = 0; i < line.length; i++) {
      if (i > 0) {
        travelled += (line[i] - line[i - 1]).distance;
      }
      final Offset tangent =
          line[math.min(i + 1, line.length - 1)] - line[math.max(i - 1, 0)];
      final double length = tangent.distance;
      final Offset normal = length == 0
          ? const Offset(1, 0)
          : Offset(-tangent.dy / length, tangent.dx / length);
      final double v = travelled * frame.pixelsPerUnit;
      positions
        ..add(line[i] + normal * half)
        ..add(line[i] - normal * half);
      texture
        ..add(Offset(0, v))
        ..add(Offset(frame.width.toDouble(), v));
    }
    return Vertices(
      VertexMode.triangleStrip,
      positions,
      textureCoordinates: texture,
    );
  }

  void _buildGrass(int index) {
    final _GrassPlan plan = _plan.grass[index];
    final MeadowGrassBand band = plan.band;
    final List<_Frame> frames = _frames.grass[index];
    _grassImages[index] = MeadowGrassImage(
      band: band,
      pieces: List<MeadowImage>.unmodifiable(<MeadowImage>[
        for (int i = 0; i < plan.pieces.length; i++)
          MeadowImage(
            image: _record(frames[i], (Canvas canvas) {
              for (int shade = 0; shade < band.colours.length; shade++) {
                final Path blades = Path();
                for (final MeadowGrassStroke stroke
                    in plan.pieces[i].strokes[shade]) {
                  blades
                    ..moveTo(stroke.start.dx, stroke.start.dy)
                    ..quadraticBezierTo(
                      stroke.control.dx,
                      stroke.control.dy,
                      stroke.end.dx,
                      stroke.end.dy,
                    );
                }
                canvas.drawPath(
                  blades,
                  Paint()
                    ..color = band.colours[shade]
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = band.strokeWidth
                    ..strokeCap = StrokeCap.round
                    ..strokeJoin = StrokeJoin.round,
                );
              }
            }),
            rect: frames[i].rect,
          ),
      ]),
    );
  }

  void _buildSlab(int index) {
    final _SlabPlan plan = _plan.slabs[index];
    final List<_Frame> frames = _frames.slabs[index];
    _slabImages[index] = MeadowTreeSlab(
      sortKey: plan.sortKey,
      bounds: plan.bounds,
      pieces: List<MeadowImage>.unmodifiable(<MeadowImage>[
        for (int i = 0; i < plan.clusters.length; i++)
          MeadowImage(
            image: _record(frames[i], (Canvas canvas) {
              for (final MeadowTree tree in plan.clusters[i].trees) {
                _drawShapes(canvas, tree.art, _ownTint);
              }
            }),
            rect: frames[i].rect,
          ),
      ]),
    );
  }

  void _buildSpruce() {
    final MeadowOldSpruce spruce = _terrain.forest.oldSpruce!;
    final _Frame frame = _frames.spruce!;
    _spruceImage = MeadowSpruceImage(
      spruce: spruce,
      image: MeadowImage(
        image: _record(frame, (Canvas canvas) {
          canvas.translate(spruce.x, spruce.y);
          _drawShapes(canvas, spruce.artAtOrigin, _ownTint);
        }),
        rect: frame.rect,
      ),
    );
  }

  void _buildStars() {
    _starImage = _record(_frames.stars, (Canvas canvas) {
      for (final MeadowStar star in _terrain.sky.stars) {
        canvas.drawCircle(
          star.centre,
          star.radius,
          Paint()
            ..color = MeadowStar.colour.withValues(
              alpha: MeadowStar.colour.a * star.opacity,
            ),
        );
      }
    });
  }

  void _buildClouds() {
    final List<MeadowCloud> clouds = _terrain.sky.clouds;
    for (int i = 0; i < clouds.length; i++) {
      final MeadowCloud cloud = clouds[i];
      _cloudImages[i] = _record(_frames.clouds[i], (Canvas canvas) {
        canvas.saveLayer(
          null,
          Paint()..color = Color.fromRGBO(0, 0, 0, cloud.opacity),
        );
        final Paint white = Paint()..color = _white;
        for (final MeadowEllipse puff in cloud.puffs) {
          canvas.drawPath(_paths.of(puff), white);
        }
        canvas.restore();
      });
    }
  }

  void _buildSprites() {
    final _SpriteSheet sheet = _frames.sprites;
    _geometryRecordings++;
    final Image image = _keep(
      _rasterise(sheet.frame, (Canvas canvas) {
        for (int i = 0; i < sheet.sprites.length; i++) {
          final MeadowSprite sprite = sheet.sprites[i];
          final MeadowEllipse ellipse = _plan.sprites[i].ellipse;
          canvas
            ..save()
            ..translate(sprite.anchor.dx, sprite.anchor.dy)
            ..scale(sheet.frame.density);
          final Rect oval = Rect.fromCenter(
            center: Offset.zero,
            width: ellipse.radiusX * 2,
            height: ellipse.radiusY * 2,
          );
          canvas.drawOval(
            oval,
            _plan.sprites[i].ring
                ? (Paint()
                    ..color = _white
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = _rippleStroke)
                : (Paint()..color = _white),
          );
          canvas.restore();
        }
      }),
    );
    List<MeadowSprite> of(_SpriteKind kind) =>
        List<MeadowSprite>.unmodifiable(<MeadowSprite>[
          for (int i = 0; i < sheet.sprites.length; i++)
            if (_plan.sprites[i].kind == kind) sheet.sprites[i],
        ]);
    _sprites = MeadowWaterSprites(
      image: image,
      density: sheet.frame.density,
      glare: of(_SpriteKind.glare).single,
      glints: of(_SpriteKind.glint),
      flows: of(_SpriteKind.flow),
      ripples: of(_SpriteKind.ripple),
    );
  }

  int? _nextPiece() {
    if (_palette == null) {
      return null;
    }
    for (int offset = 1; offset <= _pieces.length; offset++) {
      final int piece = (_last + offset) % _pieces.length;
      if (_drawn[piece] == null || _stale[piece]) {
        return piece;
      }
    }
    return null;
  }

  List<Object> _colours(_Piece kind, MeadowPalette palette) => switch (kind) {
    _Piece.mountains => <Object>[
      palette.skyHorizon,
      palette.fog,
      palette.fogV,
      palette.lit,
      palette.shade,
      palette.litL,
      palette.litR,
      palette.shL,
      palette.shR,
    ],
    _Piece.water => <Object>[
      palette.lk1,
      palette.lk2,
      palette.st2,
      palette.wDeep,
      palette.wSh,
      palette.lkHi,
    ],
    _Piece.fall => <Object>[palette.wf, palette.wfHi],
    _Piece.cloud => <Object>[palette.cloudTop, palette.cloudBottom],
  };

  void _drawNext() {
    final MeadowPalette? palette = _palette;
    final int? piece = _nextPiece();
    if (palette == null || piece == null) {
      return;
    }
    final (_Piece kind, int index) = _pieces[piece];
    switch (kind) {
      case _Piece.mountains:
        _drawMountains(palette);
      case _Piece.water:
        _drawWater(index, palette);
      case _Piece.fall:
        _fallParts[index] = _fallParts[index]!.recoloured(
          this,
          palette,
          _frames.falls[index],
        );
      case _Piece.cloud:
        _drawCloud(index, palette);
    }
    _revision++;
    _drawn[piece] = _colours(kind, palette);
    _stale[piece] = false;
    _last = piece;
  }

  void _drawMountains(MeadowPalette palette) {
    final Image previous = _mountainImage ?? _mountainBase!;
    final Image next = _keep(_composeMountains(palette));
    if (previous != _mountainBase) {
      _release(previous);
    }
    _mountainImage = next;
    for (int i = 0; i < _pieces.length; i++) {
      if (_pieces[i].$1 == _Piece.water) {
        _stale[i] = true;
      }
    }
  }

  void _drawWater(int index, MeadowPalette palette) {
    final Image previous = _waterImages[index]!;
    _waterImages[index] = _keep(_composeWater(index, palette, previous));
    _release(previous);
  }

  void _drawCloud(int index, MeadowPalette palette) {
    final Image previous = _cloudImages[index]!;
    final _Frame frame = _frames.clouds[index];
    final MeadowCloud cloud = _terrain.sky.clouds[index];
    _cloudImages[index] = _keep(
      _repaint(
        previous,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, frame.row(cloud.gradientTop)),
            Offset(0, frame.row(cloud.gradientBottom)),
            <Color>[palette.cloudTop, palette.cloudBottom],
          ),
      ),
    );
    _release(previous);
  }

  Image _composeMountains(MeadowPalette palette) {
    final _Frame frame = _frames.mountain;
    final Rect all = frame.pixels;
    final Image base = _mountainBase!;
    final Image near = _nearPack!;
    final Image far = _farPack!;
    final List<MeadowFogBand> bands = _terrain.mountains.fogBands;
    final MeadowFacets high = _terrain.mountains.highFacets;
    final MeadowFacets massif = _terrain.mountains.massifFacets;
    return _rasterise(frame, (Canvas canvas) {
      canvas
        ..saveLayer(all, Paint())
        ..drawImage(base, Offset.zero, Paint()..colorFilter = _unpremultiply)
        ..saveLayer(all, Paint()..blendMode = BlendMode.plus)
        ..drawImage(
          near,
          Offset.zero,
          Paint()
            ..colorFilter = _channel(_horizonChannel, palette.skyHorizon, 1),
        )
        ..restore()
        ..drawImage(base, Offset.zero, Paint()..blendMode = BlendMode.dstIn)
        ..restore();
      _composeFog(canvas, 0, bands[0], palette);
      _composeFacets(
        canvas,
        frame,
        near,
        (_highLeftChannel, _highRightChannel),
        high,
        palette,
      );
      _composeFog(canvas, 1, bands[1], palette);
      _composeFacets(
        canvas,
        frame,
        far,
        (_massifLeftChannel, _massifRightChannel),
        massif,
        palette,
      );
      canvas
        ..save()
        ..scale(frame.density)
        ..translate(-frame.origin.dx, -frame.origin.dy);
      _drawFogBand(
        canvas,
        bands[2],
        palette.fog,
        palette.fogV * bands[2].strength,
      );
      canvas.restore();
    });
  }

  void _composeFog(
    Canvas canvas,
    int channel,
    MeadowFogBand band,
    MeadowPalette palette,
  ) {
    final double opacity = palette.fog.a * palette.fogV * band.strength;
    if (opacity <= 0) {
      return;
    }
    canvas.drawImage(
      _fogPack!,
      Offset(0, _frames.mountain.row(_frames.fog.origin.dy).roundToDouble()),
      Paint()..colorFilter = _channel(channel, palette.fog, opacity),
    );
  }

  void _composeFacets(
    Canvas canvas,
    _Frame frame,
    Image pack,
    (int, int) channels,
    MeadowFacets facets,
    MeadowPalette palette,
  ) {
    for (final (int, double, double) side in <(int, double, double)>[
      (channels.$1, palette.litL, palette.shL),
      (channels.$2, palette.litR, palette.shR),
    ]) {
      _composeFade(canvas, frame, pack, side.$1, palette.lit, side.$2, (
        facets.litTop,
        facets.litBottom,
      ));
      _composeFade(canvas, frame, pack, side.$1, palette.shade, side.$3, (
        facets.shadeTop,
        facets.shadeBottom,
      ));
    }
  }

  void _composeFade(
    Canvas canvas,
    _Frame frame,
    Image pack,
    int channel,
    Color colour,
    double opacity,
    (double, double) fade,
  ) {
    if (opacity <= 0) {
      return;
    }
    final Rect all = frame.pixels;
    canvas
      ..saveLayer(all, Paint()..color = Color.fromRGBO(0, 0, 0, opacity))
      ..drawImage(
        pack,
        Offset.zero,
        Paint()..colorFilter = _channel(channel, _white, 1),
      )
      ..drawRect(
        all,
        Paint()
          ..blendMode = BlendMode.srcIn
          ..shader = Gradient.linear(
            Offset(0, frame.row(fade.$1)),
            Offset(0, frame.row(fade.$2)),
            <Color>[colour, colour.withValues(alpha: 0)],
          ),
      )
      ..restore();
  }

  Image _composeWater(int index, MeadowPalette palette, Image shape) {
    final MeadowWater water = _terrain.water;
    final _Frame frame = _frames.water[index];
    final Rect all = frame.pixels;
    final double far = water.lakeFarY;
    final double near = water.lakeNearY;
    final double stop =
        ((near - far) / (_waterFloor - far) * _waterStopShare * 1000)
            .roundToDouble() /
        1000;
    return _rasterise(frame, (Canvas canvas) {
      canvas
        ..saveLayer(all, Paint())
        ..drawRect(
          all,
          Paint()
            ..shader = Gradient.linear(
              Offset(0, frame.row(far)),
              Offset(0, frame.row(_waterFloor)),
              <Color>[palette.lk1, palette.lk2, palette.st2],
              <double>[0, stop, 1],
            ),
        );
      if (frame.origin.dy < near + _reflectionFade) {
        _composeReflection(canvas, frame, far, near);
      }
      canvas
        ..drawRect(
          all,
          Paint()
            ..shader = Gradient.linear(
              Offset(0, frame.row(far)),
              Offset(0, frame.row(near + _fresnelReach)),
              <Color>[
                for (final double alpha in _fresnelAlphas)
                  palette.lk2.withValues(alpha: palette.lk2.a * alpha),
              ],
              _fresnelStops,
            ),
        )
        ..saveLayer(all, Paint())
        ..saveLayer(all, Paint()..blendMode = BlendMode.plus)
        ..drawImage(
          _waterPacks[index]!,
          Offset.zero,
          Paint()
            ..colorFilter = _channel(_deepChannel, palette.wDeep, _deepOpacity),
        )
        ..restore()
        ..saveLayer(all, Paint()..blendMode = BlendMode.plus)
        ..drawImage(
          _waterPacks[index]!,
          Offset.zero,
          Paint()
            ..colorFilter = _channel(
              _shallowChannel,
              palette.wSh,
              _shallowOpacity,
            ),
        )
        ..restore()
        ..restore()
        ..drawImage(
          _waterPacks[index]!,
          Offset.zero,
          Paint()..colorFilter = _channel(_rippleChannel, palette.lkHi, 1),
        )
        ..drawImage(_waterTops[index]!, Offset.zero, Paint())
        ..drawImage(shape, Offset.zero, Paint()..blendMode = BlendMode.dstIn)
        ..restore();
    });
  }

  void _composeReflection(
    Canvas canvas,
    _Frame frame,
    double far,
    double near,
  ) {
    final _Frame mountains = _frames.mountain;
    final Rect all = frame.pixels;
    canvas
      ..saveLayer(all, Paint())
      ..saveLayer(
        all.inflate(_reflectionBlurX * frame.density * _blurReach),
        Paint()
          ..color = const Color.fromRGBO(0, 0, 0, _reflectionOpacity)
          ..imageFilter = ImageFilter.blur(
            sigmaX: _reflectionBlurX * frame.density,
            sigmaY: _reflectionBlurY * frame.density,
            tileMode: TileMode.decal,
          ),
      )
      ..translate(
        (mountains.origin.dx - frame.origin.dx) * frame.density,
        (2 * far - _reflectionLift - mountains.origin.dy - frame.origin.dy) *
            frame.density,
      )
      ..scale(1, -1)
      ..drawImage(
        _mountainImage!,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.low,
      )
      ..restore()
      ..drawRect(
        all,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = Gradient.linear(
            Offset(0, frame.row(far)),
            Offset(0, frame.row(near + _reflectionFade)),
            <Color>[
              for (final double alpha in _reflectionAlphas)
                _white.withValues(alpha: alpha),
            ],
            _reflectionStops,
          ),
      )
      ..restore();
  }

  Image _repaint(Image previous, Paint fill) {
    final Rect all = Rect.fromLTWH(
      0,
      0,
      previous.width.toDouble(),
      previous.height.toDouble(),
    );
    final PictureRecorder recorder = PictureRecorder();
    Canvas(recorder, all)
      ..drawRect(all, fill)
      ..drawImage(previous, Offset.zero, Paint()..blendMode = BlendMode.dstIn);
    final Picture picture = recorder.endRecording();
    final Image image = picture.toImageSync(previous.width, previous.height);
    picture.dispose();
    return image;
  }

  Image _repaintFlat(Image previous, Color colour) =>
      _repaint(previous, Paint()..color = colour);
}

class _FallParts {
  const _FallParts({
    required this.bodyPack,
    required this.pool,
    required this.tiles,
    required this.vertices,
    this.body,
  });

  final Image bodyPack;
  final Image? body;
  final Image pool;
  final List<Image> tiles;
  final List<Vertices> vertices;

  _FallParts recoloured(
    MeadowLayers layers,
    MeadowPalette palette,
    _FallFrames frames,
  ) {
    final Image nextBody = layers._keep(
      _rasterise(frames.body, (Canvas canvas) {
        canvas
          ..saveLayer(frames.body.pixels, Paint()..blendMode = BlendMode.plus)
          ..drawImage(
            bodyPack,
            Offset.zero,
            Paint()..colorFilter = _channel(_sheetChannel, palette.wf, 1),
          )
          ..restore()
          ..saveLayer(frames.body.pixels, Paint()..blendMode = BlendMode.plus)
          ..drawImage(
            bodyPack,
            Offset.zero,
            Paint()..colorFilter = _channel(_glossChannel, palette.wfHi, 1),
          )
          ..restore();
      }),
    );
    final Image nextPool = layers._keep(
      layers._repaintFlat(pool, palette.wfHi),
    );
    final List<Image> nextTiles = <Image>[
      for (final Image tile in tiles)
        layers._keep(layers._repaintFlat(tile, palette.wfHi)),
    ];
    layers
      .._release(body)
      .._release(pool);
    for (final Image tile in tiles) {
      layers._release(tile);
    }
    return _FallParts(
      bodyPack: bodyPack,
      body: nextBody,
      pool: nextPool,
      tiles: nextTiles,
      vertices: vertices,
    );
  }

  MeadowFallLayer layer(MeadowFall fall, _FallFrames frames) => MeadowFallLayer(
    fall: fall,
    body: MeadowImage(image: body!, rect: frames.body.rect),
    streaks: List<MeadowStreakStrip>.unmodifiable(<MeadowStreakStrip>[
      for (int i = 0; i < tiles.length; i++)
        MeadowStreakStrip(
          tile: tiles[i],
          vertices: vertices[i],
          seconds: fall.streaks[i].period,
          delay: fall.streaks[i].phase,
          travel: _streakTravel,
          pixelsPerUnit: frames.streaks[i].pixelsPerUnit,
        ),
    ]),
    pool: MeadowImage(image: pool, rect: frames.pool.rect),
  );

  void dispose() {
    for (final Vertices mesh in vertices) {
      mesh.dispose();
    }
  }
}

const int _horizonChannel = 0;
const int _highLeftChannel = 1;
const int _highRightChannel = 2;
const int _massifLeftChannel = 0;
const int _massifRightChannel = 1;
const int _nightChannel = 2;
const int _fogChannels = 2;
const int _deepChannel = 0;
const int _shallowChannel = 1;
const int _rippleChannel = 2;
const int _sheetChannel = 0;
const int _glossChannel = 1;

typedef _Tint = Color Function(MeadowRole? role, Color? colour);

Color _whiteTint(MeadowRole? role, Color? colour) => _white;

Color _ownTint(MeadowRole? role, Color? colour) => colour ?? _black;

_Tint _paletteTint(MeadowPalette palette) =>
    (MeadowRole? role, Color? colour) =>
        role == null ? colour ?? _black : _roleColour(palette, role);

_Tint _greyTint(Map<MeadowRole, double> weights) =>
    (MeadowRole? role, Color? colour) {
      final double weight = role == null ? 0 : weights[role] ?? 0;
      return Color.from(alpha: 1, red: weight, green: weight, blue: weight);
    };

Color _roleColour(MeadowPalette palette, MeadowRole role) => switch (role) {
  MeadowRole.m0 => palette.m0,
  MeadowRole.m0b => palette.m0b,
  MeadowRole.m1t => palette.m1t,
  MeadowRole.m1b => palette.m1b,
  MeadowRole.r1 => palette.r1,
  MeadowRole.r2 => palette.r2,
  MeadowRole.snow => palette.snow,
  MeadowRole.lit => palette.lit,
  MeadowRole.shade => palette.shade,
  MeadowRole.m1d => palette.m1d,
  MeadowRole.rS => palette.rS,
  MeadowRole.rL => palette.rL,
  MeadowRole.scr => palette.scr,
  MeadowRole.fo1 => palette.fo1,
  MeadowRole.fo2 => palette.fo2,
  MeadowRole.fo3 => palette.fo3,
  MeadowRole.wf => palette.wf,
  MeadowRole.wfHi => palette.wfHi,
  MeadowRole.fog => palette.fog,
  MeadowRole.lkHi => palette.lkHi,
};

class _HorizonPalettes {
  _HorizonPalettes()
    : black = _horizonPalette(_black),
      weights = _weights(_horizonPalette(_black), _horizonPalette(_white));

  final MeadowPalette black;
  final Map<MeadowRole, double> weights;

  static Map<MeadowRole, double> _weights(
    MeadowPalette black,
    MeadowPalette white,
  ) => Map<MeadowRole, double>.unmodifiable(<MeadowRole, double>{
    for (final MeadowRole role in MeadowRole.values)
      role: _weight(_roleColour(black, role), _roleColour(white, role)),
  });

  static double _weight(Color black, Color white) =>
      ((white.r - black.r) + (white.g - black.g) + (white.b - black.b)) / 3;
}

final _HorizonPalettes _horizonPalettes = _HorizonPalettes();

MeadowPalette _horizonPalette(Color horizon) => MeadowPalette.from(
  sky: SkyScene(
    sunAltitude: 0,
    moonAltitude: 0,
    gradient: SkyGradient(top: horizon, middle: horizon, horizon: horizon),
    night: 0,
    warm: 0,
    low: 0,
    sunX: 0.5,
    sunY: 0.5,
    sunColour: horizon,
    warmGlow: horizon,
    moonX: 0.5,
    moonY: 0.5,
    moonUp: false,
    moonFraction: 0,
    moonPhase: 0,
    moonOpacity: 0,
    moonGlowAlpha: 0,
    moonShadeOffset: 0,
    moonPool: horizon,
    nightEdge: horizon,
    warmTint: null,
    starsOpacity: 0,
    hazeOpacity: 0,
    firefliesOpacity: 0,
    dayLifeOpacity: 0,
    captionColour: horizon,
    phaseName: '',
  ),
  morning: false,
  heavyShare: 0,
);

final ColorFilter _unpremultiply = _colourMatrix(
  <double>[1, 0, 0, 0, 0],
  <double>[0, 1, 0, 0, 0],
  <double>[0, 0, 1, 0, 0],
  <double>[0, 0, 0, 0, 255],
);

ColorFilter _colourMatrix(
  List<double> red,
  List<double> green,
  List<double> blue,
  List<double> alpha,
) => ColorFilter.matrix(<double>[...red, ...green, ...blue, ...alpha]);

ColorFilter _maskInto(int channel) => _colourMatrix(
  <double>[channel == 0 ? 1 : 0, 0, 0, 0, 0],
  <double>[channel == 1 ? 1 : 0, 0, 0, 0, 0],
  <double>[channel == 2 ? 1 : 0, 0, 0, 0, 0],
  <double>[0, 0, 0, 1, 0],
);

ColorFilter _ratioInto(int channel) => _colourMatrix(
  <double>[channel == 0 ? 1 : 0, 0, 0, 0, 0],
  <double>[channel == 1 ? 1 : 0, 0, 0, 0, 0],
  <double>[channel == 2 ? 1 : 0, 0, 0, 0, 0],
  <double>[0, 0, 0, 0, 255],
);

ColorFilter _channel(int channel, Color colour, double alpha) => _colourMatrix(
  <double>[0, 0, 0, colour.r, 0],
  <double>[0, 0, 0, colour.g, 0],
  <double>[0, 0, 0, colour.b, 0],
  <double>[
    channel == 0 ? alpha : 0,
    channel == 1 ? alpha : 0,
    channel == 2 ? alpha : 0,
    0,
    0,
  ],
);

Float64List _affine(
  double xx,
  double yx,
  double xy,
  double yy,
  double dx,
  double dy,
) => Float64List(16)
  ..[0] = xx
  ..[1] = yx
  ..[4] = xy
  ..[5] = yy
  ..[10] = 1
  ..[12] = dx
  ..[13] = dy
  ..[15] = 1;

void _packBase(Canvas canvas, Rect bounds) {
  canvas.drawRect(bounds, Paint()..color = _black);
}

void _intoChannel(
  Canvas canvas,
  Rect bounds,
  int channel,
  void Function() draw, {
  bool ratio = false,
}) {
  canvas.saveLayer(
    bounds,
    Paint()
      ..blendMode = BlendMode.plus
      ..colorFilter = ratio ? _ratioInto(channel) : _maskInto(channel),
  );
  draw();
  canvas.restore();
}

void _toWorld(Canvas canvas, _Frame frame) {
  canvas
    ..scale(frame.density)
    ..translate(-frame.origin.dx, -frame.origin.dy);
}

void _blurred(Canvas canvas, _Frame frame, double sigma, void Function() draw) {
  final double pixels = sigma * frame.density;
  canvas
    ..save()
    ..translate(frame.origin.dx, frame.origin.dy)
    ..scale(1 / frame.density)
    ..saveLayer(
      frame.pixels.inflate(pixels * _blurReach),
      Paint()
        ..imageFilter = ImageFilter.blur(
          sigmaX: pixels,
          sigmaY: pixels,
          tileMode: TileMode.decal,
        ),
    )
    ..scale(frame.density)
    ..translate(-frame.origin.dx, -frame.origin.dy);
  draw();
  canvas
    ..restore()
    ..restore();
}

Image _rasterise(_Frame frame, void Function(Canvas canvas) paint) {
  final PictureRecorder recorder = PictureRecorder();
  paint(Canvas(recorder, frame.pixels));
  final Picture picture = recorder.endRecording();
  final Image image = picture.toImageSync(frame.width, frame.height);
  picture.dispose();
  return image;
}

sealed class _Item {
  const _Item();
}

class _Range extends _Item {
  const _Range(this.range);

  final MeadowRange range;
}

class _Shapes extends _Item {
  const _Shapes(this.shapes, {this.clip, this.opacity = 1, this.inside});

  final List<MeadowShape> shapes;
  final List<Offset>? clip;
  final double opacity;
  final MeadowRange? inside;
}

class _Fog extends _Item {
  const _Fog(this.band);

  final MeadowFogBand band;
}

class _Facets extends _Item {
  const _Facets(this.facets);

  final MeadowFacets facets;
}

List<_Item> _mountainItems(MeadowMountains mountains) =>
    List<_Item>.unmodifiable(<_Item>[
      _Range(mountains.far),
      _Fog(mountains.fogBands[0]),
      _Range(mountains.high),
      _Shapes(
        mountains.snowfield.shapes,
        clip: mountains.snowfield.clip,
        opacity: mountains.snowfield.opacity,
        inside: mountains.high,
      ),
      _Facets(mountains.highFacets),
      _Shapes(<MeadowShape>[mountains.highGullies]),
      _Fog(mountains.fogBands[1]),
      _Range(mountains.massif),
      _Shapes(
        mountains.strata.shapes,
        clip: mountains.strata.clip,
        opacity: mountains.strata.opacity,
        inside: mountains.massif,
      ),
      _Shapes(
        mountains.scree.shapes,
        clip: mountains.scree.clip,
        opacity: mountains.scree.opacity,
      ),
      _Shapes(mountains.couloirs),
      _Facets(mountains.massifFacets),
      _Shapes(<MeadowShape>[mountains.massifGullies]),
      _Shapes(mountains.skirt),
      for (final MeadowFall fall in mountains.falls) _Shapes(fall.gorge),
      _Fog(mountains.fogBands[2]),
    ]);

class _Paths {
  final Map<Object, Path> _cache = <Object, Path>{};
  final Map<Object, Path> _dashed = <Object, Path>{};

  Path of(MeadowGeometry geometry) =>
      _cache.putIfAbsent(geometry, () => _geometryPath(geometry));

  Path shape(MeadowShape shape) => shape.isStroke && shape.dash.isNotEmpty
      ? _dashed.putIfAbsent(shape, () => _dash(of(shape.geometry), shape.dash))
      : of(shape.geometry);

  Path polygon(Object key, List<Offset> points) =>
      _cache.putIfAbsent(key, () => Path()..addPolygon(points, true));

  Path band(List<Offset> first, List<Offset> second) => _cache.putIfAbsent((
    first,
    second,
  ), () => Path()..addPolygon(<Offset>[...first, ...second.reversed], true));

  void clear() {
    _cache.clear();
    _dashed.clear();
  }
}

Path _geometryPath(MeadowGeometry geometry) {
  switch (geometry) {
    case MeadowEllipse():
      final Rect oval = Rect.fromCenter(
        center: geometry.rotation == 0 ? geometry.centre : Offset.zero,
        width: geometry.radiusX * 2,
        height: geometry.radiusY * 2,
      );
      final Path path = Path()..addOval(oval);
      if (geometry.rotation == 0) {
        return path;
      }
      final double cos = math.cos(geometry.rotation);
      final double sin = math.sin(geometry.rotation);
      return path.transform(
        _affine(cos, sin, -sin, cos, geometry.centre.dx, geometry.centre.dy),
      );
    case MeadowOutline():
      final Path path = Path();
      for (final MeadowSegment segment in geometry.segments) {
        switch (segment.verb) {
          case MeadowVerb.move:
            path.moveTo(segment.to.dx, segment.to.dy);
          case MeadowVerb.line:
            path.lineTo(segment.to.dx, segment.to.dy);
          case MeadowVerb.quad:
            path.quadraticBezierTo(
              segment.control1!.dx,
              segment.control1!.dy,
              segment.to.dx,
              segment.to.dy,
            );
          case MeadowVerb.cubic:
            path.cubicTo(
              segment.control1!.dx,
              segment.control1!.dy,
              segment.control2!.dx,
              segment.control2!.dy,
              segment.to.dx,
              segment.to.dy,
            );
          case MeadowVerb.close:
            path.close();
        }
      }
      return path;
  }
}

Path _dash(Path source, List<double> pattern) {
  final List<double> dashes = pattern.length.isOdd
      ? <double>[...pattern, ...pattern]
      : pattern;
  final double period = dashes.fold<double>(0, (double a, double b) => a + b);
  if (period <= 0) {
    return source;
  }
  final Path dashed = Path();
  for (final PathMetric metric in source.computeMetrics()) {
    double distance = 0;
    int index = 0;
    while (distance < metric.length) {
      final double end = math.min(distance + dashes[index], metric.length);
      if (index.isEven && end > distance) {
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
      }
      distance += dashes[index];
      index = (index + 1) % dashes.length;
    }
  }
  return dashed;
}

Rect _union(Iterable<Rect> rects) =>
    rects.reduce((Rect a, Rect b) => a.expandToInclude(b));

Iterable<Rect> _boundsOf(Iterable<MeadowShape> shapes) =>
    shapes.map(_shapeBounds);

Rect _pointBounds(Iterable<Offset> points) {
  double left = double.infinity;
  double top = double.infinity;
  double right = double.negativeInfinity;
  double bottom = double.negativeInfinity;
  for (final Offset point in points) {
    left = math.min(left, point.dx);
    top = math.min(top, point.dy);
    right = math.max(right, point.dx);
    bottom = math.max(bottom, point.dy);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

Rect _geometryBounds(MeadowGeometry geometry) => switch (geometry) {
  MeadowEllipse(
    :final Offset centre,
    :final double radiusX,
    :final double radiusY,
    :final double rotation,
  ) =>
    rotation == 0
        ? Rect.fromCenter(
            center: centre,
            width: radiusX * 2,
            height: radiusY * 2,
          )
        : Rect.fromCircle(center: centre, radius: math.max(radiusX, radiusY)),
  MeadowOutline(:final List<MeadowSegment> segments) => _pointBounds(<Offset>[
    for (final MeadowSegment segment in segments)
      if (segment.verb != MeadowVerb.close) ...<Offset>[
        segment.to,
        ?segment.control1,
        ?segment.control2,
      ],
  ]),
};

Rect _shapeBounds(MeadowShape shape) =>
    _geometryBounds(shape.geometry).inflate((shape.strokeWidth ?? 0) / 2 + 1);

Rect _shapesBounds(Iterable<MeadowShape> shapes) =>
    _union(shapes.map(_shapeBounds));

class _Frame {
  _Frame(Rect bounds, this.density)
    : origin = bounds.topLeft,
      width = math.max(1, (bounds.width * density).ceil()),
      height = math.max(1, (bounds.height * density).ceil());

  factory _Frame.within(_Frame grid, Rect bounds) => _Frame._on(
    grid,
    bounds,
    (double top) => top.floor(),
    (double b) => b.ceil(),
  );

  factory _Frame.snapped(_Frame grid, Rect bounds) => _Frame._on(
    grid,
    bounds,
    (double top) => top.round(),
    (double b) => b.round(),
  );

  factory _Frame._on(
    _Frame grid,
    Rect bounds,
    int Function(double row) top,
    int Function(double row) bottom,
  ) {
    final double density = grid.density;
    final int left = ((bounds.left - grid.origin.dx) * density).floor();
    final int right = ((bounds.right - grid.origin.dx) * density).ceil();
    final int first = top((bounds.top - grid.origin.dy) * density);
    final int last = bottom((bounds.bottom - grid.origin.dy) * density);
    return _Frame._(
      grid.origin + Offset(left / density, first / density),
      density,
      math.max(1, right - left),
      math.max(1, last - first),
    );
  }

  const _Frame._(this.origin, this.density, this.width, this.height);

  final Offset origin;
  final double density;
  final int width;
  final int height;

  Rect get rect =>
      Rect.fromLTWH(origin.dx, origin.dy, width / density, height / density);

  Rect get pixels => Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

  int get bytes => width * height * _bytesPerPixel;

  double row(double y) => (y - origin.dy) * density;
}

class _StreakFrame {
  _StreakFrame(this.stroke, double period, this.density)
    : width = math.max(3, (stroke * density).ceil() + 2),
      height = math.max(2, (period * density).round()),
      pixelsPerUnit = math.max(2, (period * density).round()) / period;

  final double stroke;
  final double density;
  final int width;
  final int height;
  final double pixelsPerUnit;

  _Frame get frame => _Frame._(Offset.zero, density, width, height);

  int get bytes => width * height * _bytesPerPixel;
}

class _FallFrames {
  const _FallFrames({
    required this.body,
    required this.pool,
    required this.streaks,
  });

  final _Frame body;
  final _Frame pool;
  final List<_StreakFrame> streaks;

  int get bytes =>
      body.bytes * 2 +
      pool.bytes +
      streaks.fold<int>(0, (int total, _StreakFrame s) => total + s.bytes);
}

class _SpriteSheet {
  const _SpriteSheet({required this.frame, required this.sprites});

  final _Frame frame;
  final List<MeadowSprite> sprites;
}

class _Frames {
  const _Frames({
    required this.mountain,
    required this.fog,
    required this.ground,
    required this.water,
    required this.falls,
    required this.grass,
    required this.slabs,
    required this.spruce,
    required this.stars,
    required this.clouds,
    required this.sprites,
  });

  final _Frame mountain;
  final _Frame fog;
  final _Frame ground;
  final List<_Frame> water;
  final List<_FallFrames> falls;
  final List<List<_Frame>> grass;
  final List<List<_Frame>> slabs;
  final _Frame? spruce;
  final _Frame stars;
  final List<_Frame> clouds;
  final _SpriteSheet sprites;

  int get bytes {
    int total = mountain.bytes * 4 + fog.bytes + ground.bytes;
    for (final _Frame tile in water) {
      total += tile.bytes * 3;
    }
    for (final _FallFrames fall in falls) {
      total += fall.bytes;
    }
    for (final List<_Frame> pieces in <List<_Frame>>[...grass, ...slabs]) {
      for (final _Frame piece in pieces) {
        total += piece.bytes;
      }
    }
    total += (spruce?.bytes ?? 0) + stars.bytes + sprites.frame.bytes;
    for (final _Frame cloud in clouds) {
      total += cloud.bytes;
    }
    return total;
  }
}

class _FallPlan {
  const _FallPlan({required this.fall, required this.pool});

  final MeadowFall fall;
  final Rect pool;
}

class _GrassPiece {
  const _GrassPiece({required this.rect, required this.strokes});

  final Rect rect;
  final List<List<MeadowGrassStroke>> strokes;
}

class _GrassPlan {
  const _GrassPlan({required this.band, required this.pieces});

  final MeadowGrassBand band;
  final List<_GrassPiece> pieces;
}

class _Cluster {
  const _Cluster({required this.rect, required this.trees});

  final Rect rect;
  final List<MeadowTree> trees;
}

class _SlabPlan {
  const _SlabPlan({
    required this.sortKey,
    required this.bounds,
    required this.clusters,
  });

  final double sortKey;
  final Rect bounds;
  final List<_Cluster> clusters;
}

enum _SpriteKind { glare, glint, flow, ripple }

enum _Piece { mountains, water, fall, cloud }

class _SpritePlan {
  const _SpritePlan({
    required this.kind,
    required this.ellipse,
    required this.ring,
  });

  final _SpriteKind kind;
  final MeadowEllipse ellipse;
  final bool ring;
}

class _Plan {
  factory _Plan(MeadowTerrain terrain, List<MeadowGrassBand> grass) {
    final MeadowMountains mountains = terrain.mountains;
    final MeadowWater water = terrain.water;
    final MeadowGroundDressing ground = terrain.ground;
    final double groundTop = ground.groundOutline
        .where((Offset point) => point.dy < meadowWorldHeight)
        .map((Offset point) => point.dy)
        .reduce(math.max);
    final double mountainTop = <double>[
      for (final MeadowRange range in <MeadowRange>[
        mountains.far,
        mountains.high,
        mountains.massif,
      ])
        range.ridge.map((Offset point) => point.dy).reduce(math.min),
      for (final List<Offset> outline in terrain.sky.nightClip)
        outline.map((Offset point) => point.dy).reduce(math.min),
    ].reduce(math.min);
    final Rect mountain = Rect.fromLTRB(
      0,
      math.max(0, mountainTop - _edge - 1),
      meadowWorldWidth,
      math.min(_mountainFloor + _edge, groundTop + _edge),
    );
    final List<MeadowFogBand> fogBands = mountains.fogBands;
    final Rect fog = _union(<Rect>[
      fogBands[0].rect,
      fogBands[1].rect,
    ]).intersect(mountain);

    final List<Offset> bands = <Offset>[
      ...water.outerLeft,
      ...water.outerRight,
    ];
    final Rect groundBounds = _union(<Rect>[
      _pointBounds(ground.groundOutline),
      _pointBounds(bands),
      _shapeBounds(ground.farShore),
      ..._boundsOf(ground.mottles),
      ..._boundsOf(ground.wetShore),
      ..._boundsOf(ground.streamEdges),
      ..._boundsOf(ground.stones),
      ..._boundsOf(ground.pebbles),
      ..._boundsOf(ground.reeds),
    ]).inflate(_bankBlur * _blurReach);
    final Rect groundRect = Rect.fromLTRB(
      0,
      math.max(0, groundBounds.top),
      meadowWorldWidth,
      meadowWorldHeight,
    );

    final double split = water.lakeNearY + _edge;
    final Rect lake = _pointBounds(water.lakeOutline).inflate(_edge);
    final List<Rect> waterTiles = <Rect>[
      _union(<Rect>[
        Rect.fromLTRB(lake.left, lake.top, lake.right, split),
        ?_streamSpan(water, lake.top, split),
      ]).intersect(_world),
      for (double top = split; top < meadowWorldHeight; top += _streamRows)
        if (_streamSpan(
              water,
              top,
              math.min(top + _streamRows, meadowWorldHeight),
            )
            case final Rect span)
          span.intersect(_world),
    ];

    final List<_FallPlan> falls = <_FallPlan>[
      for (final MeadowFall fall in mountains.falls)
        _FallPlan(fall: fall, pool: _shapeBounds(fall.pool)),
    ];

    final MeadowOldSpruce? oldSpruce = terrain.forest.oldSpruce;
    final List<MeadowStar> stars = terrain.sky.stars;
    final Rect starRect = Rect.fromLTRB(
      0,
      0,
      meadowWorldWidth,
      stars
              .map((MeadowStar star) => star.centre.dy + star.radius)
              .fold<double>(0, math.max) +
          _edge,
    );

    final List<_SpritePlan> sprites = <_SpritePlan>[
      _SpritePlan(kind: _SpriteKind.glare, ellipse: ground.glare, ring: false),
      for (final MeadowGlint glint in ground.glints)
        _SpritePlan(
          kind: _SpriteKind.glint,
          ellipse: glint.ellipse,
          ring: false,
        ),
      for (final MeadowFlowMark flow in ground.flows)
        _SpritePlan(kind: _SpriteKind.flow, ellipse: flow.ellipse, ring: false),
      for (final MeadowRipple ripple in ground.ripples)
        _SpritePlan(
          kind: _SpriteKind.ripple,
          ellipse: ripple.ellipse,
          ring: true,
        ),
    ];

    return _Plan._(
      mountain: mountain,
      fog: fog,
      ground: groundRect,
      water: List<Rect>.unmodifiable(waterTiles),
      falls: List<_FallPlan>.unmodifiable(falls),
      grass: List<_GrassPlan>.unmodifiable(grass.map(_grassPlan)),
      slabs: List<_SlabPlan>.unmodifiable(_slabPlans(terrain.forest.trees)),
      spruce: oldSpruce?.frameAtOrigin.shift(Offset(oldSpruce.x, oldSpruce.y)),
      stars: starRect,
      clouds: List<Rect>.unmodifiable(<Rect>[
        for (final MeadowCloud cloud in terrain.sky.clouds)
          _union(<Rect>[
            cloud.bounds,
            for (final MeadowEllipse puff in cloud.puffs)
              _geometryBounds(puff).inflate(1),
          ]),
      ]),
      sprites: List<_SpritePlan>.unmodifiable(sprites),
    );
  }

  const _Plan._({
    required this.mountain,
    required this.fog,
    required this.ground,
    required this.water,
    required this.falls,
    required this.grass,
    required this.slabs,
    required this.spruce,
    required this.stars,
    required this.clouds,
    required this.sprites,
  });

  final Rect mountain;
  final Rect fog;
  final Rect ground;
  final List<Rect> water;
  final List<_FallPlan> falls;
  final List<_GrassPlan> grass;
  final List<_SlabPlan> slabs;
  final Rect? spruce;
  final Rect stars;
  final List<Rect> clouds;
  final List<_SpritePlan> sprites;

  _Frames frames(double density) {
    final _Frame mountainFrame = _Frame(mountain, density);
    final _Frame waterGrid = _Frame(
      Rect.fromLTRB(0, water.first.top, meadowWorldWidth, meadowWorldHeight),
      density,
    );
    return _Frames(
      mountain: mountainFrame,
      fog: _Frame.within(mountainFrame, fog),
      ground: _Frame(ground, density),
      water: <_Frame>[
        for (final Rect tile in water) _Frame.snapped(waterGrid, tile),
      ],
      falls: <_FallFrames>[
        for (final _FallPlan fall in falls)
          _FallFrames(
            body: _Frame(fall.fall.bounds, density),
            pool: _Frame(fall.pool, density),
            streaks: <_StreakFrame>[
              for (final MeadowStreak streak in fall.fall.streaks)
                _StreakFrame(
                  streak.shape.strokeWidth!,
                  streak.shape.dash.fold<double>(
                    0,
                    (double a, double b) => a + b,
                  ),
                  density,
                ),
            ],
          ),
      ],
      grass: <List<_Frame>>[
        for (final _GrassPlan band in grass)
          <_Frame>[
            for (final _GrassPiece piece in band.pieces)
              _Frame(piece.rect, density),
          ],
      ],
      slabs: <List<_Frame>>[
        for (final _SlabPlan slab in slabs)
          <_Frame>[
            for (final _Cluster cluster in slab.clusters)
              _Frame(cluster.rect, density),
          ],
      ],
      spruce: spruce == null ? null : _Frame(spruce!, density),
      stars: _Frame(stars, density),
      clouds: <_Frame>[for (final Rect cloud in clouds) _Frame(cloud, density)],
      sprites: _spriteSheet(sprites, density),
    );
  }
}

Rect? _streamSpan(MeadowWater water, double top, double bottom) {
  final List<Offset> points = <Offset>[
    for (final List<Offset> edge in <List<Offset>>[
      water.edgeLeft,
      water.edgeRight,
    ])
      for (int i = 0; i + 1 < edge.length; i++)
        if (math.max(edge[i].dy, edge[i + 1].dy) >= top &&
            math.min(edge[i].dy, edge[i + 1].dy) <= bottom) ...<Offset>[
          edge[i],
          edge[i + 1],
        ],
  ];
  if (points.isEmpty) {
    return null;
  }
  final Rect bounds = _pointBounds(points).inflate(_edge);
  return Rect.fromLTRB(bounds.left, top, bounds.right, bottom);
}

typedef _Blade = ({MeadowGrassStroke stroke, double left, double right});

_Blade _blade(MeadowGrassStroke stroke, double pad) {
  final List<double> xs = <double>[
    stroke.start.dx,
    stroke.control.dx,
    stroke.end.dx,
  ];
  return (
    stroke: stroke,
    left: xs.reduce(math.min) - pad,
    right: xs.reduce(math.max) + pad,
  );
}

_GrassPlan _grassPlan(MeadowGrassBand band) {
  final double pad = band.strokeWidth / 2 + 1;
  final List<_Blade> blades = <_Blade>[
    for (final List<MeadowGrassStroke> shade in band.strokes)
      for (final MeadowGrassStroke stroke in shade) _blade(stroke, pad),
  ]..sort((_Blade a, _Blade b) => a.left.compareTo(b.left));
  final List<_GrassPiece> pieces = <_GrassPiece>[];
  int first = 0;
  while (first < blades.length) {
    double right = blades[first].right;
    int last = first + 1;
    while (last < blades.length && blades[last].left - right <= _grassGap) {
      right = math.max(right, blades[last].right);
      last++;
    }
    final Rect rect = Rect.fromLTRB(
      blades[first].left,
      band.top,
      right,
      band.top + band.height,
    ).intersect(_world);
    if (rect.width > 0 && rect.height > 0) {
      final Set<MeadowGrassStroke> members = Set<MeadowGrassStroke>.identity()
        ..addAll(
          blades.sublist(first, last).map((_Blade blade) => blade.stroke),
        );
      pieces.add(
        _GrassPiece(
          rect: rect,
          strokes: List<List<MeadowGrassStroke>>.unmodifiable(
            <List<MeadowGrassStroke>>[
              for (final List<MeadowGrassStroke> shade in band.strokes)
                List<MeadowGrassStroke>.unmodifiable(
                  shade.where(members.contains),
                ),
            ],
          ),
        ),
      );
    }
    first = last;
  }
  return _GrassPlan(band: band, pieces: List<_GrassPiece>.unmodifiable(pieces));
}

List<_SlabPlan> _slabPlans(List<MeadowTree> trees) {
  final List<_SlabPlan> slabs = <_SlabPlan>[];
  int next = 0;
  while (next < trees.length) {
    final double first = trees[next].y;
    final List<MeadowTree> group = <MeadowTree>[];
    while (next < trees.length && trees[next].y - first < _slabRows) {
      group.add(trees[next]);
      next++;
    }
    final Rect bounds = Rect.fromLTRB(
      group
          .map((MeadowTree tree) => tree.x - tree.height * _treeReach)
          .reduce(math.min),
      group
          .map((MeadowTree tree) => tree.y - tree.height - _slabSpill)
          .reduce(math.min),
      group
          .map((MeadowTree tree) => tree.x + tree.height * _treeReach)
          .reduce(math.max),
      group.map((MeadowTree tree) => tree.y + _slabSpill).reduce(math.max),
    );
    final List<MeadowTree> byX = List<MeadowTree>.of(group)
      ..sort(
        (MeadowTree a, MeadowTree b) => (a.x - a.height * _treeReach).compareTo(
          b.x - b.height * _treeReach,
        ),
      );
    final List<_Cluster> clusters = <_Cluster>[];
    int start = 0;
    while (start < byX.length) {
      double right = byX[start].x + byX[start].height * _treeReach;
      int end = start + 1;
      while (end < byX.length &&
          byX[end].x - byX[end].height * _treeReach - right <= _treeGap) {
        right = math.max(right, byX[end].x + byX[end].height * _treeReach);
        end++;
      }
      final Set<MeadowTree> members = byX.sublist(start, end).toSet();
      final List<MeadowTree> ordered = <MeadowTree>[
        for (final MeadowTree tree in group)
          if (members.contains(tree)) tree,
      ];
      final Rect art = _union(<Rect>[
        for (final MeadowTree tree in ordered) _shapesBounds(tree.art),
      ]);
      final Rect rect = Rect.fromLTRB(
        byX[start].x - byX[start].height * _treeReach,
        bounds.top,
        right,
        bounds.bottom,
      ).intersect(art).intersect(_world);
      if (rect.width > 0 && rect.height > 0) {
        clusters.add(
          _Cluster(rect: rect, trees: List<MeadowTree>.unmodifiable(ordered)),
        );
      }
      start = end;
    }
    slabs.add(
      _SlabPlan(
        sortKey: bounds.bottom - _slabKeyLift,
        bounds: bounds,
        clusters: List<_Cluster>.unmodifiable(clusters),
      ),
    );
  }
  return slabs;
}

_SpriteSheet _spriteSheet(List<_SpritePlan> sprites, double density) {
  final List<MeadowSprite> placed = <MeadowSprite>[];
  int x = _spritePad;
  int y = _spritePad;
  int row = 0;
  int widest = 1;
  for (final _SpritePlan sprite in sprites) {
    final double stroke = sprite.ring ? _rippleStroke : 0;
    final int width =
        ((sprite.ellipse.radiusX * 2 + stroke) * density).ceil() + 2;
    final int height =
        ((sprite.ellipse.radiusY * 2 + stroke) * density).ceil() + 2;
    if (x + width + _spritePad > _spriteSheetWidth && x > _spritePad) {
      x = _spritePad;
      y += row + _spritePad;
      row = 0;
    }
    placed.add(
      MeadowSprite(
        source: Rect.fromLTWH(
          x.toDouble(),
          y.toDouble(),
          width.toDouble(),
          height.toDouble(),
        ),
        anchor: Offset(x + width / 2, y + height / 2),
      ),
    );
    x += width + _spritePad;
    row = math.max(row, height);
    widest = math.max(widest, x);
  }
  return _SpriteSheet(
    frame: _Frame._(Offset.zero, density, widest, y + row + _spritePad),
    sprites: List<MeadowSprite>.unmodifiable(placed),
  );
}
