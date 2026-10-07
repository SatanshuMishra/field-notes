import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'accounts.dart';
import 'auth.dart';
import 'database.dart';
import 'devices.dart';

const Duration mailboxLifetime = Duration(minutes: 10);
const Duration restoreTokenLifetime = Duration(minutes: 10);
const Duration mailboxRetention = Duration(days: 1);

const String _recoveryPrefix = 'recovery:';
const String unnamedJournalLabel = 'Unnamed journal';
const int _unnamedJournalIdLength = 6;

final RegExp _tokenHashPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

final class _Mailbox {
  const _Mailbox({
    required this.id,
    required this.accountId,
    required this.tokenHash,
    required this.createdAt,
    required this.status,
    required this.joinPayload,
    required this.completePayload,
  });

  factory _Mailbox.fromRow(Row row) => _Mailbox(
    id: row['id'] as String,
    accountId: row['account_id'] as String,
    tokenHash: row['token_hash'] as String,
    createdAt: fromMillis(row['created_at'] as int),
    status: PairingStatus.values.firstWhere(
      (PairingStatus status) => status.wireName == row['status'] as String,
    ),
    joinPayload: row['join_payload'] as String?,
    completePayload: row['complete_payload'] as Uint8List?,
  );

  final String id;
  final String accountId;
  final String tokenHash;
  final DateTime createdAt;
  final PairingStatus status;
  final String? joinPayload;
  final Uint8List? completePayload;

  PairingJoinRequest? get join => joinPayload == null
      ? null
      : PairingJoinRequest.fromJson(decodeJsonObject(joinPayload!));
}

final class Pairing {
  Pairing(this._database, this._clock);

  final RelayDatabase _database;
  final DateTime Function() _clock;

  PairingStatusResponse open(Caller caller, PairingOpenRequest request) {
    if (!isSyncId(request.mailboxId) ||
        !_tokenHashPattern.hasMatch(request.tokenHash)) {
      throw const RelayException(SyncErrorCode.badRequest, 'Invalid mailbox');
    }
    final DateTime now = _clock();
    _database.transaction(() {
      _database.execute(
        'DELETE FROM mailboxes WHERE created_at <= ?',
        <Object?>[toMillis(now.subtract(mailboxRetention))],
      );
      if (_database.count(
            'SELECT count(*) FROM mailboxes WHERE id = ?',
            <Object?>[request.mailboxId],
          ) >
          0) {
        throw const RelayException(
          SyncErrorCode.badRequest,
          'Mailbox already exists',
        );
      }
      _database.execute(
        'INSERT INTO mailboxes (id, account_id, token_hash, created_at, status) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object?>[
          request.mailboxId,
          caller.accountId,
          request.tokenHash,
          toMillis(now),
          PairingStatus.open.wireName,
        ],
      );
    });
    return PairingStatusResponse(status: PairingStatus.open);
  }

  PairingStatusResponse join(
    String mailboxId,
    String token,
    PairingJoinRequest request,
  ) {
    validateDeviceRegistration(request.device);
    return _database.transaction(() {
      final _Mailbox mailbox = _withToken(mailboxId, token);
      if (mailbox.status != PairingStatus.open) {
        throw const RelayException(
          SyncErrorCode.badRequest,
          'Mailbox already joined',
        );
      }
      _database.execute(
        'UPDATE mailboxes SET status = ?, join_payload = ? WHERE id = ?',
        <Object?>[
          PairingStatus.joined.wireName,
          jsonEncode(request.toJson()),
          mailbox.id,
        ],
      );
      return PairingStatusResponse(status: PairingStatus.joined);
    });
  }

  void verifyToken(String mailboxId, String token) =>
      _withToken(mailboxId, token);

  PairingStatusResponse statusForToken(String mailboxId, String token) =>
      _database.transaction(() {
        final _Mailbox mailbox = _withToken(mailboxId, token);
        final String journalLabel = _journalLabel(mailbox.accountId);
        if (mailbox.status != PairingStatus.complete) {
          return PairingStatusResponse(
            status: mailbox.status,
            journalLabel: journalLabel,
          );
        }
        if (mailbox.completePayload != null) {
          _database.execute(
            'UPDATE mailboxes SET complete_payload = NULL WHERE id = ?',
            <Object?>[mailbox.id],
          );
        }
        return PairingStatusResponse(
          status: PairingStatus.complete,
          accountId: mailbox.accountId,
          keyBundle: mailbox.completePayload,
          journalLabel: journalLabel,
        );
      });

  String _journalLabel(String accountId) {
    final Row? account = _database.selectOne(
      'SELECT note FROM accounts WHERE id = ?',
      <Object?>[accountId],
    );
    final String note = (account?['note'] as String? ?? '').trim();
    if (note.isNotEmpty) {
      return note;
    }
    return '$unnamedJournalLabel '
        '${accountId.substring(0, _unnamedJournalIdLength)}';
  }

  PairingStatusResponse statusForCaller(Caller caller, String mailboxId) {
    final _Mailbox mailbox = _forCaller(caller, mailboxId);
    return PairingStatusResponse(status: mailbox.status, join: mailbox.join);
  }

  PairingStatusResponse complete(
    Caller caller,
    String mailboxId,
    PairingCompleteRequest request,
  ) {
    validateDeviceRegistration(request.device);
    if (request.keyBundle.isEmpty) {
      throw const RelayException(SyncErrorCode.badRequest, 'Empty key bundle');
    }
    final DateTime now = _clock();
    return _database.transaction(() {
      final _Mailbox mailbox = _forCaller(caller, mailboxId);
      final PairingJoinRequest? join = mailbox.join;
      if (mailbox.status != PairingStatus.joined || join == null) {
        throw const RelayException(
          SyncErrorCode.badRequest,
          'Mailbox is not waiting',
        );
      }
      if (join.device.deviceId != request.device.deviceId ||
          !_sameBytes(
            join.device.signPublicKey,
            request.device.signPublicKey,
          ) ||
          !_sameBytes(join.device.boxPublicKey, request.device.boxPublicKey)) {
        throw const RelayException(
          SyncErrorCode.badRequest,
          'Device does not match the join',
        );
      }
      insertDevice(
        _database,
        accountId: caller.accountId,
        device: request.device,
        now: now,
      );
      _database.execute(
        'UPDATE mailboxes SET status = ?, complete_payload = ? WHERE id = ?',
        <Object?>[
          PairingStatus.complete.wireName,
          request.keyBundle,
          mailbox.id,
        ],
      );
      return PairingStatusResponse(status: PairingStatus.complete);
    });
  }

  void purgeExpired() {
    if (!_database.hasTable('mailboxes')) {
      return;
    }
    final int cutoff = toMillis(_clock().subtract(mailboxLifetime));
    _database.transaction(() {
      _database.execute(
        'DELETE FROM mailboxes WHERE created_at <= ?',
        <Object?>[cutoff],
      );
    });
  }

  _Mailbox _withToken(String mailboxId, String token) {
    final _Mailbox? mailbox = _mailbox(mailboxId);
    if (mailbox == null ||
        !constantTimeEquals(mailboxTokenHash(token), mailbox.tokenHash)) {
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    _requireFresh(mailbox);
    return mailbox;
  }

  _Mailbox _forCaller(Caller caller, String mailboxId) {
    final _Mailbox? mailbox = _mailbox(mailboxId);
    if (mailbox == null || mailbox.accountId != caller.accountId) {
      throw const RelayException(SyncErrorCode.notFound);
    }
    _requireFresh(mailbox);
    return mailbox;
  }

  void _requireFresh(_Mailbox mailbox) {
    if (!mailbox.createdAt.add(mailboxLifetime).isAfter(_clock())) {
      throw const RelayException(SyncErrorCode.pairingExpired);
    }
  }

  _Mailbox? _mailbox(String mailboxId) {
    final Row? row = _database.selectOne(
      'SELECT id, account_id, token_hash, created_at, status, join_payload, '
      'complete_payload FROM mailboxes WHERE id = ?',
      <Object?>[mailboxId],
    );
    return row == null ? null : _Mailbox.fromRow(row);
  }
}

final class Restores {
  Restores({
    required this._database,
    required this._clock,
    required this._sodium,
    required this._challenges,
  });

  final RelayDatabase _database;
  final DateTime Function() _clock;
  final Sodium _sodium;
  final Challenges _challenges;

  ChallengeResponse challenge(RestoreChallengeRequest request) {
    final Row? account = _database.selectOne(
      'SELECT id, status FROM accounts WHERE recovery_sign_public_key = ?',
      <Object?>[request.recoverySignPublicKey],
    );
    if (account == null) {
      throw const RelayException(SyncErrorCode.notFound);
    }
    _requireActive(account['status'] as String);
    return _challenges.issue('$_recoveryPrefix${account['id'] as String}');
  }

  RestoreResponse restore(RestoreRequest request) {
    final ChallengeClaim? claim = _challenges.consume(
      request.challengeId,
      (String subject) => subject.startsWith(_recoveryPrefix),
    );
    if (claim == null) {
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    final String accountId = claim.subject.substring(_recoveryPrefix.length);
    final Row? account = _database.selectOne(
      'SELECT status, current_epoch, recovery_sign_public_key, '
      'recovery_epoch_one_copy FROM accounts WHERE id = ?',
      <Object?>[accountId],
    );
    if (account == null) {
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    final Uint8List recoverySignPublicKey =
        account['recovery_sign_public_key'] as Uint8List;
    if (!verifySignature(
      _sodium,
      message: restoreChallengeBytes(
        challengeId: request.challengeId,
        nonce: claim.nonce,
        recoverySignPublicKey: recoverySignPublicKey,
      ),
      signature: request.signature,
      publicKey: recoverySignPublicKey,
    )) {
      throw const RelayException(SyncErrorCode.unauthorized);
    }
    _requireActive(account['status'] as String);
    final DateTime now = _clock();
    final String token = newSecret();
    return _database.transaction(() {
      _database.execute(
        'DELETE FROM restore_tokens WHERE expires_at <= ?',
        <Object?>[toMillis(now)],
      );
      _database.execute(
        'INSERT INTO restore_tokens (token_hash, account_id, expires_at, used) '
        'VALUES (?, ?, ?, 0)',
        <Object?>[
          secretHash(token),
          accountId,
          toMillis(now.add(restoreTokenLifetime)),
        ],
      );
      return RestoreResponse(
        accountId: accountId,
        restoreToken: token,
        currentEpoch: account['current_epoch'] as int,
        recoveryEpochOneCopy: account['recovery_epoch_one_copy'] as Uint8List,
        rotations: rotationsFor(
          _database,
          accountId,
          EpochKeyDelivery.recoveryRecipient,
        ),
        devices: keyDevices(_database, accountId),
      );
    });
  }

  void register(RestoreRegisterRequest request) {
    validateDeviceRegistration(request.device);
    final DateTime now = _clock();
    _database.transaction(() {
      final Row? token = _database.selectOne(
        'SELECT account_id, expires_at, used FROM restore_tokens '
        'WHERE token_hash = ?',
        <Object?>[secretHash(request.restoreToken)],
      );
      if (token == null ||
          (token['used'] as int) != 0 ||
          (token['expires_at'] as int) <= toMillis(now)) {
        throw const RelayException(SyncErrorCode.unauthorized);
      }
      final String accountId = token['account_id'] as String;
      final Row? account = _database.selectOne(
        'SELECT status FROM accounts WHERE id = ?',
        <Object?>[accountId],
      );
      if (account == null) {
        throw const RelayException(SyncErrorCode.journalErased);
      }
      _requireActive(account['status'] as String);
      insertDevice(
        _database,
        accountId: accountId,
        device: request.device,
        now: now,
      );
      _database.execute(
        'UPDATE restore_tokens SET used = 1 WHERE token_hash = ?',
        <Object?>[secretHash(request.restoreToken)],
      );
    });
  }

  static void _requireActive(String status) {
    switch (AccountStatus.parse(status)) {
      case AccountStatus.active:
        return;
      case AccountStatus.suspended:
        throw const RelayException(SyncErrorCode.suspended);
      case AccountStatus.erased:
      case null:
        throw const RelayException(SyncErrorCode.journalErased);
    }
  }
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (int index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}
