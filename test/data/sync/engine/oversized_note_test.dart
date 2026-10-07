import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const String _push = '/v1/records/push';

Future<List<String>> _waiting(SyncTestDevice device) async => <String>[
  for (final SyncOutboxData row
      in await device.database.select(device.database.syncOutbox).get())
    row.rowId,
];

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

  Future<SyncTestDevice> enrolled(String name) async {
    final SyncTestDevice created = SyncTestDevice(name);
    devices.add(created);
    return enrolDevice(relay, created);
  }

  test(
    'a note too large to sync waits with a message while others sync',
    () async {
      final SyncTestDevice mac = await enrolled('Mac');
      final domain.Day day = await mac.journal.ensureDayForDate('2026-10-06');
      final domain.Entry huge = await mac.journal.createEntry(
        dayId: day.id,
        type: domain.EntryType.text,
        textContent: 'x' * (maxEnvelopeBytes + 10),
      );
      await mac.journal.createEntry(
        dayId: day.id,
        type: domain.EntryType.text,
        textContent: 'an ordinary note',
      );
      final SyncEngine engine = mac.engine();
      await engine.start();

      await engine.syncNow();

      expect(await _waiting(mac), <String>[huge.id]);
      expect(
        await engine.status(),
        const AttentionStatus(AttentionReason.noteTooLong),
      );
      expect(
        mac.http
            .to('POST', _push)
            .every((SentRequest push) => push.bodyBytes < maxEnvelopeBytes),
        isTrue,
      );

      await mac.journal.softDeleteEntry(huge.id);
      await engine.syncNow();

      expect(await _waiting(mac), isEmpty);
      expect(await engine.status(), isA<SyncedStatus>());
    },
  );

  test(
    'a deleted note too large to sync reaches other devices emptied',
    () async {
      final SyncTestDevice mac = await enrolled('Mac');
      final SyncTestDevice phone = SyncTestDevice('Phone');
      devices.add(phone);
      await pairDevice(relay, mac, phone);
      final domain.Day day = await mac.journal.ensureDayForDate('2026-10-06');
      final domain.Entry huge = await mac.journal.createEntry(
        dayId: day.id,
        type: domain.EntryType.text,
        textContent: 'y' * (maxEnvelopeBytes + 10),
      );
      final SyncEngine macEngine = mac.engine();
      final SyncEngine phoneEngine = phone.engine();
      await macEngine.start();
      await phoneEngine.start();
      await macEngine.syncNow();

      await mac.journal.softDeleteEntry(huge.id);
      await macEngine.syncNow();
      await phoneEngine.syncNow();

      Future<Entry> row(SyncTestDevice device) => (device.database.select(
        device.database.entries,
      )..where((t) => t.id.equals(huge.id))).getSingle();
      final Entry onMac = await row(mac);
      final Entry onPhone = await row(phone);
      expect(onMac.textContent, '');
      expect(onMac.deletedAt, isNotNull);
      expect(onPhone.toJson(), onMac.toJson());
      expect(await _waiting(mac), isEmpty);
    },
  );
}
