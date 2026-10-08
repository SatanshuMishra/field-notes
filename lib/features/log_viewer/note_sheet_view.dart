import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show
        MediaResolver,
        logActionsDeleteKey,
        logActionsDeleteLabel,
        logActionsEditKey,
        logActionsEditLabel,
        logPreviewOf;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerBackKey;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/note_reading.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart'
    show ViewerKeys;

const double _ruleThickness = 1.5;
const EdgeInsets _headerPadding = EdgeInsets.fromLTRB(18, 6, 18, 10);
const double _titleSize = 21;
const double _titleLineHeight = 1.1;
const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(18, 12, 18, 16);
const BorderRadius _buttonRadius = BorderRadius.all(Radius.circular(14));
const double _labelSize = 13;
const double _backGlyphSize = 14;
const double _backGlyphGap = 6;
const double _backHorizontalPadding = 12;
const double _actionGlyphSize = 17;
const double _buttonHeight = 48;

class NoteSheetView extends StatefulWidget {
  const NoteSheetView({
    super.key,
    required this.scene,
    required this.resolver,
    this.onToggleTask,
  });

  final LogViewerScene scene;
  final MediaResolver resolver;
  final ValueChanged<int>? onToggleTask;

  @override
  State<NoteSheetView> createState() => _NoteSheetViewState();
}

class _NoteSheetViewState extends State<NoteSheetView> {
  bool _expanded = false;

  void _onExpandedChanged(bool expanded) {
    if (mounted && expanded != _expanded) {
      setState(() => _expanded = expanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    return ViewerKeys(
      onLeft: scene.onEarlier,
      onRight: scene.onLater,
      onEscape: scene.onBack,
      child: PhoneSheet(
        color: context.colors.composerPaper,
        expanded: _expanded,
        onExpandedChanged: _onExpandedChanged,
        header: _header(context),
        aboveFooter: scene.count > 1 ? _footer(context) : null,
        actions: _actions(),
        child: Padding(
          padding: _bodyPadding,
          child: NoteReadingBody(
            entry: scene.entry,
            resolver: widget.resolver,
            dayTitle: scene.dayTitle,
            onToggleTask: widget.onToggleTask,
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DashedDivider(thickness: _ruleThickness, color: context.colors.ink25),
        LogStepFooter(
          index: scene.index,
          count: scene.count,
          earlier: scene.earlier,
          later: scene.later,
          onEarlier: scene.onEarlier,
          onLater: scene.onLater,
        ),
      ],
    );
  }

  List<Widget> _actions() {
    final LogViewerScene scene = widget.scene;
    final VoidCallback? onEdit = scene.onEdit;
    return <Widget>[
      Expanded(
        child: _BackButton(
          key: logViewerBackKey,
          label: scene.exitLabel,
          onPressed: scene.onBack,
        ),
      ),
      if (onEdit != null)
        _ActionSquare(
          key: logActionsEditKey,
          glyph: IconStickerGlyph.edit,
          label: logActionsEditLabel,
          onPressed: onEdit,
        ),
      _ActionSquare(
        key: logActionsDeleteKey,
        glyph: IconStickerGlyph.trash,
        label: logActionsDeleteLabel,
        onPressed: scene.onDelete,
      ),
    ];
  }

  Widget _header(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: _headerPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.scene.dayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyles.stampAccent.copyWith(color: colors.accentInk),
              ),
              Text(
                logPreviewOf(widget.scene.entry).heading,
                style: textStyles.headlineSerif.copyWith(
                  fontSize: _titleSize,
                  height: _titleLineHeight,
                ),
              ),
            ],
          ),
        ),
        DashedDivider(thickness: _ruleThickness, color: colors.ink25),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({super.key, required this.label, required this.onPressed});

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
          borderRadius: _buttonRadius,
          child: Container(
            height: _buttonHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: _backHorizontalPadding,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.cardWarm,
              border: shadows.outline,
              borderRadius: _buttonRadius,
              boxShadow: shadows.chip,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ChevronGlyph(
                  pointsBack: true,
                  color: colors.ink,
                  size: _backGlyphSize,
                ),
                const SizedBox(width: _backGlyphGap),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.captureLabelSans.copyWith(
                      fontSize: _labelSize,
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

class _ActionSquare extends StatelessWidget {
  const _ActionSquare({
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
          borderRadius: _buttonRadius,
          child: Container(
            width: _buttonHeight,
            height: _buttonHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Palette.toolbarInk,
              borderRadius: _buttonRadius,
            ),
            child: IconStickerGlyphIcon(
              glyph: glyph,
              color: Palette.onAccent,
              size: _actionGlyphSize,
            ),
          ),
        ),
      ),
    );
  }
}
