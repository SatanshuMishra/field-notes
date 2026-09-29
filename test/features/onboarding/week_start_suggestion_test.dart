import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/onboarding/setup/week_start_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('US suggests Sunday, SA suggests Saturday, DE and no country suggest '
      'Monday', () {
    expect(suggestWeekStart('US'), WeekStart.sunday);
    expect(suggestWeekStart('SA'), WeekStart.saturday);
    expect(suggestWeekStart('DE'), WeekStart.monday);
    expect(suggestWeekStart(null), WeekStart.monday);

    for (final String region in <String>[
      'CA',
      'JP',
      'BR',
      'MX',
      'IL',
      'PH',
      'KR',
      'TW',
      'IN',
      'ZA',
    ]) {
      expect(suggestWeekStart(region), WeekStart.sunday, reason: region);
    }
    for (final String region in <String>[
      'AE',
      'EG',
      'IR',
      'AF',
      'DZ',
      'BH',
      'IQ',
      'JO',
      'KW',
      'LY',
      'OM',
      'QA',
      'SD',
      'SY',
    ]) {
      expect(suggestWeekStart(region), WeekStart.saturday, reason: region);
    }
    expect(suggestWeekStart('us'), WeekStart.sunday);
    expect(suggestWeekStart(''), WeekStart.monday);
    expect(suggestWeekStart('GB'), WeekStart.monday);
  });
}
