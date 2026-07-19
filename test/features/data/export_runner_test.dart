import 'package:field_notes/domain/services/export_service.dart';
import 'package:field_notes/features/data/data_exceptions.dart';
import 'package:field_notes/features/data/export_delivery.dart';
import 'package:field_notes/features/data/export_runner.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExportService implements ExportService {
  _FakeExportService(this._bundle);

  final ExportBundle _bundle;

  @override
  Future<ExportBundle> buildBundle() async => _bundle;
}

class _ThrowingExportService implements ExportService {
  @override
  Future<ExportBundle> buildBundle() async =>
      throw const ExportException('boom');
}

class _RecordingDelivery implements ExportDelivery {
  _RecordingDelivery(this.outcome);

  final ExportOutcome outcome;
  List<int>? capturedBytes;
  String? capturedName;

  @override
  Future<ExportOutcome> deliver({
    required List<int> zipBytes,
    required String fileName,
  }) async {
    capturedBytes = zipBytes;
    capturedName = fileName;
    return outcome;
  }
}

ExportBundle bundleWith(int exportedAt) => ExportBundle(
      manifest: ExportManifest(
        formatVersion: 1,
        appName: 'Field Notes',
        exportedAt: exportedAt,
        stats: const ExportStats(
          dayCount: 1,
          entryCount: 0,
          photoCount: 0,
          mediaBlobCount: 1,
        ),
      ),
      journalJson: '{"days":[]}',
      mediaFiles: {
        'blobs/ab/cd': [1, 2, 3],
      },
    );

void main() {
  test('run zips the bundle, delivers it, and forwards the outcome', () async {
    final delivery = _RecordingDelivery(const ExportDelivered('/tmp/out.zip'));
    final runner = ExportRunner(
      exportService: _FakeExportService(bundleWith(1751000000000)),
      delivery: delivery,
    );

    final outcome = await runner.run();

    expect(outcome, isA<ExportDelivered>());
    expect((outcome as ExportDelivered).location, '/tmp/out.zip');
    expect(delivery.capturedName, endsWith('.zip'));
    expect(delivery.capturedBytes, isNotNull);
    expect(delivery.capturedBytes!, isNotEmpty);
  });

  test('run forwards a dismissed delivery outcome unchanged', () async {
    final runner = ExportRunner(
      exportService: _FakeExportService(bundleWith(1751000000000)),
      delivery: _RecordingDelivery(const ExportDismissed()),
    );

    expect(await runner.run(), isA<ExportDismissed>());
  });

  test('run propagates an ExportException from the service', () async {
    final runner = ExportRunner(
      exportService: _ThrowingExportService(),
      delivery: _RecordingDelivery(const ExportDismissed()),
    );

    expect(runner.run(), throwsA(isA<ExportException>()));
  });
}
