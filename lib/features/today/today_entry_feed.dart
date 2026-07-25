import 'dart:async';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_providers.dart';

const String todayFeedEmptyMessage = 'Nothing captured yet today.';
const String todayFeedErrorMessage = "Couldn't load today's entries.";
const String todayMediaErrorMessage = "Couldn't load your media library.";

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
      return _message(todayFeedErrorMessage);
    }
    if (!entriesAsync.hasValue) {
      return const SizedBox.shrink();
    }
    final List<Entry> entries = entriesAsync.requireValue;
    if (entries.isEmpty) {
      return EmptyStatePlaceholder(message: emptyMessage);
    }

    final AsyncValue<MediaResolver> resolverAsync =
        ref.watch(todayMediaResolverProvider);
    if (resolverAsync.hasError) {
      return _message(todayMediaErrorMessage);
    }
    final MediaResolver resolver =
        resolverAsync.value ?? const _PendingMediaResolver();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < entries.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 12),
          FadeIn(
            child: TodayEntryTile(
              key: ValueKey<String>(entries[index].id),
              entry: entries[index],
              resolver: resolver,
            ),
          ),
        ],
      ],
    );
  }

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
    required this.resolver,
  });

  final Entry entry;
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
    );
  }
}
