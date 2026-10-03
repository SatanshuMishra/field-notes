import 'dart:math' as math;

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
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
const String dayDetailAddNoteLabel = 'Add a note';

const Key dayDetailPanelKey = ValueKey<String>('day-detail-panel');
const Key daySheetCloseKey = ValueKey<String>('day-sheet-close');

Key daySheetEditKeyFor(String entryId) =>
    ValueKey<String>('day-sheet-edit-$entryId');

Key daySheetDeleteKeyFor(String entryId) =>
    ValueKey<String>('day-sheet-delete-$entryId');

const double dayDetailPanelMaxWidth = 560;
const double dayDetailPanelWindowGutter = 32;
const double dayDetailPanelHeightShare = 0.86;

const double _panelBorderWidth = 2;
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(18, 16, 18, 20);
const double _summaryGap = 16;
const double _messageGap = 8;
const double _listLeadGap = 12;
const double _cardGap = 9;

const EdgeInsets _sheetBodyPadding = EdgeInsets.fromLTRB(12, 12, 12, 14);
const double _sheetMoodGap = 12;
const EdgeInsets _sheetCountPadding = EdgeInsets.fromLTRB(2, 2, 2, 8);
const double _sheetCountSize = 14;
const double _sheetCardGap = 8;
const double _sheetRuleThickness = 1.5;
const double _sheetActionExtent = 40;
const double _sheetActionTarget = 48;
const double _sheetActionGap = 8;
const double _sheetActionEnd = 12;
const double _sheetActionReach = (_sheetActionTarget - _sheetActionExtent) / 2;
const double _sheetActionRise = _sheetActionTarget / 2;
const double _sheetActionGlyph = 16;
const double _sheetActionBorderWidth = 1.5;
const BorderRadius _sheetActionRadius = BorderRadius.all(Radius.circular(10));
const double _sheetFooterButtonHeight = 48;
const double _sheetCloseHorizontalPadding = 18;
const BorderRadius _sheetFooterRadius = BorderRadius.all(Radius.circular(14));
const double _sheetFooterLabelSize = 13;
const double _sheetPlusExtent = 14;
const double _sheetPlusGap = 7;

const int _focusScanFrames = 32;
const double _focusAlignment = 0.1;

Color _panelPaperFor(Brightness brightness, FieldNotesColors colors) =>
    switch (brightness) {
      Brightness.light => colors.panelTop,
      Brightness.dark => colors.composerPaper,
    };

class DayDetailPanel extends ConsumerStatefulWidget {
  const DayDetailPanel({
    super.key,
    required this.date,
    this.focusEntryId,
    this.maxWidth = dayDetailPanelMaxWidth,
    this.onCoveredChanged,
    this.layout = ShellLayout.sidebar,
  });

  final String date;
  final String? focusEntryId;
  final double maxWidth;
  final ValueChanged<bool>? onCoveredChanged;
  final ShellLayout layout;

  @override
  ConsumerState<DayDetailPanel> createState() => _DayDetailPanelState();
}

class _DayDetailPanelState extends ConsumerState<DayDetailPanel> {
  final ScrollController _entryScroll = ScrollController();
  final GlobalKey _focusedTile = GlobalKey();

  String? _deleteError;

  bool get _sheet => widget.layout == ShellLayout.bottomBar;

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
    final AsyncValue<List<Entry>> entriesAsync = ref.watch(
      entriesForDateProvider(widget.date),
    );
    final List<Entry> entries = entriesAsync.value ?? const <Entry>[];
    final AsyncValue<MediaResolver> resolverAsync = ref.watch(
      dayDetailMediaResolverProvider,
    );
    final DateTime today = ref.watch(todayClockProvider)();
    final MediaResolver? resolver = resolverAsync.value;
    final List<Entry> listed = resolver == null ? const <Entry>[] : entries;

    if (_sheet) {
      return _phoneSheet(
        today: today,
        summary: _summary(entriesAsync, entries, resolverAsync),
        listed: listed,
        resolver: resolver,
      );
    }

    final Size window = MediaQuery.sizeOf(context);
    final double width = math.max(
      0,
      math.min(widget.maxWidth, window.width - dayDetailPanelWindowGutter),
    );
    final FieldNotesColors colors = context.colors;

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
            color: _panelPaperFor(Theme.of(context).brightness, colors),
            border: Border.all(color: colors.line, width: _panelBorderWidth),
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

  Widget _phoneSheet({
    required DateTime today,
    required Widget summary,
    required List<Entry> listed,
    required MediaResolver? resolver,
  }) {
    final FieldNotesColors colors = context.colors;
    return PhoneSheet(
      key: dayDetailPanelKey,
      color: colors.panelTop,
      header: DayDetailSheetHeader(date: widget.date, today: today),
      aboveFooter: DashedDivider(
        thickness: _sheetRuleThickness,
        color: colors.ink22,
      ),
      actions: <Widget>[
        _SheetFooterButton(
          key: daySheetCloseKey,
          label: dayDetailCloseLabel,
          fill: colors.cardLight,
          labelColor: colors.ink,
          horizontalPadding: _sheetCloseHorizontalPadding,
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: _SheetFooterButton(
            key: dayDetailAddNoteKey,
            label: dayDetailAddNoteLabel,
            fill: Palette.coral,
            labelColor: Palette.onAccent,
            shadow: context.shadows.emphasis,
            leading: const NavIcon(
              glyph: NavGlyph.plus,
              color: Palette.onAccent,
              size: _sheetPlusExtent,
            ),
            onPressed: _addNote,
          ),
        ),
      ],
      child: Padding(
        padding: _sheetBodyPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            summary,
            if (resolver != null)
              for (int index = 0; index < listed.length; index++)
                _sheetEntry(listed[index], index, resolver),
          ],
        ),
      ),
    );
  }

  Widget _sheetEntry(Entry entry, int index, MediaResolver resolver) {
    return KeyedSubtree(
      key: ValueKey<String>(entry.id),
      child: Padding(
        padding: EdgeInsets.only(top: index == 0 ? 0 : _sheetCardGap),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: _sheetActionRise),
              child: _card(entry, resolver),
            ),
            PositionedDirectional(
              top: 0,
              end: _sheetActionEnd - _sheetActionReach,
              child: _SheetEntryActions(
                entryId: entry.id,
                onEdit: entry.type == EntryType.text
                    ? () => _edit(entry)
                    : null,
                onDelete: () => _delete(entry),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Entry entry, MediaResolver resolver, {int? semanticIndex}) {
    return CompactLogCard(
      key: entry.id == widget.focusEntryId ? _focusedTile : null,
      entry: entry,
      resolver: resolver,
      density: CompactLogDensity.day,
      semanticIndex: semanticIndex,
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
      addSemanticIndexes: false,
      findChildIndexCallback: (Key key) {
        final int index = listed.indexWhere(
          (Entry entry) => key == ValueKey<String>(entry.id),
        );
        return index < 0 ? null : index + 1;
      },
      itemBuilder: (BuildContext context, int index) {
        final MediaResolver? listResolver = resolver;
        if (index == 0 || listResolver == null) {
          return IndexedSemantics(
            index: index,
            child: _summary(entriesAsync, entries, resolverAsync),
          );
        }
        final Entry entry = listed[index - 1];
        return KeyedSubtree(
          key: ValueKey<String>(entry.id),
          child: Padding(
            padding: EdgeInsets.only(top: index == 1 ? _listLeadGap : _cardGap),
            child: _card(entry, listResolver, semanticIndex: index),
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
    final int? count = entriesAsync.hasValue ? entries.length : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MoodBannerForDate(date: widget.date, promptText: dayDetailMoodPrompt),
        SizedBox(height: _sheet ? _sheetMoodGap : _summaryGap),
        if (_sheet)
          _SheetEntryCount(count: count)
        else
          DayDetailEntriesBar(entryCount: count, onAddNote: _addNote),
        if (entriesAsync.hasError) ...<Widget>[
          const SizedBox(height: _messageGap),
          const _DayDetailMessage(text: dayDetailEntriesErrorMessage),
        ],
        if (deleteError != null) ...<Widget>[
          const SizedBox(height: _messageGap),
          _DayDetailMessage(text: deleteError),
        ],
        if (entriesAsync.hasValue && entries.isEmpty) ...<Widget>[
          if (!_sheet) const SizedBox(height: _listLeadGap),
          const EmptyStatePlaceholder(message: dayDetailEmptyMessage),
        ] else if (entriesAsync.hasValue && resolverAsync.hasError) ...<Widget>[
          const SizedBox(height: _messageGap),
          const _DayDetailMessage(text: dayDetailMediaErrorMessage),
        ],
      ],
    );
  }
}

class _SheetEntryCount extends StatelessWidget {
  const _SheetEntryCount({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final int? value = count;
    if (value == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: _sheetCountPadding,
      child: Text(
        dayDetailEntryCountLabel(value),
        style: context.textStyles.stampAccent.copyWith(
          fontSize: _sheetCountSize,
        ),
      ),
    );
  }
}

class _SheetEntryActions extends StatelessWidget {
  const _SheetEntryActions({
    required this.entryId,
    required this.onEdit,
    required this.onDelete,
  });

  final String entryId;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final VoidCallback? edit = onEdit;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (edit != null) ...<Widget>[
          _SheetEntryAction(
            key: daySheetEditKeyFor(entryId),
            glyph: IconStickerGlyph.edit,
            label: logActionsEditLabel,
            fill: colors.cardBright,
            edge: colors.line,
            glyphColor: colors.ink,
            onPressed: edit,
          ),
          const SizedBox(width: _sheetActionGap - 2 * _sheetActionReach),
        ],
        _SheetEntryAction(
          key: daySheetDeleteKeyFor(entryId),
          glyph: IconStickerGlyph.trash,
          label: logActionsDeleteLabel,
          fill: colors.dangerSurface,
          edge: colors.dangerInk,
          glyphColor: colors.dangerInk,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _SheetEntryAction extends StatelessWidget {
  const _SheetEntryAction({
    super.key,
    required this.glyph,
    required this.label,
    required this.fill,
    required this.edge,
    required this.glyphColor,
    required this.onPressed,
  });

  final IconStickerGlyph glyph;
  final String label;
  final Color fill;
  final Color edge;
  final Color glyphColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: _sheetActionTarget,
          child: Center(
            child: FocusRing(
              onPressed: onPressed,
              borderRadius: _sheetActionRadius,
              child: Container(
                width: _sheetActionExtent,
                height: _sheetActionExtent,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  border: Border.all(
                    color: edge,
                    width: _sheetActionBorderWidth,
                  ),
                  borderRadius: _sheetActionRadius,
                ),
                child: IconStickerGlyphIcon(
                  glyph: glyph,
                  color: glyphColor,
                  size: _sheetActionGlyph,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetFooterButton extends StatelessWidget {
  const _SheetFooterButton({
    super.key,
    required this.label,
    required this.fill,
    required this.labelColor,
    required this.onPressed,
    this.leading,
    this.shadow,
    this.horizontalPadding = 0,
  });

  final String label;
  final Color fill;
  final Color labelColor;
  final VoidCallback onPressed;
  final Widget? leading;
  final List<BoxShadow>? shadow;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final Widget? glyph = leading;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: _sheetFooterRadius,
          child: Container(
            height: _sheetFooterButtonHeight,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              border: context.shadows.outline,
              borderRadius: _sheetFooterRadius,
              boxShadow: shadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (glyph != null) ...<Widget>[
                  glyph,
                  const SizedBox(width: _sheetPlusGap),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.captureLabelSans.copyWith(
                      fontSize: _sheetFooterLabelSize,
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      style: context.textStyles.captionSans.copyWith(
        color: context.colors.dangerInk,
      ),
    );
  }
}
