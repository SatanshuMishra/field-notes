import 'package:field_notes/domain/services/delete_all_service.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/data/export_delivery.dart';
import 'package:field_notes/features/data/export_runner.dart';

import 'settings_controller.dart';
import 'settings_data_controller.dart';

class JournalDataController implements SettingsDataController {
  const JournalDataController({
    required this._exportRunner,
    required this._deleteAllService,
    required this._mediaStore,
    this._onError,
  });

  final ExportRunner _exportRunner;
  final DeleteAllService _deleteAllService;
  final MediaStore _mediaStore;
  final SettingsErrorHandler? _onError;

  @override
  Future<DataActionResult> export() async {
    try {
      final ExportOutcome outcome = await _exportRunner.run();
      return switch (outcome) {
        ExportDelivered(:final String location) =>
          DataActionSucceeded('Exported to $location'),
        ExportDismissed() => const DataActionDismissed(),
      };
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
      return const DataActionFailed('Export failed. Nothing was written.');
    }
  }

  @override
  Future<DataActionResult> deleteAll() async {
    try {
      final DeleteAllResult result = await _deleteAllService.deleteAll();
      return DataActionSucceeded(
        'Deleted ${result.deletedDays} days '
        'and ${result.deletedEntries} entries.',
      );
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
      return const DataActionFailed(
        'Delete all failed. Your journal was not changed.',
      );
    }
  }

  @override
  Future<DataActionResult> reclaimSpace() async {
    try {
      final int reclaimed = await _mediaStore.collectGarbage();
      return DataActionSucceeded(
        reclaimed == 0
            ? 'Nothing to reclaim. Every photo is still in use.'
            : 'Reclaimed $reclaimed unused ${reclaimed == 1 ? 'file' : 'files'}.',
      );
    } catch (error, stackTrace) {
      _onError?.call(error, stackTrace);
      return const DataActionFailed(
        'Reclaim space failed. Nothing was removed.',
      );
    }
  }
}
