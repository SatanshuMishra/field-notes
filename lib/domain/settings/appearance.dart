enum Appearance {
  light('light'),
  dark('dark'),
  system('system');

  const Appearance(this.id);

  final String id;

  static Appearance? fromId(String? id) {
    if (id == null) {
      return null;
    }
    for (final appearance in Appearance.values) {
      if (appearance.id == id) {
        return appearance;
      }
    }
    return null;
  }
}
