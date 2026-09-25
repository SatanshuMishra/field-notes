import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart'
    show ComposerExit;
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/task_toggle.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show
        logViewerDeleteLabel,
        logViewerDeleteMessageFor,
        logViewerDeleteTitle,
        logViewerDeletedMessage;
import 'package:field_notes/features/mood/mood.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import 'day_detail_edit_note.dart';
import 'day_detail_entries_bar.dart';
import 'day_detail_header.dart';
import 'day_detail_providers.dart';

const String dayDetailMoodPrompt = 'How was this day?';
const String dayDetailEmptyMessage = 'No entries for this day yet.';
const String dayDetailEntriesErrorMessage = "Couldn't load this day's entries.";
const String dayDetailMediaErrorMessage = "Couldn't load your media library.";
const String dayDetailDeleteErrorMessage =
    "Couldn't delete that entry. Please try again.";

const Key dayDetailPanelKey = ValueKey<String>('day-detail-panel');

const double dayDetailPanelMaxWidth = 560;
const double dayDetailPanelWindowGutter = 32;
const double dayDetailPanelHeightShare = 0.86;

const double _panelBorderWidth = 2;
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(18, 16, 18, 20);
const double _summaryGap = 16;
const double _messageGap = 8;
const double _listLeadGap = 12;
const double _cardGap = 9;

const int _focusScanFrames = 32;
const double _focusAlignment = 0.1;

class DayDetailPanel extends ConsumerStatefulWidget {
  const DayDetailPanel({
    super.key,
    required this.date,
    this.focusEntryId,
    this.maxWidth = dayDetailPanelMaxWidth,
    this.onCoveredChanged,
  });

  final String date;
  final String? focusEntryId;
  final double maxWidth;
  final ValueChanged<bool>? onCoveredChanged;

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

  bool _entriesListed() =>
      ref.read(entriesForDateProvider(widget.date)).hasValue &&
      ref.read(dayDetailMediaResolverProvider).hasValue;

  Future<void> _revealFocusedEntry() async {
    bool listedLastFrame = false;
    for (int frame = 0; frame < _focusScanFrames; frame++) {
      if (!mounted) {
        return;
      }
      final BuildContext? target = _focusedTile.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(target, alignment: _focusAlignment);
        return;
      }
      final bool listed = _entriesListed();
      if (listed && listedLastFrame && _entryScroll.hasClients) {
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
      listedLastFrame = listed;
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Future<T> _handOver<T>(Future<T> Function() open) async {
    widget.onCoveredChanged?.call(true);
    try {
      return await open();
    } finally {
      if (mounted) {
        widget.onCoveredChanged?.call(false);
      }
    }
  }

  Future<void> _open(Entry entry) async {
    final LogViewerOutcome outcome = await _handOver(
      () => showLogViewer(
        context,
        date: widget.date,
        entryId: entry.id,
        exit: LogViewerExit.back,
      ),
    );
    if (!mounted || outcome != LogViewerOutcome.closedAll) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _addNote() async {
    await _handOver(
      () => showTextComposer(context, widget.date, exit: ComposerExit.back),
    );
  }

  Future<void> _edit(Entry entry) async {
    await _handOver(
      () => showEditNote(
        context,
        entry: entry,
        date: widget.date,
        exit: ComposerExit.cancel,
      ),
    );
  }

  String _deletePlace() {
    final DateTime? day = parseDateKey(widget.date);
    return day == null
        ? widget.date
        : dayShortLabelFor(day, today: ref.read(todayClockProvider)());
  }

  Future<void> _delete(Entry entry) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: logViewerDeleteTitle,
      message: logViewerDeleteMessageFor(_deletePlace()),
      confirmLabel: logViewerDeleteLabel,
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(journalRepositoryProvider).softDeleteEntry(entry.id);
      if (!mounted) {
        return;
      }
      setState(() => _deleteError = null);
      showTransientToast(context, logViewerDeletedMessage);
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
    final DateTime today = ref.watch(todayClockProvider)();
    final Size window = MediaQuery.sizeOf(context);
    final double width = math.max(
      0,
      math.min(widget.maxWidth, window.width - dayDetailPanelWindowGutter),
    );
    final MediaResolver? resolver = resolverAsync.value;
    final List<Entry> listed = resolver == null ? const <Entry>[] : entries;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: window.height * dayDetailPanelHeightShare,
        ),
        child: Container(
          key: dayDetailPanelKey,
          width: width,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Palette.panelTop,
            border: Border.all(color: Palette.ink, width: _panelBorderWidth),
            borderRadius: BorderRadius.circular(Shapes.radiusXl),
            boxShadow: Shadows.panelLift,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DayDetailHeader(
                date: widget.date,
                today: today,
                onClose: () => Navigator.of(context).pop(),
              ),
              Flexible(
                child: _body(
                  entriesAsync,
                  entries,
                  listed,
                  resolver,
                  resolverAsync,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    AsyncValue<List<Entry>> entriesAsync,
    List<Entry> entries,
    List<Entry> listed,
    MediaResolver? resolver,
    AsyncValue<MediaResolver> resolverAsync,
  ) {
    return ListView.builder(
      controller: _entryScroll,
      shrinkWrap: true,
      padding: _bodyPadding,
      itemCount: 1 + listed.length,
      findChildIndexCallback: (Key key) {
        final int index = listed.indexWhere(
          (Entry entry) => key == ValueKey<String>(entry.id),
        );
        return index < 0 ? null : index + 1;
      },
      itemBuilder: (BuildContext context, int index) {
        final MediaResolver? listResolver = resolver;
        if (index == 0 || listResolver == null) {
          return _summary(entriesAsync, entries, resolverAsync);
        }
        final Entry entry = listed[index - 1];
        return KeyedSubtree(
          key: ValueKey<String>(entry.id),
          child: Padding(
            padding: EdgeInsets.only(
              top: index == 1 ? _listLeadGap : _cardGap,
            ),
            child: CompactLogCard(
              key: entry.id == widget.focusEntryId ? _focusedTile : null,
              entry: entry,
              resolver: listResolver,
              density: CompactLogDensity.day,
              audioPlayerFactory: createJustAudioPlayer,
              onOpen: () => _open(entry),
              onEdit: () => _edit(entry),
              onDelete: () => _delete(entry),
              onToggleTask: entry.type == EntryType.text
                  ? (int boxOffset) => toggleTaskWithUndo(
                      context,
                      entry: entry,
                      date: widget.date,
                      boxOffset: boxOffset,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _summary(
    AsyncValue<List<Entry>> entriesAsync,
    List<Entry> entries,
    AsyncValue<MediaResolver> resolverAsync,
  ) {
    final String? deleteError = _deleteError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MoodBannerForDate(
          date: widget.date,
          promptText: dayDetailMoodPrompt,
        ),
        const SizedBox(height: _summaryGap),
        DayDetailEntriesBar(
          entryCount: entriesAsync.hasValue ? entries.length : null,
          onAddNote: _addNote,
        ),
        if (entriesAsync.hasError) ...<Widget>[
          const SizedBox(height: _messageGap),
          const _DayDetailMessage(text: dayDetailEntriesErrorMessage),
        ],
        if (deleteError != null) ...<Widget>[
          const SizedBox(height: _messageGap),
          _DayDetailMessage(text: deleteError),
        ],
        if (entriesAsync.hasValue && entries.isEmpty) ...<Widget>[
          const SizedBox(height: _listLeadGap),
          const EmptyStatePlaceholder(message: dayDetailEmptyMessage),
        ] else if (entriesAsync.hasValue && resolverAsync.hasError) ...<Widget>[
          const SizedBox(height: _messageGap),
          const _DayDetailMessage(text: dayDetailMediaErrorMessage),
        ],
      ],
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
