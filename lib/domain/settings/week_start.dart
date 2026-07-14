enum WeekStart {
  sunday(0, 'Sunday'),
  monday(1, 'Monday');

  const WeekStart(this.value, this.label);

  final int value;
  final String label;

  static WeekStart? fromValue(int? value) {
    if (value == null) {
      return null;
    }
    for (final start in WeekStart.values) {
      if (start.value == value) {
        return start;
      }
    }
    return null;
  }
}
