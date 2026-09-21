import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/mood/mood.dart';
import 'package:field_notes/state/state.dart';

import 'day_detail_edit_note.dart';
import 'day_detail_entries_bar.dart';
import 'day_detail_entry_tile.dart';
import 'day_detail_header.dart';
import 'day_detail_providers.dart';

const String dayDetailMoodPrompt = 'How was this day?';
const String dayDetailEmptyMessage = 'No entries for this day yet.';
const String dayDetailEntriesErrorMessage = "Couldn't load this day's entries.";
const String dayDetailMediaErrorMessage = "Couldn't load your media library.";
const String dayDetailDeleteErrorMessage =
    "Couldn't delete that entry. Please try again.";

const double dayDetailPanelMaxWidth = 640;
const double dayDetailPanelVerticalMargin = 24;

const int _focusScanFrames = 32;
const double _focusAlignment = 0.1;

class DayDetailPanel extends ConsumerStatefulWidget {
  const DayDetailPanel({
    super.key,
    required this.date,
    this.focusEntryId,
    this.maxWidth = dayDetailPanelMaxWidth,
  });

  final String date;
  final String? focusEntryId;
  final double maxWidth;

  @override
  ConsumerState<DayDetailPanel> createState() => _DayDetailPanelState();
}

class _DayDetailPanelState extends ConsumerState<DayDetailPanel> {
  final ScrollController _entryScroll = ScrollController();
  final GlobalKey _focusedTile = GlobalKey();

  String? _deleteError;

  @override
  void initState() {
    super.initState();
    if (widget.focusEntryId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (Duration _) => _revealFocusedEntry(),
      );
    }
  }

  @override
  void dispose() {
    _entryScroll.dispose();
    super.dispose();
  }

  Future<void> _revealFocusedEntry() async {
    for (int frame = 0; frame < _focusScanFrames; frame++) {
      if (!mounted) {
        return;
      }
      final BuildContext? target = _focusedTile.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(target, alignment: _focusAlignment);
        return;
      }
      if (_entryScroll.hasClients) {
        final ScrollPosition position = _entryScroll.position;
        final double next = math.min(
          position.pixels + position.viewportDimension,
          position.maxScrollExtent,
        );
        if (next <= position.pixels) {
          return;
        }
        _entryScroll.jumpTo(next);
      }
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Future<void> _addNote() async {
    await showTextComposer(context, widget.date);
  }

  Future<void> _edit(Entry entry) async {
    await showEditNote(context, entry: entry, date: widget.date);
  }

  Future<void> _delete(Entry entry) async {
    try {
      await ref.read(journalRepositoryProvider).softDeleteEntry(entry.id);
      if (!mounted) {
        return;
      }
      setState(() => _deleteError = null);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _deleteError = dayDetailDeleteErrorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Entry>> entriesAsync =
        ref.watch(entriesForDateProvider(widget.date));
    final List<Entry> entries = entriesAsync.value ?? const <Entry>[];
    final AsyncValue<MediaResolver> resolverAsync =
        ref.watch(dayDetailMediaResolverProvider);
    final String? deleteError = _deleteError;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: dayDetailPanelVerticalMargin,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: StickerCard(
            surface: Palette.cardBright,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DayDetailHeader(
                  date: widget.date,
                  onClose: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
                MoodBannerForDate(
                  date: widget.date,
                  promptText: dayDetailMoodPrompt,
                ),
                const SizedBox(height: 16),
                DayDetailEntriesBar(
                  entryCount: entriesAsync.hasValue ? entries.length : null,
                  onAddNote: _addNote,
                ),
                if (entriesAsync.hasError) ...<Widget>[
                  const SizedBox(height: 8),
                  const _DayDetailMessage(text: dayDetailEntriesErrorMessage),
                ],
                if (deleteError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  _DayDetailMessage(text: deleteError),
                ],
                const SizedBox(height: 16),
                Flexible(
                  child: _content(entriesAsync, entries, resolverAsync),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    AsyncValue<List<Entry>> entriesAsync,
    List<Entry> entries,
    AsyncValue<MediaResolver> resolverAsync,
  ) {
    if (!entriesAsync.hasValue) {
      return const SizedBox.shrink();
    }
    if (entries.isEmpty) {
      return const EmptyStatePlaceholder(message: dayDetailEmptyMessage);
    }
    if (resolverAsync.hasError) {
      return const _DayDetailMessage(text: dayDetailMediaErrorMessage);
    }
    if (!resolverAsync.hasValue) {
      return const SizedBox.shrink();
    }
    final MediaResolver resolver = resolverAsync.requireValue;
    return ListView.separated(
      controller: _entryScroll,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      findItemIndexCallback: (Key key) {
        final int index = entries.indexWhere(
          (Entry entry) => key == ValueKey<String>(entry.id),
        );
        return index < 0 ? null : index;
      },
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final Entry entry = entries[index];
        return KeyedSubtree(
          key: ValueKey<String>(entry.id),
          child: DayDetailEntryTile(
            key: entry.id == widget.focusEntryId ? _focusedTile : null,
            entry: entry,
            resolver: resolver,
            onEdit: () => _edit(entry),
            onDelete: () => _delete(entry),
          ),
        );
      },
    );
  }
}

class _DayDetailMessage extends StatelessWidget {
  const _DayDetailMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TypographyTokens.captionSans.copyWith(color: Palette.danger),
    );
  }
}
