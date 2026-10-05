import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart' hide MediaBlob;
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/media_blob.dart';
import 'package:field_notes/domain/models/media_kind.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ChangeRecorder recorder;
  late DriftSettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    recorder = ChangeRecorder(db);
    settings = DriftSettingsRepository(db, JournalSettingsStore(db, recorder));
  });

  tearDown(() async {
    await db.close();
  });

  Future<Set<String>> outbox() async {
    final List<SyncOutboxData> rows = await db.select(db.syncOutbox).get();
    return rows
        .map((SyncOutboxData row) => '${row.recordTable}/${row.rowId}')
        .toSet();
  }

  Future<JournalSetting> journalRow(String key) {
    return (db.select(
      db.journalSettings,
    )..where((t) => t.key.equals(key))).getSingle();
  }

  Set<String> stampedFields(String fieldClocks) {
    return (jsonDecode(fieldClocks) as Map<String, Object?>).keys.toSet();
  }

  test('storing a blob adds an outbox entry', () async {
    final Directory root = await Directory.systemTemp.createTemp('fn_capture');
    addTearDown(() => root.delete(recursive: true));
    final FilesystemMediaStore store = FilesystemMediaStore(
      database: db,
      recorder: recorder,
      root: root,
    );

    final MediaBlob blob = await store.putBytes(
      bytes: const <int>[1, 2, 3, 4],
      mime: 'image/jpeg',
      kind: MediaKind.photo,
      width: 2,
      height: 2,
    );

    expect(await outbox(), <String>{'media_blobs/${blob.id}'});
    final String clocks =
        (await db.select(db.mediaBlobs).getSingle()).fieldClocks;
    expect(stampedFields(clocks), isNot(contains('relPath')));
    expect(stampedFields(clocks), SyncedTables.mediaBlobFields.toSet());

    await db.delete(db.syncOutbox).go();
    await store.putBytes(
      bytes: const <int>[1, 2, 3, 4],
      mime: 'image/jpeg',
      kind: MediaKind.photo,
    );

    expect(await outbox(), isEmpty);
  });

  test('changing week start adds an outbox entry', () async {
    await settings.setWeekStart(WeekStart.monday);

    final JournalSetting row = await journalRow('week_start');
    expect(row.value, '1');
    expect(stampedFields(row.fieldClocks), contains('value'));
    expect(await outbox(), <String>{'journal_settings/week_start'});
    expect((await settings.load()).weekStart, WeekStart.monday);
  });

  test('creating the meadow key adds an outbox entry', () async {
    final int key = await settings.meadowKey();

    final JournalSetting row = await journalRow('meadow_key');
    expect(row.value, '$key');
    expect(stampedFields(row.fieldClocks), contains('value'));
    expect(await outbox(), <String>{'journal_settings/meadow_key'});

    await db.delete(db.syncOutbox).go();
    final SyncState lastBefore = await (db.select(
      db.syncStates,
    )..where((t) => t.key.equals(ChangeRecorder.lastClockKey))).getSingle();

    expect(await settings.meadowKey(), key);
    expect(
      await DriftSettingsRepository(
        db,
        JournalSettingsStore(db, ChangeRecorder(db)),
      ).meadowKey(),
      key,
    );
    expect(await outbox(), isEmpty);
    expect(
      await (db.select(
        db.syncStates,
      )..where((t) => t.key.equals(ChangeRecorder.lastClockKey))).getSingle(),
      lastBefore,
    );
  });

  test('changing a device-only setting adds no outbox entry', () async {
    await settings.setTextSize(TextSize.large);
    await settings.setSidebarCollapsed(true);
    await settings.setKeepAllMediaOnDevice(true);

    expect(await outbox(), isEmpty);
    expect(await db.select(db.journalSettings).get(), isEmpty);
    expect(await db.select(db.syncStates).get(), isEmpty);
    final AppSettings loaded = await settings.load();
    expect(loaded.textSize, TextSize.large);
    expect(loaded.sidebarCollapsed, isTrue);
    expect(loaded.keepAllMediaOnDevice, isTrue);
  });

  test('the meadow follows a synced meadow key', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final int first = await container.read(meadowKeyProvider.future);
    final int synced = (first + 1) % (1 << 32);
    final Completer<int> followed = Completer<int>();
    final ProviderSubscription<AsyncValue<int>> subscription = container
        .listen<AsyncValue<int>>(meadowKeyProvider, (
          AsyncValue<int>? previous,
          AsyncValue<int> next,
        ) {
          if (!next.isLoading &&
              next.value == synced &&
              !followed.isCompleted) {
            followed.complete(next.value);
          }
        }, fireImmediately: true);
    addTearDown(subscription.close);

    await db
        .into(db.journalSettings)
        .insertOnConflictUpdate(
          JournalSettingsCompanion.insert(
            key: 'meadow_key',
            value: '$synced',
            fieldClocks: const Value('{"value":"9999999999999-0000-remote"}'),
          ),
        );

    expect(await followed.future.timeout(const Duration(seconds: 5)), synced);
  });
}
