import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'database.dart';

const Duration inviteLifetime = Duration(days: 7);

const int publicKeyLength = 32;
const int maxOpaqueFieldBytes = 4096;

const String _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int _inviteGroups = 4;
const int _inviteGroupLength = 4;

enum InviteState {
  open('open'),
  used('used'),
  expired('expired'),
  revoked('revoked');

  const InviteState(this.label);

  final String label;
}

final class CreatedInvite {
  const CreatedInvite({
    required this.id,
    required this.code,
    required this.expiresAt,
  });

  final String id;
  final String code;
  final DateTime expiresAt;
}

final class InviteSummary {
  const InviteSummary({
    required this.id,
    required this.note,
    required this.createdAt,
    required this.expiresAt,
    required this.usedAt,
    required this.revokedAt,
    required this.accountId,
  });

  final String id;
  final String note;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime? revokedAt;
  final String? accountId;

  InviteState stateAt(DateTime now) {
    if (usedAt != null) {
      return InviteState.used;
    }
    if (revokedAt != null) {
      return InviteState.revoked;
    }
    if (!expiresAt.isAfter(now)) {
      return InviteState.expired;
    }
    return InviteState.open;
  }
}

String normalizeInviteCode(String code) =>
    code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

String newInviteCode() {
  final Uint8List bytes = randomBytes(_inviteGroups * _inviteGroupLength);
  final List<String> groups = <String>[
    for (int group = 0; group < _inviteGroups; group++)
      String.fromCharCodes(<int>[
        for (int index = 0; index < _inviteGroupLength; index++)
          _inviteAlphabet.codeUnitAt(
            bytes[group * _inviteGroupLength + index] % _inviteAlphabet.length,
          ),
      ]),
  ];
  return groups.join('-');
}

String inviteCodeHash(String code) => secretHash(normalizeInviteCode(code));

bool _isOpaque(Uint8List bytes) =>
    bytes.isNotEmpty && bytes.length <= maxOpaqueFieldBytes;

void validateDeviceRegistration(DeviceRegistration device) {
  if (!isSyncId(device.deviceId) ||
      device.signPublicKey.length != publicKeyLength ||
      device.boxPublicKey.length != publicKeyLength ||
      !_isOpaque(device.certificate) ||
      !_isOpaque(device.encryptedName)) {
    throw const RelayException(SyncErrorCode.badRequest, 'Invalid device');
  }
}

void insertDevice(
  RelayDatabase database, {
  required String accountId,
  required DeviceRegistration device,
  required DateTime now,
}) {
  validateDeviceRegistration(device);
  database.transaction(() {
    if (database.count('SELECT count(*) FROM devices WHERE id = ?', <Object?>[
          device.deviceId,
        ]) >
        0) {
      throw const RelayException(
        SyncErrorCode.badRequest,
        'Device already registered',
      );
    }
    database.execute(
      'INSERT INTO devices (id, account_id, sign_public_key, box_public_key, '
      'certificate, encrypted_name, status, created_at, last_seen_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        device.deviceId,
        accountId,
        device.signPublicKey,
        device.boxPublicKey,
        device.certificate,
        device.encryptedName,
        DeviceStatus.active.storedName,
        toMillis(now),
        toMillis(now),
      ],
    );
  });
}

final class Accounts {
  Accounts(this._database, this._clock);

  final RelayDatabase _database;
  final DateTime Function() _clock;

  CreatedInvite createInvite(String note) {
    final DateTime now = _clock();
    final String id = newSyncId();
    final String code = newInviteCode();
    final DateTime expiresAt = now.add(inviteLifetime);
    _database.transaction(() {
      _database.execute(
        'INSERT INTO invites (id, code_hash, note, created_at, expires_at) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object?>[
          id,
          inviteCodeHash(code),
          note,
          toMillis(now),
          toMillis(expiresAt),
        ],
      );
    });
    return CreatedInvite(id: id, code: code, expiresAt: expiresAt);
  }

  List<InviteSummary> listInvites() => <InviteSummary>[
    for (final Row row in _database.select(
      'SELECT id, note, created_at, expires_at, used_at, revoked_at, '
      'account_id FROM invites ORDER BY created_at, rowid',
    ))
      InviteSummary(
        id: row['id'] as String,
        note: row['note'] as String,
        createdAt: fromMillis(row['created_at'] as int),
        expiresAt: fromMillis(row['expires_at'] as int),
        usedAt: _optionalTime(row['used_at']),
        revokedAt: _optionalTime(row['revoked_at']),
        accountId: row['account_id'] as String?,
      ),
  ];

  bool revokeInvite(String id) => _database.transaction(() {
    _database.execute(
      'UPDATE invites SET revoked_at = ? '
      'WHERE id = ? AND used_at IS NULL AND revoked_at IS NULL',
      <Object?>[toMillis(_clock()), id],
    );
    return _database.updatedRows == 1;
  });

  InviteRedeemResponse redeem(InviteRedeemRequest request) {
    validateDeviceRegistration(request.device);
    if (request.recoverySignPublicKey.length != publicKeyLength ||
        request.recoveryBoxPublicKey.length != publicKeyLength ||
        !_isOpaque(request.recoveryBoxCertificate) ||
        !_isOpaque(request.recoveryEpochOneCopy)) {
      throw const RelayException(
        SyncErrorCode.badRequest,
        'Invalid recovery keys',
      );
    }
    final DateTime now = _clock();
    return _database.transaction(() {
      final Row? invite = _database.selectOne(
        'SELECT id, note, expires_at, used_at, revoked_at FROM invites '
        'WHERE code_hash = ?',
        <Object?>[inviteCodeHash(request.inviteCode)],
      );
      if (invite == null || invite['revoked_at'] != null) {
        throw const RelayException(
          SyncErrorCode.inviteInvalid,
          "That invite code didn't work. Check it and try again.",
        );
      }
      if (invite['used_at'] != null) {
        throw const RelayException(
          SyncErrorCode.inviteUsed,
          'This invite has already been used.',
        );
      }
      if ((invite['expires_at'] as int) <= toMillis(now)) {
        throw const RelayException(
          SyncErrorCode.inviteExpired,
          'This invite has expired.',
        );
      }
      if (_database.count(
            'SELECT count(*) FROM accounts WHERE recovery_sign_public_key = ?',
            <Object?>[request.recoverySignPublicKey],
          ) >
          0) {
        throw const RelayException(
          SyncErrorCode.badRequest,
          'Recovery key already registered',
        );
      }
      final String accountId = newSyncId();
      _database.execute(
        'INSERT INTO accounts (id, note, status, current_epoch, '
        'recovery_sign_public_key, recovery_box_public_key, '
        'recovery_box_certificate, recovery_epoch_one_copy, created_at) '
        'VALUES (?, ?, ?, 1, ?, ?, ?, ?, ?)',
        <Object?>[
          accountId,
          invite['note'] as String,
          AccountStatus.active.storedName,
          request.recoverySignPublicKey,
          request.recoveryBoxPublicKey,
          request.recoveryBoxCertificate,
          request.recoveryEpochOneCopy,
          toMillis(now),
        ],
      );
      insertDevice(
        _database,
        accountId: accountId,
        device: request.device,
        now: now,
      );
      _database.execute(
        'UPDATE invites SET used_at = ?, account_id = ? WHERE id = ?',
        <Object?>[toMillis(now), accountId, invite['id'] as String],
      );
      return InviteRedeemResponse(accountId: accountId);
    });
  }

  bool rename(String accountId, String note) => _database.transaction(() {
    _database.execute(
      'UPDATE accounts SET note = ? WHERE id = ? AND status != ?',
      <Object?>[note, accountId, AccountStatus.erased.storedName],
    );
    return _database.updatedRows == 1;
  });

  bool setStatus(String accountId, AccountStatus status) {
    if (status == AccountStatus.erased) {
      throw ArgumentError.value(status, 'status', 'Erase through the journal');
    }
    return _database.transaction(() {
      _database.execute(
        'UPDATE accounts SET status = ? WHERE id = ? AND status != ?',
        <Object?>[
          status.storedName,
          accountId,
          AccountStatus.erased.storedName,
        ],
      );
      return _database.updatedRows == 1;
    });
  }

  static DateTime? _optionalTime(Object? value) =>
      value is int ? fromMillis(value) : null;
}
