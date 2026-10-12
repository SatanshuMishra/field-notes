import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/updates/update_record_store.dart';
import 'package:field_notes/domain/updates/updates.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

ReleaseInfo _release(String version) {
  return ReleaseInfo(
    version: AppVersion.tryParse(version)!,
    tag: 'v$version',
    publishedAt: DateTime.utc(2026, 10, 1, 12, 15),
    notes: ReleaseNotes(
      intro: 'A calmer settings page.',
      groups: <ReleaseNoteGroup>[
        ReleaseNoteGroup(
          title: 'Added',
          items: <String>['About page.', 'Update checks.'],
        ),
        ReleaseNoteGroup(title: 'Fixed', items: <String>['Draft saving.']),
      ],
    ),
    pageUrl: Uri.parse(
      'https://github.com/SatanshuMishra/field-notes/releases/tag/v$version',
    ),
    assets: <ReleaseAsset>[
      ReleaseAsset(
        name: 'field-notes-$version-android.apk',
        url: Uri.parse(
          'https://github.com/SatanshuMishra/field-notes/releases/download/'
          'v$version/field-notes-$version-android.apk',
        ),
        size: 52428800,
      ),
      ReleaseAsset(
        name: 'SHA256SUMS.txt',
        url: Uri.parse(
          'https://github.com/SatanshuMishra/field-notes/releases/download/'
          'v$version/SHA256SUMS.txt',
        ),
        size: 300,
      ),
    ],
  );
}

Future<Map<String, String>> _deviceRows(AppDatabase db) async {
  final List<Setting> rows = await db.select(db.settings).get();
  return <String, String>{for (final Setting row in rows) row.key: row.value};
}

Future<void> _store(AppDatabase db, String key, String value) async {
  await db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fn_update_record');
    file = File(p.join(directory.path, 'field_notes.sqlite'));
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'the update record survives a restart and ignores damaged values',
    () async {
      final ReleaseInfo known = _release('1.4.0');
      final DateTime checkedAt = DateTime.utc(2026, 10, 11, 9, 30, 5);

      final AppDatabase first = AppDatabase(NativeDatabase(file));
      final DriftUpdateRecordStore fresh = DriftUpdateRecordStore(first);
      expect(await fresh.read(), UpdateRecord.empty);
      expect(UpdateRecord.empty.lastCheckedAt, isNull);
      expect(UpdateRecord.empty.lastAvailable, isNull);
      expect(UpdateRecord.empty.lastSeenVersion, isNull);

      await fresh.recordCheck(checkedAt, known);
      await fresh.recordSeenVersion('1.3.0');
      final Map<String, String> written = await _deviceRows(first);
      expect(written['update_last_checked_at'], '2026-10-11T09:30:05.000Z');
      expect(jsonDecode(written['update_last_available']!), known.toJson());
      expect(written['update_last_seen_version'], '1.3.0');
      expect(await first.select(first.journalSettings).get(), isEmpty);
      expect(await first.select(first.syncOutbox).get(), isEmpty);
      await first.close();

      final AppDatabase second = AppDatabase(NativeDatabase(file));
      final DriftUpdateRecordStore restarted = DriftUpdateRecordStore(second);
      final UpdateRecord restored = await restarted.read();
      expect(restored.lastCheckedAt, checkedAt);
      expect(restored.lastCheckedAt!.isUtc, isTrue);
      expect(restored.lastAvailable, known);
      expect(restored.lastSeenVersion, '1.3.0');
      expect(
        restored,
        UpdateRecord(
          lastCheckedAt: checkedAt,
          lastAvailable: known,
          lastSeenVersion: '1.3.0',
        ),
      );

      final DateTime attemptedAt = DateTime.utc(2026, 10, 12, 9, 31);
      await restarted.recordAttempt(attemptedAt);
      expect(
        await restarted.read(),
        UpdateRecord(
          lastCheckedAt: attemptedAt,
          lastAvailable: known,
          lastSeenVersion: '1.3.0',
        ),
      );

      final DateTime localAttempt = DateTime(2026, 10, 13, 8, 45);
      await restarted.recordAttempt(localAttempt);
      final Map<String, String> afterLocal = await _deviceRows(second);
      expect(
        afterLocal['update_last_checked_at'],
        localAttempt.toUtc().toIso8601String(),
      );
      expect(afterLocal['update_last_checked_at'], endsWith('Z'));
      expect((await restarted.read()).lastCheckedAt, localAttempt.toUtc());
      expect((await restarted.read()).lastAvailable, known);

      await restarted.recordSeenVersion('1.4.0');
      expect(
        await restarted.read(),
        UpdateRecord(
          lastCheckedAt: localAttempt.toUtc(),
          lastAvailable: known,
          lastSeenVersion: '1.4.0',
        ),
      );

      final DateTime currentAt = DateTime.utc(2026, 10, 14, 7);
      await restarted.recordCheck(currentAt, null);
      expect(
        (await _deviceRows(second)).containsKey('update_last_available'),
        isFalse,
      );
      await second.close();

      final AppDatabase third = AppDatabase(NativeDatabase(file));
      addTearDown(third.close);
      final DriftUpdateRecordStore again = DriftUpdateRecordStore(third);
      expect(
        await again.read(),
        UpdateRecord(lastCheckedAt: currentAt, lastSeenVersion: '1.4.0'),
      );

      await _store(third, 'update_last_checked_at', 'yesterday morning');
      await _store(
        third,
        'update_last_available',
        '{"version": "1.5.0", "tag"',
      );
      await _store(third, 'update_last_seen_version', 'not a version');
      expect(await again.read(), UpdateRecord.empty);

      await _store(third, 'update_last_checked_at', '2026-13-45T99:00:00Z');
      await _store(
        third,
        'update_last_available',
        jsonEncode(<String, Object?>{'version': '1.5.0', 'tag': 'v1.5.0'}),
      );
      await _store(third, 'update_last_seen_version', '');
      expect(await again.read(), UpdateRecord.empty);

      await _store(third, 'update_last_checked_at', '');
      await _store(third, 'update_last_available', '[1, 2, 3]');
      expect(await again.read(), UpdateRecord.empty);

      await _store(third, 'update_last_available', 'null');
      expect((await again.read()).lastAvailable, isNull);

      final Map<String, Object?> wrongAssets = <String, Object?>{
        ...known.toJson(),
        'assets': 'none',
      };
      await _store(third, 'update_last_available', jsonEncode(wrongAssets));
      expect((await again.read()).lastAvailable, isNull);

      await _store(third, 'update_last_checked_at', '2026-10-11T09:30:05');
      expect((await again.read()).lastCheckedAt, isNull);
      await _store(third, 'update_last_checked_at', '2026-10-11T09:30:05.000Z');
      expect(
        (await again.read()).lastCheckedAt,
        DateTime.utc(2026, 10, 11, 9, 30, 5),
      );

      await again.recordCheck(checkedAt, known);
      await again.recordSeenVersion('1.3.0');
      expect(
        await DriftUpdateRecordStore(third).read(),
        UpdateRecord(
          lastCheckedAt: checkedAt,
          lastAvailable: known,
          lastSeenVersion: '1.3.0',
        ),
      );
    },
  );

  test('the in-memory record store keeps the same rules', () async {
    final ReleaseInfo known = _release('1.4.0');
    expect(await MemoryUpdateRecordStore().read(), UpdateRecord.empty);

    final MemoryUpdateRecordStore store = MemoryUpdateRecordStore(
      UpdateRecord(
        lastCheckedAt: DateTime.utc(2026, 10, 1),
        lastSeenVersion: '1.2.0',
      ),
    );
    expect(store.record.lastCheckedAt, DateTime.utc(2026, 10, 1));

    final DateTime checkedAt = DateTime.utc(2026, 10, 11, 9);
    await store.recordCheck(checkedAt, known);
    expect(
      await store.read(),
      UpdateRecord(
        lastCheckedAt: checkedAt,
        lastAvailable: known,
        lastSeenVersion: '1.2.0',
      ),
    );

    final DateTime attemptedAt = DateTime.utc(2026, 10, 12, 9);
    await store.recordAttempt(attemptedAt);
    expect(
      await store.read(),
      UpdateRecord(
        lastCheckedAt: attemptedAt,
        lastAvailable: known,
        lastSeenVersion: '1.2.0',
      ),
    );

    await store.recordSeenVersion('1.4.0');
    expect((await store.read()).lastSeenVersion, '1.4.0');
    expect((await store.read()).lastAvailable, known);

    final DateTime currentAt = DateTime.utc(2026, 10, 13, 9);
    await store.recordCheck(currentAt, null);
    expect(
      await store.read(),
      UpdateRecord(lastCheckedAt: currentAt, lastSeenVersion: '1.4.0'),
    );
  });

  test('the update record provider stores in the app database', () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final UpdateRecordStore store = container.read(updateRecordStoreProvider);
    expect(store, isA<DriftUpdateRecordStore>());
    expect(container.read(updateRecordStoreProvider), same(store));

    await store.recordSeenVersion('1.3.0');
    expect(await _deviceRows(db), <String, String>{
      'update_last_seen_version': '1.3.0',
    });
    expect((await DriftUpdateRecordStore(db).read()).lastSeenVersion, '1.3.0');
  });
}
