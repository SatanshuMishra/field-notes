import 'package:field_notes/domain/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the export file name uses local time', () {
    final exportedAt = DateTime.utc(2026, 9, 25, 0, 18, 10).millisecondsSinceEpoch;
    final bundle = ExportBundle(
      manifest: ExportManifest(
        formatVersion: 1,
        appName: 'Field Notes',
        exportedAt: exportedAt,
        stats: const ExportStats(
          dayCount: 0,
          entryCount: 0,
          photoCount: 0,
          mediaBlobCount: 0,
        ),
      ),
      journalJson: '{}',
      mediaFiles: const <String, List<int>>{},
      toLocal: (ms) =>
          DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
              .subtract(const Duration(hours: 6)),
    );

    expect(bundle.suggestedFileName, 'field-notes-export-20260924-181810.zip');
  });
}
