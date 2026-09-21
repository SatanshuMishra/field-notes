import 'dart:async';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_providers.dart';

const String todayFeedEmptyHeadline = 'Nothing planted yet today';
const String todayFeedEmptyMessage =
    'Capture a moment — write it, speak it, or film it.';
const String todayFeedErrorMessage = "Couldn't load today's entries.";
const String todayMediaErrorMessage = "Couldn't load your media library.";

const double _feedCardHorizontalPadding = 30;
const double _feedCardGap = 12;

class _PendingMediaResolver implements MediaResolver {
  const _PendingMediaResolver();

  @override
  Future<ResolvedMedia> resolve(String? mediaId) =>
      Completer<ResolvedMedia>().future;
}

class TodayEntryFeed extends ConsumerWidget {
  const TodayEntryFeed({
    super.key,
    required this.date,
    this.emptyMessage = todayFeedEmptyMessage,
  });

  final String date;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Entry>> entriesAsync =
        ref.watch(entriesForDateProvider(date));
    if (entriesAsync.hasError) {
      return _adapter(_message(todayFeedErrorMessage));
    }
    if (!entriesAsync.hasValue) {
      return _adapter(const SizedBox.shrink());
    }
    final List<Entry> entries = entriesAsync.requireValue;
    if (entries.isEmpty) {
      return _adapter(
        EmptyStatePlaceholder(
          headline: todayFeedEmptyHeadline,
          message: emptyMessage,
          messageStyle: TypographyTokens.captionSans,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
          borderColor: Palette.ink40,
          borderRadius: Shapes.radiusLg,
        ),
      );
    }

    final AsyncValue<MediaResolver> resolverAsync =
        ref.watch(todayMediaResolverProvider);
    if (resolverAsync.hasError) {
      return _adapter(_message(todayMediaErrorMessage));
    }
    final MediaResolver resolver =
        resolverAsync.value ?? const _PendingMediaResolver();

    return SliverList.builder(
      itemCount: entries.length,
      findChildIndexCallback: (Key key) {
        final int index = entries.indexWhere(
          (Entry entry) => key == ValueKey<String>(entry.id),
        );
        return index < 0 ? null : index;
      },
      itemBuilder: (BuildContext context, int index) {
        final Entry entry = entries[index];
        return Padding(
          key: ValueKey<String>(entry.id),
          padding: EdgeInsets.only(top: index == 0 ? 0 : _feedCardGap),
          child: NoteColumn(
            horizontalInset: _feedCardHorizontalPadding,
            child: TodayEntryTile(
              entry: entry,
              date: date,
              resolver: resolver,
            ),
          ),
        );
      },
    );
  }

  static Widget _adapter(Widget child) => SliverToBoxAdapter(child: child);

  static Widget _message(String text) {
    return Text(
      text,
      style: TypographyTokens.captionSans.copyWith(color: Palette.danger),
    );
  }
}

class TodayEntryTile extends ConsumerWidget {
  const TodayEntryTile({
    super.key,
    required this.entry,
    required this.date,
    required this.resolver,
  });

  final Entry entry;
  final String date;
  final MediaResolver resolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<EntryPhoto> photos =
        ref.watch(photosForEntryProvider(entry.id)).value ??
            const <EntryPhoto>[];
    return EntryCard(
      entry: entry,
      resolver: resolver,
      photos: photos,
      audioPlayerFactory: ref.watch(todayAudioPlayerFactoryProvider),
      videoPlayerFactory: ref.watch(todayVideoPlayerFactoryProvider),
      videoSlots: ref.watch(videoSlotsProvider),
      preview: true,
      onTap: () => showDayDetail(context, date: date, focusEntryId: entry.id),
    );
  }
}
