import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/domain/settings/week_start.dart';

void main() {
  group('WeekStart', () {
    test('sunday=0 and monday=1 match the settings field option values', () {
      expect(WeekStart.sunday.value, 0);
      expect(WeekStart.monday.value, 1);
    });

    test('labels are human-readable', () {
      expect(WeekStart.sunday.label, 'Sunday');
      expect(WeekStart.monday.label, 'Monday');
    });

    test('fromValue resolves known values and rejects the rest', () {
      expect(WeekStart.fromValue(0), WeekStart.sunday);
      expect(WeekStart.fromValue(1), WeekStart.monday);
      expect(WeekStart.fromValue(2), isNull);
      expect(WeekStart.fromValue(null), isNull);
    });
  });
}
