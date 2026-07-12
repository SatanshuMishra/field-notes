enum FlowerKind {
  peony('Peony'),
  rose('Rose'),
  sunflower('Sunflower'),
  chrysanthemum('Chrysanthemum'),
  daffodil('Daffodil'),
  lavender('Lavender'),
  aster('Aster'),
  poppy('Poppy'),
  bleedingHeart('Bleeding Heart'),
  redSpiderLily('Red Spider Lily'),
  wiltingRose('Wilting Rose', ambientOnly: true),
  thistle('Thistle', ambientOnly: true);

  const FlowerKind(this.label, {this.ambientOnly = false});

  final String label;
  final bool ambientOnly;
}
