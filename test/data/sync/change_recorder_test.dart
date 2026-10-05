import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:flutter_test/flutter_test.dart';

const int _noon = 1790000000000;
const int _oneHour = 60 * 60 * 1000;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<String?> storedState(String key) async {
    final SyncState? row = await (db.select(
      db.syncStates,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  test(
    'stamping inside a transaction adds one outbox entry per record',
    () async {
      final ChangeRecorder recorder = ChangeRecorder(
        db,
        wallClock: () => _noon,
      );

      await db.transaction(() async {
        final String first = await recorder.stamp(
          table: SyncedTables.days,
          rowId: 'day-2026-09-29',
          fields: SyncedTables.dayFields,
          currentClocks: '{}',
        );
        await recorder.stamp(
          table: SyncedTables.days,
          rowId: 'day-2026-09-29',
          fields: const <String>['moodId'],
          currentClocks: first,
        );
        await recorder.stamp(
          table: SyncedTables.entries,
          rowId: 'entry-1',
          fields: SyncedTables.entryFields,
          currentClocks: '{}',
        );
      });

      final List<SyncOutboxData> outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(2));
      expect(
        outbox
            .map((SyncOutboxData row) => '${row.recordTable}/${row.rowId}')
            .toSet(),
        <String>{'days/day-2026-09-29', 'entries/entry-1'},
      );
    },
  );

  test('a rolled-back transaction leaves no outbox entry', () async {
    final ChangeRecorder recorder = ChangeRecorder(db, wallClock: () => _noon);

    await expectLater(
      db.transaction(() async {
        await recorder.stamp(
          table: SyncedTables.entries,
          rowId: 'entry-1',
          fields: SyncedTables.entryFields,
          currentClocks: '{}',
        );
        throw StateError('the save failed after the stamp');
      }),
      throwsStateError,
    );

    expect(await db.select(db.syncOutbox).get(), isEmpty);
  });

  test('the clock resumes after a restart without going backwards', () async {
    await db.transaction(() async {
      await ChangeRecorder(db, wallClock: () => _noon).stamp(
        table: SyncedTables.days,
        rowId: 'day-2026-09-29',
        fields: SyncedTables.dayFields,
        currentClocks: '{}',
      );
    });
    final Hlc storedLast = Hlc.parse((await storedState('hlc_last'))!);

    final ChangeRecorder restarted = ChangeRecorder(
      db,
      wallClock: () => _noon - _oneHour,
    );
    final String clocks = await db.transaction(
      () => restarted.stamp(
        table: SyncedTables.days,
        rowId: 'day-2026-09-29',
        fields: const <String>['moodId'],
        currentClocks: '{}',
      ),
    );

    final Hlc stamped = Hlc.parse(
      (jsonDecode(clocks) as Map<String, Object?>)['moodId']! as String,
    );
    expect(stamped > storedLast, isTrue);
    expect(Hlc.parse((await storedState('hlc_last'))!), stamped);
  });

  test(
    'a stamp sets the named fields and keeps the clocks of the rest',
    () async {
      final ChangeRecorder recorder = ChangeRecorder(
        db,
        wallClock: () => _noon,
      );
      const String earlier = '0000000000001-0000-0011223344556677';

      final String clocks = await db.transaction(
        () => recorder.stamp(
          table: SyncedTables.days,
          rowId: 'day-2026-09-29',
          fields: const <String>['moodId', 'updatedAt'],
          currentClocks: jsonEncode(<String, String>{'date': earlier}),
        ),
      );

      final Map<String, Object?> decoded =
          jsonDecode(clocks) as Map<String, Object?>;
      expect(decoded.keys.toSet(), <String>{'date', 'moodId', 'updatedAt'});
      expect(decoded['date'], earlier);
      expect(decoded['moodId'], decoded['updatedAt']);
      expect(Hlc.parse(decoded['moodId']! as String).nodeId, recorder.nodeId);
    },
  );

  test('a new stamp clears the change id of a pending entry', () async {
    final ChangeRecorder recorder = ChangeRecorder(db, wallClock: () => _noon);
    Future<void> stampDay() => db.transaction(() async {
      await recorder.stamp(
        table: SyncedTables.days,
        rowId: 'day-2026-09-29',
        fields: const <String>['moodId'],
        currentClocks: '{}',
      );
    });
    await stampDay();
    await db
        .update(db.syncOutbox)
        .write(const SyncOutboxCompanion(changeId: Value('pushed-once')));

    await stampDay();

    final SyncOutboxData pending = await db.select(db.syncOutbox).getSingle();
    expect(pending.changeId, isNull);
  });

  test('every recorder on one database shares one node id', () async {
    await db.transaction(
      () => ChangeRecorder(db, wallClock: () => _noon).stamp(
        table: SyncedTables.days,
        rowId: 'day-2026-09-29',
        fields: const <String>['moodId'],
        currentClocks: '{}',
      ),
    );
    final ChangeRecorder restarted = ChangeRecorder(db, wallClock: () => _noon);
    await db.transaction(
      () => restarted.stamp(
        table: SyncedTables.days,
        rowId: 'day-2026-09-30',
        fields: const <String>['moodId'],
        currentClocks: '{}',
      ),
    );

    final String? stored = await storedState('node_id');
    expect(stored, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(restarted.nodeId, stored);
  });

  test('a received clock is stored and a held-back one is not', () async {
    final ChangeRecorder recorder = ChangeRecorder(db, wallClock: () => _noon);
    const Hlc near = Hlc(millis: _noon + 1000, counter: 4, nodeId: 'remote');
    const Hlc far = Hlc(millis: _noon + _oneHour, counter: 0, nodeId: 'remote');

    expect(
      await db.transaction(() => recorder.receive(near)),
      HlcReceipt.accepted,
    );
    final Hlc afterNear = Hlc.parse((await storedState('hlc_last'))!);
    expect(
      await db.transaction(() => recorder.receive(far)),
      HlcReceipt.heldBack,
    );

    expect(afterNear > near, isTrue);
    expect(Hlc.parse((await storedState('hlc_last'))!), afterNear);
    expect(await db.select(db.syncOutbox).get(), isEmpty);
  });
}
