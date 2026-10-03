import 'dart:ui';

import 'package:field_notes/features/garden/scene/meadow_scene_density.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the scene density matches the screen and never makes an image wider '
      'than 8192 pixels', () {
    expect(meadowSceneScaleAndroid, 1.0);
    expect(meadowSceneScaleMacos, 1.0);
    expect(
      meadowSceneDensity(
        box: const Size(1148, 772),
        devicePixelRatio: 2,
        cover: true,
        platform: TargetPlatform.macOS,
      ),
      closeTo(1.20625 * 2, 1e-9),
    );
    expect(
      meadowSceneDensity(
        box: const Size(411.4, 868.6),
        devicePixelRatio: 2.625,
        cover: true,
        platform: TargetPlatform.android,
      ),
      closeTo(1.3571875 * 2.625, 1e-9),
    );
    expect(
      meadowSceneDensity(
        box: const Size(1148, 772),
        devicePixelRatio: 2,
        cover: false,
        platform: TargetPlatform.macOS,
      ),
      closeTo(1148 / 1400 * 2, 1e-9),
    );
    expect(
      meadowSceneDensity(
        box: const Size(3000, 1700),
        devicePixelRatio: 2.5,
        cover: true,
        platform: TargetPlatform.macOS,
      ),
      8192 / 1400,
    );
  });
}
