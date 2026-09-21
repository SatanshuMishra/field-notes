import 'package:field_notes/domain/services/delete_all_service.dart';
import 'package:field_notes/domain/services/export_service.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/data/data_exceptions.dart';
import 'package:field_notes/features/data/export_delivery.dart';
import 'package:field_notes/features/data/export_runner.dart';
import 'package:field_notes/features/settings/journal_data_controller.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:flutter_test/flutter_test.dart';

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
  }) async =>
      outcome;
}

class _StubDeleteAllService implements DeleteAllService {
  _StubDeleteAllService({this.error});

  final Object? error;
  int calls = 0;

  @override
  Future<DeleteAllResult> deleteAll() async {
    calls++;
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return const DeleteAllResult(
      deletedDays: 3,
      deletedEntries: 7,
      deletedPhotos: 2,
      deletedMediaBlobs: 2,
      deletedFiles: 2,
    );
  }
}

class _StubReclaimMediaStore implements MediaStore {
  _StubReclaimMediaStore({this.reclaimed = 0, this.error});

  final int reclaimed;
  final Object? error;
  int calls = 0;

  @override
  Future<int> collectGarbage() async {
    calls++;
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return reclaimed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

JournalDataController _controller({
  required ExportService exportService,
  required ExportOutcome outcome,
  DeleteAllService? deleteAllService,
  MediaStore? mediaStore,
  void Function(Object error)? onError,
}) {
  return JournalDataController(
    exportRunner: ExportRunner(
      exportService: exportService,
      delivery: _StubDelivery(outcome),
    ),
    deleteAllService: deleteAllService ?? _StubDeleteAllService(),
    mediaStore: mediaStore ?? _StubReclaimMediaStore(),
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
      final _StubReclaimMediaStore store = _StubReclaimMediaStore(reclaimed: 4);
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        mediaStore: store,
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
        mediaStore: _StubReclaimMediaStore(),
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
        mediaStore: _StubReclaimMediaStore(reclaimed: 1),
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

    test('turns a sweep failure into a user-facing message', () async {
      final List<Object> reported = <Object>[];
      final SettingsDataController controller = _controller(
        exportService: _FakeExportService(),
        outcome: const ExportDismissed(),
        mediaStore: _StubReclaimMediaStore(error: StateError('disk gone')),
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
}
