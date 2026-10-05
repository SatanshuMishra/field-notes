import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';

const int maxRateBuckets = 10000;
const Duration rateBucketIdleLimit = Duration(minutes: 10);

const String clientAddressHeader = 'cf-connecting-ip';
const String retryAfterHeader = 'retry-after';
const String _connectionInfoKey = 'shelf.io.connection_info';

final Set<SyncRoute> rateLimitedRoutes = <SyncRoute>{
  SyncRoutes.redeemInvite,
  SyncRoutes.sessionChallenge,
  SyncRoutes.session,
  SyncRoutes.restoreChallenge,
  SyncRoutes.restore,
  SyncRoutes.registerRestoredDevice,
  SyncRoutes.joinPairing,
  SyncRoutes.pairingStatus,
};

final class _Bucket {
  const _Bucket({required this.tokens, required this.updatedAt});

  final double tokens;
  final DateTime updatedAt;
}

final class RateLimiter {
  RateLimiter({
    required this.burst,
    required this.perSecond,
    required this._clock,
    this.maxBuckets = maxRateBuckets,
    this.idleLimit = rateBucketIdleLimit,
  }) : _hmac = Hmac(sha256, randomBytes(32));

  final int burst;
  final double perSecond;
  final int maxBuckets;
  final Duration idleLimit;
  final DateTime Function() _clock;
  final Hmac _hmac;
  final Map<String, _Bucket> _buckets = <String, _Bucket>{};

  int get bucketCount => _buckets.length;

  int? take(String address) {
    final DateTime now = _clock();
    final String key = base64Url.encode(
      _hmac.convert(utf8.encode(address)).bytes,
    );
    final _Bucket? previous = _buckets.remove(key);
    if (previous == null) {
      _makeRoom(now);
    }
    final double available = previous == null
        ? burst.toDouble()
        : _refilled(previous, now);
    if (available >= 1) {
      _buckets[key] = _Bucket(tokens: available - 1, updatedAt: now);
      return null;
    }
    _buckets[key] = _Bucket(tokens: available, updatedAt: now);
    return max(1, ((1 - available) / perSecond).ceil());
  }

  void sweep() {
    final DateTime now = _clock();
    _buckets.removeWhere((String _, _Bucket bucket) => _isIdle(bucket, now));
  }

  double _refilled(_Bucket bucket, DateTime now) {
    final int elapsed = now.difference(bucket.updatedAt).inMicroseconds;
    final double refill = elapsed <= 0
        ? 0
        : elapsed * perSecond / Duration.microsecondsPerSecond;
    return min(burst.toDouble(), bucket.tokens + refill);
  }

  bool _isIdle(_Bucket bucket, DateTime now) =>
      !now.isBefore(bucket.updatedAt.add(idleLimit));

  void _makeRoom(DateTime now) {
    if (_buckets.length < maxBuckets) {
      return;
    }
    _buckets.removeWhere((String _, _Bucket bucket) => _isIdle(bucket, now));
    while (_buckets.length >= maxBuckets) {
      _buckets.remove(_buckets.keys.first);
    }
  }
}

String clientAddressOf(Request request) {
  final String? forwarded = request.headers[clientAddressHeader]?.trim();
  if (forwarded != null && forwarded.isNotEmpty) {
    return forwarded;
  }
  final Object? connection = request.context[_connectionInfoKey];
  return connection is HttpConnectionInfo
      ? connection.remoteAddress.address
      : '';
}

Middleware rateLimit(RateLimiter limiter) =>
    (Handler inner) => (Request request) {
      final int? wait = limiter.take(clientAddressOf(request));
      if (wait == null) {
        return inner(request);
      }
      return errorResponse(SyncErrorCode.tooManyRequests)
          .change(headers: <String, String>{retryAfterHeader: '$wait'});
    };
