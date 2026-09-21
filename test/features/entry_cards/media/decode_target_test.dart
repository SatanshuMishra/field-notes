import 'package:field_notes/features/entry_cards/media/decode_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeTargetWidth', () {
    test('rounds a physical width up to the next 64px bucket', () {
      expect(decodeBucketPixels, 64);
      expect(decodeTargetWidth(logicalWidth: 1, devicePixelRatio: 1), 64);
      expect(decodeTargetWidth(logicalWidth: 64, devicePixelRatio: 1), 64);
      expect(decodeTargetWidth(logicalWidth: 65, devicePixelRatio: 1), 128);
      expect(decodeTargetWidth(logicalWidth: 300, devicePixelRatio: 1), 320);
    });

    test('a continuous resize collapses to a handful of decode targets', () {
      final Set<int?> targets = <int?>{
        for (double w = 200; w <= 360; w += 0.5)
          decodeTargetWidth(logicalWidth: w, devicePixelRatio: 2),
      };

      expect(targets.length, lessThanOrEqualTo(6));
      expect(
        targets.every((int? t) => t != null && t % decodeBucketPixels == 0),
        isTrue,
      );
    });

    test('scales the bucket by the device pixel ratio', () {
      expect(decodeTargetWidth(logicalWidth: 100, devicePixelRatio: 1), 128);
      expect(decodeTargetWidth(logicalWidth: 100, devicePixelRatio: 2), 256);
      expect(decodeTargetWidth(logicalWidth: 100, devicePixelRatio: 3), 320);
      expect(decodeTargetWidth(logicalWidth: 100, devicePixelRatio: 2.625), 320);
    });

    test('an unmeasurable box asks for no resize at all', () {
      expect(decodeTargetWidth(logicalWidth: null, devicePixelRatio: 2), isNull);
      expect(
        decodeTargetWidth(logicalWidth: double.infinity, devicePixelRatio: 2),
        isNull,
      );
      expect(decodeTargetWidth(logicalWidth: 0, devicePixelRatio: 2), isNull);
      expect(decodeTargetWidth(logicalWidth: -10, devicePixelRatio: 2), isNull);
    });

    test('a nonsense pixel ratio falls back to one physical pixel per point',
        () {
      expect(decodeTargetWidth(logicalWidth: 100, devicePixelRatio: 0), 128);
      expect(
        decodeTargetWidth(logicalWidth: 100, devicePixelRatio: double.nan),
        128,
      );
    });
  });
}
