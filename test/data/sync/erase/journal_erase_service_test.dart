import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/journal/journal_delete_all_service.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/erase/journal_erase_service.dart';
import 'package:field_notes/data/sync/erase/local_journal_wipe.dart';
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

Future<void> _note(SyncTestDevice device, String date, String text) async {
  final domain.Day day = await device.journal.ensureDayForDate(date);
  await device.journal.createEntry(
    dayId: day.id,
    type: domain.EntryType.text,
    textContent: text,
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'deleting everywhere erases the relay and wipes other devices',
    () async {
      final RelayFixture relay = await RelayFixture.start(rateBurst: 1000);
      addTearDown(relay.dispose);
      final SyncTestDevice mac = await enrolDevice(
        relay,
        SyncTestDevice('Mac'),
      );
      addTearDown(mac.dispose);
      final SyncTestDevice phone = await pairDevice(
        relay,
        mac,
        SyncTestDevice('Phone'),
      );
      addTearDown(phone.dispose);
      final SyncTestMedia macMedia = await SyncTestMedia.create(mac);
      final SyncTestMedia phoneMedia = await SyncTestMedia.create(phone);
      final String accountId = relay.accountOf(await mac.deviceId());
      await _note(mac, '2026-10-18', 'a shared morning');
      final SyncEngine macEngine = mac.engine();
      await macEngine.start();
      await macEngine.syncNow();
      await mac.disposeEngines();
      final LocalJournalWipe phoneWipe = _wipeFor(phone, phoneMedia);
      final SyncEngine phoneEngine = phone.engine(wipe: phoneWipe.wipe);
      await phoneEngine.start();
      await phoneEngine.syncNow();
      expect(
        await phone.database.select(phone.database.entries).get(),
        hasLength(1),
      );
      expect(
        relay.app.database.count(
          'SELECT count(*) FROM records WHERE account_id = ?',
          <Object?>[accountId],
        ),
        greaterThan(0),
      );
      await phone.disposeEngines();

      await JournalEraseService(
        database: mac.database,
        keyStore: mac.keyStore,
        wipe: _wipeFor(mac, macMedia),
      ).eraseEverywhere();

      expect(
        relay.app.database.count(
          'SELECT count(*) FROM records WHERE account_id = ?',
          <Object?>[accountId],
        ),
        0,
      );
      expect(await mac.database.select(mac.database.entries).get(), isEmpty);
      expect(await mac.keyStore.readJournalKeys(), isNull);
      expect(await mac.syncState(SyncStateKeys.syncEnabled), isNull);

      final SyncEngine returning = phone.engine(wipe: phoneWipe.wipe);
      await returning.start();
      await returning.syncNow();
      await eventually(
        () async => await phone.keyStore.readJournalKeys() == null,
      );

      expect(returning.notice, 'Your journal was deleted everywhere');
      expect(
        await phone.database.select(phone.database.entries).get(),
        isEmpty,
      );
      expect(await phone.database.select(phone.database.days).get(), isEmpty);
      expect(await phone.syncState(SyncStateKeys.syncEnabled), isNull);
      await eventually(() async => !returning.isEnabled);
      expect(await returning.status(), isNull);
    },
  );
}
