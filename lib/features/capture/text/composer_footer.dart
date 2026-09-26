import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show parseNoteTree;
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/note_engine/capabilities.dart'
    show tablesEnabled;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart'
    show PhotoEdit, photoInsertion, photoTargetAt;
import 'package:field_notes/features/notes/photos/photo_import.dart';

import 'editor/format_bar.dart';

const Key composerAddPhotoKey = ValueKey<String>('composer-add-photo');

const Key composerHintsKey = ValueKey<String>('composer-hints');

const String composerAddPhotoLabel = 'Add memory';

const String composerAddPhotoHint = 'Adds a photo to this note';

const String composerAddingLabel = 'Adding…';

const List<(String, String)> composerMarkdownHints = <(String, String)>[
  ('# ', 'title'),
  ('- ', 'list'),
  ('1. ', 'steps'),
  ('> ', 'quote'),
];

const double composerFooterHeight = 48;

const double composerFooterHintsMinWidth = 360;

const double composerFooterBlur = 18;

const double composerFooterVeilOpacity = 0.72;

class ComposerFooterVeil extends StatelessWidget {
  const ComposerFooterVeil({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: composerFooterBlur,
          sigmaY: composerFooterBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.composerPaper
                .withValues(alpha: composerFooterVeilOpacity),
          ),
          child: child,
        ),
      ),
    );
  }
}

const double _addHorizontalPadding = 12;
const double _addVerticalPadding = 8;
const double _cameraExtent = 16;
const double _cameraStroke = 2;
const double _plusGap = 7;
const double _hintsGap = 12;
const double _busyOpacity = 0.5;
const double _focusBorderWidth = 3;
const Border _focusBorder = Border.fromBorderSide(
  BorderSide(color: Palette.ink, width: _focusBorderWidth),
);

class ComposerFooter extends StatefulWidget {
  const ComposerFooter({
    super.key,
    required this.controller,
    required this.onAddPhoto,
    this.editorFocusNode,
    this.showHints = true,
    this.compact = false,
  });

  final TextEditingController controller;
  final PhotoImporter onAddPhoto;
  final FocusNode? editorFocusNode;
  final bool showHints;
  final bool compact;

  @override
  State<ComposerFooter> createState() => _ComposerFooterState();
}

class _ComposerFooterState extends State<ComposerFooter> {
  final FocusNode _addFocus = FocusNode(debugLabel: composerAddPhotoLabel);
  bool _busy = false;
  bool _addFocused = false;

  @override
  void dispose() {
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final TextEditingController controller = widget.controller;
      if (controller is NoteEditorController) {
        await controller.addPhotos(widget.onAddPhoto);
      } else {
        final List<String> picked = await widget.onAddPhoto();
        if (mounted && picked.isNotEmpty) {
          _insert(controller, picked);
        }
      }
    } on PhotoPickException catch (error) {
      _report(error.message);
    } catch (error, stackTrace) {
      debugPrint('Adding a photo to a note failed: $error\n$stackTrace');
      _report(composerPhotoFailedMessage);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.editorFocusNode?.requestFocus();
      }
    }
  }

  void _insert(TextEditingController controller, List<String> references) {
    final String text = controller.text;
    final int caret = controller.selection.isValid
        ? controller.selection.end
        : text.length;
    final PhotoEdit edit = photoInsertion(
      text,
      photoTargetAt(text, parseNoteTree(text, tables: tablesEnabled), caret),
      references,
    );
    controller.value = TextEditingValue(
      text: edit.changes.apply(text),
      selection: TextSelection(
        baseOffset: edit.selection.anchor,
        extentOffset: edit.selection.head,
      ),
    );
  }

  void _report(String message) {
    if (mounted) {
      showTransientToast(context, message, glyph: IconStickerGlyph.close);
    }
  }

  void _onAddFocusHighlight(bool focused) {
    if (mounted && focused != _addFocused) {
      setState(() => _addFocused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return TextFieldTapRegion(
        child: SizedBox(height: formatBarHeight, child: _addButton()),
      );
    }
    return TextFieldTapRegion(
      child: SizedBox(
        height: composerFooterHeight,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool hints = widget.showHints &&
                constraints.maxWidth >= composerFooterHintsMinWidth;
            return Row(
              children: <Widget>[
                _addButton(),
                if (hints) ...<Widget>[
                  const SizedBox(width: _hintsGap),
                  Expanded(child: _hints()),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _addButton() {
    final bool enabled = !_busy;
    return FocusableActionDetector(
      focusNode: _addFocus,
      enabled: enabled,
      onShowFocusHighlight: _onAddFocusHighlight,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            unawaited(_add());
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: composerAddPhotoLabel,
        hint: composerAddPhotoHint,
        child: GestureDetector(
          key: composerAddPhotoKey,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => unawaited(_add()) : null,
          child: ExcludeSemantics(
            child: SizedBox(
              height:
                  widget.compact ? formatBarHeight : composerFooterHeight,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.coral,
                    border: _addFocused ? _focusBorder : Shapes.outline,
                    borderRadius: Shapes.buttonBorderRadius,
                    boxShadow: Shadows.control,
                  ),
                  child: Opacity(
                    opacity: enabled ? 1 : _busyOpacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _addHorizontalPadding,
                        vertical: _addVerticalPadding,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox.square(
                            dimension: _cameraExtent,
                            child: CustomPaint(painter: _CameraPainter()),
                          ),
                          const SizedBox(width: _plusGap),
                          Text(
                            enabled
                                ? composerAddPhotoLabel
                                : composerAddingLabel,
                            style: TypographyTokens.captureLabelSans
                                .copyWith(color: Palette.onAccent),
                          ),
                        ],
                      ),
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

  Widget _hints() {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            for (final (String marker, String word) in composerMarkdownHints)
              ...<InlineSpan>[
                TextSpan(
                  text: marker,
                  style: TypographyTokens.caption10Sans.copyWith(
                    color: Palette.ink40,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: '$word   '),
              ],
          ],
        ),
        key: composerHintsKey,
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypographyTokens.caption10Sans,
      ),
    );
  }
}

class _CameraPainter extends CustomPainter {
  const _CameraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _cameraStroke
      ..strokeJoin = StrokeJoin.round;
    final Rect body = Rect.fromLTWH(
      _cameraStroke / 2,
      size.height * 0.22,
      size.width - _cameraStroke,
      size.height * 0.62,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2)),
      stroke,
    );
    canvas.drawCircle(
      Offset(size.width / 2, body.center.dy),
      size.height * 0.18,
      stroke,
    );
  }

  @override
  bool shouldRepaint(_CameraPainter oldDelegate) => false;
}

