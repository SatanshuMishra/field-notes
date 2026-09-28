abstract interface class ExportService {
  Future<ExportBundle> buildBundle();
}

class ExportStats {
  const ExportStats({
    required this.dayCount,
    required this.entryCount,
    required this.photoCount,
    required this.mediaBlobCount,
  });

  final int dayCount;
  final int entryCount;
  final int photoCount;
  final int mediaBlobCount;

  Map<String, Object?> toJson() => {
        'days': dayCount,
        'entries': entryCount,
        'photos': photoCount,
        'mediaBlobs': mediaBlobCount,
      };
}

class ExportManifest {
  const ExportManifest({
    required this.formatVersion,
    required this.appName,
    required this.exportedAt,
    required this.stats,
  });

  final int formatVersion;
  final String appName;
  final int exportedAt;
  final ExportStats stats;

  Map<String, Object?> toJson() => {
        'formatVersion': formatVersion,
        'appName': appName,
        'exportedAt': exportedAt,
        'counts': stats.toJson(),
      };
}

DateTime _exportedAtToLocal(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

class ExportBundle {
  const ExportBundle({
    required this.manifest,
    required this.journalJson,
    required this.mediaFiles,
    this.skippedMediaIds = const <String>[],
    this.toLocal = _exportedAtToLocal,
  });

  static const String manifestFileName = 'manifest.json';
  static const String journalFileName = 'journal.json';

  final ExportManifest manifest;
  final String journalJson;
  final Map<String, List<int>> mediaFiles;
  final List<String> skippedMediaIds;
  final DateTime Function(int ms) toLocal;

  String get suggestedFileName {
    final at = toLocal(manifest.exportedAt);
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${at.year}${two(at.month)}${two(at.day)}'
        '-${two(at.hour)}${two(at.minute)}${two(at.second)}';
    return 'field-notes-export-$stamp.zip';
  }
}
