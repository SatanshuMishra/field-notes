import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/rate_limit.dart';
import 'package:test/test.dart';

final DateTime start = DateTime.utc(2026, 10, 4, 12);

void main() {
  test(
    'a full limiter drops idle buckets first, then the least recently used',
    () {
      DateTime now = start;
      final RateLimiter limiter = RateLimiter(
        burst: 1,
        perSecond: 0.001,
        clock: () => now,
        maxBuckets: 3,
      );

      expect(limiter.take('a'), isNull);
      now = start.add(const Duration(minutes: 5));
      expect(limiter.take('b'), isNull);
      expect(limiter.take('c'), isNull);
      now = start.add(rateBucketIdleLimit);
      expect(limiter.take('d'), isNull);
      expect(limiter.bucketCount, 3);

      expect(limiter.take('b'), isNotNull);
      expect(limiter.take('c'), isNotNull);
      expect(limiter.take('a'), isNull);
      expect(limiter.take('d'), isNull);
      expect(limiter.take('b'), isNull);
      expect(limiter.take('a'), isNotNull);
      expect(limiter.bucketCount, 3);
    },
  );

  test('the limiter keeps at most 10,000 buckets', () {
    final RateLimiter limiter = RateLimiter(
      burst: 60,
      perSecond: 1,
      clock: () => start,
    );
    expect(limiter.maxBuckets, 10000);
    expect(limiter.idleLimit, const Duration(minutes: 10));

    for (int index = 0; index <= 10000; index++) {
      expect(limiter.take('client-$index'), isNull);
    }

    expect(limiter.bucketCount, 10000);
  });

  test('a sweep forgets buckets idle for ten minutes', () {
    DateTime now = start;
    final RateLimiter limiter = RateLimiter(
      burst: 1,
      perSecond: 0.001,
      clock: () => now,
    );
    expect(limiter.take('a'), isNull);
    now = start.add(const Duration(minutes: 5));
    expect(limiter.take('b'), isNull);

    now = start.add(rateBucketIdleLimit - const Duration(seconds: 1));
    limiter.sweep();
    expect(limiter.bucketCount, 2);

    now = start.add(rateBucketIdleLimit);
    limiter.sweep();
    expect(limiter.bucketCount, 1);
    expect(limiter.take('a'), isNull);
    expect(limiter.take('b'), isNotNull);
  });

  test('the rate limit settings come from the environment', () {
    final RelayConfig defaults = RelayConfig.fromEnvironment(
      const <String, String>{},
    );
    expect(defaults.rateBurst, 60);
    expect(defaults.ratePerSecond, 1.0);

    final RelayConfig set = RelayConfig.fromEnvironment(const <String, String>{
      RelayConfig.rateBurstVariable: '120',
      RelayConfig.ratePerSecondVariable: '2.5',
    });
    expect(set.rateBurst, 120);
    expect(set.ratePerSecond, 2.5);

    for (final String invalid in <String>['0', '-1', 'many', '1.5']) {
      expect(
        () => RelayConfig.fromEnvironment(<String, String>{
          RelayConfig.rateBurstVariable: invalid,
        }),
        throwsA(isA<ConfigException>()),
        reason: invalid,
      );
    }
    for (final String invalid in <String>[
      '0',
      '-1',
      'fast',
      'Infinity',
      'NaN',
    ]) {
      expect(
        () => RelayConfig.fromEnvironment(<String, String>{
          RelayConfig.ratePerSecondVariable: invalid,
        }),
        throwsA(isA<ConfigException>()),
        reason: invalid,
      );
    }
  });
}
