import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_date.dart';
import 'today_memory.dart';
import 'today_providers.dart';

const String onThisDayTitle = 'On this day';
const String onThisDayEmptyMessage =
    'No memory from this day in past years yet.';
const String onThisDayErrorMessage = "Couldn't load your past-year memory.";

class OnThisDayCard extends StatelessWidget {
  const OnThisDayCard({
    super.key,
    required this.memory,
    this.preview,
    this.title = onThisDayTitle,
    this.emptyMessage = onThisDayEmptyMessage,
  });

  final OnThisDayMemory? memory;
  final String? preview;
  final String title;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final OnThisDayMemory? current = memory;
    if (current == null) {
      return _shell(
        title: title,
        child: EmptyStatePlaceholder(message: emptyMessage),
      );
    }
    final Mood? mood = current.day.mood;
    final DateTime? moment = parseDateKey(current.day.date);
    final String? previewText = preview;
    return _shell(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (mood != null) ...<Widget>[
                FlowerBloom.forMood(mood, size: 34),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      yearsAgoLabel(current.yearsAgo),
                      style: TypographyTokens.labelSans,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      moment == null
                          ? current.day.date
                          : longDateLabel(moment),
                      style: TypographyTokens.captionSans,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (previewText != null && previewText.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              previewText,
              style: TypographyTokens.bodySerifItalic,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _shell({required String title, required Widget child}) {
    return StickerCard(
      surface: Palette.cardLight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: TypographyTokens.eyebrowAccent),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class OnThisDayRailCard extends ConsumerWidget {
  const OnThisDayRailCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OnThisDayMemory?> memoryAsync =
        ref.watch(onThisDayMemoryProvider);
    if (memoryAsync.hasError) {
      return OnThisDayCard._shell(
        title: onThisDayTitle,
        child: Text(
          onThisDayErrorMessage,
          style: TypographyTokens.captionSans.copyWith(color: Palette.danger),
        ),
      );
    }
    if (!memoryAsync.hasValue) {
      return const SizedBox.shrink();
    }
    final OnThisDayMemory? memory = memoryAsync.requireValue;
    if (memory == null) {
      return const OnThisDayCard(memory: null);
    }
    final List<Entry> entries =
        ref.watch(entriesForDayProvider(memory.day.id)).value ??
            const <Entry>[];
    return OnThisDayCard(memory: memory, preview: firstTextPreview(entries));
  }
}
