import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/widgets.dart';
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
const double _desktopInset = 6;
const double _desktopHeaderGap = 16;

const EdgeInsets _phoneTitlePadding = EdgeInsets.fromLTRB(2, 0, 2, 2);

const String _noDaysTitle = 'No days yet.';

const String _noDaysMessage = 'Start journaling and your days appear here.';

const String _noMatchMessage = 'Try a different word.';

const String _loadFailedTitle = 'Your days could not be loaded right now.';

const String _loadFailedMessage = 'Your logs are safe. Try again in a moment.';

const String _loadingMessage = 'Loading your days…';

const PageHeader _searchHeader = PageHeader(
  eyebrow: searchPhoneEyebrow,
  title: searchPhoneTitle,
);

StateBlock _emptyBlock(String query) => query.isEmpty
    ? const StateBlock.empty(title: _noDaysTitle, message: _noDaysMessage)
    : StateBlock.empty(
        title: 'No days match "$query".',
        message: _noMatchMessage,
      );

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
            padding: EdgeInsets.symmetric(horizontal: _desktopInset),
            child: _searchHeader,
          ),
          const SizedBox(height: _desktopHeaderGap),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: _desktopInset),
            child: SearchField(),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _DaysBody(
              days: days,
              results: const _SearchResultsList(),
              frame: (Widget block) => _DesktopStateFrame(block: block),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysBody extends StatelessWidget {
  const _DaysBody({
    required this.days,
    required this.results,
    required this.frame,
  });

  final AsyncValue<List<Day>> days;
  final Widget results;
  final Widget Function(Widget block) frame;

  @override
  Widget build(BuildContext context) {
    return days.when(
      data: (List<Day> list) => list.isEmpty ? frame(_emptyBlock('')) : results,
      loading: () => frame(const StateBlock.loading(message: _loadingMessage)),
      error: (Object error, StackTrace stackTrace) =>
          frame(const _DaysLoadFailed()),
    );
  }
}

class _DaysLoadFailed extends ConsumerWidget {
  const _DaysLoadFailed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StateBlock.error(
      title: _loadFailedTitle,
      message: _loadFailedMessage,
      onRetry: () => ref.invalidate(allDaysProvider),
    );
  }
}

class _DesktopStateFrame extends StatelessWidget {
  const _DesktopStateFrame({required this.block});

  final Widget block;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(_desktopInset),
      child: block,
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
            child: _DaysBody(
              days: days,
              results: const _PhoneResults(),
              frame: (Widget block) => _PhoneScroll(floor: block),
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
      return _PhoneScroll(floor: _emptyBlock(query));
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
          sliver: const SliverToBoxAdapter(
            child: Padding(padding: _phoneTitlePadding, child: _searchHeader),
          ),
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

class _SearchResultsList extends ConsumerWidget {
  const _SearchResultsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SearchDayView> results = ref.watch(searchResultsProvider);
    final String query = ref.watch(searchQueryProvider).trim();
    if (results.isEmpty) {
      return _DesktopStateFrame(block: _emptyBlock(query));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(_desktopInset),
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
