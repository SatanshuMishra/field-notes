import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/show_day_detail.dart';
import 'package:field_notes/features/entry_cards/media/hatched_media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
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
const String onThisDayPhotoUnavailableLabel = 'Photo unavailable';

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
    this.photo,
    this.resolver,
    this.onOpen,
    this.title = onThisDayTitle,
    this.emptyMessage = onThisDayEmptyMessage,
  });

  final OnThisDayMemory? memory;
  final String? preview;
  final String? photo;
  final MediaResolver? resolver;
  final VoidCallback? onOpen;
  final String title;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final OnThisDayMemory? current = memory;
    if (current == null) {
      return _shell(
        context,
        title: title,
        child: Padding(
          padding: _cardInsets,
          child: EmptyStatePlaceholder(message: emptyMessage),
        ),
      );
    }
    final DateTime? moment = parseDateKey(current.day.date);
    final String? previewText = preview;
    final FieldNotesTextStyles textStyles = context.textStyles;
    final String caption = _bandCaption(current.yearsAgo);
    final String meta = _metaLabel(
      date: moment == null ? current.day.date : shortDateLabel(moment),
      mood: current.day.mood,
    );
    return _shell(
      context,
      title: title,
      onOpen: onOpen,
      label: <String>[
        if (previewText != null && previewText.isNotEmpty) previewText,
        meta,
        caption,
      ].join(', '),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _band(Text(caption, style: textStyles.monoMicroSans)),
          Padding(
            padding: _cardInsets,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (previewText != null && previewText.isNotEmpty) ...<Widget>[
                  Text(previewText, style: textStyles.memoryTitleSerif),
                  const SizedBox(height: _metaGap),
                ],
                Text(meta, style: textStyles.caption9Sans),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _band(Widget caption) {
    final String? reference = photo;
    final MediaResolver? source = resolver;
    if (reference == null || source == null) {
      return CrossHatchPlaceholder(
        height: _bandHeight,
        borderRadius: _bandRadius,
        child: caption,
      );
    }
    return HatchedMediaImage(
      resolver: source,
      mediaId: reference,
      width: null,
      height: _bandHeight,
      borderRadius: _bandRadius,
      variant: CrossHatchVariant.photo,
      errorLabel: onThisDayPhotoUnavailableLabel,
      hatchChild: caption,
    );
  }

  static Widget _shell(
    BuildContext context, {
    required String title,
    required Widget child,
    VoidCallback? onOpen,
    String? label,
  }) {
    final Widget card = StickerCard(
      surface: context.colors.cardWarm,
      borderRadius: _cardRadius,
      shadow: context.shadows.cardDefault,
      padding: EdgeInsets.zero,
      child: ClipRRect(borderRadius: _cardRadius, child: child),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: context.textStyles.sectionHeaderAccent),
        const SizedBox(height: _titleGap),
        if (onOpen == null)
          card
        else
          Semantics(
            button: true,
            label: label,
            onTap: onOpen,
            child: FocusRing(
              onPressed: onOpen,
              borderRadius: _cardRadius,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: onOpen,
                  child: ExcludeSemantics(child: card),
                ),
              ),
            ),
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
        context,
        title: onThisDayTitle,
        child: Padding(
          padding: _cardInsets,
          child: Text(
            onThisDayErrorMessage,
            style: context.textStyles.captionSans.copyWith(
              color: context.colors.dangerInk,
            ),
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
    return OnThisDayCard(
      memory: memory,
      preview: firstTextPreview(entries),
      photo: firstPhotoReference(entries),
      resolver: ref.watch(todayMediaResolverProvider).value,
      onOpen: () => showDayDetail(context, date: memory.day.date),
    );
  }
}
