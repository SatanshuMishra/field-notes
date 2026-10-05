import 'dart:io';

import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/journal_delete_all_service.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/media/media_gc.dart';
import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:field_notes/data/sync/background/battery_settings.dart';
import 'package:field_notes/data/sync/background/upload_result_applier.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/engine/server_address.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/erase/device_unlink_service.dart';
import 'package:field_notes/data/sync/erase/journal_erase_service.dart';
import 'package:field_notes/data/sync/erase/local_journal_wipe.dart';
import 'package:field_notes/data/sync/join/join_merge.dart';
import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/data/sync/media/media_cache.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/media/poster_maker.dart';
import 'package:field_notes/data/sync/media/unused_blobs.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
KeyStore keyStore(Ref ref) => const KeyStore();

@Riverpod(keepAlive: true)
NetworkMonitor networkMonitor(Ref ref) => ConnectivityNetworkMonitor();

@Riverpod(keepAlive: true)
Stream<bool> syncEnabled(Ref ref) {
  final AppDatabase database = ref.watch(databaseProvider);
  return (database.select(database.syncStates)
        ..where((t) => t.key.equals(SyncStateKeys.syncEnabled)))
      .watchSingleOrNull()
      .map((SyncState? row) => row?.value == syncEnabledValue)
      .distinct();
}

@Riverpod(keepAlive: true)
LifecycleSource appLifecycle(Ref ref) {
  final AppLifecycleSource lifecycle = AppLifecycleSource();
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
}

@Riverpod(keepAlive: true)
SyncEngine syncEngine(Ref ref) {
  final LifecycleSource lifecycle = ref.watch(appLifecycleProvider);
  final SyncEngine engine = SyncEngine(
    database: ref.watch(databaseProvider),
    keyStore: ref.watch(keyStoreProvider),
    recorder: ref.watch(changeRecorderProvider),
    network: ref.watch(networkMonitorProvider),
    lifecycle: lifecycle,
    media: () => ref.read(syncMediaProvider.future),
    join: JoinMerge(
      database: ref.watch(databaseProvider),
      recorder: ref.watch(changeRecorderProvider),
      readMeadowKey: ref.watch(settingsRepositoryProvider).meadowKey,
    ),
    wipe: () async => (await ref.read(localJournalWipeProvider.future)).wipe(),
    backgroundSource: () => ref.read(backgroundTransferProvider.future),
  );
  ref.onDispose(engine.dispose);
  engine.start();
  return engine;
}

@Riverpod(keepAlive: true)
Stream<SyncStatus?> syncStatus(Ref ref) =>
    ref.watch(syncEngineProvider).watchStatus();

@Riverpod(keepAlive: true)
Stream<FirstPullProgress?> firstPullProgress(Ref ref) async* {
  final SyncEngine engine = ref.watch(syncEngineProvider);
  yield engine.firstPullProgress;
  yield* engine.progress;
}

@Riverpod(keepAlive: true)
Future<SyncMedia> syncMedia(Ref ref) async {
  final AppDatabase database = ref.watch(databaseProvider);
  final KeyStore keyStore = ref.watch(keyStoreProvider);
  final FilesystemMediaStore store = await ref.watch(
    filesystemMediaStoreProvider.future,
  );
  final Directory root = await ref.watch(mediaRootProvider.future);
  final Directory drafts = await ref.watch(mediaDraftsRootProvider.future);
  final MediaGarbageCollector collector = MediaGarbageCollector(
    database: database,
    root: root,
    drafts: drafts,
  );
  final UploadQueue uploads = UploadQueue(
    database: database,
    store: store,
    keys: journalKeysFrom(keyStore),
    workRoot: uploadWorkRoot(root),
  );
  return SyncMedia(
    uploads: uploads,
    downloads: DownloadService(
      database: database,
      store: store,
      keyStore: keyStore,
      workRoot: downloadWorkRoot(root),
    ),
    posters: PosterMaker(
      database: database,
      store: store,
      recorder: ref.watch(changeRecorderProvider),
    ),
    cache: MediaCache(
      database: database,
      store: store,
      reachable: collector.reachableMediaIds,
    ),
    unusedBlobs: UnusedBlobReporter(
      database: database,
      reachable: collector.reachableMediaIds,
      keys: journalKeysFrom(keyStore),
      uploads: uploads,
    ),
    settings: ref.watch(settingsRepositoryProvider).load,
  );
}

@Riverpod(keepAlive: true)
Future<LocalJournalWipe> localJournalWipe(Ref ref) async {
  final AppDatabase database = ref.watch(databaseProvider);
  final Directory root = await ref.watch(mediaRootProvider.future);
  return LocalJournalWipe(
    database: database,
    keyStore: ref.watch(keyStoreProvider),
    deleteAll: JournalDeleteAllService(
      database: database,
      mediaRoot: root,
      draftsRoot: await ref.watch(mediaDraftsRootProvider.future),
      temporaryDirectory: getTemporaryDirectory,
    ),
    workDirectories: <Directory>[
      uploadWorkRoot(root),
      downloadWorkRoot(root),
      pushWorkRoot(root),
    ],
    cancelUploads: () async =>
        (await ref.read(backgroundTransferProvider.future))?.uploads
            .cancelAll(),
  );
}

@Riverpod(keepAlive: true)
Future<DeviceUnlinkService> deviceUnlinkService(Ref ref) async =>
    DeviceUnlinkService(
      database: ref.watch(databaseProvider),
      keyStore: ref.watch(keyStoreProvider),
      wipe: await ref.watch(localJournalWipeProvider.future),
      network: ref.watch(networkMonitorProvider),
    );

@Riverpod(keepAlive: true)
Future<JournalEraseService> journalEraseService(Ref ref) async =>
    JournalEraseService(
      database: ref.watch(databaseProvider),
      keyStore: ref.watch(keyStoreProvider),
      wipe: await ref.watch(localJournalWipeProvider.future),
    );

@Riverpod(keepAlive: true)
Stream<String?> syncNotice(Ref ref) async* {
  final SyncEngine engine = ref.watch(syncEngineProvider);
  yield engine.notice;
  yield* engine.notices;
}

@Riverpod(keepAlive: true)
BackgroundUploader backgroundUploader(Ref ref) => PackageBackgroundUploader();

@Riverpod(keepAlive: true)
Future<BackgroundTransfer?> backgroundTransfer(Ref ref) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }
  final AppDatabase database = ref.watch(databaseProvider);
  final LifecycleSource lifecycle = ref.watch(appLifecycleProvider);
  final BackgroundUploader uploader = ref.watch(backgroundUploaderProvider);
  final UploadQueue uploads = (await ref.watch(syncMediaProvider.future))
      .uploads;
  final Directory root = await ref.watch(mediaRootProvider.future);
  final SettingsRepository settings = ref.watch(settingsRepositoryProvider);
  final BackgroundUploads background = BackgroundUploads(
    database: database,
    uploader: uploader,
    keyStore: ref.watch(keyStoreProvider),
    uploads: uploads,
    isVisible: () {
      final AppLifecycleState? state = lifecycle.current;
      return state == null || !isBackgrounded(state);
    },
    pushRoot: pushWorkRoot(root),
    allowMobileData: () async =>
        (await settings.load()).allowMobileDataForMedia,
  );
  return BackgroundTransfer(
    uploads: background,
    results: UploadResultApplier(
      database: database,
      uploader: uploader,
      uploads: uploads,
      background: background,
    ),
    mobileDataChanges: settings
        .watch()
        .map((AppSettings current) => current.allowMobileDataForMedia)
        .distinct(),
  );
}

@Riverpod(keepAlive: true)
BatterySettings batterySettings(Ref ref) => const ChannelBatterySettings();

@riverpod
Future<bool> batteryExempt(Ref ref) =>
    ref.watch(batterySettingsProvider).isExempt();

@Riverpod(keepAlive: true)
ServerAddress serverAddress(Ref ref) {
  final SyncEngine engine = ref.watch(syncEngineProvider);
  return ServerAddress(
    database: ref.watch(databaseProvider),
    keyStore: ref.watch(keyStoreProvider),
    settings: ref.watch(journalSettingsStoreProvider),
    syncNow: engine.syncNow,
  );
}
