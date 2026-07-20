import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/day_detail/day_detail_heading.dart';

void main() {
  test('formats a valid date key as weekday, month day and year', () {
    expect(
      dayDetailHeadingFor('2026-07-19'),
      const DayDetailHeading(title: 'Sunday, July 19', subtitle: '2026'),
    );
    expect(
      dayDetailHeadingFor('2026-01-01'),
      const DayDetailHeading(title: 'Thursday, January 1', subtitle: '2026'),
    );
    expect(
      dayDetailHeadingFor('2026-12-25'),
      const DayDetailHeading(title: 'Friday, December 25', subtitle: '2026'),
    );
  });

  test('formats a leap day', () {
    expect(
      dayDetailHeadingFor('2024-02-29'),
      const DayDetailHeading(title: 'Thursday, February 29', subtitle: '2024'),
    );
  });

  test('falls back to the raw key when the date is malformed', () {
    expect(
      dayDetailHeadingFor('19-07-2026'),
      const DayDetailHeading(title: '19-07-2026', subtitle: ''),
    );
    expect(
      dayDetailHeadingFor(''),
      const DayDetailHeading(title: '', subtitle: ''),
    );
  });

  test('falls back to the raw key when the date does not exist', () {
    expect(
      dayDetailHeadingFor('2026-02-31'),
      const DayDetailHeading(title: '2026-02-31', subtitle: ''),
    );
    expect(
      dayDetailHeadingFor('2026-13-01'),
      const DayDetailHeading(title: '2026-13-01', subtitle: ''),
    );
  });
}
