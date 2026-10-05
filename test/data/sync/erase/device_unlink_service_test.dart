import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/journal_delete_all_service.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/erase/device_unlink_service.dart';
import 'package:field_notes/data/sync/erase/journal_erase_service.dart';
import 'package:field_notes/data/sync/erase/local_journal_wipe.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

LocalJournalWipe _wipeFor(SyncTestDevice device, SyncTestMedia media) =>
    LocalJournalWipe(
      database: device.database,
      keyStore: device.keyStore,
      deleteAll: JournalDeleteAllService(
        database: device.database,
        mediaRoot: media.root,
      ),
    );

DeviceUnlinkService _unlinker(SyncTestDevice device, SyncTestMedia media) =>
    DeviceUnlinkService(
      database: device.database,
      keyStore: device.keyStore,
      wipe: _wipeFor(device, media),
      network: device.network,
    );

Future<File> _keepsake(SyncTestDevice device, SyncTestMedia media) async {
  final domain.MediaBlob photo = await media.store.putBytes(
    bytes: List<int>.generate(400, (int index) => index % 251),
    mime: 'image/jpeg',
    kind: domain.MediaKind.photo,
  );
  return File(media.store.absolutePath(photo));
}

Future<void> _note(SyncTestDevice device, String date, String text) async {
  final domain.Day day = await device.journal.ensureDayForDate(date);
  await device.journal.createEntry(
    dayId: day.id,
    type: domain.EntryType.text,
    textContent: text,
  );
}

Future<void> _sync(SyncTestDevice device) async {
  final SyncEngine engine = device.engine();
  await engine.start();
  await engine.syncNow();
  await device.disposeEngines();
}

Future<void> _expectWiped(SyncTestDevice device, File keepsake) async {
  final AppDatabase database = device.database;
  expect(await database.select(database.entries).get(), isEmpty);
  expect(await database.select(database.days).get(), isEmpty);
  expect(await database.select(database.mediaBlobs).get(), isEmpty);
  expect(await database.select(database.journalSettings).get(), isEmpty);
  expect(await database.select(database.syncOutbox).get(), isEmpty);
  expect(await database.select(database.syncRecordSeqs).get(), isEmpty);
  expect(await database.select(database.syncTextBases).get(), isEmpty);
  expect(
    (await database.select(database.syncStates).get()).map(
      (SyncState state) => state.key,
    ),
    everyElement(
      isIn(<String>[ChangeRecorder.nodeIdKey, ChangeRecorder.lastClockKey]),
    ),
  );
  expect(await device.syncState(SyncStateKeys.syncEnabled), isNull);
  expect(await device.keyStore.readDeviceKeys(), isNull);
  expect(await device.keyStore.readJournalKeys(), isNull);
  expect(await keepsake.exists(), isFalse);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RelayFixture relay;
  late List<SyncTestDevice> devices;

  setUp(() async {
    relay = await RelayFixture.start(rateBurst: 1000);
    devices = <SyncTestDevice>[];
  });

  tearDown(() async {
    for (final SyncTestDevice device in devices) {
      await device.dispose();
    }
    await relay.dispose();
  });

  SyncTestDevice device(String name) {
    final SyncTestDevice created = SyncTestDevice(name);
    devices.add(created);
    return created;
  }

  test(
    'removing this device wipes it and keeps the journal elsewhere',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final SyncTestDevice phone = await pairDevice(
        relay,
        mac,
        device('Phone'),
      );
      final SyncTestMedia phoneMedia = await SyncTestMedia.create(phone);
      await _note(mac, '2026-10-14', 'written on the mac');
      await _note(phone, '2026-10-15', 'written on the phone');
      final File keepsake = await _keepsake(phone, phoneMedia);
      await _sync(mac);
      await _sync(phone);
      await _sync(mac);
      final String phoneId = await phone.deviceId();

      phone.network.kind = NetworkKind.offline;
      await expectLater(
        _unlinker(phone, phoneMedia).removeThisDevice(),
        throwsA(
          isA<DeviceUnlinkException>().having(
            (DeviceUnlinkException error) => error.message,
            'message',
            'Connect to the internet to remove this device.',
          ),
        ),
      );
      expect(relay.isActiveDevice(phoneId), isTrue);
      expect(await phone.keyStore.readDeviceKeys(), isNotNull);
      expect(await keepsake.exists(), isTrue);

      phone.network.kind = NetworkKind.unmetered;
      await _unlinker(phone, phoneMedia).removeThisDevice();

      expect(relay.isActiveDevice(phoneId), isFalse);
      await _expectWiped(phone, keepsake);
      final SyncEngine macEngine = mac.engine();
      await macEngine.start();
      await macEngine.syncNow();
      expect(await macEngine.status(), isA<SyncedStatus>());
      expect(
        (await mac.database.select(mac.database.entries).get()).map(
          (Entry entry) => entry.textContent,
        ),
        unorderedEquals(<String>['written on the mac', 'written on the phone']),
      );
      expect((await mac.journalKeys()).currentEpoch, 2);
    },
  );

  test('an already removed device still wipes itself', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    final SyncTestDevice tablet = await pairDevice(
      relay,
      mac,
      device('Tablet'),
    );
    final SyncTestMedia phoneMedia = await SyncTestMedia.create(phone);
    final SyncTestMedia tabletMedia = await SyncTestMedia.create(tablet);
    final SyncTestMedia macMedia = await SyncTestMedia.create(mac);
    await _note(phone, '2026-10-16', 'phone copy');
    await _note(tablet, '2026-10-17', 'tablet copy');
    final File phoneKeepsake = await _keepsake(phone, phoneMedia);
    final File tabletKeepsake = await _keepsake(tablet, tabletMedia);
    await DeviceService(
      database: mac.database,
      keyStore: mac.keyStore,
      client: await mac.plainClient(relay.baseUrl),
    ).remove(await phone.deviceId());

    await _unlinker(phone, phoneMedia).removeThisDevice();

    await _expectWiped(phone, phoneKeepsake);

    await JournalEraseService(
      database: mac.database,
      keyStore: mac.keyStore,
      wipe: _wipeFor(mac, macMedia),
    ).eraseEverywhere();
    await _unlinker(tablet, tabletMedia).removeThisDevice();

    await _expectWiped(tablet, tabletKeepsake);
  });
}
