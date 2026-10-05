import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'config.dart';

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

String rateKeyOf(String address) {
  final InternetAddress? parsed = InternetAddress.tryParse(address);
  if (parsed == null) {
    return address;
  }
  if (parsed.type != InternetAddressType.IPv6) {
    return parsed.address;
  }
  final Uint8List bytes = parsed.rawAddress;
  final bool mapped =
      bytes.take(10).every((int byte) => byte == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff;
  if (mapped) {
    return bytes.sublist(12).join('.');
  }
  return '${<String>[for (final int byte in bytes.take(8)) byte.toRadixString(16).padLeft(2, '0')].join()}/64';
}

double _refilled(_Bucket bucket, DateTime now, int capacity, double rate) {
  final int elapsed = now.difference(bucket.updatedAt).inMicroseconds;
  final double refill = elapsed <= 0
      ? 0
      : elapsed * rate / Duration.microsecondsPerSecond;
  return min(capacity.toDouble(), bucket.tokens + refill);
}

int _wait(double available, double rate) =>
    max(1, ((1 - available) / rate).ceil());

final class SharedRateLimit {
  SharedRateLimit({
    required this._clock,
    this.burst = RelayConfig.defaultRateGlobalBurst,
    this.perSecond = RelayConfig.defaultRateGlobalPerSecond,
  });

  final int burst;
  final double perSecond;
  final DateTime Function() _clock;
  _Bucket? _bucket;

  int? take() {
    final DateTime now = _clock();
    final _Bucket? previous = _bucket;
    final double available = previous == null
        ? burst.toDouble()
        : _refilled(previous, now, burst, perSecond);
    if (available < 1) {
      _bucket = _Bucket(tokens: available, updatedAt: now);
      return _wait(available, perSecond);
    }
    _bucket = _Bucket(tokens: available - 1, updatedAt: now);
    return null;
  }
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
      _hmac.convert(utf8.encode(rateKeyOf(address))).bytes,
    );
    final _Bucket? previous = _buckets.remove(key);
    if (previous == null) {
      _makeRoom();
    }
    final double available = previous == null
        ? burst.toDouble()
        : _refilled(previous, now, burst, perSecond);
    if (available < 1) {
      _buckets[key] = _Bucket(tokens: available, updatedAt: now);
      return _wait(available, perSecond);
    }
    _buckets[key] = _Bucket(tokens: available - 1, updatedAt: now);
    return null;
  }

  void sweep() {
    final DateTime now = _clock();
    _buckets.removeWhere((String _, _Bucket bucket) => _isIdle(bucket, now));
  }

  bool _isIdle(_Bucket bucket, DateTime now) =>
      !now.isBefore(bucket.updatedAt.add(idleLimit));

  void _makeRoom() {
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

bool rateLimitApplies(SyncRoute route, Request request) =>
    route != SyncRoutes.pairingStatus ||
    credentialOf(request)?.scheme == AuthScheme.mailbox;

Middleware rateLimit(
  RateLimiter limiter,
  SharedRateLimit shared,
  SyncRoute route,
) =>
    (Handler inner) => (Request request) {
      if (!rateLimitApplies(route, request)) {
        return inner(request);
      }
      final int? wait = limiter.take(clientAddressOf(request)) ?? shared.take();
      if (wait == null) {
        return inner(request);
      }
      return errorResponse(SyncErrorCode.tooManyRequests)
          .change(headers: <String, String>{retryAfterHeader: '$wait'});
    };
