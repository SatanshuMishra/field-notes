import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_reminder_ledger_store.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/settings/settings_keys.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/services/reminder_ledger.dart';
import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

final List<int> _ids = ReminderService.bookingIds;

final ReminderLedger _week = ReminderLedger(
  booked: <ReminderBooking>[
    ReminderBooking(
      id: _ids[0],
      at: DateTime(2026, 11, 10, 20, 30),
      body: reminderEveningBody,
    ),
    ReminderBooking(
      id: _ids[1],
      at: DateTime(2026, 11, 10, 22, 30),
      body: reminderLastCallBody,
    ),
  ],
  unsettled: <int>{_ids[5]},
);

Future<void> _store(AppDatabase db, String value) => db
    .into(db.settings)
    .insertOnConflictUpdate(
      SettingsCompanion(
        key: const Value<String>(SettingsKeys.reminderLedger),
        value: Value<String>(value),
      ),
    );

void main() {
  late AppDatabase db;
  late DriftReminderLedgerStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftReminderLedgerStore(db);
  });

  tearDown(() => db.close());

  test('nothing is read before the first write', () async {
    expect(await store.read(), isNull);
  });

  test('a written ledger reads back the same bookings and ids', () async {
    await store.write(_week);

    final ReminderLedger? read = await store.read();

    expect(read, _week);
    expect(read!.booked.first.at, DateTime(2026, 11, 10, 20, 30));
    expect(read.booked.first.at.isUtc, isFalse);
  });

  test('a later write replaces the earlier one', () async {
    await store.write(_week);
    const ReminderLedger cleared = ReminderLedger(
      booked: <ReminderBooking>[],
      unsettled: <int>{},
    );

    await store.write(cleared);

    expect(await store.read(), cleared);
    expect(await db.select(db.settings).get(), hasLength(1));
  });

  test('a garbled or out-of-range ledger reads as none', () async {
    for (final String raw in <String>[
      'not json',
      '[]',
      '{"booked": [], "unsettled": ["1001"]}',
      '{"booked": [{"id": 9, "at": 0, "body": "x"}], "unsettled": []}',
      '{"booked": [{"id": 1001, "at": "today", "body": "x"}], '
          '"unsettled": []}',
      '{"booked": []}',
    ]) {
      await _store(db, raw);

      expect(await store.read(), isNull, reason: raw);
    }
  });

  test('the ledger is a device record, neither a stored setting nor '
      'exported', () async {
    await store.write(_week);

    final DriftSettingsRepository settings = DriftSettingsRepository(
      db,
      JournalSettingsStore(db, ChangeRecorder(db)),
    );

    expect(await settings.hasStoredValues(), isFalse);
    expect(SettingsKeys.isExportedKey(SettingsKeys.reminderLedger), isFalse);
    expect(SettingsKeys.isDeviceRecordKey(SettingsKeys.reminderLedger), isTrue);
  });
}
