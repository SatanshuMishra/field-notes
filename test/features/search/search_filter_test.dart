import 'package:field_notes/features/search/search_day_view.dart';
import 'package:field_notes/features/search/search_filter.dart';
import 'package:flutter_test/flutter_test.dart';

SearchDayView _view(String date, String searchText) {
  return SearchDayView(
    date: date,
    mood: null,
    entryCount: 1,
    preview: searchText,
    searchText: searchText.toLowerCase(),
  );
}

void main() {
  final List<SearchDayView> views = <SearchDayView>[
    _view('2026-07-15', 'rainy morning walk'),
    _view('2026-07-14', 'sunny picnic in the park'),
    _view('2026-07-13', 'happy birthday'),
  ];

  group('filterSearchDays', () {
    test('empty query returns every view unchanged', () {
      expect(filterSearchDays(views, ''), views);
    });

    test('whitespace-only query returns every view', () {
      expect(filterSearchDays(views, '   ').length, 3);
    });

    test('matches a case-insensitive substring of searchText', () {
      final List<SearchDayView> result = filterSearchDays(views, 'PARK');
      expect(result.map((SearchDayView v) => v.date).toList(),
          <String>['2026-07-14']);
    });

    test('trims the query before matching', () {
      final List<SearchDayView> result = filterSearchDays(views, '  rainy  ');
      expect(result.single.date, '2026-07-15');
    });

    test('non-matching query yields an empty list', () {
      expect(filterSearchDays(views, 'zzz'), isEmpty);
    });

    test('does not mutate the input list', () {
      filterSearchDays(views, 'rainy');
      expect(views.length, 3);
    });
  });
}
