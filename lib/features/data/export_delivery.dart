import 'dart:io';

import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:windows_file_picker/windows_file_picker.dart';

sealed class ExportOutcome {
  const ExportOutcome();
}

class ExportDelivered extends ExportOutcome {
  const ExportDelivered(this.location);

  final String location;
}

class ExportDismissed extends ExportOutcome {
  const ExportDismissed();
}

abstract interface class ExportDelivery {
  Future<ExportOutcome> deliver({
    required List<int> zipBytes,
    required String fileName,
  });
}

Future<WindowsOptions> _unownedDialog() async => const WindowsOptions();

Future<WindowsOptions> dialogOwnedByAppWindow() async {
  final int? owner = await windowHandle();
  return FilePickerWindowsOptions(
    lockParentWindow: owner != null,
    parentWindowHandle: owner,
  );
}

class SaveFileExportDelivery implements ExportDelivery {
  const SaveFileExportDelivery({this.windowsOptions = _unownedDialog});

  final Future<WindowsOptions> Function() windowsOptions;

  @override
  Future<ExportOutcome> deliver({
    required List<int> zipBytes,
    required String fileName,
  }) async {
    final Uri? saved = await FilePicker.saveFile(
      dialogTitle: 'Export Field Notes',
      fileName: fileName,
      bytes: Uint8List.fromList(zipBytes),
      windowsOptions: await windowsOptions(),
    );
    if (saved == null) {
      return const ExportDismissed();
    }
    return ExportDelivered(saved.toFilePath());
  }
}

class ShareExportDelivery implements ExportDelivery {
  const ShareExportDelivery();

  @override
  Future<ExportOutcome> deliver({
    required List<int> zipBytes,
    required String fileName,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(zipBytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip')],
        subject: 'Field Notes export',
      ),
    );
    if (result.status == ShareResultStatus.dismissed) {
      return const ExportDismissed();
    }
    return ExportDelivered(file.path);
  }
}

ExportDelivery defaultExportDelivery() => switch (defaultTargetPlatform) {
  TargetPlatform.android || TargetPlatform.iOS => const ShareExportDelivery(),
  TargetPlatform.windows => const SaveFileExportDelivery(
    windowsOptions: dialogOwnedByAppWindow,
  ),
  _ => const SaveFileExportDelivery(),
};
