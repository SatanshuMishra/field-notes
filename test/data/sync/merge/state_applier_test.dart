import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/day_ids.dart';
import 'package:field_notes/data/journal/days_dao.dart';
import 'package:field_notes/data/journal/entries_dao.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/merge/record_reader.dart';
import 'package:field_notes/data/sync/merge/record_state.dart';
import 'package:field_notes/data/sync/merge/state_applier.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/entry_type.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:flutter_test/flutter_test.dart';

const int _noon = 1790000000000;
const int _minute = 60 * 1000;
const String _date = '2026-09-29';
const String _entryId = 'entry-1';

class _Device {
  _Device(this.name) : db = AppDatabase(NativeDatabase.memory());

  final String name;
  final AppDatabase db;
  int now = _noon;

  late final ChangeRecorder recorder = ChangeRecorder(db, wallClock: () => now);
  late final DaysDao days = DaysDao(db, recorder);
  late final EntriesDao entries = EntriesDao(db, recorder);
  late final StateApplier applier = StateApplier(
    database: db,
    recorder: recorder,
    localDeviceName: name,
    wallClock: () => now,
  );

  Future<RecordState> state(String table, String rowId) async {
    final RecordState? read = await RecordReader(db).read(table, rowId);
    return RecordState.fromJson(
      jsonDecode(jsonEncode(read!.toJson())) as Map<String, Object?>,
    );
  }

  Future<ApplyOutcome> apply(RecordState state) => applier.apply(state);

  Future<void> applyAll(Iterable<RecordState> states) async {
    for (final RecordState state in states) {
      expect(await apply(state), ApplyOutcome.applied);
    }
  }

  Future<Day> day() async {
    return (await days.dayById(dayIdForDate(_date)))!;
  }

  Future<Entry> entry() async {
    return (await entries.entryById(_entryId))!;
  }

  Future<List<Entry>> allEntries() => db.select(db.entries).get();

  Future<List<Entry>> conflictCopies() {
    return (db.select(
      db.entries,
    )..where((t) => t.conflictSourceDevice.isNotNull())).get();
  }

  Future<List<SyncOutboxData>> outbox() => db.select(db.syncOutbox).get();

  Future<void> shareBase() async {
    final Entry shared = await entry();
    await db
        .into(db.syncTextBases)
        .insertOnConflictUpdate(
          SyncTextBasesCompanion.insert(
            entryId: shared.id,
            textContent: shared.textContent!,
            clock:
                (jsonDecode(shared.fieldClocks)
                        as Map<String, Object?>)['textContent']!
                    as String,
            version: shared.textVersion,
          ),
        );
  }

  Future<void> addDay({String? moodId}) async {
    await days.insertDay(
      date: _date,
      moodId: moodId,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> addText(String text) async {
    await entries.insertEntry(
      id: _entryId,
      dayId: dayIdForDate(_date),
      type: EntryType.text.id,
      textContent: text,
      mediaId: null,
      thumbnailMediaId: null,
      durationMs: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> editText(String text) async {
    await entries.updateText(id: _entryId, textContent: text, updatedAt: now);
  }
}

void main() {
  final List<_Device> devices = <_Device>[];

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  _Device device(String name) {
    final _Device created = _Device(name);
    devices.add(created);
    return created;
  }

  tearDown(() async {
    for (final _Device created in devices) {
      await created.db.close();
    }
    devices.clear();
  });

  Future<void> shareEntry(_Device from, _Device to, String text) async {
    await from.addDay();
    await from.addText(text);
    await from.shareBase();
    await to.applyAll(<RecordState>[
      await from.state(SyncedTables.days, dayIdForDate(_date)),
      await from.state(SyncedTables.entries, _entryId),
    ]);
  }

  Future<void> inEitherOrder(
    RecordState first,
    RecordState second,
    Future<void> Function(_Device fresh) check,
  ) async {
    for (final List<RecordState> order in <List<RecordState>>[
      <RecordState>[first, second],
      <RecordState>[second, first],
    ]) {
      final _Device fresh = device('Tablet')..now = _noon + 10 * _minute;
      await fresh.applyAll(order);
      await check(fresh);
    }
  }

  test('a state more than five minutes ahead is held back', () async {
    final _Device phone = device('Phone')
      ..now = _noon + HlcClock.maxAhead.inMilliseconds + 1;
    final _Device mac = device('Mac');
    await phone.addDay(moodId: 'sunny');
    await phone.addText('from the future');

    final ApplyOutcome dayOutcome = await mac.apply(
      await phone.state(SyncedTables.days, dayIdForDate(_date)),
    );
    final ApplyOutcome entryOutcome = await mac.apply(
      await phone.state(SyncedTables.entries, _entryId),
    );

    expect(dayOutcome, ApplyOutcome.heldBack);
    expect(entryOutcome, ApplyOutcome.heldBack);
    expect(await mac.db.select(mac.db.days).get(), isEmpty);
    expect(await mac.allEntries(), isEmpty);
    expect(await mac.db.select(mac.db.syncTextBases).get(), isEmpty);
    expect(await mac.outbox(), isEmpty);
  });

  test('the newest mood wins in either order', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await phone.addDay();
    await mac.applyAll(<RecordState>[
      await phone.state(SyncedTables.days, dayIdForDate(_date)),
    ]);
    phone.now = _noon + _minute;
    await phone.days.updateMood(
      id: dayIdForDate(_date),
      moodId: 'sunny',
      updatedAt: phone.now,
    );
    mac.now = _noon + 2 * _minute;
    await mac.days.updateMood(
      id: dayIdForDate(_date),
      moodId: 'rainy',
      updatedAt: mac.now,
    );
    final RecordState sunny = await phone.state(
      SyncedTables.days,
      dayIdForDate(_date),
    );
    final RecordState rainy = await mac.state(
      SyncedTables.days,
      dayIdForDate(_date),
    );

    await phone.applyAll(<RecordState>[rainy]);
    await mac.applyAll(<RecordState>[sunny]);

    expect((await phone.day()).moodId, 'rainy');
    expect((await mac.day()).moodId, 'rainy');
    await inEitherOrder(sunny, rainy, (_Device fresh) async {
      expect((await fresh.day()).moodId, 'rainy');
    });
  });

  test('a day created later without a mood keeps the other mood', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await mac.addDay(moodId: 'sunny');
    phone.now = _noon + _minute;
    await phone.addDay();
    final RecordState planted = await mac.state(
      SyncedTables.days,
      dayIdForDate(_date),
    );
    final RecordState empty = await phone.state(
      SyncedTables.days,
      dayIdForDate(_date),
    );

    await phone.applyAll(<RecordState>[planted]);
    await mac.applyAll(<RecordState>[empty]);

    expect((await phone.day()).moodId, 'sunny');
    expect((await mac.day()).moodId, 'sunny');
    await inEitherOrder(planted, empty, (_Device fresh) async {
      expect((await fresh.day()).moodId, 'sunny');
    });
  });

  test('a delete wins over a later edit', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await shareEntry(phone, mac, 'first');
    phone.now = _noon + _minute;
    await phone.entries.softDelete(id: _entryId, deletedAt: phone.now);
    mac.now = _noon + 2 * _minute;
    await mac.editText('edited later');
    final RecordState deleted = await phone.state(
      SyncedTables.entries,
      _entryId,
    );
    final RecordState edited = await mac.state(SyncedTables.entries, _entryId);

    await phone.applyAll(<RecordState>[edited]);
    await mac.applyAll(<RecordState>[deleted]);

    expect((await phone.entry()).deletedAt, isNotNull);
    expect((await mac.entry()).deletedAt, isNotNull);
    await inEitherOrder(deleted, edited, (_Device fresh) async {
      expect((await fresh.entry()).deletedAt, isNotNull);
    });
  });

  test('a revive later than a delete wins', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await phone.addDay(moodId: 'sunny');
    await mac.applyAll(<RecordState>[
      await phone.state(SyncedTables.days, dayIdForDate(_date)),
    ]);
    phone.now = _noon + _minute;
    await phone.days.softDelete(id: dayIdForDate(_date), deletedAt: phone.now);
    final RecordState deleted = await phone.state(
      SyncedTables.days,
      dayIdForDate(_date),
    );
    await mac.applyAll(<RecordState>[deleted]);
    expect((await mac.day()).deletedAt, isNotNull);
    mac.now = _noon + 2 * _minute;
    await mac.addDay(moodId: 'rainy');
    final RecordState revived = await mac.state(
      SyncedTables.days,
      dayIdForDate(_date),
    );

    await phone.applyAll(<RecordState>[revived]);

    expect((await phone.day()).deletedAt, isNull);
    expect((await phone.day()).moodId, 'rainy');
    expect((await mac.day()).deletedAt, isNull);
    await inEitherOrder(deleted, revived, (_Device fresh) async {
      expect((await fresh.day()).deletedAt, isNull);
      expect((await fresh.day()).moodId, 'rainy');
    });
  });

  test('a deleted entry makes no conflict copy', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await shareEntry(phone, mac, 'a\nb');
    phone.now = _noon + _minute;
    await phone.editText('a\nX');
    phone.now = _noon + 2 * _minute;
    await phone.entries.softDelete(id: _entryId, deletedAt: phone.now);
    mac.now = _noon + 3 * _minute;
    await mac.editText('a\nY');
    final RecordState deleted = await phone.state(
      SyncedTables.entries,
      _entryId,
    );
    final RecordState edited = await mac.state(SyncedTables.entries, _entryId);

    await phone.applyAll(<RecordState>[edited]);
    await mac.applyAll(<RecordState>[deleted]);

    Future<void> expectNoLiveText(_Device holder) async {
      expect((await holder.entry()).deletedAt, isNotNull);
      expect(await holder.conflictCopies(), isEmpty);
      expect(
        (await holder.allEntries()).where((Entry row) => row.deletedAt == null),
        isEmpty,
      );
    }

    await expectNoLiveText(phone);
    await expectNoLiveText(mac);
    await inEitherOrder(deleted, edited, expectNoLiveText);
  });

  test(
    'a remote text the local one already includes changes nothing',
    () async {
      final _Device phone = device('Phone');
      final _Device mac = device('Mac');
      await shareEntry(phone, mac, 'first');
      final RecordState older = await phone.state(
        SyncedTables.entries,
        _entryId,
      );
      mac.now = _noon + _minute;
      await mac.editText('second');
      final Entry before = await mac.entry();
      final List<SyncOutboxData> outboxBefore = await mac.outbox();

      await mac.applyAll(<RecordState>[older]);

      expect(await mac.entry(), before);
      expect((await mac.entry()).textContent, 'second');
      expect(await mac.allEntries(), hasLength(1));
      expect(await mac.outbox(), outboxBefore);
    },
  );

  test(
    'an own earlier text coming back stale makes no conflict copy',
    () async {
      final _Device mac = device('Mac');
      await mac.addDay();
      await mac.addText('one');
      await mac.shareBase();
      mac.now = _noon + _minute;
      await mac.editText('two');
      final RecordState accepted = await mac.state(
        SyncedTables.entries,
        _entryId,
      );
      mac.now = _noon + 2 * _minute;
      await mac.editText('three');
      final Entry before = await mac.entry();

      await mac.applyAll(<RecordState>[accepted]);

      expect(await mac.entry(), before);
      expect((await mac.entry()).textContent, 'three');
      expect(await mac.conflictCopies(), isEmpty);
      expect(await mac.allEntries(), hasLength(1));
    },
  );

  test('overlapping text edits keep a conflict copy', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await shareEntry(phone, mac, 'a\nb');
    mac.now = _noon + _minute;
    await mac.editText('a\nX');
    phone.now = _noon + 2 * _minute;
    await phone.editText('a\nY');
    await mac.db.delete(mac.db.syncOutbox).go();

    await mac.applyAll(<RecordState>[
      await phone.state(SyncedTables.entries, _entryId),
    ]);

    final Entry kept = await mac.entry();
    final List<Entry> copies = await mac.conflictCopies();
    expect(kept.textContent, 'a\nY');
    expect(kept.deletedAt, isNull);
    expect(copies, hasLength(1));
    expect(copies.single.textContent, 'a\nX');
    expect(copies.single.conflictSourceDevice, 'Mac');
    expect(copies.single.dayId, kept.dayId);
    expect(copies.single.type, EntryType.text.id);
    expect(copies.single.deletedAt, isNull);
    expect(
      (await mac.outbox()).map((SyncOutboxData row) => row.rowId),
      <String>[copies.single.id],
    );
  });

  test('concurrent texts without a shared base keep a conflict copy', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await shareEntry(phone, mac, 'a\nb\nc');
    phone.now = _noon + _minute;
    await phone.editText('A\nb\nc');
    await phone.shareBase();
    mac.now = _noon + 2 * _minute;
    await mac.editText('a\nb\nC');

    await phone.applyAll(<RecordState>[
      await mac.state(SyncedTables.entries, _entryId),
    ]);

    final List<Entry> copies = await phone.conflictCopies();
    expect((await phone.entry()).textContent, 'a\nb\nC');
    expect(copies, hasLength(1));
    expect(copies.single.textContent, 'A\nb\nc');
    expect(copies.single.conflictSourceDevice, 'Phone');
  });

  test('concurrent texts with no stored base keep a conflict copy', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await shareEntry(phone, mac, 'a\nb\nc');
    await phone.db.delete(phone.db.syncTextBases).go();
    phone.now = _noon + _minute;
    await phone.editText('A\nb\nc');
    mac.now = _noon + 2 * _minute;
    await mac.editText('a\nb\nC');

    await phone.applyAll(<RecordState>[
      await mac.state(SyncedTables.entries, _entryId),
    ]);

    final List<Entry> copies = await phone.conflictCopies();
    expect((await phone.entry()).textContent, 'a\nb\nC');
    expect(copies.single.textContent, 'A\nb\nc');
  });

  test('separate concurrent edits merge into one entry to push', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await shareEntry(phone, mac, 'a\nb\nc');
    phone.now = _noon + _minute;
    await phone.editText('A\nb\nc');
    mac.now = _noon + 2 * _minute;
    await mac.editText('a\nb\nC');
    final RecordState remote = await mac.state(SyncedTables.entries, _entryId);
    await phone.db.delete(phone.db.syncOutbox).go();
    phone.now = _noon + 3 * _minute;

    await phone.applyAll(<RecordState>[remote]);

    final Entry merged = await phone.entry();
    final Map<String, Object?> version =
        jsonDecode(merged.textVersion) as Map<String, Object?>;
    final Map<String, Object?> clocks =
        jsonDecode(merged.fieldClocks) as Map<String, Object?>;
    expect(merged.textContent, 'A\nb\nC');
    expect(await phone.conflictCopies(), isEmpty);
    expect(version[phone.recorder.nodeId], 3);
    expect(version[mac.recorder.nodeId], 1);
    expect(
      Hlc.parse(clocks['textContent']! as String) >
          Hlc.parse(remote.clocks['textContent']!),
      isTrue,
    );
    expect(
      (await phone.outbox()).map((SyncOutboxData row) => row.rowId),
      <String>[_entryId],
    );

    await mac.applyAll(<RecordState>[
      await phone.state(SyncedTables.entries, _entryId),
    ]);

    expect((await mac.entry()).textContent, 'A\nb\nC');
    expect((await mac.entry()).textVersion, merged.textVersion);
  });

  test('a media blob state stores its metadata at a local path', () async {
    final _Device mac = device('Mac');
    final String blobId = List<String>.filled(64, 'b').join();
    final RecordState blob = RecordState(
      table: SyncedTables.mediaBlobs,
      rowId: blobId,
      fields: <String, Object?>{
        'id': blobId,
        'mime': 'image/jpeg',
        'kind': MediaKind.photo.id,
        'bytes': 2048,
        'width': 640,
        'height': 480,
        'durationMs': null,
        'createdAt': _noon,
        'posterId': null,
      },
      clocks: <String, String>{
        for (final String field in SyncedTables.mediaBlobFields)
          field: Hlc(millis: _noon, counter: 0, nodeId: 'phone').encode(),
      },
    );

    await mac.applyAll(<RecordState>[blob]);

    final MediaBlob stored = await (mac.db.select(
      mac.db.mediaBlobs,
    )..where((t) => t.id.equals(blobId))).getSingle();
    expect(
      stored.relPath,
      relPathForBlob(id: blobId, mime: 'image/jpeg', kind: MediaKind.photo),
    );
    expect(stored.width, 640);
    expect(await mac.outbox(), isEmpty);
    expect(
      (await mac.state(SyncedTables.mediaBlobs, blobId)).fields.keys,
      isNot(contains('relPath')),
    );
  });

  test('an applied state reaches open live queries', () async {
    final _Device phone = device('Phone');
    final _Device mac = device('Mac');
    await phone.addDay();
    await phone.addText('hello from the phone');
    final Future<void> arrived = expectLater(
      mac.entries.watchActiveEntriesForDate(_date),
      emitsThrough(
        predicate<List<Entry>>(
          (List<Entry> shown) => shown.any(
            (Entry row) =>
                row.id == _entryId && row.textContent == 'hello from the phone',
          ),
        ),
      ),
    );

    await mac.applyAll(<RecordState>[
      await phone.state(SyncedTables.days, dayIdForDate(_date)),
      await phone.state(SyncedTables.entries, _entryId),
    ]);

    await arrived;
  });
}
