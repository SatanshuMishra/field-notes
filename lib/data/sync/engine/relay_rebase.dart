import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

const String relayGenerationKey = 'relay_generation';
const String rebaseCounterKey = 'rebase_counter';
const String _emptyParts = '[]';

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

final class RelayTag {
  const RelayTag({
    required this.address,
    required this.generation,
    required this.counter,
  });

  factory RelayTag.fromJson(Map<String, Object?> json) {
    final Object? address = json['address'];
    final Object? generation = json['generation'];
    final Object? counter = json['counter'];
    if ((address != null && address is! String) ||
        (generation != null && generation is! String) ||
        counter is! int) {
      throw const FormatException('Not a relay tag');
    }
    return RelayTag(
      address: address as String?,
      generation: generation as String?,
      counter: counter,
    );
  }

  final String? address;
  final String? generation;
  final int counter;

  bool admits(RelayTag made) =>
      made.address == address &&
      made.counter == counter &&
      (made.generation == null ||
          generation == null ||
          made.generation == generation);

  RelayTag withGeneration(String value) =>
      RelayTag(address: address, generation: value, counter: counter);

  Map<String, Object?> toJson() => <String, Object?>{
    'address': address,
    'generation': generation,
    'counter': counter,
  };

  @override
  bool operator ==(Object other) =>
      other is RelayTag &&
      other.address == address &&
      other.generation == generation &&
      other.counter == counter;

  @override
  int get hashCode => Object.hash(address, generation, counter);

  @override
  String toString() => 'RelayTag($address, $generation, $counter)';
}

Future<RelayTag> readRelayTag(AppDatabase database) async => RelayTag(
  address: await readSyncState(database, SyncStateKeys.relayUrl),
  generation: await readSyncState(database, relayGenerationKey),
  counter:
      int.tryParse(await readSyncState(database, rebaseCounterKey) ?? '') ?? 0,
);

final class RelayRebase {
  RelayRebase({
    required AppDatabase database,
    required this._keyStore,
    int Function()? wallClock,
    Random? random,
  }) : _db = database,
       _wallClock = wallClock ?? _systemMillis,
       _random = random ?? Random.secure();

  final AppDatabase _db;
  final KeyStore _keyStore;
  final int Function() _wallClock;
  final Random _random;

  Future<void> putKeysRight(RelayClient client) async {
    final DeviceService devices = DeviceService(
      database: _db,
      keyStore: _keyStore,
      client: client,
    );
    int current = (await client.keys()).currentEpoch;
    for (final OwnRotation own in await devices.ownRotationsAbove(current)) {
      if (own.epoch != current + 1) {
        break;
      }
      try {
        await client.removeDevice(
          own.removedDeviceId,
          DeviceRemoveRequest(rotation: own.rotation),
        );
      } on RelayRejected {
        break;
      }
      current = own.epoch;
    }
    final int relayEpoch = (await client.keys()).currentEpoch;
    final JournalKeys? held = await _keyStore.readJournalKeys();
    if (held != null && held.epochs.any((int epoch) => epoch > relayEpoch)) {
      await _keyStore.writeJournalKeys(held.withoutEpochsAbove(relayEpoch));
    }
    await devices.refreshKeys();
  }

  Future<void> reset({
    required String address,
    required String generation,
    required int counter,
  }) => _db.transaction(() async {
    await writeSyncState(_db, SyncStateKeys.relayUrl, address);
    await writeSyncState(_db, relayGenerationKey, generation);
    await writeSyncState(_db, rebaseCounterKey, '$counter');
    await writeSyncState(_db, pullCursorKey, '0');
    await writeSyncState(_db, pullCompleteKey, pullIncompleteValue);
    await _db.delete(_db.syncRecordSeqs).go();
    await _db.delete(_db.syncHeldStates).go();
    await _db
        .update(_db.syncOutbox)
        .write(const SyncOutboxCompanion(changeId: Value(null)));
    await _enqueueAll();
    for (final SyncUpload upload in await _db.select(_db.syncUploads).get()) {
      await (_db.update(
        _db.syncUploads,
      )..where((t) => t.blobId.equals(upload.blobId))).write(
        SyncUploadsCompanion(
          uploadId: Value(newSyncId(_random)),
          ackedParts: const Value(_emptyParts),
        ),
      );
    }
    await _db
        .update(_db.syncMediaCache)
        .write(const SyncMediaCacheCompanion(uploaded: Value(false)));
  });

  Future<void> _enqueueAll() async {
    final int now = _wallClock();
    final Map<String, Iterable<String>> rows = <String, Iterable<String>>{
      SyncedTables.days: (await _db.select(_db.days).get()).map(
        (Day row) => row.id,
      ),
      SyncedTables.entries: (await _db.select(_db.entries).get()).map(
        (Entry row) => row.id,
      ),
      SyncedTables.entryPhotos: (await _db.select(_db.entryPhotos).get()).map(
        (EntryPhoto row) => row.id,
      ),
      SyncedTables.mediaBlobs: (await _db.select(_db.mediaBlobs).get()).map(
        (MediaBlob row) => row.id,
      ),
      SyncedTables.journalSettings:
          (await _db.select(_db.journalSettings).get()).map(
            (JournalSetting row) => row.key,
          ),
    };
    await _db.batch((Batch batch) {
      for (final MapEntry<String, Iterable<String>> table in rows.entries) {
        for (final String rowId in table.value) {
          batch.insert(
            _db.syncOutbox,
            SyncOutboxCompanion.insert(
              recordTable: table.key,
              rowId: rowId,
              enqueuedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
  }
}
