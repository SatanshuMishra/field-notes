import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/settings/drift_settings_repository.dart';
import 'package:field_notes/data/settings/journal_settings_store.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
JournalRepository journalRepository(Ref ref) {
  return DriftJournalRepository(
    ref.watch(databaseProvider),
    recorder: ref.watch(changeRecorderProvider),
  );
}

@Riverpod(keepAlive: true)
JournalSettingsStore journalSettingsStore(Ref ref) {
  return JournalSettingsStore(
    ref.watch(databaseProvider),
    ref.watch(changeRecorderProvider),
  );
}

@Riverpod(keepAlive: true)
Stream<Map<String, String>> journalSettingChanges(Ref ref) {
  return ref.watch(journalSettingsStoreProvider).watch();
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return DriftSettingsRepository(
    ref.watch(databaseProvider),
    ref.watch(journalSettingsStoreProvider),
  );
}
