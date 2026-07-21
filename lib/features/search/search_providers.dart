import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'search_day_view.dart';
import 'search_entries_provider.dart';
import 'search_filter.dart';

part 'search_providers.g.dart';

@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void update(String value) => state = value;
}

@riverpod
List<SearchDayView> searchDayViews(Ref ref) {
  final List<Day> days =
      ref.watch(allDaysProvider).value ?? const <Day>[];
  final List<Entry> entries =
      ref.watch(searchAllEntriesProvider).value ?? const <Entry>[];
  return buildSearchDayViews(days, entries);
}

@riverpod
List<SearchDayView> searchResults(Ref ref) {
  return filterSearchDays(
    ref.watch(searchDayViewsProvider),
    ref.watch(searchQueryProvider),
  );
}
