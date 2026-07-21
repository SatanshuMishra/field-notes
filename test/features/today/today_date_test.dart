import 'package:field_notes/features/today/today_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('greetingFor', () {
    test('spans morning, afternoon and evening', () {
      expect(greetingFor(DateTime(2026, 7, 19, 0)), 'Good morning');
      expect(greetingFor(DateTime(2026, 7, 19, 11, 59)), 'Good morning');
      expect(greetingFor(DateTime(2026, 7, 19, 12)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 7, 19, 16, 59)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 7, 19, 17)), 'Good evening');
      expect(greetingFor(DateTime(2026, 7, 19, 23, 59)), 'Good evening');
    });
  });

  group('longDateLabel', () {
    test('renders weekday, month name, day and year', () {
      expect(longDateLabel(DateTime(2026, 7, 19)), 'Sunday, July 19, 2026');
      expect(longDateLabel(DateTime(2025, 1, 1)), 'Wednesday, January 1, 2025');
      expect(longDateLabel(DateTime(2024, 12, 31)), 'Tuesday, December 31, 2024');
    });
  });

  group('shortWeekdayLabel', () {
    test('abbreviates to three letters', () {
      expect(shortWeekdayLabel(DateTime(2026, 7, 19)), 'Sun');
      expect(shortWeekdayLabel(DateTime(2026, 7, 20)), 'Mon');
      expect(shortWeekdayLabel(DateTime(2026, 7, 25)), 'Sat');
    });
  });

  group('yearsAgoLabel', () {
    test('singularises one year', () {
      expect(yearsAgoLabel(1), '1 year ago');
      expect(yearsAgoLabel(2), '2 years ago');
    });
  });

  group('parseDateKey', () {
    test('round-trips valid keys and rejects malformed ones', () {
      expect(parseDateKey('2026-07-19'), DateTime(2026, 7, 19));
      expect(parseDateKey('2026-7-19'), isNull);
      expect(parseDateKey('2026-13-01'), isNull);
      expect(parseDateKey('2026-02-30'), isNull);
      expect(parseDateKey(''), isNull);
    });
  });
}
