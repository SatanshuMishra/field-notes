import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/notes.dart';

const double photoToolbarGap = 10;
const double photoToolbarPadding = 5;
const double photoToolbarTarget = 28;
const double photoToolbarControlPadding = 7;
const double photoToolbarControlGap = 2;
const double photoToolbarGroupGap = 5;
const double _ruleWidth = 1 + 2 * photoToolbarGroupGap;
const double photoToolbarRuleHeight = 17;

const String photoToolbarCaptionLabel = 'Caption';
const String photoToolbarRemoveLabel = 'Remove';
const String photoToolbarMoveUpLabel = 'Move up';
const String photoToolbarMoveDownLabel = 'Move down';
const String photoToolbarReplaceLabel = 'Replace';
const String photoRemovedMessage = 'Photo removed';
const String photoRemovedUndoLabel = 'Undo';

const Key photoToolbarKey = ValueKey<String>('photo-toolbar');
const Key photoToolbarCaptionKey = ValueKey<String>('photo-toolbar-caption');
const Key photoToolbarRemoveKey = ValueKey<String>('photo-toolbar-remove');
const Key photoToolbarMoveUpKey = ValueKey<String>('photo-toolbar-move-up');
const Key photoToolbarMoveDownKey = ValueKey<String>('photo-toolbar-move-down');
const Key photoToolbarReplaceKey = ValueKey<String>('photo-toolbar-replace');

Key photoToolbarSizeKey(PhotoSize size) =>
    ValueKey<String>('photo-toolbar-size-${size.name}');

Key photoToolbarSideKey(PhotoSide side) =>
    ValueKey<String>('photo-toolbar-side-${side.name}');

String photoToolbarSizeLabel(PhotoSize size) => '${size.label} size';

double photoToolbarWidthFor({
  required TextScaler scaler,
  required bool placement,
  required bool moves,
}) {
  double width = 2 * photoToolbarPadding;
  for (final PhotoSize size in PhotoSize.values) {
    width += _controlWidth(size.shortLabel, scaler);
  }
  width += _ruleWidth;
  width += _controlWidth(photoToolbarCaptionLabel, scaler);
  width += photoToolbarTarget;
  if (placement) {
    width += _ruleWidth + 2 * photoToolbarTarget;
  }
  if (moves) {
    width += _ruleWidth + 3 * photoToolbarTarget;
  }
  return width;
}

double _controlWidth(String label, TextScaler scaler) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: label, style: TypographyTokens.toolbarSans),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return math.max(
    photoToolbarTarget,
    width + 2 * photoToolbarControlPadding,
  );
}

String photoToolbarSideLabel(PhotoSide side) => '${side.label} side';

const double _glyphExtent = 14;
const double _sideGlyphExtent = 18;
const int _sideGlyphLines = 3;
const double _disabledOpacity = 0.4;
const double _focusRingWidth = 2;
const BorderRadius _controlRadius =
    BorderRadius.all(Radius.circular(Shapes.radiusXs + 1));
const BorderRadius _barRadius =
    BorderRadius.all(Radius.circular(Shapes.radiusSm + 1));

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

  bool get sideApplies => line.placement.size != PhotoSize.full;

  void setSize(PhotoSize size) {
    _apply(setPhotoSize(controller.value, line, size));
  }

  void setSide(PhotoSide side) {
    if (!sideApplies) {
      return;
    }
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
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool moves = constraints.maxWidth >=
            photoToolbarWidthFor(
              scaler: scaler,
              placement: placementApplies,
              moves: true,
            );
        return Semantics(
          container: true,
          explicitChildNodes: true,
          child: DecoratedBox(
            key: photoToolbarKey,
            decoration: const BoxDecoration(
              color: Palette.toolbarInk,
              borderRadius: _barRadius,
              boxShadow: Shadows.toastLift,
            ),
            child: Padding(
              padding: const EdgeInsets.all(photoToolbarPadding),
              child: _PhotoToolbarBody(toolbar: this, moves: moves),
            ),
          ),
        );
      },
    );
  }
}

class _PhotoToolbarBody extends StatefulWidget {
  const _PhotoToolbarBody({required this.toolbar, required this.moves});

  final PhotoToolbar toolbar;
  final bool moves;

  @override
  State<_PhotoToolbarBody> createState() => _PhotoToolbarBodyState();
}

class _PhotoToolbarBodyState extends State<_PhotoToolbarBody> {
  PhotoToolbar get _toolbar => widget.toolbar;

  NotePhotoLine get _line => _toolbar.line;

  @override
  Widget build(BuildContext context) {
    final PhotoPlacement placement = _line.placement;
    final String text = _toolbar.controller.text;
    final bool moves = widget.moves;
    return Row(
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
              const _PhotoToolbarRule(),
              for (final PhotoSide side in PhotoSide.values)
                _PhotoToolbarControl(
                  controlKey: photoToolbarSideKey(side),
                  label: photoToolbarSideLabel(side),
                  selected: _toolbar.sideApplies && side == placement.side,
                  onTap: _toolbar.sideApplies
                      ? () => _toolbar.setSide(side)
                      : null,
                  child: PhotoSideGlyph(
                    side: side,
                    selected: _toolbar.sideApplies && side == placement.side,
                  ),
                ),
            ],
            if (moves) ...<Widget>[
              const _PhotoToolbarRule(),
              _PhotoToolbarControl(
                controlKey: photoToolbarMoveUpKey,
                label: photoToolbarMoveUpLabel,
                onTap: canMovePhotoUp(text, _line) ? _toolbar.moveUp : null,
                child: _glyph(_PhotoToolbarGlyph.up),
              ),
              _PhotoToolbarControl(
                controlKey: photoToolbarMoveDownKey,
                label: photoToolbarMoveDownLabel,
                onTap: canMovePhotoDown(text, _line) ? _toolbar.moveDown : null,
                child: _glyph(_PhotoToolbarGlyph.down),
              ),
              _PhotoToolbarControl(
                controlKey: photoToolbarReplaceKey,
                label: photoToolbarReplaceLabel,
                onTap: _toolbar.importer == null
                    ? null
                    : () => unawaited(_toolbar.replace()),
                child: _glyph(_PhotoToolbarGlyph.swap),
              ),
            ],
            const _PhotoToolbarRule(),
            _PhotoToolbarControl(
              controlKey: photoToolbarCaptionKey,
              label: photoToolbarCaptionLabel,
              onTap: _toolbar.onCaption,
              child: _segmentLabel(
                photoToolbarCaptionLabel,
                selected: false,
              ),
            ),
            _PhotoToolbarControl(
              controlKey: photoToolbarRemoveKey,
              label: photoToolbarRemoveLabel,
              onTap: () => _toolbar.remove(context),
              child: const IconStickerGlyphIcon(
                glyph: IconStickerGlyph.trash,
                color: Palette.toolbarLabel,
                size: _glyphExtent,
              ),
            ),
      ],
    );
  }

  Widget _glyph(_PhotoToolbarGlyph glyph) => SizedBox.square(
        dimension: _glyphExtent,
        child: CustomPaint(
          painter: _PhotoToolbarGlyphPainter(
            glyph: glyph,
            color: Palette.toolbarLabel,
          ),
        ),
      );

  Widget _segmentLabel(String text, {required bool selected}) {
    return Text(
      text,
      style: TypographyTokens.toolbarSans.copyWith(
        color: selected ? Palette.onAccent : Palette.toolbarLabel,
      ),
    );
  }
}

class _PhotoToolbarRule extends StatelessWidget {
  const _PhotoToolbarRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: photoToolbarGroupGap),
      child: SizedBox(
        width: 1,
        height: photoToolbarRuleHeight,
        child: ColoredBox(color: Palette.toolbarRule),
      ),
    );
  }
}

enum _PhotoToolbarGlyph { up, down, swap }

class _PhotoToolbarGlyphPainter extends CustomPainter {
  const _PhotoToolbarGlyphPainter({required this.glyph, required this.color});

  final _PhotoToolbarGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / 24);
    canvas.drawPath(_path(), stroke);
    canvas.restore();
  }

  Path _path() {
    return switch (glyph) {
      _PhotoToolbarGlyph.up => Path()
        ..moveTo(12, 19)
        ..lineTo(12, 5)
        ..moveTo(6, 11)
        ..lineTo(12, 5)
        ..lineTo(18, 11),
      _PhotoToolbarGlyph.down => Path()
        ..moveTo(12, 5)
        ..lineTo(12, 19)
        ..moveTo(6, 13)
        ..lineTo(12, 19)
        ..lineTo(18, 13),
      _PhotoToolbarGlyph.swap => Path()
        ..moveTo(4, 8)
        ..lineTo(19, 8)
        ..moveTo(15, 4)
        ..lineTo(19, 8)
        ..lineTo(15, 12)
        ..moveTo(20, 16)
        ..lineTo(5, 16)
        ..moveTo(9, 12)
        ..lineTo(5, 16)
        ..lineTo(9, 20),
    };
  }

  @override
  bool shouldRepaint(_PhotoToolbarGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

class _PhotoToolbarControl extends StatefulWidget {
  const _PhotoToolbarControl({
    required this.controlKey,
    required this.label,
    required this.child,
    required this.onTap,
    this.selected,
  });

  final Key controlKey;
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool? selected;

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
                            color: Palette.toolbarLabel,
                            width: _focusRingWidth,
                          ),
                        )
                      : null,
                  borderRadius: _controlRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: photoToolbarControlPadding,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
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
      ),
    );
  }
}

class PhotoSideGlyph extends StatelessWidget {
  const PhotoSideGlyph({
    super.key,
    required this.side,
    required this.selected,
  });

  final PhotoSide side;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _sideGlyphExtent,
      child: CustomPaint(
        painter: _PhotoSideGlyphPainter(
          side: side,
          color: selected ? Palette.onAccent : Palette.toastInk,
        ),
      ),
    );
  }
}

class _PhotoSideGlyphPainter extends CustomPainter {
  const _PhotoSideGlyphPainter({required this.side, required this.color});

  final PhotoSide side;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double block = size.width * 0.5;
    final double inset = size.height * 0.1;
    final bool left = side == PhotoSide.left;
    final Rect picture = Rect.fromLTWH(
      left ? 0 : size.width - block,
      inset,
      block,
      size.height - 2 * inset,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(picture, const Radius.circular(2)),
      Paint()..color = color,
    );
    final Paint rule = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.height * 0.11;
    final double gap = (size.height - rule.strokeWidth) / (_sideGlyphLines - 1);
    final double from = left ? block + size.width * 0.14 : 0;
    final double to = left ? size.width : size.width - block - size.width * 0.14;
    for (int i = 0; i < _sideGlyphLines; i++) {
      final double y = rule.strokeWidth / 2 + gap * i;
      canvas.drawLine(Offset(from, y), Offset(to, y), rule);
    }
  }

  @override
  bool shouldRepaint(_PhotoSideGlyphPainter oldDelegate) =>
      oldDelegate.side != side || oldDelegate.color != color;
}
