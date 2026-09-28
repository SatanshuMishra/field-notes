enum OnboardingStatus {
  pending('pending'),
  done('done');

  const OnboardingStatus(this.id);

  final String id;

  static OnboardingStatus? fromId(String? id) {
    if (id == null) {
      return null;
    }
    for (final status in OnboardingStatus.values) {
      if (status.id == id) {
        return status;
      }
    }
    return null;
  }
}
