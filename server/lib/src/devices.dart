import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'blobs.dart';
import 'database.dart';

DeviceInfo deviceInfoFromRow(Row row) => DeviceInfo(
  deviceId: row['id'] as String,
  signPublicKey: row['sign_public_key'] as Uint8List,
  boxPublicKey: row['box_public_key'] as Uint8List,
  certificate: row['certificate'] as Uint8List,
  encryptedName: row['encrypted_name'] as Uint8List,
  createdAt: fromMillis(row['created_at'] as int),
  lastSeenAt: fromMillis(row['last_seen_at'] as int),
);

const String _deviceColumns =
    'id, sign_public_key, box_public_key, certificate, encrypted_name, '
    'created_at, last_seen_at';

List<DeviceInfo> keyDevices(RelayDatabase database, String accountId) =>
    <DeviceInfo>[
      for (final Row row in database.select(
        'SELECT $_deviceColumns FROM devices WHERE account_id = ? AND '
        '(status = ? OR id IN (SELECT signer_device_id FROM epoch_rotations '
        'WHERE account_id = ?)) ORDER BY created_at, rowid',
        <Object?>[accountId, DeviceStatus.active.storedName, accountId],
      ))
        deviceInfoFromRow(row),
    ];

List<EpochRotation> rotationsFor(
  RelayDatabase database,
  String accountId,
  String recipient,
) => <EpochRotation>[
  for (final Row rotation in database.select(
    'SELECT epoch, signer_device_id FROM epoch_rotations '
    'WHERE account_id = ? ORDER BY epoch',
    <Object?>[accountId],
  ))
    EpochRotation(
      epoch: rotation['epoch'] as int,
      signerDeviceId: rotation['signer_device_id'] as String,
      deliveries: <EpochKeyDelivery>[
        for (final Row delivery in database.select(
          'SELECT recipient, sealed, signature FROM epoch_deliveries '
          'WHERE account_id = ? AND epoch = ? AND recipient = ?',
          <Object?>[accountId, rotation['epoch'] as int, recipient],
        ))
          EpochKeyDelivery(
            recipient: delivery['recipient'] as String,
            sealed: delivery['sealed'] as Uint8List,
            signature: delivery['signature'] as Uint8List,
          ),
      ],
    ),
];

void eraseAccountData(
  RelayDatabase database,
  String mediaDirectory,
  String accountId,
) {
  database.transaction(() {
    final List<String> uploadIds = <String>[
      for (final Row row in database.select(
        'SELECT id FROM uploads WHERE account_id = ?',
        <Object?>[accountId],
      ))
        row['id'] as String,
    ];
    final List<Object?> account = <Object?>[accountId];
    database.execute('DELETE FROM records WHERE account_id = ?', account);
    database.execute('DELETE FROM account_seqs WHERE account_id = ?', account);
    database.execute('DELETE FROM change_ids WHERE account_id = ?', account);
    database.execute('DELETE FROM blobs WHERE account_id = ?', account);
    database.execute(
      'DELETE FROM upload_parts WHERE upload_id IN '
      '(SELECT id FROM uploads WHERE account_id = ?)',
      account,
    );
    database.execute('DELETE FROM uploads WHERE account_id = ?', account);
    database.execute(
      'DELETE FROM epoch_rotations WHERE account_id = ?',
      account,
    );
    database.execute(
      'DELETE FROM epoch_deliveries WHERE account_id = ?',
      account,
    );
    database.execute('DELETE FROM mailboxes WHERE account_id = ?', account);
    database.execute(
      'DELETE FROM restore_tokens WHERE account_id = ?',
      account,
    );
    database.execute(
      'DELETE FROM sessions WHERE device_id IN '
      '(SELECT id FROM devices WHERE account_id = ?)',
      account,
    );
    database.execute(
      "UPDATE devices SET status = ?, encrypted_name = x'' "
      'WHERE account_id = ?',
      <Object?>[DeviceStatus.erased.storedName, accountId],
    );
    database.execute(
      "UPDATE accounts SET recovery_epoch_one_copy = x'' WHERE id = ?",
      account,
    );
    _deleteTree(Directory(accountMediaPath(mediaDirectory, accountId)));
    for (final String uploadId in uploadIds) {
      _deleteTree(Directory(stagingPath(mediaDirectory, uploadId)));
    }
  });
}

void _deleteTree(Directory directory) {
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
}

final class Devices {
  Devices(this._database, this._mediaDirectory);

  final RelayDatabase _database;
  final String _mediaDirectory;

  EpochKeysResponse keys(Caller caller) => _database.read(() {
    final Row account = _account(caller.accountId);
    return EpochKeysResponse(
      currentEpoch: account['current_epoch'] as int,
      rotations: rotationsFor(
        _database,
        caller.accountId,
        EpochKeyDelivery.deviceRecipient(caller.deviceId),
      ),
      recoveryBoxPublicKey: account['recovery_box_public_key'] as Uint8List,
      recoveryBoxCertificate: account['recovery_box_certificate'] as Uint8List,
      devices: keyDevices(_database, caller.accountId),
    );
  });

  DeviceListResponse list(Caller caller) => DeviceListResponse(
    devices: <DeviceInfo>[
      for (final Row row in _database.select(
        'SELECT $_deviceColumns FROM devices WHERE account_id = ? '
        'AND status = ? ORDER BY created_at, rowid',
        <Object?>[caller.accountId, DeviceStatus.active.storedName],
      ))
        deviceInfoFromRow(row),
    ],
  );

  void remove(Caller caller, String deviceId, DeviceRemoveRequest request) {
    final EpochRotation rotation = request.rotation;
    _database.transaction(() {
      final Row? target = _database.selectOne(
        'SELECT status FROM devices WHERE id = ? AND account_id = ?',
        <Object?>[deviceId, caller.accountId],
      );
      if (target == null ||
          target['status'] != DeviceStatus.active.storedName) {
        throw const RelayException(SyncErrorCode.notFound);
      }
      final int currentEpoch =
          _account(caller.accountId)['current_epoch'] as int;
      final Set<String> recipients = <String>{
        for (final EpochKeyDelivery delivery in rotation.deliveries)
          delivery.recipient,
      };
      if (rotation.epoch != currentEpoch + 1 ||
          rotation.signerDeviceId != caller.deviceId ||
          recipients.length != rotation.deliveries.length ||
          recipients.contains(EpochKeyDelivery.deviceRecipient(deviceId))) {
        throw const RelayException(
          SyncErrorCode.badRequest,
          'Invalid rotation',
        );
      }
      final int active = _database.count(
        'SELECT count(*) FROM devices WHERE account_id = ? AND status = ?',
        <Object?>[caller.accountId, DeviceStatus.active.storedName],
      );
      if (active <= 1) {
        throw const RelayException(
          SyncErrorCode.badRequest,
          'The last device cannot be removed',
        );
      }
      _database.execute(
        'INSERT INTO epoch_rotations (account_id, epoch, signer_device_id, '
        'signature) VALUES (?, ?, ?, NULL)',
        <Object?>[caller.accountId, rotation.epoch, rotation.signerDeviceId],
      );
      for (final EpochKeyDelivery delivery in rotation.deliveries) {
        _database.execute(
          'INSERT INTO epoch_deliveries (account_id, epoch, recipient, sealed, '
          'signature) VALUES (?, ?, ?, ?, ?)',
          <Object?>[
            caller.accountId,
            rotation.epoch,
            delivery.recipient,
            delivery.sealed,
            delivery.signature,
          ],
        );
      }
      _database.execute('UPDATE devices SET status = ? WHERE id = ?', <Object?>[
        DeviceStatus.removed.storedName,
        deviceId,
      ]);
      _database.execute('DELETE FROM sessions WHERE device_id = ?', <Object?>[
        deviceId,
      ]);
      _database.execute(
        'UPDATE accounts SET current_epoch = ? WHERE id = ?',
        <Object?>[rotation.epoch, caller.accountId],
      );
    });
  }

  void eraseJournal(Caller caller) {
    _database.transaction(() {
      eraseAccountData(_database, _mediaDirectory, caller.accountId);
      _database.execute(
        'UPDATE accounts SET status = ? WHERE id = ?',
        <Object?>[AccountStatus.erased.storedName, caller.accountId],
      );
    });
  }

  Row _account(String accountId) {
    final Row? row = _database.selectOne(
      'SELECT current_epoch, recovery_box_public_key, recovery_box_certificate '
      'FROM accounts WHERE id = ?',
      <Object?>[accountId],
    );
    if (row == null) {
      throw const RelayException(SyncErrorCode.journalErased);
    }
    return row;
  }
}
