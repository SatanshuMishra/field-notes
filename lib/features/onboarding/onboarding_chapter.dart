enum OnboardingChapter {
  opening('Opening'),
  day('A day'),
  moment('A moment'),
  month('A month'),
  year('A year'),
  theme('Theme'),
  reminder('Reminder'),
  week('Week'),
  tour('The app');

  const OnboardingChapter(this.progressName);

  final String progressName;

  bool get isStory => index <= OnboardingChapter.year.index;
}
