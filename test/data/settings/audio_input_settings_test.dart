import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String?> _localRow(AppDatabase db, String key) async {
  final Setting? row = await (db.select(
    db.settings,
  )..where((t) => t.key.equals(key))).getSingleOrNull();
  return row?.value;
}

Future<JournalSetting?> _journalRow(AppDatabase db, String key) {
  return (db.select(
    db.journalSettings,
  )..where((t) => t.key.equals(key))).getSingleOrNull();
}

Future<void> _writeRow(AppDatabase db, String key, String value) {
  return db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
}

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftSettingsRepository(
      db,
      JournalSettingsStore(db, ChangeRecorder(db)),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'audio input settings round-trip through the local settings rows',
    () async {
      await repository.setInputProfile(InputProfile.voiceIsolation);
      expect(
        (await repository.watch().first).inputProfile,
        InputProfile.voiceIsolation,
      );
      expect(await _localRow(db, 'input_profile'), 'voiceIsolation');

      await repository.setInputProfile(InputProfile.studio);
      expect(
        (await repository.watch().first).inputProfile,
        InputProfile.studio,
      );
      expect(await _localRow(db, 'input_profile'), 'studio');

      await repository.setInputVolume(0);
      expect((await repository.watch().first).inputVolume, 0);
      expect(await _localRow(db, 'input_volume'), '0');

      await repository.setInputVolume(37);
      expect((await repository.watch().first).inputVolume, 37);
      expect(await _localRow(db, 'input_volume'), '37');

      await repository.setInputVolume(100);
      expect((await repository.watch().first).inputVolume, 100);
      expect(await _localRow(db, 'input_volume'), '100');

      await repository.setInputVolume(180);
      expect((await repository.watch().first).inputVolume, 180);
      expect(await _localRow(db, 'input_volume'), '180');

      await repository.setAudioInputId('mic-1');
      expect((await repository.watch().first).audioInputId, 'mic-1');
      expect(await _localRow(db, 'audio_input_id'), 'mic-1');

      expect(await _journalRow(db, 'input_profile'), isNull);
      expect(await _journalRow(db, 'input_volume'), isNull);
      expect(await _journalRow(db, 'audio_input_id'), isNull);
    },
  );

  test('missing audio input rows read as the defaults', () async {
    final AppSettings loaded = await repository.load();

    expect(loaded.inputProfile, InputProfile.studio);
    expect(loaded.inputVolume, 100);
    expect(loaded.audioInputId, isNull);
  });

  test('malformed audio input rows read as safe values', () async {
    await _writeRow(db, 'input_profile', 'loud');
    expect((await repository.load()).inputProfile, InputProfile.studio);
    await _writeRow(db, 'input_profile', '');
    expect((await repository.load()).inputProfile, InputProfile.studio);

    await _writeRow(db, 'input_volume', 'abc');
    expect((await repository.load()).inputVolume, 100);
    await _writeRow(db, 'input_volume', '-5');
    expect((await repository.load()).inputVolume, 0);
    await _writeRow(db, 'input_volume', '900');
    expect((await repository.load()).inputVolume, 200);

    await _writeRow(db, 'audio_input_id', '');
    expect((await repository.load()).audioInputId, isNull);
  });

  test('whole numbers beyond 64 bits clamp to the volume\'s ends', () async {
    await _writeRow(db, 'input_volume', '9223372036854775808');
    expect((await repository.load()).inputVolume, 200);
    await _writeRow(db, 'input_volume', '99999999999999999999');
    expect((await repository.load()).inputVolume, 200);
    await _writeRow(db, 'input_volume', '-9223372036854775809');
    expect((await repository.load()).inputVolume, 0);
    await _writeRow(db, 'input_volume', '-99999999999999999999');
    expect((await repository.load()).inputVolume, 0);
  });
}
