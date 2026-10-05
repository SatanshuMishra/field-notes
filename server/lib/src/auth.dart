import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:sodium/sodium.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'body_slots.dart';
import 'database.dart';
import 'in_flight.dart';
import 'logging.dart';
import 'request_body.dart';

const List<SyncRoute> uploadPassRoutes = <SyncRoute>[
  SyncRoutes.pushRecords,
  SyncRoutes.uploadPart,
];

const Duration challengeLifetime = Duration(seconds: 60);
const Duration sessionLifetime = Duration(hours: 24);
const Duration uploadPassLifetime = Duration(days: 7);

const int smallJsonLimit = 64 * 1024;
const int largeJsonLimit = 1024 * 1024;
const int pushJsonLimit = maxPushBodyBytes;
const int maxJsonOpeners = 4096;

const String callerContextKey = 'relay.caller';
const String grantContextKey = 'relay.grant';
const String verifiedGrantContextKey = 'relay.verified_grant';

enum Access { open, session, sessionOrUploadPass, sessionOrMailbox, mailbox }

enum CallerKind {
  session('session'),
  uploadPass('upload');

  const CallerKind(this.storedName);

  final String storedName;
}

final class Caller {
  const Caller({
    required this.accountId,
    required this.deviceId,
    required this.kind,
  });

  final String accountId;
  final String deviceId;
  final CallerKind kind;
}

final class SessionGrant {
  const SessionGrant({
    required this.caller,
    required this.tokenHash,
    required this.expiresAt,
  });

  final Caller caller;
  final String tokenHash;
  final DateTime expiresAt;
}

final Random _secureRandom = Random.secure();

Uint8List randomBytes(int length) => Uint8List.fromList(
  List<int>.generate(length, (_) => _secureRandom.nextInt(256)),
);

String newSecret() => encodeBase64Url(randomBytes(32));

String secretHash(String secret) =>
    encodeBase64Url(sha256.convert(utf8.encode(secret)).bytes);

bool constantTimeEquals(String a, String b) {
  final List<int> left = utf8.encode(a);
  final List<int> right = utf8.encode(b);
  int difference = left.length ^ right.length;
  for (int index = 0; index < left.length && index < right.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}

String newDeviceToken(String deviceId) => '$deviceId.${newSecret()}';

String? deviceIdOfToken(String token) {
  final int dot = token.indexOf('.');
  if (dot <= 0) {
    return null;
  }
  final String deviceId = token.substring(0, dot);
  return isSyncId(deviceId) ? deviceId : null;
}

String deviceSubject(String deviceId) => 'device:$deviceId';

const Map<String, String> jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

Response jsonResponse(SyncMessage message, {int status = HttpStatus.ok}) =>
    Response(status, body: jsonEncode(message.toJson()), headers: jsonHeaders);

Response errorResponse(SyncErrorCode code, [String message = '']) =>
    jsonResponse(
      ErrorResponse(
        code: code,
        message: message.isEmpty ? code.wireName : message,
      ),
      status: code.httpStatus,
    );

const Set<int> _storageFullErrors = <int>{28, 69, 122};

bool isStorageFull(Object error) =>
    error is FileSystemException &&
    _storageFullErrors.contains(error.osError?.errorCode);

Response? knownErrorResponse(Object error) => switch (error) {
  RelayException(
    :final SyncErrorCode code,
    :final String message,
    :final int? retryAfter,
  ) =>
    retryAfter == null
        ? errorResponse(code, message)
        : errorResponse(
            code,
            message,
          ).change(headers: <String, String>{'retry-after': '$retryAfter'}),
  FormatException() => errorResponse(SyncErrorCode.badRequest),
  _ when isStorageFull(error) => errorResponse(SyncErrorCode.storageFull),
  _ => null,
};

const RelayException _bodyTooLarge = RelayException(
  SyncErrorCode.badRequest,
  'Body too large',
);

const RelayException _tryAgainShortly = RelayException(
  SyncErrorCode.tooManyRequests,
  '',
  1,
);

Future<Uint8List> readBody(
  Request request, {
  required int maxBytes,
  BodyPace pace = BodyPace.whole,
}) async {
  final int? declared = request.contentLength;
  if (declared != null && declared > maxBytes) {
    throw _bodyTooLarge;
  }
  final BytesBuilder builder = BytesBuilder(copy: false);
  int received = 0;
  try {
    await for (final List<int> chunk in bodyOf(request).read(pace)) {
      received += chunk.length;
      if (received <= maxBytes) {
        builder.add(chunk);
        continue;
      }
      builder.clear();
      if (received > 2 * maxBytes) {
        break;
      }
    }
  } on Object {
    builder.clear();
    rethrow;
  }
  if (received > maxBytes) {
    throw _bodyTooLarge;
  }
  return builder.takeBytes();
}

bool _needsSlot(Request request, int maxBytes) {
  final int? declared = request.contentLength;
  return maxBytes > smallJsonLimit &&
      (declared == null || declared > smallJsonLimit);
}

Future<Uint8List> _readLargeBody(
  Request request,
  int maxBytes,
  LargeBodySlots slots,
) async {
  final int? declared = request.contentLength;
  if (declared != null && declared > maxBytes) {
    throw _bodyTooLarge;
  }
  final String accountId =
      (request.context[callerContextKey] as Caller?)?.accountId ?? '';
  if (!await slots.acquire(accountId)) {
    await bodyOf(request).drain(maxBytes: 2 * maxBytes);
    throw _tryAgainShortly;
  }
  try {
    return await readBody(request, maxBytes: maxBytes, pace: BodyPace.steady);
  } finally {
    slots.release(accountId);
  }
}

int jsonOpeners(List<int> body) {
  int openers = 0;
  for (final int byte in body) {
    if (byte == 0x7b || byte == 0x5b) {
      openers++;
    }
  }
  return openers;
}

Future<Map<String, Object?>> readJson(
  Request request, {
  required int maxBytes,
  LargeBodySlots? slots,
}) async {
  final Uint8List body = slots != null && _needsSlot(request, maxBytes)
      ? await _readLargeBody(request, maxBytes, slots)
      : await readBody(request, maxBytes: maxBytes);
  if (jsonOpeners(body) > maxJsonOpeners) {
    throw const RelayException(SyncErrorCode.badRequest, 'Too many objects');
  }
  final Map<String, Object?> json = decodeJsonObject(utf8.decode(body));
  if (readProtocolVersion(json) != syncProtocolVersion) {
    throw const RelayException(SyncErrorCode.unsupportedProtocol);
  }
  return json;
}

Caller callerOf(Request request) =>
    request.context[callerContextKey]! as Caller;

SessionGrant grantOf(Request request) =>
    request.context[grantContextKey]! as SessionGrant;

AuthCredential? credentialOf(Request request) =>
    AuthCredential.parse(request.headers[SyncHeaders.authorization]);

enum AccountStatus {
  active('active'),
  suspended('suspended'),
  erased('erased');

  const AccountStatus(this.storedName);

  final String storedName;

  static AccountStatus? parse(String? value) {
    for (final AccountStatus status in values) {
      if (status.storedName == value) {
        return status;
      }
    }
    return null;
  }
}

enum DeviceStatus {
  active('active'),
  removed('removed'),
  erased('erased');

  const DeviceStatus(this.storedName);

  final String storedName;

  static DeviceStatus? parse(String? value) {
    for (final DeviceStatus status in values) {
      if (status.storedName == value) {
        return status;
      }
    }
    return null;
  }
}

final class DeviceStanding {
  const DeviceStanding({
    required this.accountId,
    required this.deviceStatus,
    required this.accountStatus,
  });

  final String accountId;
  final DeviceStatus deviceStatus;
  final AccountStatus? accountStatus;

  bool get isActive =>
      deviceStatus == DeviceStatus.active &&
      accountStatus == AccountStatus.active;

  void requireActive() {
    if (accountStatus == null ||
        accountStatus == AccountStatus.erased ||
        deviceStatus == DeviceStatus.erased) {
      throw const RelayException(SyncErrorCode.journalErased);
    }
    if (deviceStatus == DeviceStatus.removed) {
      throw const RelayException(SyncErrorCode.deviceRemoved);
    }
    if (accountStatus == AccountStatus.suspended) {
      throw const RelayException(SyncErrorCode.suspended);
    }
  }
}

DeviceStanding? deviceStanding(RelayDatabase database, String deviceId) {
  final Row? row = database.selectOne(
    'SELECT d.account_id AS account_id, d.status AS device_status, '
    'a.status AS account_status FROM devices d '
    'LEFT JOIN accounts a ON a.id = d.account_id WHERE d.id = ?',
    <Object?>[deviceId],
  );
  if (row == null) {
    return null;
  }
  return DeviceStanding(
    accountId: row['account_id'] as String,
    deviceStatus:
        DeviceStatus.parse(row['device_status'] as String?) ??
        DeviceStatus.erased,
    accountStatus: AccountStatus.parse(row['account_status'] as String?),
  );
}

final class ChallengeClaim {
  const ChallengeClaim({required this.subject, required this.nonce});

  final String subject;
  final String nonce;
}

final class Challenges {
  Challenges(this._database, this._clock);

  final RelayDatabase _database;
  final DateTime Function() _clock;

  ChallengeResponse issue(String subject) {
    final DateTime now = _clock();
    final String id = newSyncId();
    final String nonce = encodeBase64Url(randomBytes(32));
    final DateTime expiresAt = now.add(challengeLifetime);
    _database.transaction(() {
      _database.execute(
        'DELETE FROM challenges WHERE expires_at <= ?',
        <Object?>[toMillis(now)],
      );
      _database.execute(
        'INSERT INTO challenges (id, subject, nonce, expires_at, used) '
        'VALUES (?, ?, ?, ?, 0)',
        <Object?>[id, subject, nonce, toMillis(expiresAt)],
      );
    });
    return ChallengeResponse(
      challengeId: id,
      nonce: nonce,
      expiresAt: expiresAt,
    );
  }

  ChallengeResponse decoy() => ChallengeResponse(
    challengeId: newSyncId(),
    nonce: encodeBase64Url(randomBytes(32)),
    expiresAt: _clock().add(challengeLifetime),
  );

  ChallengeClaim? consume(
    String challengeId,
    bool Function(String subject) accepts,
  ) {
    final DateTime now = _clock();
    return _database.transaction(() {
      final Row? row = _database.selectOne(
        'SELECT subject, nonce, expires_at, used FROM challenges WHERE id = ?',
        <Object?>[challengeId],
      );
      if (row == null) {
        return null;
      }
      final String subject = row['subject'] as String;
      if (!accepts(subject)) {
        return null;
      }
      _database.execute(
        'UPDATE challenges SET used = 1 WHERE id = ?',
        <Object?>[challengeId],
      );
      if ((row['used'] as int) != 0 ||
          (row['expires_at'] as int) <= toMillis(now)) {
        return null;
      }
      return ChallengeClaim(subject: subject, nonce: row['nonce'] as String);
    });
  }
}

bool verifySignature(
  Sodium sodium, {
  required Uint8List message,
  required Uint8List signature,
  required Uint8List publicKey,
}) {
  if (signature.length != sodium.crypto.sign.bytes ||
      publicKey.length != sodium.crypto.sign.publicKeyBytes) {
    return false;
  }
  try {
    return sodium.crypto.sign.verifyDetached(
      message: message,
      signature: signature,
      publicKey: publicKey,
    );
  } on SodiumException {
    return false;
  }
}

final class Sessions {
  Sessions({
    required this._database,
    required this._clock,
    required this._sodium,
    required this.challenges,
  });

  final RelayDatabase _database;
  final DateTime Function() _clock;
  final Sodium _sodium;
  final Challenges challenges;

  ChallengeResponse challenge(ChallengeRequest request) {
    if (!isSyncId(request.deviceId)) {
      throw const RelayException(SyncErrorCode.badRequest);
    }
    final DeviceStanding? standing = deviceStanding(
      _database,
      request.deviceId,
    );
    if (standing == null) {
      return challenges.decoy();
    }
    standing.requireActive();
    return challenges.issue(deviceSubject(request.deviceId));
  }

  SessionResponse signIn(SessionRequest request) {
    final String subject = deviceSubject(request.deviceId);
    final ChallengeClaim? claim = challenges.consume(
      request.challengeId,
      (String candidate) => candidate == subject,
    );
    if (claim == null) {
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    final Row? device = _database.selectOne(
      'SELECT sign_public_key FROM devices WHERE id = ?',
      <Object?>[request.deviceId],
    );
    if (device == null ||
        !verifySignature(
          _sodium,
          message: sessionChallengeBytes(
            challengeId: request.challengeId,
            nonce: claim.nonce,
            deviceId: request.deviceId,
          ),
          signature: request.signature,
          publicKey: device['sign_public_key'] as Uint8List,
        )) {
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    final DeviceStanding? standing = deviceStanding(
      _database,
      request.deviceId,
    );
    if (standing == null) {
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    standing.requireActive();
    final DateTime now = _clock();
    final String token = newDeviceToken(request.deviceId);
    final String uploadPass = newDeviceToken(request.deviceId);
    final DateTime expiresAt = now.add(sessionLifetime);
    final DateTime uploadPassExpiresAt = now.add(uploadPassLifetime);
    final (int currentEpoch, String generation) = _database.transaction(() {
      _database.execute(
        'DELETE FROM sessions WHERE device_id = ? AND expires_at <= ?',
        <Object?>[request.deviceId, toMillis(now)],
      );
      _database.execute(
        'INSERT INTO sessions (token_hash, device_id, kind, expires_at) '
        'VALUES (?, ?, ?, ?), (?, ?, ?, ?)',
        <Object?>[
          secretHash(token),
          request.deviceId,
          CallerKind.session.storedName,
          toMillis(expiresAt),
          secretHash(uploadPass),
          request.deviceId,
          CallerKind.uploadPass.storedName,
          toMillis(uploadPassExpiresAt),
        ],
      );
      _database.execute(
        'UPDATE devices SET last_seen_at = ? WHERE id = ?',
        <Object?>[toMillis(now), request.deviceId],
      );
      return (
        _database.selectOne(
              'SELECT current_epoch FROM accounts WHERE id = ?',
              <Object?>[standing.accountId],
            )!['current_epoch']
            as int,
        _database.generation(),
      );
    });
    return SessionResponse(
      token: token,
      expiresAt: expiresAt,
      currentEpoch: currentEpoch,
      uploadPass: uploadPass,
      uploadPassExpiresAt: uploadPassExpiresAt,
      generation: generation,
    );
  }

  SessionGrant? authorize(
    SyncRoute route,
    Access access,
    AuthCredential? credential,
  ) {
    if (credential?.scheme == AuthScheme.uploadPass &&
        !uploadPassRoutes.contains(route)) {
      _authenticate(credential!);
      throw const RelayException(SyncErrorCode.forbidden);
    }
    switch (access) {
      case Access.open:
        return null;
      case Access.mailbox:
        if (credential?.scheme != AuthScheme.mailbox) {
          throw const RelayException(SyncErrorCode.unauthorized);
        }
        return null;
      case Access.sessionOrMailbox:
        if (credential?.scheme == AuthScheme.mailbox) {
          return null;
        }
        return _requireScheme(credential, AuthScheme.session);
      case Access.session:
        return _requireScheme(credential, AuthScheme.session);
      case Access.sessionOrUploadPass:
        if (credential?.scheme == AuthScheme.uploadPass) {
          return _authenticate(credential!);
        }
        return _requireScheme(credential, AuthScheme.session);
    }
  }

  SessionGrant _requireScheme(AuthCredential? credential, AuthScheme scheme) {
    if (credential == null || credential.scheme != scheme) {
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    return _authenticate(credential);
  }

  SessionGrant _authenticate(AuthCredential credential) {
    final CallerKind kind = credential.scheme == AuthScheme.uploadPass
        ? CallerKind.uploadPass
        : CallerKind.session;
    final DateTime now = _clock();
    final String tokenHash = secretHash(credential.token);
    final Row? row = _database.selectOne(
      'SELECT device_id, expires_at FROM sessions '
      'WHERE token_hash = ? AND kind = ?',
      <Object?>[tokenHash, kind.storedName],
    );
    if (row == null || (row['expires_at'] as int) <= toMillis(now)) {
      final String? deviceId = deviceIdOfToken(credential.token);
      if (deviceId != null) {
        deviceStanding(_database, deviceId)?.requireActive();
      }
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    final String deviceId = row['device_id'] as String;
    final DeviceStanding? standing = deviceStanding(_database, deviceId);
    if (standing == null) {
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    standing.requireActive();
    _database.execute(
      'UPDATE devices SET last_seen_at = ? WHERE id = ?',
      <Object?>[toMillis(now), deviceId],
    );
    return SessionGrant(
      caller: Caller(
        accountId: standing.accountId,
        deviceId: deviceId,
        kind: kind,
      ),
      tokenHash: tokenHash,
      expiresAt: fromMillis(row['expires_at'] as int),
    );
  }

  bool isCurrent(SessionGrant grant) {
    final DateTime now = _clock();
    if (!grant.expiresAt.isAfter(now)) {
      return false;
    }
    final Row? row = _database.selectOne(
      'SELECT device_id, expires_at FROM sessions '
      'WHERE token_hash = ? AND kind = ?',
      <Object?>[grant.tokenHash, grant.caller.kind.storedName],
    );
    if (row == null ||
        row['device_id'] != grant.caller.deviceId ||
        (row['expires_at'] as int) <= toMillis(now)) {
      return false;
    }
    final DeviceStanding? standing = deviceStanding(
      _database,
      grant.caller.deviceId,
    );
    return standing != null &&
        standing.accountId == grant.caller.accountId &&
        standing.isActive;
  }

  void purgeExpired() {
    final int now = toMillis(_clock());
    _database.transaction(() {
      _database.execute('DELETE FROM sessions WHERE expires_at <= ?', <Object?>[
        now,
      ]);
      _database.execute(
        'DELETE FROM challenges WHERE expires_at <= ?',
        <Object?>[now],
      );
    });
  }
}

Middleware protocolGate() =>
    (Handler inner) => (Request request) {
      if (request.headers[SyncHeaders.protocol]?.trim() !=
          '$syncProtocolVersion') {
        throw const RelayException(SyncErrorCode.unsupportedProtocol);
      }
      return inner(request);
    };

Middleware authorization(
  Sessions sessions,
  RequestsInFlight devicesInFlight,
  SyncRoute route,
  Access access,
) =>
    (Handler inner) => (Request request) async {
      final SessionGrant? grant =
          request.context[verifiedGrantContextKey] as SessionGrant? ??
          sessions.authorize(route, access, credentialOf(request));
      final Caller? caller = grant?.caller;
      final Map<String, Object> attribution = <String, Object>{
        if (caller != null) LogContext.account: caller.accountId,
        if (caller != null) LogContext.device: caller.deviceId,
      };
      if (caller != null && !devicesInFlight.enter(caller.deviceId)) {
        bodyOf(request).abandon();
        return knownErrorResponse(_tryAgainShortly)!
            .change(context: attribution);
      }
      try {
        final Response response = await inner(
          grant == null
              ? request
              : request.change(
                  context: <String, Object>{
                    callerContextKey: grant.caller,
                    grantContextKey: grant,
                  },
                ),
        );
        return response.change(context: attribution);
      } on HijackException {
        throw AttributedHijack(attribution);
      } catch (error) {
        final Response? response = knownErrorResponse(error);
        if (response == null) {
          rethrow;
        }
        return response.change(context: attribution);
      } finally {
        if (caller != null) {
          devicesInFlight.leave(caller.deviceId);
        }
      }
    };
