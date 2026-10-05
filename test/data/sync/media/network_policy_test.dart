import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 11 + seed) % 251);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'a metered phone moves records and posters but not full media',
    () async {
      expect(
        networkKindOf(<ConnectivityResult>[
          ConnectivityResult.mobile,
        ], platform: TargetPlatform.android),
        NetworkKind.metered,
      );
      expect(
        networkKindOf(<ConnectivityResult>[
          ConnectivityResult.mobile,
          ConnectivityResult.wifi,
        ], platform: TargetPlatform.android),
        NetworkKind.unmetered,
      );
      expect(
        networkKindOf(<ConnectivityResult>[
          ConnectivityResult.mobile,
        ], platform: TargetPlatform.macOS),
        NetworkKind.unmetered,
      );
      expect(
        networkKindOf(<ConnectivityResult>[
          ConnectivityResult.none,
        ], platform: TargetPlatform.android),
        NetworkKind.offline,
      );
      const NetworkPolicy saving = NetworkPolicy(
        allowMobileDataForMedia: false,
      );
      expect(saving.allows(TransferKind.record, NetworkKind.metered), isTrue);
      expect(saving.allows(TransferKind.poster, NetworkKind.metered), isTrue);
      expect(
        saving.allows(TransferKind.fullMedia, NetworkKind.metered),
        isFalse,
      );
      expect(
        saving.allows(TransferKind.fullMedia, NetworkKind.unmetered),
        isTrue,
      );
      expect(saving.requiresWiFi(TransferKind.fullMedia), isTrue);
      expect(saving.requiresWiFi(TransferKind.poster), isFalse);
      expect(saving.requiresWiFi(TransferKind.record), isFalse);
      const NetworkPolicy spending = NetworkPolicy(
        allowMobileDataForMedia: true,
      );
      expect(
        spending.allows(TransferKind.fullMedia, NetworkKind.metered),
        isTrue,
      );
      expect(spending.requiresWiFi(TransferKind.fullMedia), isFalse);

      final RelayFixture relay = await RelayFixture.start(rateBurst: 1000);
      addTearDown(relay.dispose);
      final SyncTestDevice phone = await enrolDevice(
        relay,
        SyncTestDevice('Phone'),
      );
      addTearDown(phone.dispose);
      final SyncTestMedia media = await SyncTestMedia.create(phone);
      final domain.MediaBlob photo = await media.store.putBytes(
        bytes: _bytes(2400, 1),
        mime: 'image/jpeg',
        kind: domain.MediaKind.photo,
      );
      final domain.MediaBlob poster = await media.store.putBytes(
        bytes: _bytes(400, 2),
        mime: 'image/jpeg',
        kind: domain.MediaKind.photo,
      );
      final MediaBlob row = await (phone.database.select(
        phone.database.mediaBlobs,
      )..where((t) => t.id.equals(photo.id))).getSingle();
      await (phone.database.update(
        phone.database.mediaBlobs,
      )..where((t) => t.id.equals(photo.id))).write(
        MediaBlobsCompanion(
          posterId: Value(poster.id),
          fieldClocks: Value(
            await phone.recorder.stamp(
              table: SyncedTables.mediaBlobs,
              rowId: photo.id,
              fields: const <String>['posterId'],
              currentClocks: row.fieldClocks,
            ),
          ),
        ),
      );
      phone.network.kind = NetworkKind.metered;
      final SyncEngine engine = phone.engine(media: media.source());

      await engine.start();
      await engine.syncNow();

      final RelayClient client = phone.relayClient(
        relay.baseUrl,
        await phone.deviceKeys(),
        (_) {},
      );
      final KeyedNames names = KeyedNames(await phone.journalKeys());
      expect(
        await phone.database.select(phone.database.syncOutbox).get(),
        isEmpty,
      );
      expect(await client.blobExists(names.blobName(poster.id)), isTrue);
      expect(await client.blobExists(names.blobName(photo.id)), isFalse);
      expect(
        (await phone.database.select(phone.database.syncUploads).get()).map(
          (SyncUpload upload) => upload.blobId,
        ),
        <String>[photo.id],
      );

      phone.network.kind = NetworkKind.unmetered;
      await eventually(
        () async =>
            (await phone.database.select(phone.database.syncUploads).get())
                .isEmpty,
      );
      expect(await client.blobExists(names.blobName(photo.id)), isTrue);
    },
  );
}
