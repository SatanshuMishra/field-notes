import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/notes/photos/photo_import.dart';
import 'package:field_notes/features/notes/photos/photo_line_edits.dart';

const Key composerAddPhotoKey = ValueKey<String>('composer-add-photo');

const Key composerHintsKey = ValueKey<String>('composer-hints');

const String composerAddPhotoLabel = 'Add memory';

const String composerAddPhotoHint = 'Adds a photo to this note';

const String composerAddingLabel = 'Adding…';

const String composerMarkdownHints =
    '**bold**  *italic*  # heading  - list  > quote';

const double composerFooterHeight = 44;

const double composerFooterHintsMinWidth = 360;

const double _addHorizontalPadding = 12;
const double _addVerticalPadding = 8;
const double _plusExtent = 14;
const double _plusStroke = 2;
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
  });

  final TextEditingController controller;
  final PhotoImporter onAddPhoto;
  final FocusNode? editorFocusNode;
  final bool showHints;

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
      final List<String> picked = await widget.onAddPhoto();
      if (mounted && picked.isNotEmpty) {
        _insert(picked);
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

  void _insert(List<String> references) {
    final TextEditingValue current = widget.controller.value;
    final TextEditingValue next = insertPhotoLinesAtCaret(current, references);
    if (next != current) {
      widget.controller.value = next;
    }
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
              height: composerFooterHeight,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.cardBright,
                    border: _addFocused ? _focusBorder : Shapes.outline,
                    borderRadius: Shapes.buttonBorderRadius,
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
                            dimension: _plusExtent,
                            child: CustomPaint(painter: _PlusPainter()),
                          ),
                          const SizedBox(width: _plusGap),
                          Text(
                            enabled
                                ? composerAddPhotoLabel
                                : composerAddingLabel,
                            style: TypographyTokens.captureLabelSans
                                .copyWith(color: Palette.ink),
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
      child: Text(
        composerMarkdownHints,
        key: composerHintsKey,
        textAlign: TextAlign.end,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypographyTokens.caption10Sans,
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  const _PlusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = Palette.ink
      ..strokeWidth = _plusStroke
      ..strokeCap = StrokeCap.round;
    final double middleX = size.width / 2;
    final double middleY = size.height / 2;
    canvas.drawLine(Offset(middleX, 0), Offset(middleX, size.height), stroke);
    canvas.drawLine(Offset(0, middleY), Offset(size.width, middleY), stroke);
  }

  @override
  bool shouldRepaint(_PlusPainter oldDelegate) => false;
}
