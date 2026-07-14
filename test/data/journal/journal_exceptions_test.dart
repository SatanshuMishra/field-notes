import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/journal/journal_exceptions.dart';

void main() {
  test('DuplicateDayException exposes the conflicting date in data and message',
      () {
    const exception = DuplicateDayException('2026-07-12');

    expect(exception.date, '2026-07-12');
    expect(exception.toString(), contains('2026-07-12'));
  });

  test('MalformedRowException carries its diagnostic message', () {
    const exception = MalformedRowException('unknown entry type "hologram"');

    expect(exception.message, 'unknown entry type "hologram"');
    expect(exception.toString(), contains('unknown entry type "hologram"'));
  });
}
