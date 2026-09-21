import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

import '../model/photo_placement.dart';
import '../render/note_photo_plan.dart';
import 'photo_line_edits.dart';
import 'photo_placement_diagram.dart';

const double photoControlTarget = 48;
const double photoControlGroupGap = 8;
const double photoSheetWideWidth = 600;
const int photoInlineControlTargets = 11;
const double photoInlineControlsWidth =
    photoInlineControlTargets * photoControlTarget + 3 * photoControlGroupGap;

const String photoSizeLabel = 'Size';
const String photoSideLabel = 'Side';
const String photoMoveUpLabel = 'Move up';
const String photoMoveDownLabel = 'Move down';
const String photoReplaceLabel = 'Replace';
const String photoRemoveLabel = 'Remove';
const String photoCaptionLabel = 'Caption';
const String photoOptionsTitle = 'Photo';
const String photoOptionsMissingMessage = 'This photo is no longer in the note.';

const Key photoSizeControlKey = ValueKey<String>('photo-size');
const Key photoSideControlKey = ValueKey<String>('photo-side');
const Key photoMoveUpKey = ValueKey<String>('photo-move-up');
const Key photoMoveDownKey = ValueKey<String>('photo-move-down');
const Key photoReplaceKey = ValueKey<String>('photo-replace');
const Key photoRemoveKey = ValueKey<String>('photo-remove');
const Key photoCaptionKey = ValueKey<String>('photo-caption');
const Key photoOptionsSheetKey = ValueKey<String>('photo-options-sheet');

Key photoSizeKey(PhotoSize size) => ValueKey<String>('photo-size-${size.name}');

Key photoSideKey(PhotoSide side) => ValueKey<String>('photo-side-${side.name}');

const double _disabledOpacity = 0.4;
const double _glyphExtent = 20;
const double _glyphStroke = 1.8;
const double _glyphViewBox = 24;
const double _sheetGap = 14;
const double _sheetRowGap = 8;
const double _sheetThumbExtent = 56;
const double _sheetPanelMaxWidth = 440;
const double _sheetBorderWidth = 2;
const double _sheetPaddingTop = 14;
const double _sheetPaddingHorizontal = 16;
const double _sheetPaddingBottom = 22;
const double _sheetTitleSize = 18;
const double _grabHandleWidth = 38;
const double _grabHandleHeight = 4;
const double _grabHandleGap = 12;
const BorderRadius _controlRadius =
    BorderRadius.all(Radius.circular(Shapes.radiusControl));
const Color _barrierColor = Color(0x572A241D);
const Cubic _sheetCurve = Cubic(0.2, 0.8, 0.2, 1);

enum PhotoControlsLayout { inline, sheet }

@immutable
class PhotoControlActions {
  const PhotoControlActions({
    required this.onSide,
    required this.onSize,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onReplace,
    required this.onRemove,
    required this.onCaption,
  });

  final ValueChanged<PhotoSide> onSide;
  final ValueChanged<PhotoSize> onSize;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onReplace;
  final VoidCallback onRemove;
  final VoidCallback onCaption;

  PhotoControlActions closingFirst(VoidCallback close) {
    return PhotoControlActions(
      onSide: onSide,
      onSize: onSize,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onReplace: () {
        close();
        onReplace();
      },
      onRemove: () {
        close();
        onRemove();
      },
      onCaption: () {
        close();
        onCaption();
      },
    );
  }
}

class PhotoControls extends StatelessWidget {
  const PhotoControls({
    super.key,
    required this.plan,
    required this.actions,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.layout = PhotoControlsLayout.inline,
  });

  final PhotoPlan plan;
  final PhotoControlActions? actions;
  final bool canMoveUp;
  final bool canMoveDown;
  final PhotoControlsLayout layout;

  bool get _inline => layout == PhotoControlsLayout.inline;

  @override
  Widget build(BuildContext context) {
    final PhotoControlActions? actions = this.actions;
    final List<Widget> moves = <Widget>[
      _button(
        photoMoveUpKey,
        _PhotoGlyph.up,
        photoMoveUpLabel,
        canMoveUp ? actions?.onMoveUp : null,
      ),
      _button(
        photoMoveDownKey,
        _PhotoGlyph.down,
        photoMoveDownLabel,
        canMoveDown ? actions?.onMoveDown : null,
      ),
    ];
    final List<Widget> edits = <Widget>[
      _button(
        photoReplaceKey,
        _PhotoGlyph.replace,
        photoReplaceLabel,
        actions?.onReplace,
      ),
      _button(
        photoRemoveKey,
        _PhotoGlyph.remove,
        photoRemoveLabel,
        actions?.onRemove,
      ),
      _button(
        photoCaptionKey,
        _PhotoGlyph.caption,
        photoCaptionLabel,
        actions?.onCaption,
      ),
    ];
    if (_inline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _sizes(actions),
          if (plan.measureCanFloat) ...<Widget>[
            const SizedBox(width: photoControlGroupGap),
            _sides(actions),
          ],
          const SizedBox(width: photoControlGroupGap),
          ...moves,
          const SizedBox(width: photoControlGroupGap),
          ...edits,
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _sheetLabel(photoSizeLabel),
        _sizes(actions),
        if (plan.measureCanFloat) ...<Widget>[
          const SizedBox(height: _sheetRowGap),
          _sheetLabel(photoSideLabel),
          _sides(actions),
        ],
        const SizedBox(height: _sheetGap),
        _sheetRow(moves),
        const SizedBox(height: _sheetRowGap),
        _sheetRow(edits),
      ],
    );
  }

  Widget _sheetLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ExcludeSemantics(
        child: Text(label, style: TypographyTokens.captionSans),
      ),
    );
  }

  Widget _sheetRow(List<Widget> buttons) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < buttons.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: _sheetRowGap),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  Widget _sizes(PhotoControlActions? actions) {
    return _PhotoSegments<PhotoSize>(
      key: photoSizeControlKey,
      label: photoSizeLabel,
      values: PhotoSize.values,
      selected: actions == null ? null : plan.size,
      keyOf: photoSizeKey,
      labelOf: (PhotoSize size) => _inline ? size.shortLabel : size.label,
      semanticsOf: (PhotoSize size) => size.label,
      stretch: !_inline,
      onSelected: actions?.onSize,
    );
  }

  Widget _sides(PhotoControlActions? actions) {
    return _PhotoSegments<PhotoSide>(
      key: photoSideControlKey,
      label: photoSideLabel,
      values: PhotoSide.values,
      selected: actions == null ? null : plan.side,
      keyOf: photoSideKey,
      labelOf: (PhotoSide side) => side.label,
      semanticsOf: (PhotoSide side) => side.label,
      stretch: !_inline,
      onSelected: plan.sideApplies ? actions?.onSide : null,
    );
  }

  Widget _button(
    Key key,
    _PhotoGlyph glyph,
    String label,
    VoidCallback? onTap,
  ) {
    return _PhotoControlButton(
      key: key,
      glyph: glyph,
      label: label,
      showLabel: !_inline,
      onTap: onTap,
    );
  }
}

class _PhotoSegments<T> extends StatelessWidget {
  const _PhotoSegments({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.keyOf,
    required this.labelOf,
    required this.semanticsOf,
    required this.stretch,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T? selected;
  final Key Function(T value) keyOf;
  final String Function(T value) labelOf;
  final String Function(T value) semanticsOf;
  final bool stretch;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onSelected != null;
    return Semantics(
      container: true,
      label: label,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: const BoxDecoration(
            border: Shapes.outline,
            borderRadius: _controlRadius,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Palette.panelTop,
              borderRadius: _controlRadius,
            ),
            child: Row(
              mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
              children: <Widget>[
                for (final T value in values)
                  stretch
                      ? Expanded(child: _segment(value))
                      : _segment(value),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(T value) {
    final bool isSelected = value == selected;
    final ValueChanged<T>? select = onSelected;
    return Semantics(
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      enabled: select != null,
      label: semanticsOf(value),
      child: GestureDetector(
        key: keyOf(value),
        behavior: HitTestBehavior.opaque,
        onTap: select == null || isSelected ? null : () => select(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: photoControlTarget,
            minHeight: photoControlTarget,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isSelected ? Palette.cardBright : null,
              border: isSelected ? Shapes.outline : null,
              borderRadius: _controlRadius,
            ),
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  labelOf(value),
                  style: TypographyTokens.labelSans.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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

class _PhotoControlButton extends StatelessWidget {
  const _PhotoControlButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.showLabel,
    required this.onTap,
  });

  final _PhotoGlyph glyph;
  final String label;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Widget icon = SizedBox.square(
      dimension: _glyphExtent,
      child: CustomPaint(painter: glyph.painter(Palette.ink)),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : _disabledOpacity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: photoControlTarget,
              minHeight: photoControlTarget,
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Palette.cardBright,
                border: Shapes.outline,
                borderRadius: _controlRadius,
              ),
              child: ExcludeSemantics(
                child: showLabel
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          icon,
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              label,
                              style: TypographyTokens.labelSans,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    : Center(child: icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PhotoGlyph {
  up,
  down,
  replace,
  remove,
  caption;

  CustomPainter painter(Color color) {
    return switch (this) {
      _PhotoGlyph.remove =>
        IconStickerGlyphPainter(glyph: IconStickerGlyph.trash, color: color),
      _PhotoGlyph.caption =>
        IconStickerGlyphPainter(glyph: IconStickerGlyph.edit, color: color),
      _ => _PhotoGlyphPainter(glyph: this, color: color),
    };
  }
}

class _PhotoGlyphPainter extends CustomPainter {
  const _PhotoGlyphPainter({required this.glyph, required this.color});

  final _PhotoGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _glyphStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / _glyphViewBox);
    canvas.drawPath(_path(), stroke);
    canvas.restore();
  }

  Path _path() {
    return switch (glyph) {
      _PhotoGlyph.up => Path()
        ..moveTo(12, 19)
        ..lineTo(12, 5)
        ..moveTo(6, 11)
        ..lineTo(12, 5)
        ..lineTo(18, 11),
      _PhotoGlyph.down => Path()
        ..moveTo(12, 5)
        ..lineTo(12, 19)
        ..moveTo(6, 13)
        ..lineTo(12, 19)
        ..lineTo(18, 13),
      _ => Path()
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
  bool shouldRepaint(_PhotoGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

class PhotoSheetFrame extends StatelessWidget {
  const PhotoSheetFrame({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= photoSheetWideWidth;
          return wide ? _panel(constraints.maxWidth) : _sheet(context);
        },
      ),
    );
  }

  Widget _content({required bool handle}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (handle) ...<Widget>[
          const Center(
            child: SizedBox(
              width: _grabHandleWidth,
              height: _grabHandleHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.ink30,
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                ),
              ),
            ),
          ),
          const SizedBox(height: _grabHandleGap),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TypographyTokens.headlineSerif.copyWith(
              fontSize: _sheetTitleSize,
            ),
          ),
        ),
        const SizedBox(height: _sheetGap),
        child,
      ],
    );
  }

  Widget _panel(double available) {
    return Center(
      child: SizedBox(
        width: math.min(_sheetPanelMaxWidth, available),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Palette.cardWarm,
            border: Border.fromBorderSide(
              BorderSide(color: Palette.ink, width: _sheetBorderWidth),
            ),
            borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusXl)),
            boxShadow: Shadows.softLift,
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: _content(handle: false),
          ),
        ),
      ),
    );
  }

  Widget _sheet(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Palette.cardWarm,
            border: Border(
              top: BorderSide(color: Palette.ink, width: _sheetBorderWidth),
            ),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Shapes.radiusSheet),
            ),
            boxShadow: Shadows.pickerSheetLift,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _sheetPaddingHorizontal,
                _sheetPaddingTop,
                _sheetPaddingHorizontal,
                _sheetPaddingBottom,
              ),
              child: _content(handle: true),
            ),
          ),
        ),
      ),
    );
  }
}

Widget photoSheetTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.sizeOf(context).width >= photoSheetWideWidth) {
    final Animation<double> curved =
        CurvedAnimation(parent: animation, curve: Motion.entranceCurve);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
  return SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: _sheetCurve)),
    child: child,
  );
}

Future<T?> showPhotoSheet<T>(
  BuildContext context, {
  required String barrierLabel,
  required Widget Function(BuildContext dialogContext) builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: _barrierColor,
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(child: builder(dialogContext));
    },
    transitionBuilder: photoSheetTransition,
  );
}

Future<void> showPhotoOptionsSheet(
  BuildContext context, {
  required ValueListenable<TextEditingValue> value,
  required double measure,
  required PhotoControlActions actions,
  MediaResolver? resolver,
}) {
  return showPhotoSheet<void>(
    context,
    barrierLabel: 'Dismiss photo options',
    builder: (BuildContext dialogContext) => PhotoOptionsSheet(
      value: value,
      measure: measure,
      resolver: resolver,
      actions: actions.closingFirst(() => Navigator.of(dialogContext).pop()),
    ),
  );
}

class PhotoOptionsSheet extends StatelessWidget {
  const PhotoOptionsSheet({
    super.key,
    required this.value,
    required this.measure,
    required this.actions,
    this.resolver,
  });

  final ValueListenable<TextEditingValue> value;
  final double measure;
  final PhotoControlActions actions;
  final MediaResolver? resolver;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: value,
      builder: (BuildContext context, TextEditingValue current, Widget? _) {
        final NotePhotoLine? line = photoLineAtCaret(current);
        if (line == null) {
          return PhotoSheetFrame(
            key: photoOptionsSheetKey,
            title: photoOptionsTitle,
            child: const Text(
              photoOptionsMissingMessage,
              style: TypographyTokens.bodySans,
              textAlign: TextAlign.center,
            ),
          );
        }
        final int count = notePhotoLines(current.text).length;
        final PhotoPlan plan = photoPlanFor(
          line,
          measure: measure,
          em: NoteColumn.emOf(context),
          resolver: resolver,
        );
        return PhotoSheetFrame(
          key: photoOptionsSheetKey,
          title: '$photoOptionsTitle ${line.ordinal + 1} of $count',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _thumbnail(line),
                  const SizedBox(width: 12),
                  Expanded(child: PhotoPlacementDiagram(plan: plan)),
                ],
              ),
              const SizedBox(height: _sheetGap),
              PhotoControls(
                plan: plan,
                actions: actions,
                canMoveUp: canMovePhotoUp(current.text, line),
                canMoveDown: canMovePhotoDown(current.text, line),
                layout: PhotoControlsLayout.sheet,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _thumbnail(NotePhotoLine line) {
    final MediaResolver? resolver = this.resolver;
    if (resolver == null) {
      return const NeutralMediaPlaceholder(
        width: _sheetThumbExtent,
        height: _sheetThumbExtent,
        borderRadius: Shapes.buttonBorderRadius,
      );
    }
    return MediaImage(
      resolver: resolver,
      mediaId: line.reference,
      errorLabel: '',
      width: _sheetThumbExtent,
      height: _sheetThumbExtent,
      borderRadius: Shapes.buttonBorderRadius,
      border: Shapes.outline,
    );
  }
}

PhotoPlan photoPlanFor(
  NotePhotoLine line, {
  required double measure,
  required double em,
  MediaResolver? resolver,
}) {
  final PhotoPlacement placement = line.placement;
  final ResolvedMedia? media = resolver?.resolved(line.reference);
  return planFloat(
    measure: measure,
    em: em,
    side: placement.side,
    size: placement.size,
    aspect: photoAspectOf(media?.blob?.width, media?.blob?.height),
  );
}
