import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:field_notes/features/garden/scene/meadow_world.dart';

final double meadowSceneScaleAndroid = double.parse(
  const String.fromEnvironment('MEADOW_SCENE_SCALE_ANDROID', defaultValue: '1'),
);

final double meadowSceneScaleMacos = double.parse(
  const String.fromEnvironment('MEADOW_SCENE_SCALE_MACOS', defaultValue: '1'),
);

const double meadowSceneMaxImagePixels = 8192;

double meadowSceneDensity({
  required Size box,
  required double devicePixelRatio,
  required bool cover,
  required TargetPlatform platform,
}) {
  final double scale = switch (platform) {
    TargetPlatform.android => meadowSceneScaleAndroid,
    _ => meadowSceneScaleMacos,
  };
  return math.min(
    MeadowViewport.resolve(box: box, cover: cover, focusX: 0).scale *
        devicePixelRatio *
        scale,
    meadowSceneMaxImagePixels / meadowWorldWidth,
  );
}
