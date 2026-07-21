import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/show_day_detail.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_day_tile.dart';
import 'search_day_view.dart';
import 'search_field.dart';
import 'search_providers.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Day>> days = ref.watch(allDaysProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SearchField(),
          const SizedBox(height: 16),
          Expanded(
            child: days.when(
              data: (List<Day> list) => list.isEmpty
                  ? const _SearchEmptyJournal()
                  : const _SearchResultsList(),
              loading: () => const _SearchLoading(),
              error: (Object error, StackTrace stackTrace) =>
                  const _SearchError(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsList extends ConsumerWidget {
  const _SearchResultsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SearchDayView> results = ref.watch(searchResultsProvider);
    final String query = ref.watch(searchQueryProvider).trim();
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyStatePlaceholder(
            message:
                query.isEmpty ? 'No days yet.' : 'No days match "$query".',
            messageStyle: TypographyTokens.bodySerif,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final SearchDayView view = results[index];
        return SearchDayTile(
          view: view,
          onTap: () => showDayDetail(context, date: view.date),
        );
      },
    );
  }
}

class _SearchEmptyJournal extends StatelessWidget {
  const _SearchEmptyJournal();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePlaceholder(
          message: 'No days yet. Start journaling and your days appear here.',
          messageStyle: TypographyTokens.bodySerif,
        ),
      ),
    );
  }
}

class _SearchLoading extends StatelessWidget {
  const _SearchLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Loading your days…',
        style: TypographyTokens.captionSans,
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePlaceholder(
          message: 'Your days could not be loaded right now.',
          messageStyle: TypographyTokens.bodySerif,
        ),
      ),
    );
  }
}
