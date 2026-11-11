import 'dart:async';

import 'package:flutter/material.dart'
    show InputDecoration, Material, MaterialType, TextField, Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart'
    show IconStickerGlyph, IconStickerGlyphIcon;
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/capture_day_line.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart'
    show ComposerStageGround, ComposerStageInks;
import 'package:field_notes/features/capture/core/saved_note_day_line.dart';
import 'package:field_notes/features/capture/immersive/stage_phase.dart'
    show stageLayoutOf;
import 'package:field_notes/features/capture/text/editor/format_bar.dart'
    show formatBarHeightOn;
import 'package:field_notes/features/capture/text/text_composer_sheet.dart'
    show
        ComposerBand,
        ComposerDayLine,
        ComposerLeaveControl,
        ComposerPage,
        ComposerScrollbar,
        ComposerTitleSlot,
        ComposerWritingColumn,
        composerCompactWidth,
        composerEditorEndInset,
        composerEditorSidePaddingFor,
        composerMeasureEm,
        composerTitleHint,
        composerTitleStyle;
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show
        LogMenuGlyph,
        LogMenuItem,
        MediaResolver,
        logActionsAddTitleLabel,
        logActionsDeleteKey,
        logActionsEditKey,
        logActionsEditLabel,
        logActionsMoreKey,
        logActionsMoreLabel,
        logActionsRenameKey,
        logActionsRenameLabel,
        logMenuDeleteLabel,
        showLogActionsMenu;
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart'
    show TransportGlyph, TransportGlyphIcon;
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerExit;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerBackKey;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/note_reading.dart'
    show LogStepFooter, NoteReadingBody;
import 'package:field_notes/features/log_viewer/viewer_chrome.dart'
    show ViewerKeys, viewerTitleFieldKey;
import 'package:field_notes/features/today/today_date.dart' show parseDateKey;

const Key noteReadingRoomKey = ValueKey<String>('note-reading-room');
const Key noteReadingRuleKey = ValueKey<String>('note-reading-rule');

const String noteReadingEditLabel = 'Edit';
const String _editTooltip = 'Edit (E)';

const double _compactActionsReach = 112;
const double _wideActionsReach = 176;
const double _actionGap = 8;
const double _actionGlyphSize = 17;
const double _actionLabelGap = 8;
const double _editHorizontalPadding = 14;
const double _actionBorderWidth = 1.5;
const double _ruleWidth = 120;
const double _compactRuleWidth = 80;
const double _ruleThickness = 2;
const double _footThickness = 1.5;
const EdgeInsets _footPadding = EdgeInsets.fromLTRB(24, 0, 24, 8);
const BorderRadius _actionRadius = BorderRadius.all(
  Radius.circular(Shapes.radius12),
);

String? _titleOrNull(String? raw) {
  final String trimmed = raw?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

class NoteReadingRoom extends StatefulWidget {
  const NoteReadingRoom({
    super.key,
    required this.scene,
    required this.resolver,
    this.onToggleTask,
  });

  final LogViewerScene scene;
  final MediaResolver resolver;
  final ValueChanged<int>? onToggleTask;

  @override
  State<NoteReadingRoom> createState() => _NoteReadingRoomState();
}

class _NoteReadingRoomState extends State<NoteReadingRoom> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _moreAnchor = GlobalKey(debugLabel: 'note-reading-more');
  bool _renaming = false;
  ({String? title})? _pendingTitle;

  @override
  void didUpdateWidget(NoteReadingRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool otherNote = oldWidget.scene.entry.id != widget.scene.entry.id;
    if (otherNote) {
      _renaming = false;
    }
    if (otherNote || oldWidget.scene.entry.title != widget.scene.entry.title) {
      _pendingTitle = null;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? get _savedTitle => _titleOrNull(widget.scene.entry.title);

  String? get _shownTitle {
    final ({String? title})? pending = _pendingTitle;
    return pending == null ? _savedTitle : pending.title;
  }

  void _startRename() {
    if (mounted && widget.scene.onRename != null) {
      setState(() => _renaming = true);
    }
  }

  void _cancelRename() {
    if (mounted) {
      setState(() => _renaming = false);
    }
  }

  Future<void> _commitRename(String typed) async {
    if (!mounted) {
      return;
    }
    final String? title = _titleOrNull(typed);
    final LogViewerRename? rename = widget.scene.onRename;
    if (rename == null || title == _shownTitle) {
      _cancelRename();
      return;
    }
    setState(() {
      _renaming = false;
      _pendingTitle = (title: title);
    });
    final bool saved = await rename(title);
    if (!saved && mounted) {
      setState(() => _pendingTitle = null);
    }
  }

  List<LogMenuItem> _menuItems() {
    final LogViewerScene scene = widget.scene;
    return <LogMenuItem>[
      if (scene.onRename != null)
        LogMenuItem(
          key: logActionsRenameKey,
          label: _shownTitle == null
              ? logActionsAddTitleLabel
              : logActionsRenameLabel,
          glyph: LogMenuGlyph.title,
          onSelected: _startRename,
        ),
      LogMenuItem(
        key: logActionsDeleteKey,
        label: logMenuDeleteLabel,
        glyph: LogMenuGlyph.trash,
        danger: true,
        onSelected: scene.onDelete,
      ),
    ];
  }

  void _openMore() {
    final BuildContext? anchor = _moreAnchor.currentContext;
    if (anchor != null) {
      unawaited(showLogActionsMenu(anchor, items: _menuItems()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    return ViewerKeys(
      onLeft: scene.onEarlier,
      onRight: scene.onLater,
      onEscape: scene.onBack,
      onPageUp: scene.onEarlier,
      onPageDown: scene.onLater,
      onEdit: _renaming ? null : scene.onEdit,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ComposerStageGround(),
            LayoutBuilder(builder: _layout),
          ],
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, BoxConstraints constraints) {
    final MediaQueryData media = MediaQuery.of(context);
    final double top = media.padding.top > media.viewPadding.top
        ? media.padding.top
        : media.viewPadding.top;
    final double bottom = media.padding.bottom > media.viewPadding.bottom
        ? media.padding.bottom
        : media.viewPadding.bottom;
    final bool compact =
        stageLayoutOf(context) != ShellLayout.sidebar ||
        constraints.maxWidth < composerCompactWidth;
    final LogViewerScene scene = widget.scene;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ComposerBand(
            leading: ComposerLeaveControl(
              pressableKey: logViewerBackKey,
              label: scene.exitLabel,
              back: scene.exit == LogViewerExit.back,
              iconOnly: compact,
              onPressed: scene.onBack,
            ),
            centre: ComposerDayLine(line: _dayLine(context, compact: compact)),
            centreReach: compact ? _compactActionsReach : _wideActionsReach,
            trailing: _actions(context, compact: compact),
          ),
          ComposerTitleSlot(
            compact: compact,
            child: _title(context, compact: compact),
          ),
          Expanded(
            child: ComposerPage(
              toolbar: _rule(context, compact: compact),
              surface: _body(
                composerEditorSidePaddingFor(constraints.maxWidth),
              ),
            ),
          ),
          if (scene.count > 1) _foot(context),
        ],
      ),
    );
  }

  CaptureDayLine _dayLine(BuildContext context, {required bool compact}) {
    final LogViewerScene scene = widget.scene;
    final String clock = scene.clockOf(context);
    final DateTime? day = parseDateKey(scene.date);
    if (compact && day != null) {
      return savedNoteShortDayLine(day: day, clock: clock);
    }
    return savedNoteDayLine(dayTitle: scene.dayTitle, clock: clock);
  }

  Widget _actions(BuildContext context, {required bool compact}) {
    final VoidCallback? onEdit = widget.scene.onEdit;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (onEdit != null) ...<Widget>[
          _EditButton(iconOnly: compact, onPressed: onEdit),
          if (!compact) const SizedBox(width: _actionGap),
        ],
        KeyedSubtree(
          key: _moreAnchor,
          child: _MoreButton(outlined: !compact, onPressed: _openMore),
        ),
      ],
    );
  }

  Widget _title(BuildContext context, {required bool compact}) {
    final TextStyle style = composerTitleStyle(context, compact: compact);
    if (_renaming) {
      return _RenameField(
        key: ValueKey<String>('note-reading-rename-${widget.scene.entry.id}'),
        initial: _shownTitle ?? '',
        style: style,
        hintStyle: style.copyWith(color: ComposerStageInks.of(context).chrome),
        onCommit: _commitRename,
        onCancel: _cancelRename,
      );
    }
    final String? title = _shownTitle;
    if (title == null) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Semantics(
        header: true,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }

  Widget _rule(BuildContext context, {required bool compact}) {
    return SizedBox(
      key: noteReadingRuleKey,
      height: formatBarHeightOn(Theme.of(context).platform),
      child: Center(
        child: SizedBox(
          width: compact ? _compactRuleWidth : _ruleWidth,
          child: DashedDivider(
            thickness: _ruleThickness,
            color: ComposerStageInks.of(context).line,
          ),
        ),
      ),
    );
  }

  Widget _body(double sidePadding) {
    final LogViewerScene scene = widget.scene;
    return ComposerScrollbar(
      controller: _scroll,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: composerEditorEndInset),
        child: ComposerWritingColumn(
          sidePadding: sidePadding,
          child: NoteReadingBody(
            entry: scene.entry,
            resolver: widget.resolver,
            dayTitle: scene.dayTitle,
            onToggleTask: widget.onToggleTask,
            showsMeta: false,
          ),
        ),
      ),
    );
  }

  Widget _foot(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    final ComposerStageInks inks = ComposerStageInks.of(context);
    return Padding(
      padding: _footPadding,
      child: NoteColumn(
        maxEm: composerMeasureEm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DashedDivider(thickness: _footThickness, color: inks.line),
            LogStepFooter(
              index: scene.index,
              count: scene.count,
              earlier: scene.earlier,
              later: scene.later,
              onEarlier: scene.onEarlier,
              onLater: scene.onLater,
              positionColor: inks.chrome,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.iconOnly, required this.onPressed});

  final bool iconOnly;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ComposerStageInks inks = ComposerStageInks.of(context);
    final TargetPlatform platform = Theme.of(context).platform;
    final Widget glyph = IconStickerGlyphIcon(
      glyph: IconStickerGlyph.edit,
      color: inks.ink,
      size: _actionGlyphSize,
    );
    return Pressable(
      key: logActionsEditKey,
      label: logActionsEditLabel,
      tooltip: _editTooltip,
      iconOnly: iconOnly,
      onPressed: onPressed,
      borderRadius: _actionRadius,
      child: iconOnly
          ? SizedBox.square(
              dimension: minIconTargetOn(platform),
              child: Center(child: glyph),
            )
          : Container(
              constraints: BoxConstraints(
                minHeight: minButtonTargetOn(platform),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: _editHorizontalPadding,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: inks.line, width: _actionBorderWidth),
                borderRadius: _actionRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  glyph,
                  const SizedBox(width: _actionLabelGap),
                  Text(
                    noteReadingEditLabel,
                    style: context.textStyles.buttonSans.copyWith(
                      color: inks.ink,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.outlined, required this.onPressed});

  final bool outlined;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ComposerStageInks inks = ComposerStageInks.of(context);
    final TargetPlatform platform = Theme.of(context).platform;
    final double extent = outlined
        ? minButtonTargetOn(platform)
        : minIconTargetOn(platform);
    return Pressable(
      key: logActionsMoreKey,
      label: logActionsMoreLabel,
      tooltip: logActionsMoreLabel,
      iconOnly: true,
      onPressed: onPressed,
      borderRadius: _actionRadius,
      child: Container(
        width: extent,
        height: extent,
        alignment: Alignment.center,
        decoration: outlined
            ? BoxDecoration(
                border: Border.all(color: inks.line, width: _actionBorderWidth),
                borderRadius: _actionRadius,
              )
            : null,
        child: TransportGlyphIcon(
          glyph: TransportGlyph.more,
          color: inks.ink,
          size: _actionGlyphSize,
        ),
      ),
    );
  }
}

class _RenameField extends StatefulWidget {
  const _RenameField({
    super.key,
    required this.initial,
    required this.style,
    required this.hintStyle,
    required this.onCommit,
    required this.onCancel,
  });

  final String initial;
  final TextStyle style;
  final TextStyle hintStyle;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;

  @override
  State<_RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<_RenameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  late final FocusNode _focus = FocusNode(
    debugLabel: 'note reading rename',
    onKeyEvent: _onKey,
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    if (_done) {
      return;
    }
    _done = true;
    widget.onCommit(_controller.text);
  }

  void _onFocus() {
    if (!_focus.hasFocus) {
      _commit();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _done = true;
    widget.onCancel();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: logActionsRenameLabel,
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          key: viewerTitleFieldKey,
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          maxLines: 1,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: ComposerStageInks.of(context).caret,
          style: widget.style,
          decoration: InputDecoration.collapsed(
            hintText: composerTitleHint,
            hintStyle: widget.hintStyle,
          ),
          onEditingComplete: _commit,
          onTapOutside: (PointerDownEvent _) => _commit(),
        ),
      ),
    );
  }
}
