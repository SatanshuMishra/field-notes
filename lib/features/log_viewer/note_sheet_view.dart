import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show
        MediaResolver,
        logActionsDeleteKey,
        logActionsEditKey,
        logActionsEditLabel,
        logPreviewOf;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerBackKey, logViewerDeleteLabel;
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
const double _labelVerticalPadding = 6;
const double _deleteGlyphSize = 15;
const double _headerDeleteGap = 8;

class NoteSheetView extends StatelessWidget {
  const NoteSheetView({
    super.key,
    required this.scene,
    required this.resolver,
    required this.expanded,
    required this.onExpandedChanged,
    this.onToggleTask,
  });

  final LogViewerScene scene;
  final MediaResolver resolver;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<int>? onToggleTask;

  @override
  Widget build(BuildContext context) {
    return ViewerKeys(
      onLeft: scene.onEarlier,
      onRight: scene.onLater,
      onEscape: scene.onBack,
      child: PhoneSheet(
        color: context.colors.composerPaper,
        expanded: expanded,
        onExpandedChanged: onExpandedChanged,
        header: _header(context),
        aboveFooter: scene.count > 1 ? _footer(context) : null,
        actions: _actions(),
        child: Padding(
          padding: _bodyPadding,
          child: NoteReadingBody(
            entry: scene.entry,
            resolver: resolver,
            dayTitle: scene.dayTitle,
            onToggleTask: onToggleTask,
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
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
        Flexible(
          child: _EditButton(
            key: logActionsEditKey,
            label: logActionsEditLabel,
            onPressed: onEdit,
          ),
        ),
    ];
  }

  Widget _delete(BuildContext context) {
    const StickerButtonVariant variant = StickerButtonVariant.danger;
    return StickerButton(
      key: logActionsDeleteKey,
      label: logViewerDeleteLabel,
      onPressed: scene.onDelete,
      variant: variant,
      padTapTarget: true,
      icon: IconStickerGlyphIcon(
        glyph: IconStickerGlyph.trash,
        color: variant.inkOn(StickerGround.page, context.colors),
        size: _deleteGlyphSize,
      ),
    );
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      scene.dayTitle,
                      style: textStyles.stampAccent.copyWith(
                        color: colors.accentInk,
                      ),
                    ),
                    Text(
                      logPreviewOf(scene.entry).heading,
                      style: textStyles.headlineSerif.copyWith(
                        fontSize: _titleSize,
                        height: _titleLineHeight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _headerDeleteGap),
              _delete(context),
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
    return Pressable(
      label: label,
      onPressed: onPressed,
      borderRadius: _buttonRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => HoverFill(
        hovered: hovered,
        borderRadius: _buttonRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: _buttonHeight),
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
          child: _ButtonLabel(
            glyph: ChevronGlyph(
              pointsBack: true,
              color: colors.ink,
              size: _backGlyphSize,
            ),
            label: label,
            color: colors.ink,
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesShadows shadows = context.shadows;
    return Pressable(
      label: label,
      onPressed: onPressed,
      borderRadius: _buttonRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => HoverFill(
        hovered: hovered,
        surface: FocusRingSurface.dark,
        borderRadius: _buttonRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: _buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: _backHorizontalPadding,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.coral,
            border: shadows.outline,
            borderRadius: _buttonRadius,
            boxShadow: shadows.emphasis,
          ),
          child: _ButtonLabel(
            glyph: const IconStickerGlyphIcon(
              glyph: IconStickerGlyph.edit,
              color: Palette.onAccent,
              size: _actionGlyphSize,
            ),
            label: label,
            color: Palette.onAccent,
          ),
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.glyph,
    required this.label,
    required this.color,
  });

  final Widget glyph;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        glyph,
        const SizedBox(width: _backGlyphGap),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _labelVerticalPadding,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: context.textStyles.captureLabelSans.copyWith(
                fontSize: _labelSize,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
