import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'config.dart';
import 'in_flight.dart';
import 'request_body.dart';

const int maxRateBuckets = 10000;
const int prefixRateFactor = 4;
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

final Set<SyncRoute> relayWideRoutes = <SyncRoute>{
  SyncRoutes.redeemInvite,
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

bool _isMapped(Uint8List bytes) =>
    bytes.take(10).every((int byte) => byte == 0) &&
    bytes[10] == 0xff &&
    bytes[11] == 0xff;

String _prefixOf(Uint8List bytes, int prefixBytes) =>
    '${<String>[for (final int byte in bytes.take(prefixBytes)) byte.toRadixString(16).padLeft(2, '0')].join()}/${prefixBytes * 8}';

String rateKeyOf(String address) {
  final InternetAddress? parsed = InternetAddress.tryParse(address);
  if (parsed == null) {
    return address;
  }
  if (parsed.type != InternetAddressType.IPv6) {
    return parsed.address;
  }
  final Uint8List bytes = parsed.rawAddress;
  if (_isMapped(bytes)) {
    return bytes.sublist(12).join('.');
  }
  return _prefixOf(bytes, 8);
}

String? widePrefixKeyOf(String address) {
  final InternetAddress? parsed = InternetAddress.tryParse(address);
  if (parsed == null || parsed.type != InternetAddressType.IPv6) {
    return null;
  }
  final Uint8List bytes = parsed.rawAddress;
  return _isMapped(bytes) ? null : _prefixOf(bytes, 6);
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

  int? check() {
    final DateTime now = _clock();
    final _Bucket? previous = _bucket;
    final double available = previous == null
        ? burst.toDouble()
        : _refilled(previous, now, burst, perSecond);
    _bucket = _Bucket(tokens: available, updatedAt: now);
    return available < 1 ? _wait(available, perSecond) : null;
  }

  void spend() {
    final _Bucket? bucket = _bucket;
    if (bucket != null) {
      _bucket = _Bucket(tokens: bucket.tokens - 1, updatedAt: bucket.updatedAt);
    }
  }

  int? take() {
    final int? wait = check();
    if (wait == null) {
      spend();
    }
    return wait;
  }
}

final class RateLimiter {
  RateLimiter({
    required this.burst,
    required this.perSecond,
    required this._clock,
    this.maxBuckets = maxRateBuckets,
    this.idleLimit = rateBucketIdleLimit,
    this.keyOf = rateKeyOf,
  }) : _hmac = Hmac(sha256, randomBytes(32));

  final int burst;
  final double perSecond;
  final int maxBuckets;
  final Duration idleLimit;
  final String? Function(String address) keyOf;
  final DateTime Function() _clock;
  final Hmac _hmac;
  final Map<String, _Bucket> _buckets = <String, _Bucket>{};

  int get bucketCount => _buckets.length;

  int? check(String address) {
    final String? key = _keyOf(address);
    if (key == null) {
      return null;
    }
    final DateTime now = _clock();
    final _Bucket? previous = _buckets.remove(key);
    if (previous == null) {
      _makeRoom();
    }
    final double available = previous == null
        ? burst.toDouble()
        : _refilled(previous, now, burst, perSecond);
    _buckets[key] = _Bucket(tokens: available, updatedAt: now);
    return available < 1 ? _wait(available, perSecond) : null;
  }

  void spend(String address) {
    final String? key = _keyOf(address);
    final _Bucket? bucket = key == null ? null : _buckets[key];
    if (key != null && bucket != null) {
      _buckets[key] = _Bucket(
        tokens: bucket.tokens - 1,
        updatedAt: bucket.updatedAt,
      );
    }
  }

  int? take(String address) {
    final int? wait = check(address);
    if (wait == null) {
      spend(address);
    }
    return wait;
  }

  String? _keyOf(String address) {
    final String? rateKey = keyOf(address);
    return rateKey == null
        ? null
        : base64Url.encode(_hmac.convert(utf8.encode(rateKey)).bytes);
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

final class RateLimits {
  const RateLimits({
    required this.address,
    required this.widePrefix,
    required this.relayWide,
  });

  factory RateLimits.fromConfig(
    RelayConfig config,
    DateTime Function() clock,
  ) => RateLimits(
    address: RateLimiter(
      burst: config.rateBurst,
      perSecond: config.ratePerSecond,
      clock: clock,
    ),
    widePrefix: RateLimiter(
      burst: config.rateBurst * prefixRateFactor,
      perSecond: config.ratePerSecond * prefixRateFactor,
      clock: clock,
      keyOf: widePrefixKeyOf,
    ),
    relayWide: SharedRateLimit(
      burst: config.rateGlobalBurst,
      perSecond: config.rateGlobalPerSecond,
      clock: clock,
    ),
  );

  final RateLimiter address;
  final RateLimiter widePrefix;
  final SharedRateLimit relayWide;

  int? take(String client, {required bool relayWideRoute}) {
    final int wait = <int>[
      address.check(client) ?? 0,
      widePrefix.check(client) ?? 0,
      if (relayWideRoute) relayWide.check() ?? 0,
    ].reduce(max);
    if (wait > 0) {
      return wait;
    }
    address.spend(client);
    widePrefix.spend(client);
    if (relayWideRoute) {
      relayWide.spend();
    }
    return null;
  }

  void sweep() {
    address.sweep();
    widePrefix.sweep();
  }
}

Response _tooManyRequests(int wait) =>
    errorResponse(SyncErrorCode.tooManyRequests)
        .change(headers: <String, String>{retryAfterHeader: '$wait'});

Middleware rateLimit(
  RateLimits limits,
  RequestsInFlight addressesInFlight,
  SyncRoute route, {
  SessionGrant? Function(Request request)? exempt,
}) =>
    (Handler inner) => (Request request) async {
      final SessionGrant? verified = exempt?.call(request);
      if (verified != null) {
        return inner(
          request.change(
            context: <String, Object>{verifiedGrantContextKey: verified},
          ),
        );
      }
      final String client = clientAddressOf(request);
      final String inFlightKey = rateKeyOf(client);
      if (!addressesInFlight.enter(inFlightKey)) {
        bodyOf(request).abandon();
        return _tooManyRequests(1);
      }
      try {
        final int? wait = limits.take(
          client,
          relayWideRoute: relayWideRoutes.contains(route),
        );
        if (wait != null) {
          return _tooManyRequests(wait);
        }
        return await inner(request);
      } finally {
        addressesInFlight.leave(inFlightKey);
      }
    };
