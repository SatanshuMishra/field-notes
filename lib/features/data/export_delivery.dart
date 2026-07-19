import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

class SaveFileExportDelivery implements ExportDelivery {
  const SaveFileExportDelivery();

  @override
  Future<ExportOutcome> deliver({
    required List<int> zipBytes,
    required String fileName,
  }) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export Field Notes',
      fileName: fileName,
    );
    if (path == null) {
      return const ExportDismissed();
    }
    await File(path).writeAsBytes(Uint8List.fromList(zipBytes), flush: true);
    return ExportDelivered(path);
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

ExportDelivery defaultExportDelivery() {
  if (Platform.isAndroid || Platform.isIOS) {
    return const ShareExportDelivery();
  }
  return const SaveFileExportDelivery();
}
