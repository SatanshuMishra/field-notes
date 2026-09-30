import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> _draws(int seed, int count) {
  final MeadowRandom random = MeadowRandom(seed);
  return <double>[for (int i = 0; i < count; i++) random.next()];
}

void _expectSequence(int seed, List<double> expected) {
  final List<double> actual = _draws(seed, expected.length);
  for (int i = 0; i < expected.length; i++) {
    expect(actual[i], closeTo(expected[i], 1e-12), reason: 'seed $seed #$i');
  }
}

void main() {
  test('the generator matches the prototype sequence', () {
    _expectSequence(1187, <double>[
      0.056816068711,
      0.471531275893,
      0.403789049713,
      0.272750831442,
      0.886696269503,
    ]);
    _expectSequence(0, <double>[
      0.266429208685,
      0.000329745701,
      0.223272027448,
    ]);
    _expectSequence(4294967295, <double>[
      0.896422614111,
      0.189478256740,
      0.715652678162,
    ]);

    final MeadowRandom spread = MeadowRandom(1187);
    final double first = spread.between(10, 20);
    expect(first, closeTo(10 + 10 * 0.056816068711, 1e-9));
    expect(spread.nextInt(10), 4);
    expect(spread.nextInt(10), 4);
    expect(spread.nextInt(10), 2);

    for (final int seed in <int>[1, 99, 123456789, 4294967295]) {
      for (final double value in _draws(seed, 200)) {
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(1));
      }
    }
  });

  test(
    'the same key and year give the same seed and different ones differ',
    () {
      const int key = 0x5EED1234;
      final int seed = meadowSeed(key, 2025);

      expect(meadowSeed(key, 2025), seed);
      expect(seed, inInclusiveRange(0, 0xFFFFFFFF));
      expect(meadowSeed(key, 2024), isNot(seed));
      expect(meadowSeed(key, 2026), isNot(seed));
      expect(meadowSeed(key + 1, 2025), isNot(seed));
      expect(meadowSeed(0, 2025), isNot(meadowSeed(0, 2024)));
      expect(meadowSeed(-1, 2025), meadowSeed(0xFFFFFFFF, 2025));

      expect(_draws(meadowSeed(key, 2025), 8), _draws(seed, 8));
      expect(_draws(meadowSeed(key, 2024), 8), isNot(_draws(seed, 8)));

      final Set<int> partSeeds = <int>{
        for (final MeadowPart part in MeadowPart.values)
          meadowPartSeed(seed, part),
      };
      expect(partSeeds, hasLength(MeadowPart.values.length));
      expect(partSeeds, isNot(contains(seed)));
      expect(
        meadowPartSeed(seed, MeadowPart.plants),
        meadowPartSeed(meadowSeed(key, 2025), MeadowPart.plants),
      );
      expect(
        meadowPartSeed(meadowSeed(key, 2024), MeadowPart.plants),
        isNot(meadowPartSeed(seed, MeadowPart.plants)),
      );
      for (final int partSeed in partSeeds) {
        expect(partSeed, inInclusiveRange(0, 0xFFFFFFFF));
      }
    },
  );
}
