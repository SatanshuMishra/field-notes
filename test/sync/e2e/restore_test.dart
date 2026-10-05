import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/enrolment/restore_service.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/relay_fixture.dart';
import '../support/simulated_device.dart';

const int _seed = 9311;
const int _sharedSteps = 80;
const int _stepsAfterRemoval = 40;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a fresh install restores the whole journal from the phrase', () async {
    final RelayFixture relay = await RelayFixture.start(rateBurst: 1000);
    addTearDown(relay.dispose);
    final SimulatedDevice mac = await SimulatedDevice.create(
      'Studio Mac of Ada',
    );
    addTearDown(mac.dispose);
    final SimulatedDevice phone = await SimulatedDevice.create(
      'Pocket Phone of Ada',
    );
    addTearDown(phone.dispose);
    final List<String> words = await mac.enrol(relay);
    await phone.pairWith(mac, relay);
    await settle(relay, <SimulatedDevice>[mac, phone]);

    final JournalLedger ledger = JournalLedger();
    final RandomActivity activity = RandomActivity(Random(_seed), ledger);
    for (int step = 0; step < _sharedSteps; step++) {
      await activity.step(step.isEven ? mac : phone);
    }
    await settle(relay, <SimulatedDevice>[mac, phone]);

    final RelayClient client = RelayClient(
      baseUrl: relay.baseUrl,
      device: await mac.keyStore.readDeviceKeys(),
    );
    addTearDown(client.close);
    final int epoch = await DeviceService(
      database: mac.database,
      keyStore: mac.keyStore,
      client: client,
    ).remove((await phone.keyStore.readDeviceKeys())!.deviceId);
    expect(epoch, 2);
    await phone.dispose();
    for (int step = 0; step < _stepsAfterRemoval; step++) {
      await activity.step(mac);
    }
    await settle(relay, <SimulatedDevice>[mac]);
    final String accountId = await mac.accountId();
    expect(
      <Object?>{
        for (final Map<String, Object?> row in relay.app.database.select(
          'SELECT DISTINCT epoch FROM records WHERE account_id = ?',
          <Object?>[accountId],
        ))
          row['epoch'],
      },
      <int>{1, 2},
    );

    final SimulatedDevice restored = await SimulatedDevice.create(
      'Reading Mac of Ada',
    );
    addTearDown(restored.dispose);
    final RestoredJournal journal = await restored.restore(relay, words);
    expect(journal.epochs, <int>[1, 2]);
    await settle(relay, <SimulatedDevice>[mac, restored]);

    expect(
      (await restored.keyStore.readJournalKeys())!.epochs,
      (await mac.keyStore.readJournalKeys())!.epochs,
    );
    final SyncedRows enrolled = await mac.syncedRows();
    final SyncedRows fresh = await restored.syncedRows();
    expect(enrolled[SyncedTables.entries]!.length, greaterThan(30));
    expect(enrolled[SyncedTables.entryPhotos], isNotEmpty);
    expect(enrolled[SyncedTables.mediaBlobs], isNotEmpty);
    expect(enrolled[SyncedTables.journalSettings], isNotEmpty);
    for (final String table in SyncedTables.fields.keys) {
      expect(
        fresh[table],
        enrolled[table],
        reason: 'the restored device holds a different $table table',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
