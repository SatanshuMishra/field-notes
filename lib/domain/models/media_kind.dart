enum MediaKind {
  photo('photo'),
  audio('audio'),
  video('video');

  const MediaKind(this.id);

  final String id;

  static MediaKind? fromId(String? id) {
    if (id == null) {
      return null;
    }
    for (final kind in MediaKind.values) {
      if (kind.id == id) {
        return kind;
      }
    }
    return null;
  }
}
