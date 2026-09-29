import 'package:field_notes/domain/settings/settings.dart';

const Set<String> _sundayRegions = <String>{
  'US',
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
};

const Set<String> _saturdayRegions = <String>{
  'AE',
  'EG',
  'SA',
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
};

WeekStart suggestWeekStart(String? countryCode) {
  final String region = (countryCode ?? '').toUpperCase();
  if (_sundayRegions.contains(region)) {
    return WeekStart.sunday;
  }
  if (_saturdayRegions.contains(region)) {
    return WeekStart.saturday;
  }
  return WeekStart.monday;
}
