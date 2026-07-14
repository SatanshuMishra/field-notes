import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/domain/settings/reminder_time.dart';
import 'package:field_notes/domain/settings/text_size.dart';
import 'package:field_notes/domain/settings/week_start.dart';

void main() {
  group('AppSettings.defaults', () {
    test('match the spec: reminder on at 20:30, sound on, text size medium, '
        'week starts Sunday', () {
      const defaults = AppSettings.defaults;
      expect(defaults.reminderEnabled, isTrue);
      expect(defaults.reminderTime, ReminderTime.defaultTime);
      expect(defaults.soundEnabled, isTrue);
      expect(defaults.textSize, TextSize.medium);
      expect(defaults.weekStart, WeekStart.sunday);
    });
  });

  group('AppSettings', () {
    test('copyWith replaces only the named field', () {
      final updated = AppSettings.defaults.copyWith(soundEnabled: false);
      expect(updated.soundEnabled, isFalse);
      expect(updated.reminderEnabled, AppSettings.defaults.reminderEnabled);
      expect(updated.reminderTime, AppSettings.defaults.reminderTime);
      expect(updated.textSize, AppSettings.defaults.textSize);
      expect(updated.weekStart, AppSettings.defaults.weekStart);
    });

    test('value equality', () {
      expect(AppSettings.defaults, AppSettings.defaults.copyWith());
      expect(
        AppSettings.defaults,
        isNot(AppSettings.defaults.copyWith(textSize: TextSize.large)),
      );
    });
  });
}
