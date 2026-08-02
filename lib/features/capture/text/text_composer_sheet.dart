import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

const Key composerCloseKey = ValueKey<String>('composer-close');

const double _headerVerticalPadding = 14;
const double _headerHorizontalPadding = 18;
const double _headerRuleThickness = 1.5;
const double _headerLineHeight = 1.1;
const double _closeGlyphSize = 22;
const double _closeStrokeWidth = 2.2;
const double _closeViewBox = 24;
const double _saveVerticalPadding = 7;
const double _saveHorizontalPadding = 15;
const double _disabledOpacity = 0.5;
const double _bodyHorizontalPadding = 18;
const double _bodyVerticalPadding = 14;

class TextComposerSheet extends StatefulWidget {
  const TextComposerSheet({
    super.key,
    required this.onSave,
    required this.onCancel,
    this.initialText = '',
    this.errorMessage,
    this.isSaving = false,
    this.title = 'Write a note',
    this.metaText = '',
    this.hintText = 'What happened today?',
    this.saveLabel = 'Save note',
    this.savingLabel = 'Saving...',
    this.cancelLabel = 'Cancel',
  });

  final ValueChanged<String> onSave;
  final VoidCallback onCancel;
  final String initialText;
  final String? errorMessage;
  final bool isSaving;
  final String title;
  final String metaText;
  final String hintText;
  final String saveLabel;
  final String savingLabel;
  final String cancelLabel;

  @override
  State<TextComposerSheet> createState() => _TextComposerSheetState();
}

class _TextComposerSheetState extends State<TextComposerSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _header(),
        const DashedDivider(
          thickness: _headerRuleThickness,
          color: Palette.ink25,
        ),
        _body(),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _headerHorizontalPadding,
        vertical: _headerVerticalPadding,
      ),
      child: Row(
        children: <Widget>[
          _closeButton(),
          Expanded(child: _titleBlock()),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _closeButton() {
    return GestureDetector(
      key: composerCloseKey,
      behavior: HitTestBehavior.opaque,
      onTap: widget.isSaving ? null : widget.onCancel,
      child: const SizedBox.square(
        dimension: _closeGlyphSize,
        child: CustomPaint(painter: _CloseGlyphPainter()),
      ),
    );
  }

  Widget _titleBlock() {
    final String metaText = widget.metaText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TypographyTokens.composerTitleAccent
              .copyWith(height: _headerLineHeight),
        ),
        if (metaText.isNotEmpty)
          Text(
            metaText,
            textAlign: TextAlign.center,
            style: TypographyTokens.caption9Sans
                .copyWith(height: _headerLineHeight),
          ),
      ],
    );
  }

  Widget _saveButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (
        BuildContext context,
        TextEditingValue value,
        Widget? child,
      ) {
        final bool canSave = value.text.trim().isNotEmpty && !widget.isSaving;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canSave ? () => widget.onSave(value.text) : null,
          child: Opacity(
            opacity: canSave ? 1 : _disabledOpacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.coral,
                border: Shapes.outline,
                borderRadius: BorderRadius.circular(Shapes.radiusPill),
                boxShadow: Shadows.control,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _saveHorizontalPadding,
                  vertical: _saveVerticalPadding,
                ),
                child: Text(
                  widget.isSaving ? widget.savingLabel : widget.saveLabel,
                  style: TypographyTokens.captureLabelSans
                      .copyWith(color: Palette.onAccent),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body() {
    final String? errorMessage = widget.errorMessage;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _bodyHorizontalPadding,
        vertical: _bodyVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _editor(),
          if (errorMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style:
                  TypographyTokens.captionSans.copyWith(color: Palette.danger),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              StickerButton(
                label: widget.cancelLabel,
                variant: StickerButtonVariant.secondary,
                onPressed: widget.isSaving ? null : widget.onCancel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editor() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.cardWarm,
        border: Shapes.outline,
        borderRadius: Shapes.buttonBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Stack(
          children: <Widget>[
            IgnorePointer(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (
                  BuildContext context,
                  TextEditingValue value,
                  Widget? child,
                ) {
                  if (value.text.isNotEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    widget.hintText,
                    style: TypographyTokens.bodySans
                        .copyWith(color: Palette.placeholder),
                  );
                },
              ),
            ),
            EditableText(
              controller: _controller,
              focusNode: _focusNode,
              style: TypographyTokens.bodySerif,
              cursorColor: Palette.coral,
              backgroundCursorColor: Palette.muted,
              keyboardType: TextInputType.multiline,
              minLines: 4,
              maxLines: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _closeStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / _closeViewBox);
    canvas.drawLine(const Offset(6, 6), const Offset(18, 18), stroke);
    canvas.drawLine(const Offset(18, 6), const Offset(6, 18), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloseGlyphPainter oldDelegate) => false;
}
