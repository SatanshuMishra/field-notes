import '../../domain/services/export_service.dart';
import 'export_delivery.dart';
import 'export_zip_writer.dart';

class ExportRunner {
  ExportRunner({
    required this._exportService,
    required this._delivery,
    this._zipWriter = const ExportZipWriter(),
  });

  final ExportService _exportService;
  final ExportDelivery _delivery;
  final ExportZipWriter _zipWriter;

  Future<ExportOutcome> run() async {
    final bundle = await _exportService.buildBundle();
    final zipBytes = _zipWriter.toZipBytes(bundle);
    return _delivery.deliver(
      zipBytes: zipBytes,
      fileName: bundle.suggestedFileName,
    );
  }
}
