import 'dart:typed_data';

import 'package:field_notes/features/data/export_delivery.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

class _SaveRequest {
  const _SaveRequest({
    required this.bytes,
    required this.fileName,
    required this.dialogTitle,
  });

  final List<int> bytes;
  final String fileName;
  final String? dialogTitle;
}

class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker(this._saved);

  final Uri? _saved;
  _SaveRequest? received;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    received = _SaveRequest(
      bytes: List<int>.unmodifiable(bytes),
      fileName: fileName,
      dialogTitle: dialogTitle,
    );
    return _saved;
  }
}

_FakeFilePicker _installFakePicker(Uri? saved) {
  final FilePickerPlatform original = FilePickerPlatform.instance;
  final _FakeFilePicker fake = _FakeFilePicker(saved);
  FilePickerPlatform.instance = fake;
  addTearDown(() => FilePickerPlatform.instance = original);
  return fake;
}

void main() {
  group('SaveFileExportDelivery', () {
    test(
      'the save dialog receives the archive bytes and its location is reported',
      () async {
        final _FakeFilePicker picker = _installFakePicker(
          Uri.file('/tmp/field-notes.zip'),
        );

        final ExportOutcome outcome = await const SaveFileExportDelivery()
            .deliver(zipBytes: <int>[1, 2, 3], fileName: 'field-notes.zip');

        expect(
          outcome,
          isA<ExportDelivered>().having(
            (ExportDelivered d) => d.location,
            'location',
            '/tmp/field-notes.zip',
          ),
        );
        final _SaveRequest? request = picker.received;
        expect(request, isNotNull);
        expect(request!.bytes, <int>[1, 2, 3]);
        expect(request.fileName, 'field-notes.zip');
        expect(request.dialogTitle, 'Export Field Notes');
      },
    );

    test('a dismissed save dialog reports dismissed', () async {
      _installFakePicker(null);

      final ExportOutcome outcome = await const SaveFileExportDelivery()
          .deliver(zipBytes: <int>[1, 2, 3], fileName: 'field-notes.zip');

      expect(outcome, isA<ExportDismissed>());
    });
  });
}
