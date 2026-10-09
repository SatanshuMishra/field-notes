import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/features/data/export_delivery.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_file_picker/windows_file_picker.dart';

class _SaveRequest {
  const _SaveRequest({
    required this.bytes,
    required this.fileName,
    required this.dialogTitle,
    required this.initialDirectory,
    required this.windowsOptions,
  });

  final List<int> bytes;
  final String fileName;
  final String? dialogTitle;
  final String? initialDirectory;
  final WindowsOptions windowsOptions;
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
      initialDirectory: initialDirectory,
      windowsOptions: windowsOptions,
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

void _answerWindowHandle(Object? Function() reply) {
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(windowChannel, (MethodCall call) async {
    if (call.method != windowHandleMethod) {
      return null;
    }
    return reply();
  });
  addTearDown(() => messenger.setMockMethodCallHandler(windowChannel, null));
}

void _onPlatform(TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
}

Future<_SaveRequest> _exportOnce(_FakeFilePicker picker) async {
  await defaultExportDelivery().deliver(
    zipBytes: <int>[1, 2, 3],
    fileName: 'field-notes.zip',
  );
  final _SaveRequest? request = picker.received;
  expect(request, isNotNull);
  return request!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('defaultExportDelivery', () {
    test('the Windows save dialog belongs to the Field Notes window and lets '
        'Windows reopen the last folder', () async {
      _onPlatform(TargetPlatform.windows);
      final _FakeFilePicker picker = _installFakePicker(
        Uri.file('/tmp/field-notes.zip'),
      );
      _answerWindowHandle(() => 4242);

      final _SaveRequest request = await _exportOnce(picker);

      expect(request.initialDirectory, isNull);
      expect(
        request.windowsOptions,
        isA<FilePickerWindowsOptions>()
            .having(
              (FilePickerWindowsOptions o) => o.parentWindowHandle,
              'parentWindowHandle',
              4242,
            )
            .having(
              (FilePickerWindowsOptions o) => o.lockParentWindow,
              'lockParentWindow',
              isTrue,
            ),
      );
    });

    test('a Windows window that cannot name itself never lends the dialog to '
        'whichever window is in front', () async {
      _onPlatform(TargetPlatform.windows);
      final _FakeFilePicker picker = _installFakePicker(null);
      _answerWindowHandle(() => throw PlatformException(code: 'unavailable'));

      final _SaveRequest request = await _exportOnce(picker);

      expect(request.initialDirectory, isNull);
      expect(request.windowsOptions.lockParentWindow, isFalse);
    });

    test('the macOS save panel keeps its own folder and owner', () async {
      _onPlatform(TargetPlatform.macOS);
      final _FakeFilePicker picker = _installFakePicker(null);
      bool asked = false;
      _answerWindowHandle(() {
        asked = true;
        return 4242;
      });

      final _SaveRequest request = await _exportOnce(picker);

      expect(request.initialDirectory, isNull);
      expect(request.windowsOptions.lockParentWindow, isFalse);
      expect(request.windowsOptions, isNot(isA<FilePickerWindowsOptions>()));
      expect(asked, isFalse);
    });

    test('phones share the archive instead of saving it', () {
      _onPlatform(TargetPlatform.android);

      expect(defaultExportDelivery(), isA<ShareExportDelivery>());
    });
  });
}
