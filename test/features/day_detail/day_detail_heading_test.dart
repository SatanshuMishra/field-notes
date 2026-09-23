import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/day_detail/day_detail_heading.dart';

final DateTime _today = DateTime(2026, 7, 23, 9);

void main() {
  test('formats a valid date key as weekday, month and day', () {
    expect(
      dayDetailHeadingFor('2026-07-19', today: _today),
      const DayDetailHeading(title: 'Sunday, July 19'),
    );
    expect(
      dayDetailHeadingFor('2026-01-01', today: _today),
      const DayDetailHeading(title: 'Thursday, January 1'),
    );
    expect(
      dayDetailHeadingFor('2026-12-25', today: _today),
      const DayDetailHeading(title: 'Friday, December 25'),
    );
  });

  test('appends the year to a day outside the current year', () {
    expect(
      dayDetailHeadingFor('2025-07-02', today: _today),
      const DayDetailHeading(title: 'Wednesday, July 2, 2025'),
    );
  });

  test('formats a leap day', () {
    expect(
      dayDetailHeadingFor('2024-02-29', today: _today),
      const DayDetailHeading(title: 'Thursday, February 29, 2024'),
    );
  });

  test('falls back to the raw key when the date is malformed', () {
    expect(
      dayDetailHeadingFor('19-07-2026', today: _today),
      const DayDetailHeading(title: '19-07-2026'),
    );
    expect(
      dayDetailHeadingFor('', today: _today),
      const DayDetailHeading(title: ''),
    );
  });

  test('falls back to the raw key when the date does not exist', () {
    expect(
      dayDetailHeadingFor('2026-02-31', today: _today),
      const DayDetailHeading(title: '2026-02-31'),
    );
    expect(
      dayDetailHeadingFor('2026-13-01', today: _today),
      const DayDetailHeading(title: '2026-13-01'),
    );
  });

  test('the kicker names today apart from any other day', () {
    expect(
      dayDetailKickerFor('2026-07-23', today: _today),
      'today · in your garden',
    );
    expect(
      dayDetailKickerFor('2026-07-19', today: _today),
      'a day in the garden',
    );
  });
}
