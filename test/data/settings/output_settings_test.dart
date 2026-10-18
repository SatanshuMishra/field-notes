import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('output settings default to the system output at full volume', () async {
    final loaded = await repository.load();

    expect(loaded.audioOutputId, isNull);
    expect(loaded.outputVolume, 100);
  });

  test('output volume clamps', () async {
    await repository.setOutputVolume(-5);
    expect((await repository.load()).outputVolume, 0);

    await repository.setOutputVolume(140);
    expect((await repository.load()).outputVolume, 100);
  });

  test('output settings stay on this device', () async {
    await repository.setAudioOutputId('b');
    await repository.setOutputVolume(40);

    final rows =
        await (db.select(db.journalSettings)..where(
              (t) => t.key.isIn(<String>['audio_output_id', 'output_volume']),
            ))
            .get();
    expect(rows, isEmpty);

    final loaded = await repository.load();
    expect(loaded.audioOutputId, 'b');
    expect(loaded.outputVolume, 40);
  });
}
