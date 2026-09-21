import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/notes/notes.dart';

const double _em = 16;
const double _line = 25.6;

FloatSplit _split(
  InlineSpan span, {
  TextScaler scaler = TextScaler.noScaling,
  int bucket = 3,
  int lines = 5,
  int lineCount = 12,
}) {
  final List<double> tops = <double>[
    for (int i = 0; i < lineCount && i < lines + 2; i++) i * _line,
  ];
  return FloatSplit(
    span: span,
    scaler: scaler,
    bucket: bucket,
    width: floatBandWidth(band: double.infinity, bucket: bucket, em: _em),
    offset: lines * 40,
    head: TextSpan(text: 'head of $bucket'),
    tail: TextSpan(text: 'tail of $bucket'),
    lines: lines,
    lineTops: tops,
  );
}

double _heightFor(int lines) => (lines - 0.5) * _line;

FloatSplit? _lookup(
  FloatSplitCache cache,
  InlineSpan span, {
  TextScaler scaler = TextScaler.noScaling,
  int bucket = 3,
  double? floatHeight,
}) {
  return cache.lookup(
    span: span,
    scaler: scaler,
    bucket: bucket,
    floatHeight: floatHeight ?? _heightFor(5),
  );
}

void main() {
  const TextSpan paragraph = TextSpan(text: 'a paragraph');

  group('band buckets', () {
    test('start at the 19.4 em residual and step every half em', () {
      final double floor = photoBandResidualEm * _em;
      expect(floatBandBucket(band: floor, em: _em), 0);
      expect(floatBandBucket(band: floor + 7.9, em: _em), 0);
      expect(floatBandBucket(band: floor + 8, em: _em), 1);
      expect(floatBandBucket(band: 352, em: _em), 5);
    });

    test('lay the head out no wider than the band and never under 19.4 em', () {
      for (double band = photoBandResidualEm * _em; band < 400; band += 0.7) {
        final int bucket = floatBandBucket(band: band, em: _em);
        final double width =
            floatBandWidth(band: band, bucket: bucket, em: _em);
        expect(width, lessThanOrEqualTo(band));
        expect(width, greaterThanOrEqualTo(photoBandResidualEm * _em - 1e-9));
        expect(band - width, lessThan(floatBandBucketEm * _em + 1e-9));
      }
    });

    test('a rounding hair under the residual still lands in bucket zero', () {
      final double band = photoBandResidualEm * _em - 1e-12;
      expect(floatBandBucket(band: band, em: _em), 0);
      expect(floatBandWidth(band: band, bucket: 0, em: _em), band);
    });

    test('are the same at every text scale', () {
      for (final double scale in <double>[0.9, 1, 1.15, 1.5]) {
        final double em = _em * scale;
        expect(floatBandBucket(band: 22 * em, em: em), 5);
      }
    });
  });

  group('FloatSplitCache', () {
    test('misses when nothing is stored', () {
      expect(_lookup(FloatSplitCache(), paragraph), isNull);
    });

    test('hits on the same span, scaler and bucket', () {
      final FloatSplitCache cache = FloatSplitCache();
      final FloatSplit stored = cache.store(_split(paragraph));

      expect(identical(_lookup(cache, paragraph), stored), isTrue);
    });

    test('keys on span identity, not on equal content', () {
      final FloatSplitCache cache = FloatSplitCache()..store(_split(paragraph));
      final TextSpan twin = TextSpan(text: paragraph.text);

      expect(twin, paragraph);
      expect(_lookup(cache, twin), isNull);
    });

    test('misses when the text scaler changes', () {
      final FloatSplitCache cache = FloatSplitCache()..store(_split(paragraph));

      expect(
        _lookup(cache, paragraph, scaler: const TextScaler.linear(1.15)),
        isNull,
      );
    });

    test('misses when the band narrows into a lower bucket', () {
      final FloatSplitCache cache = FloatSplitCache()..store(_split(paragraph));

      expect(_lookup(cache, paragraph, bucket: 2), isNull);
    });

    test('holds the split for one bucket of widening, not two', () {
      final FloatSplitCache cache = FloatSplitCache();
      final FloatSplit stored = cache.store(_split(paragraph));

      expect(identical(_lookup(cache, paragraph, bucket: 4), stored), isTrue);
      expect(_lookup(cache, paragraph, bucket: 5), isNull);
    });

    test('walking the band back and forth across a bucket edge never misses',
        () {
      final FloatSplitCache cache = FloatSplitCache();
      final FloatSplit stored = cache.store(_split(paragraph));

      for (int step = 0; step < 20; step++) {
        final int bucket = step.isEven ? 4 : 3;
        expect(
          identical(_lookup(cache, paragraph, bucket: bucket), stored),
          isTrue,
          reason: 'step $step',
        );
      }
    });

    test('holds within one line of the photo height and misses past it', () {
      final FloatSplitCache cache = FloatSplitCache()..store(_split(paragraph));

      for (final int lines in <int>[4, 5, 6]) {
        expect(
          _lookup(cache, paragraph, floatHeight: _heightFor(lines)),
          isNotNull,
          reason: '$lines lines beside',
        );
      }
      for (final int lines in <int>[2, 3, 7, 8]) {
        expect(
          _lookup(cache, paragraph, floatHeight: _heightFor(lines)),
          isNull,
          reason: '$lines lines beside',
        );
      }
    });

    test('walking the photo height across a line boundary never misses', () {
      final FloatSplitCache cache = FloatSplitCache();
      final FloatSplit stored = cache.store(_split(paragraph));
      final double boundary = 5 * _line;

      for (int step = 0; step < 20; step++) {
        final double height = boundary + (step.isEven ? 0.5 : -0.5);
        expect(
          identical(_lookup(cache, paragraph, floatHeight: height), stored),
          isTrue,
          reason: 'step $step at $height',
        );
      }
    });

    test('a float with no line beside it never hits', () {
      final FloatSplitCache cache = FloatSplitCache()
        ..store(_split(paragraph, lines: 1));

      expect(
          _lookup(cache, paragraph, floatHeight: floatEdgeTolerance), isNull);
      expect(_lookup(cache, paragraph, floatHeight: _line), isNotNull);
    });

    test('a line starting within the edge tolerance of the foot is below it',
        () {
      expect(lineStartsBeside(5 * _line, 5 * _line), isFalse);
      expect(
          lineStartsBeside(5 * _line - floatEdgeTolerance, 5 * _line), isFalse);
      expect(lineStartsBeside(5 * _line - 1, 5 * _line), isTrue);
    });

    test('a paragraph wholly beside the photo holds however tall it grows', () {
      final FloatSplitCache cache = FloatSplitCache()
        ..store(_split(paragraph, lines: 3, lineCount: 3));

      for (final double height in <double>[80, 200, 2000]) {
        expect(_lookup(cache, paragraph, floatHeight: height), isNotNull);
      }
    });

    test('a replaced split is served in place of the old one', () {
      final FloatSplitCache cache = FloatSplitCache()..store(_split(paragraph));
      final FloatSplit taller = cache.store(_split(paragraph, lines: 9));

      expect(cache.length, 1);
      expect(
        identical(
          _lookup(cache, paragraph, floatHeight: _heightFor(9)),
          taller,
        ),
        isTrue,
      );
    });

    test('is bounded and evicts the least recently used split', () {
      final FloatSplitCache cache = FloatSplitCache(capacity: 3);
      for (int bucket = 0; bucket < 3; bucket++) {
        cache.store(_split(paragraph, bucket: bucket * 10));
      }
      _lookup(cache, paragraph, bucket: 0);
      cache.store(_split(paragraph, bucket: 30));

      expect(cache.length, 3);
      expect(_lookup(cache, paragraph, bucket: 0), isNotNull);
      expect(_lookup(cache, paragraph, bucket: 10), isNull);
      expect(_lookup(cache, paragraph, bucket: 20), isNotNull);
    });

    test('clear drops every split', () {
      final FloatSplitCache cache = FloatSplitCache()..store(_split(paragraph));

      cache.clear();

      expect(cache.length, 0);
      expect(_lookup(cache, paragraph), isNull);
    });
  });
}
