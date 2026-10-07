import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/merge/text_merge.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const int _notes = 300;

String _lines(int count, String tag) =>
    <String>[for (int line = 0; line < count; line++) 'line $line $tag']
        .join('\n');

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
    'a pulled page wakes the screens a few times, not once per note',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final SyncTestDevice phone = await pairDevice(
        relay,
        mac,
        device('Phone'),
      );
      final domain.Day day = await phone.journal.ensureDayForDate('2026-10-06');
      for (int index = 0; index < _notes; index++) {
        await phone.journal.createEntry(
          dayId: day.id,
          type: domain.EntryType.text,
          textContent: 'note $index from the phone',
        );
      }
      final SyncEngine phoneEngine = phone.engine();
      await phoneEngine.start();
      await phoneEngine.syncNow();

      int wakes = 0;
      final StreamSubscription<List<domain.Entry>> watching = mac.journal
          .watchEntriesForDate('2026-10-06')
          .listen((_) => wakes += 1);
      addTearDown(watching.cancel);
      final SyncEngine macEngine = mac.engine();
      await macEngine.start();
      await macEngine.syncNow();

      await eventually(
        () async =>
            (await (mac.database.select(
              mac.database.entries,
            )..where((t) => t.dayId.isNotNull())).get()).length >=
            _notes,
      );
      expect(wakes, lessThan(_notes ~/ 10));
    },
  );

  test(
    'a large merge off the main thread matches the same merge inline',
    () async {
      final String base = _lines(4000, 'base');
      final String local = base.replaceFirst('line 10 base', 'line 10 local');
      final String remote = base.replaceFirst(
        'line 3900 base',
        'line 3900 remote',
      );
      expect(
        base.length + local.length + remote.length,
        greaterThan(mergeOffThreadChars),
      );

      final TextMergeResult away = await mergeAway(
        base: base,
        local: local,
        remote: remote,
      );

      expect(away, merge(base: base, local: local, remote: remote));
      expect(
        away,
        TextMergeResult.merged(
          local.replaceFirst('line 3900 base', 'line 3900 remote'),
        ),
      );
    },
  );
}
