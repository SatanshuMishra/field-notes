import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WeekStart.fromValue(6) is Saturday labelled Saturday', () {
    final WeekStart? start = WeekStart.fromValue(6);

    expect(start, WeekStart.saturday);
    expect(start!.label, 'Saturday');
    expect(WeekStart.values, <WeekStart>[
      WeekStart.sunday,
      WeekStart.monday,
      WeekStart.saturday,
    ]);
  });

  test(
    'AppSettings defaults leave reflection questions off and onboarding unset',
    () {
      expect(AppSettings.defaults.reflectionPromptsEnabled, isFalse);
      expect(AppSettings.defaults.onboardingStatus, isNull);
      expect(AppSettings.defaults.weekStart, WeekStart.sunday);
    },
  );
}
