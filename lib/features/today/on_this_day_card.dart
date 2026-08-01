import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_date.dart';
import 'today_memory.dart';
import 'today_providers.dart';

const String onThisDayTitle = 'on this day';
const String onThisDayEmptyMessage =
    'No memory from this day in past years yet.';
const String onThisDayErrorMessage = "Couldn't load your past-year memory.";

const double _titleGap = 9;
const double _bandHeight = 82;
const double _metaGap = 1;
const BorderRadius _cardRadius =
    BorderRadius.all(Radius.circular(Shapes.radiusPill));
const BorderRadius _bandRadius =
    BorderRadius.vertical(top: Radius.circular(Shapes.radiusPill));
const EdgeInsets _cardInsets =
    EdgeInsets.symmetric(vertical: 9, horizontal: 11);

String _bandCaption(int yearsAgo) => 'memory · ${yearsAgoLabel(yearsAgo)}';

String _metaLabel({required String date, required Mood? mood}) {
  return mood == null ? date : '$date · felt ${mood.label}';
}

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
        child: Padding(
          padding: _cardInsets,
          child: EmptyStatePlaceholder(message: emptyMessage),
        ),
      );
    }
    final DateTime? moment = parseDateKey(current.day.date);
    final String? previewText = preview;
    return _shell(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CrossHatchPlaceholder(
            height: _bandHeight,
            borderRadius: _bandRadius,
            child: Text(
              _bandCaption(current.yearsAgo),
              style: TypographyTokens.monoMicroSans,
            ),
          ),
          Padding(
            padding: _cardInsets,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (previewText != null && previewText.isNotEmpty) ...<Widget>[
                  Text(
                    previewText,
                    style: TypographyTokens.memoryTitleSerif,
                  ),
                  const SizedBox(height: _metaGap),
                ],
                Text(
                  _metaLabel(
                    date: moment == null
                        ? current.day.date
                        : shortDateLabel(moment),
                    mood: current.day.mood,
                  ),
                  style: TypographyTokens.caption9Sans,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _shell({required String title, required Widget child}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: TypographyTokens.sectionHeaderAccent),
        const SizedBox(height: _titleGap),
        StickerCard(
          surface: Palette.cardWarm,
          borderRadius: _cardRadius,
          shadow: Shadows.cardDefault,
          padding: EdgeInsets.zero,
          child: ClipRRect(borderRadius: _cardRadius, child: child),
        ),
      ],
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
        child: Padding(
          padding: _cardInsets,
          child: Text(
            onThisDayErrorMessage,
            style: TypographyTokens.captionSans.copyWith(color: Palette.danger),
          ),
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
