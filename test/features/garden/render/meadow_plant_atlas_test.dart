import 'dart:typed_data';
import 'dart:ui';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_plant_atlas.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const int _leapYear = 2028;
const int _megabyte = 1000 * 1000;
const int _openKey = 90210;
const int _spruceKey = 7;

String _dateOf(int index) => captureDateKey(DateTime(_leapYear, 1, 1 + index));

MeadowYear _fullYear() => MeadowYear.build(
  days: <Day>[
    for (int i = 0; i < 366; i++)
      dayOf(_dateOf(i), mood: Mood.values[i % Mood.values.length]),
  ],
  entryCounts: <String, int>{for (int i = 0; i < 366; i++) _dateOf(i): 3},
  year: _leapYear,
  today: DateTime(_leapYear + 1, 3, 1),
);

MeadowPlants _plantsFor(int key) {
  final MeadowYear year = _fullYear();
  final int seed = meadowSeed(key, _leapYear);
  return buildMeadowPlants(
    seed: seed,
    year: year,
    terrain: buildMeadowTerrain(seed: seed, year: year),
  );
}

double _densityOf(Size box, {required bool cover, required double ratio}) =>
    MeadowViewport.resolve(
      box: box,
      cover: cover,
      focusX: meadowWorldWidth / 2,
    ).scale *
    ratio;

final double _fullScreen = _densityOf(
  const Size(411.4, 868.6),
  cover: true,
  ratio: 2.625,
);
final double _sidebarCard = _densityOf(
  const Size(1100, 502.9),
  cover: false,
  ratio: 2,
);
final double _bottomBarCard = _densityOf(
  const Size(400, 300),
  cover: true,
  ratio: 2.625,
);

MeadowPlantAtlas _built(
  MeadowPlants plants, {
  required double density,
  required int maxBytes,
}) {
  final MeadowPlantAtlas atlas = MeadowPlantAtlas(
    plants,
    density: density,
    maxBytes: maxBytes,
  )..buildAll();
  addTearDown(atlas.dispose);
  return atlas;
}

List<Image> _sheets(MeadowPlantAtlas atlas) => <Image>[
  for (int sheet = 0; sheet < atlas.sheetCount; sheet++) atlas.imageOf(sheet)!,
];

int _sheetBytes(MeadowPlantAtlas atlas) => _sheets(atlas).fold<int>(
  0,
  (int total, Image image) => total + image.width * image.height * 4,
);

Future<ByteData> _pixels(Image image) async =>
    (await image.toByteData(format: ImageByteFormat.rawRgba))!;

bool _inside(MeadowPlantSprite sprite, Image image) =>
    sprite.source.left >= 0 &&
    sprite.source.top >= 0 &&
    sprite.source.right <= image.width &&
    sprite.source.bottom <= image.height &&
    sprite.anchor.dx >= 0 &&
    sprite.anchor.dy >= 0 &&
    sprite.anchor.dx <= sprite.source.width &&
    sprite.anchor.dy <= sprite.source.height;

bool _painted(ByteData pixels, int stride, Rect source) {
  for (int y = source.top.toInt(); y < source.bottom.toInt(); y++) {
    for (int x = source.left.toInt(); x < source.right.toInt(); x++) {
      if (pixels.getUint8((y * stride + x) * 4 + 3) > 0) {
        return true;
      }
    }
  }
  return false;
}

Future<ByteData> _render(
  int width,
  int height,
  void Function(Canvas canvas) paint,
) async {
  final PictureRecorder recorder = PictureRecorder();
  paint(Canvas(recorder));
  final Picture picture = recorder.endRecording();
  final Image image = picture.toImageSync(width, height);
  picture.dispose();
  final ByteData pixels = await _pixels(image);
  image.dispose();
  return pixels;
}

Future<void> _expectOwnSprites(
  MeadowPlants plants,
  MeadowPlantAtlas atlas,
) async {
  final List<MeadowPlant> visible = <MeadowPlant>[
    for (final MeadowPlant plant in plants.plants)
      if (!plant.hidden) plant,
  ];
  expect(visible, hasLength(366));
  expect(atlas.isReady, isTrue);
  expect(atlas.sprites, hasLength(366));
  expect(
    <int>{
      for (final MeadowPlantSprite sprite in atlas.sprites) sprite.dayIndex,
    },
    <int>{for (final MeadowPlant plant in visible) plant.dayIndex},
  );
  final List<Image> sheets = _sheets(atlas);
  final List<ByteData> pixels = <ByteData>[
    for (final Image sheet in sheets) await _pixels(sheet),
  ];
  expect(<int>[
    for (final MeadowPlant plant in visible)
      if (atlas.spriteOf(plant.dayIndex)?.base != plant.base) plant.dayIndex,
  ], isEmpty);
  expect(<int>[
    for (final MeadowPlantSprite sprite in atlas.sprites)
      if (!_inside(sprite, sheets[sprite.sheet])) sprite.dayIndex,
  ], isEmpty);
  expect(<int>[
    for (final MeadowPlantSprite sprite in atlas.sprites)
      if (!_painted(
        pixels[sprite.sheet],
        sheets[sprite.sheet].width,
        sprite.source,
      ))
        sprite.dayIndex,
  ], isEmpty);
  final List<MeadowPlantSprite> sprites = atlas.sprites;
  expect(<(int, int)>[
    for (int i = 0; i < sprites.length; i++)
      for (int j = i + 1; j < sprites.length; j++)
        if (sprites[i].sheet == sprites[j].sheet &&
            sprites[i].source.overlaps(sprites[j].source))
          (sprites[i].dayIndex, sprites[j].dayIndex),
  ], isEmpty);
}

void main() {
  test('every flower has its own sprite', () async {
    final MeadowPlants plants = _plantsFor(_openKey);
    final MeadowPlantAtlas phone = _built(
      plants,
      density: _fullScreen,
      maxBytes: meadowPlantSpriteBudget,
    );
    await _expectOwnSprites(plants, phone);
    final MeadowPlantAtlas crowded = _built(
      plants,
      density: _fullScreen * 1.25,
      maxBytes: 1 << 40,
    );
    expect(crowded.sheetCount, greaterThan(1));
    await _expectOwnSprites(plants, crowded);
  });

  test(
    'the flower sprites fit the memory ceiling at full screen on the phone',
    () {
      final MeadowPlants plants = _plantsFor(_openKey);
      final MeadowPlantAtlas phone = _built(
        plants,
        density: _fullScreen,
        maxBytes: meadowPlantSpriteBudget,
      );
      expect(phone.imageBytes, greaterThan(0));
      expect(phone.imageBytes, _sheetBytes(phone));
      expect(phone.imageBytes, lessThanOrEqualTo(50 * _megabyte));
      for (final double page in <double>[_sidebarCard, _bottomBarCard]) {
        final MeadowPlantAtlas card = _built(
          plants,
          density: page,
          maxBytes: meadowPlantSpritePageBudget,
        );
        expect(card.imageBytes, greaterThan(0));
        expect(card.imageBytes, _sheetBytes(card));
        expect(card.imageBytes, lessThanOrEqualTo(24 * _megabyte));
      }
    },
  );

  test('flowers keep the device density until the ceiling needs less', () {
    final MeadowPlants plants = _plantsFor(_openKey);
    final MeadowPlantAtlas phone = _built(
      plants,
      density: _fullScreen,
      maxBytes: meadowPlantSpriteBudget,
    );
    expect(phone.density, lessThan(_fullScreen));
    expect(phone.imageBytes, greaterThan(meadowPlantSpriteBudget * 0.97));
    for (final double page in <double>[_sidebarCard, _bottomBarCard]) {
      final MeadowPlantAtlas card = _built(
        plants,
        density: page,
        maxBytes: meadowPlantSpritePageBudget,
      );
      expect(card.density, page);
    }
  });

  test(
    'a sprite placed at its plant matches the plant\'s vector art',
    () async {
      final MeadowPlants plants = _plantsFor(_openKey);
      final MeadowPlantAtlas atlas = _built(
        plants,
        density: _fullScreen,
        maxBytes: meadowPlantSpriteBudget,
      );
      final MeadowPlant plant = plants.plants.reduce(
        (MeadowPlant a, MeadowPlant b) => a.scale >= b.scale ? a : b,
      );
      final MeadowPlantSprite sprite = atlas.spriteOf(plant.dayIndex)!;
      const int margin = 6;
      final int width = sprite.source.width.toInt() + margin * 2;
      final int height = sprite.source.height.toInt() + margin * 2;
      final double baseX = sprite.anchor.dx + margin;
      final double baseY = sprite.anchor.dy + margin;
      final double density = atlas.density;
      final ByteData drawn = await _render(width, height, (Canvas canvas) {
        canvas.translate(baseX, baseY);
        canvas.scale(plant.scale * density);
        paintMeadowPlantArt(canvas, plant.art);
      });
      final ByteData placed = await _render(width, height, (Canvas canvas) {
        canvas.translate(baseX - plant.x * density, baseY - plant.y * density);
        canvas.scale(density);
        canvas.drawAtlas(
          atlas.imageOf(sprite.sheet)!,
          <RSTransform>[atlas.placement(sprite)],
          <Rect>[sprite.source],
          null,
          null,
          null,
          Paint(),
        );
      });
      int coverage = 0;
      int differing = 0;
      for (int i = 0; i < drawn.lengthInBytes; i++) {
        if (i % 4 == 3) {
          coverage += drawn.getUint8(i);
        }
        if ((drawn.getUint8(i) - placed.getUint8(i)).abs() > 8) {
          differing++;
        }
      }
      expect(coverage, greaterThan(255 * 1000));
      expect(differing, lessThan(drawn.lengthInBytes ~/ 1000));
    },
  );

  test('a plant hidden behind the old spruce gets no sprite', () {
    final MeadowPlants plants = _plantsFor(_spruceKey);
    final List<MeadowPlant> hidden = <MeadowPlant>[
      for (final MeadowPlant plant in plants.plants)
        if (plant.hidden) plant,
    ];
    expect(hidden, isNotEmpty);
    final MeadowPlantAtlas atlas = _built(
      plants,
      density: _sidebarCard,
      maxBytes: meadowPlantSpritePageBudget,
    );
    expect(atlas.sprites, hasLength(plants.plants.length - hidden.length));
    expect(<MeadowPlantSprite?>[
      for (final MeadowPlant plant in hidden) atlas.spriteOf(plant.dayIndex),
    ], everyElement(isNull));
  });

  test('the build finishes at most one sheet per step', () {
    final MeadowPlantAtlas atlas = MeadowPlantAtlas(
      _plantsFor(_openKey),
      density: _fullScreen * 1.25,
      maxBytes: 1 << 40,
    );
    addTearDown(atlas.dispose);
    int built() => <Image?>[
      for (int sheet = 0; sheet < atlas.sheetCount; sheet++)
        atlas.imageOf(sheet),
    ].nonNulls.length;
    expect(atlas.sheetCount, greaterThan(1));
    expect(atlas.isReady, isFalse);
    expect(atlas.imageBytes, 0);
    final List<int> perStep = <int>[];
    bool more = true;
    while (more) {
      final int before = built();
      more = atlas.step();
      perStep.add(built() - before);
    }
    expect(perStep, everyElement(lessThanOrEqualTo(1)));
    expect(
      perStep.where((int count) => count == 1),
      hasLength(atlas.sheetCount),
    );
    expect(perStep.length, greaterThan(atlas.sheetCount));
    expect(atlas.isReady, isTrue);
  });

  test('dispose releases every sheet', () {
    final MeadowPlantAtlas atlas = MeadowPlantAtlas(
      _plantsFor(_openKey),
      density: _sidebarCard,
      maxBytes: meadowPlantSpritePageBudget,
    )..buildAll();
    final List<Image> sheets = _sheets(atlas);
    atlas.dispose();
    expect(
      sheets.map((Image sheet) => sheet.debugDisposed),
      everyElement(isTrue),
    );
    expect(atlas.imageBytes, 0);
    expect(atlas.isReady, isFalse);
    expect(atlas.step(), isFalse);
  });
}
