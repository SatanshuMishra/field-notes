import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/request_pacer.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_server/src/config.dart';

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const int _notes = 1200;
const Duration _refill = Duration(seconds: 20);
const int _perRound = 4;

Future<bool> _outboxEmpty(SyncTestDevice device) async =>
    (await device.database.select(device.database.syncOutbox).get()).isEmpty;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'a device the relay slows down still sends everything, quietly',
    () async {
      final RelayFixture relay = await RelayFixture.start(
        rateBurst: 1000,
        deviceRateBurst: _perRound,
        deviceRatePerSecond: 1 / _refill.inSeconds,
      );
      addTearDown(relay.dispose);
      final SyncTestDevice mac = await enrolDevice(
        relay,
        SyncTestDevice('Mac'),
      );
      addTearDown(mac.dispose);
      final domain.Day day = await mac.journal.ensureDayForDate('2026-10-06');
      for (int index = 0; index < _notes; index++) {
        await mac.journal.createEntry(
          dayId: day.id,
          type: domain.EntryType.text,
          textContent: 'note $index',
        );
      }
      final SyncEngine engine = mac.engine();
      await engine.start();
      await engine.syncNow();
      final List<SyncStatus?> seen = <SyncStatus?>[];

      int waits = 0;
      for (; waits < 60 && !await _outboxEmpty(mac); waits++) {
        seen.add(await engine.status());
        relay.advance(_refill * _perRound);
        await mac.clock.advance(_refill);
        await engine.syncNow();
      }

      expect(await _outboxEmpty(mac), isTrue);
      expect(waits, greaterThan(0));
      expect(
        relay.logLines.where(
          (String line) =>
              line.contains('"route":"/v1/records/push"') &&
              line.contains('"status":429'),
        ),
        isNotEmpty,
      );
      expect(mac.http.countOf('POST', '/v1/records/push'), greaterThan(2));
      expect(engine.consecutiveFailures, 0);
      expect(seen.whereType<AttentionStatus>(), isEmpty);
      expect(
        await mac.database.select(mac.database.syncRecordSeqs).get(),
        hasLength(_notes + 1),
      );
    },
  );

  test('the pacer lets a burst through, then spaces requests out', () async {
    DateTime now = DateTime.utc(2026, 10, 6);
    final List<Duration> waits = <Duration>[];
    final RequestPacer pacer = RequestPacer(
      burst: 3,
      perSecond: 2,
      now: () => now,
      sleep: (Duration wait) async => waits.add(wait),
    );

    for (int request = 0; request < 3; request++) {
      await pacer.take();
    }
    expect(waits, isEmpty);

    await pacer.take();
    await pacer.take();
    expect(waits, <Duration>[
      const Duration(milliseconds: 500),
      const Duration(milliseconds: 1000),
    ]);

    now = now.add(const Duration(seconds: 3));
    waits.clear();
    await pacer.take();
    expect(waits, isEmpty);
  });

  test('the app paces itself below what the relay allows', () {
    expect(clientRequestBurst, lessThan(RelayConfig.defaultDeviceRateBurst));
    expect(
      clientRequestsPerSecond,
      lessThan(RelayConfig.defaultDeviceRatePerSecond),
    );
  });
}
