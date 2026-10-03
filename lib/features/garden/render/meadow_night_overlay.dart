import 'dart:ui';

import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_paint_units.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';

const String meadowNightOverlayAsset = 'shaders/meadow_night_overlay.frag';

const Rect _world = Rect.fromLTWH(0, 0, meadowWorldWidth, meadowWorldHeight);

Future<FragmentProgram>? _loading;
FragmentProgram? _loaded;

FragmentProgram? get meadowNightOverlayProgram => _loaded;

Future<FragmentProgram> loadMeadowNightOverlay() =>
    _loading ??= FragmentProgram.fromAsset(meadowNightOverlayAsset)
        .then((FragmentProgram program) => _loaded = program);

void paintMeadowNightOverlay(
  Canvas canvas, {
  required FragmentProgram program,
  required MeadowLayers layers,
  required MeadowPalette palette,
  Shader? gradient,
}) {
  final MeadowLandMask mask = layers.nightMask;
  final Rect within = mask.rect.intersect(_world);
  if (!within.isEmpty) {
    final FragmentShader shader = _nightShader(program, mask, palette);
    canvas.drawRect(
      within,
      Paint()
        ..shader = shader
        ..isAntiAlias = false,
    );
    shader.dispose();
  }
  final Paint open = Paint()
    ..shader = gradient ?? meadowOverlayShader(palette)
    ..isAntiAlias = false;
  for (final Rect box in _unmasked(mask.rect)) {
    meadowDrawUnit(
      canvas,
      box: box,
      centre: palette.overlayCentre,
      radii: meadowOverlayRadii,
      paint: open,
    );
  }
}

void paintMeadowNightOverlayLayered(
  Canvas canvas, {
  required MeadowLayers layers,
  required MeadowPalette palette,
  Shader? gradient,
}) {
  canvas.saveLayer(_world, Paint());
  meadowDrawUnit(
    canvas,
    box: _world,
    centre: palette.overlayCentre,
    radii: meadowOverlayRadii,
    paint: Paint()..shader = gradient ?? meadowOverlayShader(palette),
  );
  layers.nightMask.apply(canvas);
  canvas.restore();
}

FragmentShader _nightShader(
  FragmentProgram program,
  MeadowLandMask mask,
  MeadowPalette palette,
) {
  final Offset centre = palette.overlayCentre;
  final Color colour = palette.overlayColour;
  final Rect land = mask.rect;
  return program.fragmentShader()
    ..getUniformVec2('uCentre').set(centre.dx, centre.dy)
    ..getUniformVec2('uRadii')
        .set(meadowOverlayRadii.width, meadowOverlayRadii.height)
    ..getUniformVec3('uColour').set(colour.r, colour.g, colour.b)
    ..getUniformVec2('uAlpha')
        .set(palette.overlayCentreAlpha, palette.overlayAlpha)
    ..getUniformVec4('uLand').set(land.left, land.top, land.width, land.height)
    ..getUniformVec4('uChannel').set(
      meadowNightChannel == 0 ? 1 : 0,
      meadowNightChannel == 1 ? 1 : 0,
      meadowNightChannel == 2 ? 1 : 0,
      0,
    )
    ..setImageSampler(0, mask.image, filterQuality: FilterQuality.low);
}

Iterable<Rect> _unmasked(Rect land) => <Rect>[
  Rect.fromLTRB(_world.left, land.top, land.left, _world.bottom),
  Rect.fromLTRB(land.right, land.top, _world.right, _world.bottom),
  Rect.fromLTRB(land.left, land.bottom, land.right, _world.bottom),
].map((Rect box) => box.intersect(_world)).where((Rect box) => !box.isEmpty);
