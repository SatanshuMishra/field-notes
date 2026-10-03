import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/features/garden/render/meadow_layers.dart';

class MeadowWaterMark {
  const MeadowWaterMark({
    required this.oval,
    required this.colour,
    required this.opacity,
    this.stroke,
  });

  final Rect oval;
  final Color colour;
  final double opacity;
  final double? stroke;

  Color get shade => colour.withValues(alpha: colour.a * opacity);

  Rect get bounds {
    final double? width = stroke;
    return width == null ? oval : oval.inflate(width / 2);
  }
}

void paintMeadowWaterMarks(
  Canvas canvas, {
  required List<MeadowWaterMark> marks,
  required List<MeadowImage> water,
}) {
  if (marks.isEmpty || water.isEmpty) {
    return;
  }
  final List<ImageShader> shaders = <ImageShader>[
    for (final MeadowImage tile in water)
      ImageShader(
        tile.image,
        TileMode.clamp,
        TileMode.clamp,
        _tileMatrix(tile),
        filterQuality: FilterQuality.low,
      ),
  ];
  for (final MeadowWaterMark mark in marks) {
    final Rect bounds = mark.bounds;
    final List<int> under = <int>[
      for (int index = 0; index < water.length; index++)
        if (bounds.overlaps(water[index].rect)) index,
    ];
    if (under.length == 1 && _holds(water[under.single].rect, bounds)) {
      _drawMark(canvas, mark, shaders[under.single]);
      continue;
    }
    for (final int index in under) {
      canvas
        ..save()
        ..clipRect(water[index].rect, doAntiAlias: false);
      for (int earlier = 0; earlier < index; earlier++) {
        final Rect before = water[earlier].rect;
        if (before.overlaps(water[index].rect)) {
          canvas.clipRect(
            before,
            clipOp: ClipOp.difference,
            doAntiAlias: false,
          );
        }
      }
      _drawMark(canvas, mark, shaders[index]);
      canvas.restore();
    }
  }
  for (final ImageShader shader in shaders) {
    shader.dispose();
  }
}

void _drawMark(Canvas canvas, MeadowWaterMark mark, ImageShader water) {
  final double? stroke = mark.stroke;
  canvas.drawOval(
    mark.oval,
    Paint()
      ..shader = water
      ..colorFilter = ColorFilter.mode(mark.shade, BlendMode.srcIn)
      ..style = stroke == null ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = stroke ?? 0,
  );
}

bool _holds(Rect outer, Rect inner) =>
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;

Float64List _tileMatrix(MeadowImage tile) => Float64List(16)
  ..[0] = tile.rect.width / tile.image.width
  ..[5] = tile.rect.height / tile.image.height
  ..[10] = 1
  ..[12] = tile.rect.left
  ..[13] = tile.rect.top
  ..[15] = 1;
