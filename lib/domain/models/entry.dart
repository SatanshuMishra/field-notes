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
          deletedAt == other.deletedAt;

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
      );

  @override
  String toString() =>
      'Entry(id: $id, dayId: $dayId, type: $type, '
      'textContent: $textContent, mediaId: $mediaId, '
      'thumbnailMediaId: $thumbnailMediaId, durationMs: $durationMs, '
      'createdAt: $createdAt, updatedAt: $updatedAt, deletedAt: $deletedAt)';
}
