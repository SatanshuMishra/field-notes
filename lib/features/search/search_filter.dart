import 'search_day_view.dart';

List<SearchDayView> filterSearchDays(
  List<SearchDayView> views,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return views;
  }
  return <SearchDayView>[
    for (final SearchDayView view in views)
      if (view.searchText.contains(needle)) view,
  ];
}
