import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/journal_delete_all_service.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/delete_all_service.dart';
import 'package:field_notes/domain/services/export_service.dart';
import 'package:field_notes/features/data/data_exceptions.dart';
import 'package:field_notes/features/data/export_delivery.dart';
import 'package:field_notes/features/data/export_runner.dart';
import 'package:field_notes/features/settings/journal_data_controller.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakeExportService implements ExportService {
  @override
  Future<ExportBundle> buildBundle() async => const ExportBundle(
    manifest: ExportManifest(
      formatVersion: 1,
      appName: 'Field Notes',
      exportedAt: 1751000000000,
      stats: ExportStats(
        dayCount: 1,
        entryCount: 2,
        photoCount: 0,
        mediaBlobCount: 0,
      ),
    ),
    journalJson: '{"days":[]}',
    mediaFiles: <String, List<int>>{},
  );
}

class _ThrowingExportService implements ExportService {
  @override
  Future<ExportBundle> buildBundle() async =>
      throw const ExportException('boom');
}

class _StubDelivery implements ExportDelivery {
  const _StubDelivery(this.outcome);

  final ExportOutcome outcome;

  @override
  Future<ExportOutcome> deliver({
    required List<int> zipBytes,
    required String fileName,
  }) async => outcome;
}

class _StubDeleteAllService implements DeleteAllService {
  _StubDeleteAllService({this.error, this.result = _defaultResult});

  static const DeleteAllResult _defaultResult = DeleteAllResult(
    deletedDays: 3,
    deletedEntries: 7,
    deletedPhotos: 2,
    deletedMediaBlobs: 2,
    deletedFiles: 2,
  );

  final Object? error;
  final DeleteAllResult result;
  int calls = 0;

  @override
  Future<DeleteAllResult> deleteAll() async {
    calls++;
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return result;
  }
}

class _StubReclaim {
  _StubReclaim({this.reclaimed = 0, this.error});

  final int reclaimed;
  final Object? error;
  int calls = 0;

  Future<int> call() async {
    calls++;
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return reclaimed;
  }
}

class _TemporaryPaths extends PathProviderPlatform {
  _TemporaryPaths(this.path);

  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

JournalDataController _controller({
  required ExportService exportService,
  required ExportOutcome outcome,
  DeleteAllService? deleteAllService,
  Future<int> Function()? reclaim,
  Future<Directory> Function()? temporaryDirectory,
  void Function(Object error)? onError,
}) {
  return JournalDataController(
    exportRunner: ExportRunner(
      exportService: exportService,
      delivery: _StubDelivery(outcome),
    ),
    deleteAllService: deleteAllService ?? _StubDeleteAllService(),
    reclaim: reclaim ?? _StubReclaim().call,
    temporaryDirectory: temporaryDirectory,
    onError: (Object error, StackTrace _) => onError?.call(error),
  );
}

void main() {
  group('JournalDataController.export', () {
    test('reports where the export was written', () async {
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDelivered('/tmp/field-notes.zip'),
      );

      final DataActionResult result = await controller.export();

      expect(
        result,
        isA<DataActionSucceeded>().having(
          (DataActionSucceeded s) => s.message,
          'message',
          'Exported to /tmp/field-notes.zip',
        ),
      );
    });

    test('reports a dismissed save dialog as dismissed', () async {
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
      );

      expect(await controller.export(), isA<DataActionDismissed>());
    });

    test('turns an export failure into a user-facing message', () async {
      final List<Object> reported = <Object>[];
      final SettingsDataController controller = _controller(
        exportService: _ThrowingExportService(),
        outcome: const ExportDismissed(),
        onError: reported.add,
      );

      final DataActionResult result = await controller.export();

      expect(
        result,
        isA<DataActionFailed>().having(
          (DataActionFailed f) => f.message,
          'message',
          'Export failed. Nothing was written.',
        ),
      );
      expect(reported, hasLength(1));
    });
  });

  group('JournalDataController.deleteAll', () {
    test('reports what was deleted', () async {
      final _StubDeleteAllService deleter = _StubDeleteAllService();
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        deleteAllService: deleter,
      );

      final DataActionResult result = await controller.deleteAll();

      expect(deleter.calls, 1);
      expect(
        result,
        isA<DataActionSucceeded>().having(
          (DataActionSucceeded s) => s.message,
          'message',
          'Deleted 3 days and 7 entries.',
        ),
      );
    });

    test('deleting one day and one entry reports the singular', () async {
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        deleteAllService: _StubDeleteAllService(
          result: const DeleteAllResult(
            deletedDays: 1,
            deletedEntries: 1,
            deletedPhotos: 0,
            deletedMediaBlobs: 0,
            deletedFiles: 0,
          ),
        ),
      );

      final DataActionResult result = await controller.deleteAll();

      expect(
        result,
        isA<DataActionSucceeded>().having(
          (DataActionSucceeded s) => s.message,
          'message',
          'Deleted 1 day and 1 entry.',
        ),
      );
    });

    test('turns a delete failure into a user-facing message', () async {
      final List<Object> reported = <Object>[];
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        deleteAllService: _StubDeleteAllService(
          error: const DeleteAllException('boom'),
        ),
        onError: reported.add,
      );

      final DataActionResult result = await controller.deleteAll();

      expect(
        result,
        isA<DataActionFailed>().having(
          (DataActionFailed f) => f.message,
          'message',
          'Delete all failed. Your journal was not changed.',
        ),
      );
      expect(reported, hasLength(1));
    });
  });

  group('JournalDataController.reclaimSpace', () {
    test('reports how many unused files were reclaimed', () async {
      final _StubReclaim store = _StubReclaim(reclaimed: 4);
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        reclaim: store.call,
      );

      final DataActionResult result = await controller.reclaimSpace();

      expect(store.calls, 1);
      expect(
        result,
        isA<DataActionSucceeded>().having(
          (DataActionSucceeded s) => s.message,
          'message',
          'Reclaimed 4 unused files.',
        ),
      );
    });

    test('says so plainly when there was nothing to reclaim', () async {
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        reclaim: _StubReclaim().call,
      );

      expect(
        await controller.reclaimSpace(),
        isA<DataActionSucceeded>().having(
          (DataActionSucceeded s) => s.message,
          'message',
          'Nothing to reclaim. Every photo is still in use.',
        ),
      );
    });

    test('counts a single reclaimed file in the singular', () async {
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        reclaim: _StubReclaim(reclaimed: 1).call,
      );

      expect(
        await controller.reclaimSpace(),
        isA<DataActionSucceeded>().having(
          (DataActionSucceeded s) => s.message,
          'message',
          'Reclaimed 1 unused file.',
        ),
      );
    });

    test('reclaim space removes temporary capture files', () async {
      final Directory temporary = await Directory.systemTemp.createTemp(
        'fn_reclaim_tmp',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final List<File> captures = <File>[
        File(p.join(temporary.path, 'voice_1720000000000.m4a')),
        File(p.join(temporary.path, 'video_thumb_1720000000000.jpg')),
      ];
      final File unrelated = File(p.join(temporary.path, 'notes.txt'));
      for (final File file in <File>[...captures, unrelated]) {
        await file.writeAsBytes(<int>[1, 2, 3], flush: true);
      }
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        reclaim: _StubReclaim(reclaimed: 1).call,
        temporaryDirectory: () async => temporary,
      );

      final DataActionResult result = await controller.reclaimSpace();

      for (final File capture in captures) {
        expect(await capture.exists(), isFalse);
      }
      expect(await unrelated.exists(), isTrue);
      expect(
        result,
        isA<DataActionSucceeded>().having(
          (DataActionSucceeded s) => s.message,
          'message',
          'Reclaimed 3 unused files.',
        ),
      );
    });

    test('turns a sweep failure into a user-facing message', () async {
      final List<Object> reported = <Object>[];
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        reclaim: _StubReclaim(error: StateError('disk gone')).call,
        onError: reported.add,
      );

      expect(
        await controller.reclaimSpace(),
        isA<DataActionFailed>().having(
          (DataActionFailed f) => f.message,
          'message',
          'Reclaim space failed. Nothing was removed.',
        ),
      );
      expect(reported, hasLength(1));
    });
  });

  group('settingsDataControllerProvider', () {
    late Directory root;
    late AppDatabase database;
    late PathProviderPlatform previous;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('fn_reclaim_sync');
      database = AppDatabase(NativeDatabase.memory());
      previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryPaths(p.join(root.path, 'tmp'));
      await Directory(p.join(root.path, 'tmp')).create();
    });

    tearDown(() async {
      PathProviderPlatform.instance = previous;
      await database.close();
      await root.delete(recursive: true);
    });

    Future<(SettingsDataController, File, String)> reclaimSetup({
      required bool syncOn,
    }) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          mediaRootProvider.overrideWith(
            (Ref ref) async => Directory(p.join(root.path, 'media')),
          ),
          mediaDraftsRootProvider.overrideWith(
            (Ref ref) async => Directory(p.join(root.path, 'drafts')),
          ),
          syncEnabledProvider.overrideWith(
            (Ref ref) => Stream<bool>.value(syncOn),
          ),
        ],
      );
      addTearDown(container.dispose);
      final FilesystemMediaStore store = await container.read(
        filesystemMediaStoreProvider.future,
      );
      final MediaBlob blob = await store.putBytes(
        bytes: const <int>[7, 7, 7, 7],
        mime: 'image/jpeg',
        kind: MediaKind.photo,
      );
      await markBlobUploaded(database, blob.id);
      await writeSyncState(database, pullCompleteKey, pullCompleteValue);
      final SettingsDataController controller = await container.read(
        settingsDataControllerProvider.future,
      );
      return (controller, File(store.absolutePath(blob)), blob.id);
    }

    Future<bool> rowExists(String id) async =>
        await (database.select(
          database.mediaBlobs,
        )..where((t) => t.id.equals(id))).getSingleOrNull() !=
        null;

    test('reclaim space follows the sync state', () async {
      final (SettingsDataController syncing, File syncedFile, String syncedId) =
          await reclaimSetup(syncOn: true);
      expect(await syncedFile.exists(), isTrue);

      final DataActionResult kept = await syncing.reclaimSpace();

      expect(
        kept,
        isA<DataActionSucceeded>().having(
          (DataActionSucceeded s) => s.message,
          'message',
          'Reclaimed 1 unused file.',
        ),
      );
      expect(await syncedFile.exists(), isFalse);
      expect(await rowExists(syncedId), isTrue);

      await database.delete(database.mediaBlobs).go();
      final (SettingsDataController local, File localFile, String localId) =
          await reclaimSetup(syncOn: false);
      expect(await localFile.exists(), isTrue);

      final DataActionResult collected = await local.reclaimSpace();

      expect(collected, isA<DataActionSucceeded>());
      expect(await localFile.exists(), isFalse);
      expect(await rowExists(localId), isFalse);
    });
  });
}
