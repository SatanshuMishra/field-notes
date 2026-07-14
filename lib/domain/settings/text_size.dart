enum TextSize {
  small(1),
  medium(2),
  large(3);

  const TextSize(this.value);

  final int value;

  static TextSize? fromValue(int? value) {
    if (value == null) {
      return null;
    }
    for (final size in TextSize.values) {
      if (size.value == value) {
        return size;
      }
    }
    return null;
  }
}
