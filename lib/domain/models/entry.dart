import 'entry_type.dart';

class Entry {
  const Entry({
    required this.id,
    required this.dayId,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.textContent,
    this.mediaId,
    this.thumbnailMediaId,
    this.durationMs,
    this.deletedAt,
    this.conflictSourceDevice,
    this.peaks,
  });

  final String id;
  final String dayId;
  final EntryType type;
  final String? textContent;
  final String? mediaId;
  final String? thumbnailMediaId;
  final int? durationMs;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String? conflictSourceDevice;
  final List<double>? peaks;

  bool get isDeleted => deletedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          dayId == other.dayId &&
          type == other.type &&
          textContent == other.textContent &&
          mediaId == other.mediaId &&
          thumbnailMediaId == other.thumbnailMediaId &&
          durationMs == other.durationMs &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt &&
          conflictSourceDevice == other.conflictSourceDevice &&
          _samePeaks(peaks, other.peaks);

  @override
  int get hashCode => Object.hash(
    id,
    dayId,
    type,
    textContent,
    mediaId,
    thumbnailMediaId,
    durationMs,
    createdAt,
    updatedAt,
    deletedAt,
    conflictSourceDevice,
    peaks == null ? null : Object.hashAll(peaks!),
  );

  @override
  String toString() =>
      'Entry(id: $id, dayId: $dayId, type: $type, '
      'textContent: $textContent, mediaId: $mediaId, '
      'thumbnailMediaId: $thumbnailMediaId, durationMs: $durationMs, '
      'createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt, '
      'conflictSourceDevice: $conflictSourceDevice, '
      'peaks: ${peaks == null ? null : '${peaks!.length} values'})';
}

bool _samePeaks(List<double>? a, List<double>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null || a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
