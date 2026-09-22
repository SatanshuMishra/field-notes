import 'dart:async';

import 'package:flutter/material.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/notes.dart';

const double photoToolbarGap = 8;
const double photoToolbarPadding = 8;
const double photoToolbarTarget = 48;
const double photoToolbarGroupGap = 8;
const double photoToolbarRowGap = 8;

const String photoToolbarCaptionLabel = 'Caption';
const String photoToolbarRemoveLabel = 'Remove';
const String photoToolbarMoreLabel = 'More';
const String photoToolbarMoveUpLabel = 'Move up';
const String photoToolbarMoveDownLabel = 'Move down';
const String photoToolbarReplaceLabel = 'Replace';
const String photoRemovedMessage = 'Photo removed';
const String photoRemovedUndoLabel = 'Undo';

const Key photoToolbarKey = ValueKey<String>('photo-toolbar');
const Key photoToolbarCaptionKey = ValueKey<String>('photo-toolbar-caption');
const Key photoToolbarRemoveKey = ValueKey<String>('photo-toolbar-remove');
const Key photoToolbarMoreKey = ValueKey<String>('photo-toolbar-more');
const Key photoToolbarMoveUpKey = ValueKey<String>('photo-toolbar-move-up');
const Key photoToolbarMoveDownKey = ValueKey<String>('photo-toolbar-move-down');
const Key photoToolbarReplaceKey = ValueKey<String>('photo-toolbar-replace');
const Key photoToolbarDiagramKey = ValueKey<String>('photo-toolbar-diagram');

Key photoToolbarSizeKey(PhotoSize size) =>
    ValueKey<String>('photo-toolbar-size-${size.name}');

Key photoToolbarSideKey(PhotoSide side) =>
    ValueKey<String>('photo-toolbar-side-${side.name}');

String photoToolbarSizeLabel(PhotoSize size) => '${size.label} size';

String photoToolbarSideLabel(PhotoSide side) => '${side.label} side';

const double _glyphExtent = 20;
const double _moreExtent = 18;
const double _disabledOpacity = 0.4;
const double _focusRingWidth = 2;
const double _diagramInset = 6;
const BorderRadius _controlRadius =
    BorderRadius.all(Radius.circular(Shapes.radiusSm));
const BorderRadius _barRadius =
    BorderRadius.all(Radius.circular(Shapes.radiusMd));

typedef PhotoToolbarImporter = Future<List<String>> Function();

class PhotoToolbar extends StatelessWidget {
  const PhotoToolbar({
    super.key,
    required this.controller,
    required this.line,
    required this.measure,
    required this.em,
    required this.onCaption,
    required this.onRemove,
    this.media,
    this.importer,
  });

  final TextEditingController controller;
  final NotePhotoLine line;
  final double measure;
  final double em;
  final VoidCallback onCaption;
  final VoidCallback onRemove;
  final ResolvedMedia? media;
  final PhotoToolbarImporter? importer;

  bool get placementApplies => canFloatAt(measure: measure, em: em);

  PhotoPlan get readerPlan => planFloat(
        measure: NoteColumn.measureEm * em,
        em: em,
        side: line.placement.side,
        size: line.placement.size,
        aspect: photoAspectOf(media?.blob?.width, media?.blob?.height),
        nextIsParagraph: line.wrapsParagraph && line.placement.isValid,
      );

  void setSize(PhotoSize size) {
    _apply(setPhotoSize(controller.value, line, size));
  }

  void setSide(PhotoSide side) {
    _apply(setPhotoSide(controller.value, line, side));
  }

  void remove(BuildContext context) {
    final PhotoLineRemoval removal = removePhotoLine(controller.value, line);
    final RemovedPhotoLine removed = removal.removed;
    controller.value = removal.value;
    onRemove();
    showTransientToast(
      context,
      photoRemovedMessage,
      glyph: IconStickerGlyph.trash,
      action: ToastAction(
        label: photoRemovedUndoLabel,
        onPressed: () => _apply(restorePhotoLine(controller.value, removed)),
      ),
    );
  }

  void moveUp() => _apply(movePhotoUp(controller.value, line));

  void moveDown() => _apply(movePhotoDown(controller.value, line));

  Future<void> replace() async {
    final PhotoToolbarImporter? pick = importer;
    if (pick == null) {
      return;
    }
    final List<String> picked;
    try {
      picked = await pick();
    } catch (error, stackTrace) {
      debugPrint('Replacing a photo in a note failed: $error\n$stackTrace');
      return;
    }
    if (picked.isEmpty) {
      return;
    }
    final List<NotePhotoLine> lines = notePhotoLines(controller.text);
    if (line.ordinal >= lines.length) {
      return;
    }
    _apply(
      replacePhotoReference(
        controller.value,
        lines[line.ordinal],
        picked.first,
      ),
    );
  }

  void _apply(TextEditingValue next) {
    if (next != controller.value) {
      controller.value = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        key: photoToolbarKey,
        decoration: const BoxDecoration(
          color: Palette.ink,
          borderRadius: _barRadius,
          boxShadow: Shadows.toastLift,
        ),
        child: Padding(
          padding: const EdgeInsets.all(photoToolbarPadding),
          child: IntrinsicWidth(child: _PhotoToolbarBody(toolbar: this)),
        ),
      ),
    );
  }
}

class _PhotoToolbarBody extends StatefulWidget {
  const _PhotoToolbarBody({required this.toolbar});

  final PhotoToolbar toolbar;

  @override
  State<_PhotoToolbarBody> createState() => _PhotoToolbarBodyState();
}

class _PhotoToolbarBodyState extends State<_PhotoToolbarBody> {
  bool _moreOpen = false;

  PhotoToolbar get _toolbar => widget.toolbar;

  NotePhotoLine get _line => _toolbar.line;

  @override
  void didUpdateWidget(_PhotoToolbarBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_moreOpen && oldWidget.toolbar.line.ordinal != _line.ordinal) {
      _moreOpen = false;
    }
  }

  void _toggleMore() => setState(() => _moreOpen = !_moreOpen);

  @override
  Widget build(BuildContext context) {
    final PhotoPlacement placement = _line.placement;
    final String text = _toolbar.controller.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final PhotoSize size in PhotoSize.values)
              _PhotoToolbarControl(
                controlKey: photoToolbarSizeKey(size),
                label: photoToolbarSizeLabel(size),
                selected: size == placement.size,
                onTap: () => _toolbar.setSize(size),
                child: _segmentLabel(
                  size.shortLabel,
                  selected: size == placement.size,
                ),
              ),
            if (_toolbar.placementApplies) ...<Widget>[
              const SizedBox(width: photoToolbarGroupGap),
              for (final PhotoSide side in PhotoSide.values)
                _PhotoToolbarControl(
                  controlKey: photoToolbarSideKey(side),
                  label: photoToolbarSideLabel(side),
                  selected: side == placement.side,
                  onTap: () => _toolbar.setSide(side),
                  child: _segmentLabel(
                    side.label,
                    selected: side == placement.side,
                  ),
                ),
            ],
            const SizedBox(width: photoToolbarGroupGap),
            _PhotoToolbarControl(
              controlKey: photoToolbarCaptionKey,
              label: photoToolbarCaptionLabel,
              onTap: _toolbar.onCaption,
              child: const IconStickerGlyphIcon(
                glyph: IconStickerGlyph.edit,
                color: Palette.toastInk,
                size: _glyphExtent,
              ),
            ),
            _PhotoToolbarControl(
              controlKey: photoToolbarRemoveKey,
              label: photoToolbarRemoveLabel,
              onTap: () => _toolbar.remove(context),
              child: const IconStickerGlyphIcon(
                glyph: IconStickerGlyph.trash,
                color: Palette.toastInk,
                size: _glyphExtent,
              ),
            ),
            _PhotoToolbarControl(
              controlKey: photoToolbarMoreKey,
              label: photoToolbarMoreLabel,
              expanded: _moreOpen,
              onTap: _toggleMore,
              child: Text(
                '…',
                style: TypographyTokens.labelSans.copyWith(
                  color: Palette.toastInk,
                  fontSize: _moreExtent,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        if (_moreOpen) ...<Widget>[
          const SizedBox(height: photoToolbarRowGap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PhotoToolbarControl(
                controlKey: photoToolbarMoveUpKey,
                label: photoToolbarMoveUpLabel,
                onTap: canMovePhotoUp(text, _line) ? _toolbar.moveUp : null,
                child: _menuLabel(photoToolbarMoveUpLabel),
              ),
              _PhotoToolbarControl(
                controlKey: photoToolbarMoveDownKey,
                label: photoToolbarMoveDownLabel,
                onTap: canMovePhotoDown(text, _line) ? _toolbar.moveDown : null,
                child: _menuLabel(photoToolbarMoveDownLabel),
              ),
              _PhotoToolbarControl(
                controlKey: photoToolbarReplaceKey,
                label: photoToolbarReplaceLabel,
                onTap: _toolbar.importer == null
                    ? null
                    : () => unawaited(_toolbar.replace()),
                child: _menuLabel(photoToolbarReplaceLabel),
              ),
            ],
          ),
        ],
        const SizedBox(height: photoToolbarRowGap),
        DecoratedBox(
          key: photoToolbarDiagramKey,
          decoration: const BoxDecoration(
            color: Palette.panelTop,
            borderRadius: _controlRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(_diagramInset),
            child: SizedBox(
              height: photoDiagramHeight,
              child: PhotoPlacementDiagram(plan: _toolbar.readerPlan),
            ),
          ),
        ),
      ],
    );
  }

  Widget _segmentLabel(String text, {required bool selected}) {
    return Text(
      text,
      style: TypographyTokens.labelSans.copyWith(
        color: selected ? Palette.onAccent : Palette.toastInk,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }

  Widget _menuLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        text,
        style: TypographyTokens.labelSans.copyWith(color: Palette.toastInk),
      ),
    );
  }
}

class _PhotoToolbarControl extends StatefulWidget {
  const _PhotoToolbarControl({
    required this.controlKey,
    required this.label,
    required this.child,
    required this.onTap,
    this.selected,
    this.expanded,
  });

  final Key controlKey;
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool? selected;
  final bool? expanded;

  @override
  State<_PhotoToolbarControl> createState() => _PhotoToolbarControlState();
}

class _PhotoToolbarControlState extends State<_PhotoToolbarControl> {
  bool _focused = false;

  void _onFocusHighlight(bool focused) {
    if (mounted && focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = widget.onTap;
    final bool enabled = onTap != null;
    final bool marked = widget.selected ?? false;
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: _onFocusHighlight,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            onTap?.call();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        expanded: widget.expanded,
        inMutuallyExclusiveGroup: widget.selected != null,
        label: widget.label,
        child: GestureDetector(
          key: widget.controlKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: photoToolbarTarget,
                minHeight: photoToolbarTarget,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: marked ? Palette.coral : null,
                  border: _focused
                      ? const Border.fromBorderSide(
                          BorderSide(
                            color: Palette.toastInk,
                            width: _focusRingWidth,
                          ),
                        )
                      : null,
                  borderRadius: _controlRadius,
                ),
                child: Center(
                  child: Opacity(
                    opacity: enabled ? 1 : _disabledOpacity,
                    child: widget.child,
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
