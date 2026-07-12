class EntryPhoto {
  const EntryPhoto({
    required this.id,
    required this.entryId,
    required this.mediaId,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String entryId;
  final String mediaId;
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EntryPhoto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          entryId == other.entryId &&
          mediaId == other.mediaId &&
          sortOrder == other.sortOrder &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode => Object.hash(
        id,
        entryId,
        mediaId,
        sortOrder,
        createdAt,
        updatedAt,
        deletedAt,
      );

  @override
  String toString() =>
      'EntryPhoto(id: $id, entryId: $entryId, mediaId: $mediaId, '
      'sortOrder: $sortOrder, createdAt: $createdAt, '
      'updatedAt: $updatedAt, deletedAt: $deletedAt)';
}
