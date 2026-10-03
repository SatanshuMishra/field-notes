import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/show_day_detail.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_day_tile.dart';
import 'search_day_view.dart';
import 'search_field.dart';
import 'search_providers.dart';

const String searchPhoneEyebrow = 'search';

const String searchPhoneTitle = 'Find a day';

const double _phonePagePadding = 14;
const double _phoneHeaderGap = 6;
const double _phoneRingRoom = 6;
const double _phoneFieldGap = 10;
const double _phoneItemGap = 10;
const double _phoneEyebrowSize = 15;
const double _phoneTitleSize = 26;
const double _phoneTitleHeight = 1.05;
const double _phoneMessageHeight = 1.5;
const double _phoneMessageBorderAlpha = 0.4;

const EdgeInsets _phoneTitlePadding = EdgeInsets.fromLTRB(2, 0, 2, 2);

const EdgeInsets _phoneMessagePadding = EdgeInsets.symmetric(
  horizontal: 28,
  vertical: 26,
);

const String _emptyJournalMessage =
    'No days yet. Start journaling and your days appear here.';

const String _errorMessage = 'Your days could not be loaded right now.';

const String _loadingMessage = 'Loading your days…';

String _noResultsMessage(String query) =>
    query.isEmpty ? 'No days yet.' : 'No days match "$query".';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Day>> days = ref.watch(allDaysProvider);
    if (resolveShellLayout(Theme.of(context).platform) ==
        ShellLayout.bottomBar) {
      return _PhoneSearch(days: days);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: SearchField(),
          ),
          const SizedBox(height: 10),
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

class _PhoneSearch extends StatelessWidget {
  const _PhoneSearch({required this.days});

  final AsyncValue<List<Day>> days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + _phonePagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: days.when(
              data: (List<Day> list) => list.isEmpty
                  ? const _PhoneScroll(
                      floor: _PhoneMessage(message: _emptyJournalMessage),
                    )
                  : const _PhoneResults(),
              loading: () => const _PhoneScroll(floor: _PhoneLoading()),
              error: (Object error, StackTrace stackTrace) =>
                  const _PhoneScroll(
                    floor: _PhoneMessage(message: _errorMessage),
                  ),
            ),
          ),
          const SizedBox(height: _phoneFieldGap),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: _phonePagePadding),
            child: SearchField(variant: SearchFieldVariant.phone),
          ),
        ],
      ),
    );
  }
}

class _PhoneResults extends ConsumerWidget {
  const _PhoneResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SearchDayView> results = ref.watch(searchResultsProvider);
    if (results.isEmpty) {
      final String query = ref.watch(searchQueryProvider).trim();
      return _PhoneScroll(
        floor: _PhoneMessage(message: _noResultsMessage(query)),
      );
    }
    return _PhoneScroll.sliver(
      floor: SliverList.separated(
        itemCount: results.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: _phoneItemGap),
        itemBuilder: (BuildContext context, int index) {
          final SearchDayView view = results[index];
          return SearchDayTile(
            view: view,
            onTap: () => showDayDetail(
              context,
              date: view.date,
              focusEntryId: view.matchedEntryId,
            ),
          );
        },
      ),
    );
  }
}

class _PhoneScroll extends StatelessWidget {
  const _PhoneScroll({required this.floor}) : boxed = true;

  const _PhoneScroll.sliver({required this.floor}) : boxed = false;

  final Widget floor;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            _phonePagePadding,
            MediaQuery.paddingOf(context).top + _phoneHeaderGap,
            _phonePagePadding,
            _phoneItemGap,
          ),
          sliver: const SliverToBoxAdapter(child: _PhoneTitle()),
        ),
        _SliverFloor(
          sliver: SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              _phonePagePadding,
              0,
              _phonePagePadding,
              _phoneRingRoom,
            ),
            sliver: boxed ? SliverToBoxAdapter(child: floor) : floor,
          ),
        ),
      ],
    );
  }
}

class _SliverFloor extends SingleChildRenderObjectWidget {
  const _SliverFloor({required Widget sliver}) : super(child: sliver);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSliverFloor();
}

class _RenderSliverFloor extends RenderSliverEdgeInsetsPadding {
  EdgeInsets _lift = EdgeInsets.zero;

  @override
  EdgeInsets get resolvedPadding => _lift;

  @override
  void performLayout() {
    _lift = EdgeInsets.zero;
    super.performLayout();
    final SliverGeometry measured = geometry!;
    if (measured.scrollOffsetCorrection != null) {
      return;
    }
    final double room =
        constraints.viewportMainAxisExtent -
        constraints.precedingScrollExtent -
        measured.scrollExtent;
    if (room <= 0) {
      return;
    }
    _lift = EdgeInsets.only(top: room);
    super.performLayout();
  }
}

class _PhoneLoading extends StatelessWidget {
  const _PhoneLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(_loadingMessage, style: context.textStyles.captionSans),
    );
  }
}

class _PhoneTitle extends StatelessWidget {
  const _PhoneTitle();

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Padding(
      padding: _phoneTitlePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            searchPhoneEyebrow,
            style: textStyles.pageEyebrowAccent.copyWith(
              fontSize: _phoneEyebrowSize,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              searchPhoneTitle,
              style: textStyles.displaySerif.copyWith(
                fontSize: _phoneTitleSize,
                height: _phoneTitleHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneMessage extends StatelessWidget {
  const _PhoneMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return EmptyStatePlaceholder(
      message: message,
      padding: _phoneMessagePadding,
      borderColor: colors.ink.withValues(alpha: _phoneMessageBorderAlpha),
      borderRadius: Shapes.radiusLg,
      messageStyle: context.textStyles.bodySans.copyWith(
        height: _phoneMessageHeight,
        color: colors.mutedDeep,
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
            message: _noResultsMessage(query),
            messageStyle: context.textStyles.bodySerif,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(6),
      itemCount: results.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final SearchDayView view = results[index];
        return SearchDayTile(
          view: view,
          onTap: () => showDayDetail(
            context,
            date: view.date,
            focusEntryId: view.matchedEntryId,
          ),
        );
      },
    );
  }
}

class _SearchEmptyJournal extends StatelessWidget {
  const _SearchEmptyJournal();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyStatePlaceholder(
          message: _emptyJournalMessage,
          messageStyle: context.textStyles.bodySerif,
        ),
      ),
    );
  }
}

class _SearchLoading extends StatelessWidget {
  const _SearchLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(_loadingMessage, style: context.textStyles.captionSans),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyStatePlaceholder(
          message: _errorMessage,
          messageStyle: context.textStyles.bodySerif,
        ),
      ),
    );
  }
}
