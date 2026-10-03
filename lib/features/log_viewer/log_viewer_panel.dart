import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/format/clock_format.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/task_toggle.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show isTextInputFocused;
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import 'log_viewer.dart';

const Key logViewerPanelKey = ValueKey<String>('log-viewer-panel');
const Key logViewerEarlierKey = ValueKey<String>('log-viewer-earlier');
const Key logViewerLaterKey = ValueKey<String>('log-viewer-later');
const Key logViewerBackKey = ValueKey<String>('log-viewer-back');

const String logViewerDeleteTitle = 'Delete this entry?';
const String logViewerDeleteLabel = 'Delete';
const String logViewerDeletedMessage = 'Entry deleted';
const String logViewerDeleteFailedMessage =
    "Couldn't delete that entry. Please try again.";
const String logViewerEarlierLabel = 'Earlier log';
const String logViewerLaterLabel = 'Later log';
const String logViewerBackLabel = 'Back';
const String logViewerCloseLabel = 'Close';

String logViewerDeleteMessageFor(String place) =>
    'This log will be removed from $place. This can’t be undone.';

const double _headerVerticalPadding = 16;
const double _headerHorizontalPadding = 18;
const double _headerGap = 14;
const double _ruleThickness = 1.5;
const double _titleSize = 22;
const double _titleLineHeight = 1.05;
const double _exitPillHeight = 34;
const double _exitPillStartPadding = 8;
const double _exitPillEndPadding = 12;
const BorderRadius _exitPillBorderRadius = BorderRadius.all(
  Radius.circular(10),
);
const double _exitGlyphSize = 15;
const double _exitGlyphGap = 4;
const double _actionButtonExtent = 30;
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(38, 22, 38, 28);
const double _metaSize = 11;
const double _metaLetterSpacing = 0.44;
const double _metaGap = 14;
const double _footerVerticalPadding = 10;
const double _footerHorizontalPadding = 14;
const double _stepGlyphSize = 14;
const double _stepGlyphGap = 6;
const double _absentStepOpacity = 0.35;
const double _chevronStrokeWidth = 2;
const double _chevronArm = 5;
const double _minTapTarget = 48;
const double _exitPillReach = (_minTapTarget - _exitPillHeight) / 2;
const EdgeInsets _sheetHeaderPadding = EdgeInsets.fromLTRB(18, 6, 18, 10);
const double _sheetTitleSize = 21;
const double _sheetTitleLineHeight = 1.1;
const EdgeInsets _sheetBodyPadding = EdgeInsets.fromLTRB(18, 12, 18, 16);
const BorderRadius _sheetButtonRadius = BorderRadius.all(Radius.circular(14));
const double _sheetLabelSize = 13;
const double _sheetBackGlyphSize = 14;
const double _sheetBackGlyphGap = 6;
const double _sheetBackHorizontalPadding = 12;
const double _sheetActionGlyphSize = 17;
const double _sheetButtonHeight = 48;

class LogViewerPanel extends ConsumerStatefulWidget {
  const LogViewerPanel({
    super.key,
    required this.date,
    required this.entryId,
    required this.exit,
    this.layout = ShellLayout.sidebar,
  });

  final String date;
  final String entryId;
  final LogViewerExit exit;
  final ShellLayout layout;

  @override
  ConsumerState<LogViewerPanel> createState() => _LogViewerPanelState();
}

class _LogViewerPanelState extends ConsumerState<LogViewerPanel> {
  final FocusNode _keys = FocusNode(debugLabel: 'log-viewer-keys');
  late String _entryId = widget.entryId;
  bool _editing = false;
  bool _deleting = false;
  bool _left = false;
  int? _scrimPointer;

  bool get _sheet => widget.layout == ShellLayout.bottomBar;

  String get _exitLabel => widget.exit == LogViewerExit.back
      ? logViewerBackLabel
      : logViewerCloseLabel;

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _keys.dispose();
    super.dispose();
  }

  void _onPointer(PointerEvent event) {
    final int pointer = event.pointer;
    if (pointer != _scrimPointer) {
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      Timer.run(() {
        if (_scrimPointer == pointer) {
          _scrimPointer = null;
        }
      });
    }
  }

  void _onTapOutside(PointerDownEvent event) {
    _scrimPointer = event.pointer;
  }

  void _leave(LogViewerOutcome outcome) {
    if (!mounted || _left) {
      return;
    }
    _left = true;
    Navigator.of(context).pop(outcome);
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop || _editing) {
      return;
    }
    _leave(
      _scrimPointer == null
          ? LogViewerOutcome.returned
          : LogViewerOutcome.closedAll,
    );
  }

  List<Entry>? _currentEntries() =>
      ref.read(entriesForDateProvider(widget.date)).value;

  int _indexIn(List<Entry> entries) =>
      entries.indexWhere((Entry entry) => entry.id == _entryId);

  void _step(int delta) {
    final List<Entry>? entries = _currentEntries();
    if (entries == null) {
      return;
    }
    final int index = _indexIn(entries);
    final int target = index + delta;
    if (index < 0 || target < 0 || target >= entries.length) {
      return;
    }
    setState(() => _entryId = entries[target].id);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final bool topmost = ModalRoute.of(context)?.isCurrent ?? true;
    if (_editing || !topmost || isTextInputFocused()) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      _leave(LogViewerOutcome.returned);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _step(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _edit() {
    setState(() => _editing = true);
  }

  Future<void> _editInComposer(Entry entry) async {
    if (_editing || _left) {
      return;
    }
    setState(() => _editing = true);
    final bool? saved = await showEditNote(
      context,
      entry: entry,
      date: widget.date,
      exit: ComposerExit.back,
    );
    _onEditDone(saved ?? false);
  }

  void _onEditDone(bool saved) {
    if (!mounted) {
      return;
    }
    setState(() => _editing = false);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted && !_editing) {
        _keys.requestFocus();
      }
    });
  }

  Future<void> _delete(Entry entry) async {
    if (_deleting || _left) {
      return;
    }
    _deleting = true;
    final DateTime? day = parseDateKey(widget.date);
    final String place = day == null
        ? widget.date
        : dayShortLabelFor(day, today: ref.read(todayClockProvider)());
    final bool confirmed = await showConfirmDialog(
      context,
      title: logViewerDeleteTitle,
      message: logViewerDeleteMessageFor(place),
      confirmLabel: logViewerDeleteLabel,
      danger: true,
    );
    if (!mounted) {
      return;
    }
    if (!confirmed) {
      setState(() => _deleting = false);
      return;
    }
    try {
      await ref.read(journalRepositoryProvider).softDeleteEntry(entry.id);
    } catch (error, stackTrace) {
      debugPrint('Log delete failed: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() => _deleting = false);
      showTransientToast(context, logViewerDeleteFailedMessage);
      return;
    }
    if (!mounted) {
      return;
    }
    showTransientToast(context, logViewerDeletedMessage);
    _leave(LogViewerOutcome.deleted);
  }

  void _leaveIfRemoved(List<Entry>? entries) {
    if (entries == null || _deleting || _left || _indexIn(entries) >= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      final List<Entry>? latest = _currentEntries();
      if (mounted && !_deleting && latest != null && _indexIn(latest) < 0) {
        _leave(LogViewerOutcome.returned);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Entry>? entries = ref
        .watch(entriesForDateProvider(widget.date))
        .value;
    _leaveIfRemoved(entries);
    final int index = entries == null ? -1 : _indexIn(entries);
    final Entry? entry = index < 0 ? null : entries![index];
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: TapRegion(
        onTapOutside: _onTapOutside,
        child: Focus(
          focusNode: _keys,
          autofocus: true,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: _sheet
              ? _phoneSheet(entries ?? const <Entry>[], index, entry)
              : AnimatedSize(
                  key: logViewerPanelKey,
                  duration: Motion.modalPop,
                  curve: Motion.entranceCurve,
                  alignment: Alignment.topCenter,
                  child: _editing && entry != null
                      ? EditNoteConnector(
                          key: ValueKey<String>('log-viewer-edit-${entry.id}'),
                          entry: entry,
                          date: widget.date,
                          exit: ComposerExit.back,
                          onDone: _onEditDone,
                        )
                      : _viewMode(entries ?? const <Entry>[], index, entry),
                ),
        ),
      ),
    );
  }

  Widget _viewMode(List<Entry> entries, int index, Entry? entry) {
    final Color rule = context.colors.ink25;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(entry),
        DashedDivider(thickness: _ruleThickness, color: rule),
        Flexible(
          child: SingleChildScrollView(
            padding: _bodyPadding,
            child: entry == null ? const SizedBox.shrink() : _body(entry),
          ),
        ),
        if (entry != null && entries.length > 1) ...<Widget>[
          DashedDivider(thickness: _ruleThickness, color: rule),
          _footer(entries, index),
        ],
      ],
    );
  }

  Widget _header(Entry? entry) {
    final bool editable = entry?.type == EntryType.text;
    final EdgeInsets reach = entry == null
        ? EdgeInsets.zero
        : logActionsPillTapInset(
            buttonExtent: _actionButtonExtent,
            withEdit: editable,
          );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: _headerHorizontalPadding,
        end: math.max<double>(0, _headerHorizontalPadding - reach.right),
      ),
      child: Row(
        children: <Widget>[
          _exitPill(),
          Expanded(
            child: _titleBlock(
              entry,
              endGap: math.max<double>(0, _headerGap - reach.left),
            ),
          ),
          if (entry != null)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: math.max<double>(
                  0,
                  _headerVerticalPadding - reach.top,
                ),
              ),
              child: LogActionsPill(
                buttonExtent: _actionButtonExtent,
                onEdit: editable ? _edit : null,
                onDelete: () => _delete(entry),
              ),
            ),
        ],
      ),
    );
  }

  Widget _exitPill() {
    final String label = _exitLabel;
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: _headerVerticalPadding - _exitPillReach,
      ),
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _leave(LogViewerOutcome.returned),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            child: Center(
              child: FocusRing(
                onPressed: () => _leave(LogViewerOutcome.returned),
                borderRadius: _exitPillBorderRadius,
                child: Container(
                  height: _exitPillHeight,
                  padding: const EdgeInsets.only(
                    left: _exitPillStartPadding,
                    right: _exitPillEndPadding,
                  ),
                  decoration: BoxDecoration(
                    color: colors.cardWarm,
                    border: shadows.outline,
                    borderRadius: _exitPillBorderRadius,
                    boxShadow: shadows.chip,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox.square(
                        dimension: _exitGlyphSize,
                        child: CustomPaint(
                          painter: _ChevronPainter(
                            pointsBack: true,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: _exitGlyphGap),
                      Text(
                        label,
                        style: context.textStyles.captureLabelSans.copyWith(
                          color: colors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _dayTitle() {
    final DateTime? day = parseDateKey(widget.date);
    return day == null
        ? widget.date
        : dayTitleFor(day, today: ref.watch(todayClockProvider)());
  }

  Widget _phoneSheet(List<Entry> entries, int index, Entry? entry) {
    final FieldNotesColors colors = context.colors;
    return PhoneSheet(
      key: logViewerPanelKey,
      color: colors.composerPaper,
      header: _sheetHeader(entry),
      aboveFooter: entry != null && entries.length > 1
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DashedDivider(thickness: _ruleThickness, color: colors.ink25),
                _footer(entries, index),
              ],
            )
          : null,
      actions: <Widget>[
        Expanded(
          child: _SheetBackButton(
            key: logViewerBackKey,
            label: _exitLabel,
            onPressed: () => _leave(LogViewerOutcome.returned),
          ),
        ),
        if (entry != null && entry.type == EntryType.text)
          _SheetActionSquare(
            key: logActionsEditKey,
            glyph: IconStickerGlyph.edit,
            label: logActionsEditLabel,
            onPressed: () => _editInComposer(entry),
          ),
        if (entry != null)
          _SheetActionSquare(
            key: logActionsDeleteKey,
            glyph: IconStickerGlyph.trash,
            label: logActionsDeleteLabel,
            onPressed: () => _delete(entry),
          ),
      ],
      child: Padding(
        padding: _sheetBodyPadding,
        child: entry == null ? const SizedBox.shrink() : _body(entry),
      ),
    );
  }

  Widget _sheetHeader(Entry? entry) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: _sheetHeaderPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _dayTitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyles.stampAccent.copyWith(color: colors.accentInk),
              ),
              Text(
                entry == null ? '' : logPreviewOf(entry).heading,
                style: textStyles.headlineSerif.copyWith(
                  fontSize: _sheetTitleSize,
                  height: _sheetTitleLineHeight,
                ),
              ),
            ],
          ),
        ),
        DashedDivider(thickness: _ruleThickness, color: colors.ink25),
      ],
    );
  }

  Widget _titleBlock(Entry? entry, {required double endGap}) {
    final String kicker = _dayTitle();
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        _headerGap,
        _headerVerticalPadding,
        endGap,
        _headerVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kicker,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyles.stampAccent.copyWith(
              color: context.colors.accentInk,
            ),
          ),
          Text(
            entry == null ? '' : logPreviewOf(entry).heading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyles.headlineSerif.copyWith(
              fontSize: _titleSize,
              height: _titleLineHeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Entry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _metaFor(context, entry),
          style: context.textStyles.captureLabelSans.copyWith(
            fontSize: _metaSize,
            letterSpacing: _metaLetterSpacing,
            color: context.colors.muted,
          ),
        ),
        const SizedBox(height: _metaGap),
        KeyedSubtree(
          key: ValueKey<String>('log-viewer-content-${entry.id}'),
          child: _content(entry),
        ),
      ],
    );
  }

  Widget _content(Entry entry) {
    final MediaResolver? resolver = ref.watch(notesMediaResolverProvider).value;
    if (resolver == null) {
      return const SizedBox.shrink();
    }
    switch (entry.type) {
      case EntryType.text:
        return _NoteFocusRing(
          child: NoteMediaScope(
            resolver: resolver,
            child: NoteBody(
              text: entry.textContent ?? '',
              onToggleTask: (int boxOffset) => toggleTaskWithUndo(
                context,
                entry: entry,
                date: widget.date,
                boxOffset: boxOffset,
              ),
            ),
          ),
        );
      case EntryType.voice:
        return VoiceBody(
          entry: entry,
          resolver: resolver,
          playerFactory: ref.watch(todayAudioPlayerFactoryProvider),
        );
      case EntryType.video:
        return VideoBody(
          entry: entry,
          resolver: resolver,
          playerFactory: ref.watch(todayVideoPlayerFactoryProvider),
          slots: ref.watch(videoSlotsProvider),
        );
    }
  }

  Widget _footer(List<Entry> entries, int index) {
    final Entry? earlier = index > 0 ? entries[index - 1] : null;
    final Entry? later = index + 1 < entries.length ? entries[index + 1] : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _footerHorizontalPadding),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _StepControl(
                key: logViewerEarlierKey,
                label: logViewerEarlierLabel,
                neighbour: earlier,
                pointsBack: true,
                onStep: () => _step(-1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _footerVerticalPadding,
            ),
            child: Text(
              '${index + 1} of ${entries.length}',
              style: context.textStyles.promptAccent,
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _StepControl(
                key: logViewerLaterKey,
                label: logViewerLaterLabel,
                neighbour: later,
                pointsBack: false,
                onStep: () => _step(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _clockOf(BuildContext context, Entry entry) {
  final DateTime at = DateTime.fromMillisecondsSinceEpoch(entry.createdAt);
  return formatClock(context, TimeOfDay.fromDateTime(at));
}

String _metaFor(BuildContext context, Entry entry) {
  final int? durationMs = entry.durationMs;
  final List<String> parts = <String>[
    _clockOf(context, entry),
    if (entry.type == EntryType.text) logPreviewOf(entry).meta,
    if (entry.type != EntryType.text && durationMs != null)
      formatMediaDuration(durationMs),
  ];
  return parts.where((String part) => part.isNotEmpty).join(' · ');
}

class _StepControl extends StatelessWidget {
  const _StepControl({
    super.key,
    required this.label,
    required this.neighbour,
    required this.pointsBack,
    required this.onStep,
  });

  final String label;
  final Entry? neighbour;
  final bool pointsBack;
  final VoidCallback onStep;

  @override
  Widget build(BuildContext context) {
    final Entry? target = neighbour;
    final bool enabled = target != null;
    final String caption = target == null
        ? label
        : '${_clockOf(context, target)} · ${logTypeLabelFor(target.type)}';
    final FieldNotesColors colors = context.colors;
    final Widget glyph = SizedBox.square(
      dimension: _stepGlyphSize,
      child: CustomPaint(
        painter: _ChevronPainter(pointsBack: pointsBack, color: colors.ink),
      ),
    );
    final Widget text = Text(
      caption,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textStyles.captureLabelSans.copyWith(color: colors.ink),
    );
    final VoidCallback? step = enabled ? onStep : null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: step,
      child: FocusRing(
        enabled: enabled,
        onPressed: step,
        borderRadius: _stepBorderRadius,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: step,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _minTapTarget,
                minHeight: _minTapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: _footerVerticalPadding,
                ),
                child: Opacity(
                  opacity: enabled ? 1 : _absentStepOpacity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: pointsBack
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.end,
                    children: pointsBack
                        ? <Widget>[
                            glyph,
                            const SizedBox(width: _stepGlyphGap),
                            Flexible(child: text),
                          ]
                        : <Widget>[
                            Flexible(child: text),
                            const SizedBox(width: _stepGlyphGap),
                            glyph,
                          ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetBackButton extends StatelessWidget {
  const _SheetBackButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: _sheetButtonRadius,
          child: Container(
            height: _sheetButtonHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: _sheetBackHorizontalPadding,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.cardWarm,
              border: shadows.outline,
              borderRadius: _sheetButtonRadius,
              boxShadow: shadows.chip,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox.square(
                  dimension: _sheetBackGlyphSize,
                  child: CustomPaint(
                    painter: _ChevronPainter(
                      pointsBack: true,
                      color: colors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: _sheetBackGlyphGap),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.captureLabelSans.copyWith(
                      fontSize: _sheetLabelSize,
                      color: colors.ink,
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

class _SheetActionSquare extends StatelessWidget {
  const _SheetActionSquare({
    super.key,
    required this.glyph,
    required this.label,
    required this.onPressed,
  });

  final IconStickerGlyph glyph;
  final String label;
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
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: _sheetButtonRadius,
          child: Container(
            width: _sheetButtonHeight,
            height: _sheetButtonHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Palette.toolbarInk,
              borderRadius: _sheetButtonRadius,
            ),
            child: IconStickerGlyphIcon(
              glyph: glyph,
              color: Palette.onAccent,
              size: _sheetActionGlyphSize,
            ),
          ),
        ),
      ),
    );
  }
}

const double _noteRingOutset = 8;

const BorderRadius _stepBorderRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

const BorderRadius _noteRingRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusSm),
);

class _NoteFocusRing extends StatefulWidget {
  const _NoteFocusRing({required this.child});

  final Widget child;

  @override
  State<_NoteFocusRing> createState() => _NoteFocusRingState();
}

class _NoteFocusRingState extends State<_NoteFocusRing> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) {
    if (mounted) {
      setState(() {});
    }
  }

  void _onFocusChange(bool focused) {
    if (mounted && focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ringed =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _onFocusChange,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: <Widget>[
          widget.child,
          if (ringed)
            Positioned(
              left: -_noteRingOutset,
              top: -_noteRingOutset,
              right: -_noteRingOutset,
              bottom: -_noteRingOutset,
              child: IgnorePointer(
                key: focusRingKey,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: context.colors.ink,
                      width: FocusRingSurface.light.width,
                    ),
                    borderRadius: _noteRingRadius,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.pointsBack, required this.color});

  final bool pointsBack;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _chevronStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double reach = pointsBack ? _chevronArm / 2 : -_chevronArm / 2;
    final Path path = Path()
      ..moveTo(cx + reach, cy - _chevronArm)
      ..lineTo(cx - reach, cy)
      ..lineTo(cx + reach, cy + _chevronArm);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.pointsBack != pointsBack || oldDelegate.color != color;
}
