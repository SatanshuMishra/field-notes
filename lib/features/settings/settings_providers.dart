import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/data/export_delivery.dart';
import 'package:field_notes/features/data/export_runner.dart';
import 'package:field_notes/features/data/journal_delete_all_service.dart';
import 'package:field_notes/features/data/journal_export_service.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'journal_data_controller.dart';
import 'settings_controller.dart';
import 'settings_data_controller.dart';

part 'settings_providers.g.dart';

@Riverpod(keepAlive: true)
SettingsController settingsController(Ref ref) {
  return SettingsController(
    repository: ref.watch(settingsRepositoryProvider),
    onError: (Object error, StackTrace _) =>
        debugPrint('Settings write failed: $error'),
  );
}

final Provider<bool> sidebarCollapsedProvider = Provider<bool>((Ref ref) {
  final AppSettings settings =
      ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
  return settings.sidebarCollapsed;
});

final Provider<bool> meadowPausesWhenInactiveProvider = Provider<bool>((
  Ref ref,
) {
  final AppSettings settings =
      ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
  return settings.meadowPausesWhenInactive;
});

@Riverpod(keepAlive: true)
Future<SettingsDataController> settingsDataController(Ref ref) async {
  final database = ref.watch(databaseProvider);
  final root = await ref.watch(mediaRootProvider.future);
  final mediaStore = await ref.watch(mediaStoreProvider.future);
  return JournalDataController(
    exportRunner: ExportRunner(
      exportService: JournalExportService(
        database: database,
        mediaStore: mediaStore,
      ),
      delivery: defaultExportDelivery(),
    ),
    mediaStore: mediaStore,
    temporaryDirectory: getTemporaryDirectory,
    deleteAllService: JournalDeleteAllService(
      database: database,
      mediaRoot: root,
      draftsRoot: await ref.watch(mediaDraftsRootProvider.future),
      temporaryDirectory: getTemporaryDirectory,
    ),
    onError: (Object error, StackTrace _) =>
        debugPrint('Settings data action failed: $error'),
  );
}
