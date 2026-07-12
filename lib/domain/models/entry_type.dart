enum EntryType {
  text('text'),
  voice('voice'),
  video('video');

  const EntryType(this.id);

  final String id;

  static EntryType? fromId(String? id) {
    if (id == null) {
      return null;
    }
    for (final type in EntryType.values) {
      if (type.id == id) {
        return type;
      }
    }
    return null;
  }
}
