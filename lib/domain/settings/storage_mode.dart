enum StorageMode {
  onDevice('on_device');

  const StorageMode(this.id);

  final String id;

  static StorageMode? fromId(String? id) {
    if (id == null) {
      return null;
    }
    for (final mode in StorageMode.values) {
      if (mode.id == id) {
        return mode;
      }
    }
    return null;
  }
}
