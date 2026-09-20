import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

const Key composerCloseKey = ValueKey<String>('composer-close');

const String emptySaveGuardMessage = 'Write something first';

const Duration composerToastLifetime = Duration(milliseconds: 1900);

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
const double _bodyBottomPadding = 14;
const double _surfaceMaxHeight = 440;
const double _surfaceRuleThickness = 1;
const double _pageTopPaddingShare = 0.10;
const double _pageTopPaddingMin = 8;
const double _pageTopPaddingMax = 44;
const double _pageHorizontalPadding = 38;
const double _pageBottomPaddingShare = 0.12;
const double _pageBottomPaddingMin = 12;
const double _pageBottomPaddingMax = 120;
const double _scrollbarThickness = 9;
const double _errorGap = 8;

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
    this.hintText = 'Start writing…',
    this.saveLabel = 'Save',
    this.savingLabel = 'Saving…',
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

  @override
  State<TextComposerSheet> createState() => _TextComposerSheetState();
}

class _TextComposerSheetState extends State<TextComposerSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  String? _guardMessage;
  Timer? _guardTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _guardTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
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
        Flexible(child: _body()),
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
    final bool enabled = !widget.isSaving;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? _handleSaveTap : null,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
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
  }

  void _handleSaveTap() {
    final String text = _controller.text;
    if (text.trim().isEmpty) {
      _showGuard();
      return;
    }
    widget.onSave(text);
  }

  void _showGuard() {
    _guardTimer?.cancel();
    setState(() => _guardMessage = emptySaveGuardMessage);
    _guardTimer = Timer(composerToastLifetime, () {
      if (!mounted) {
        return;
      }
      setState(() => _guardMessage = null);
    });
  }

  Widget _body() {
    final String? errorMessage = widget.errorMessage;
    final String? guardMessage = _guardMessage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Flexible(child: _writingSurface()),
        Padding(
          padding: const EdgeInsets.only(
            left: _bodyHorizontalPadding,
            right: _bodyHorizontalPadding,
            bottom: _bodyBottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (errorMessage != null) ...<Widget>[
                const SizedBox(height: _errorGap),
                Text(
                  errorMessage,
                  style: TypographyTokens.captionSans
                      .copyWith(color: Palette.danger),
                ),
              ],
              if (guardMessage != null) ...<Widget>[
                const SizedBox(height: _errorGap),
                Toast(message: guardMessage),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _writingSurface() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _surfaceMaxHeight),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Palette.composerPaper),
        child: Column(
          children: <Widget>[
            const DashedDivider(
              thickness: _surfaceRuleThickness,
              color: Palette.ink20,
            ),
            Expanded(child: _editor()),
          ],
        ),
      ),
    );
  }

  Widget _editor() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return RawScrollbar(
          controller: _scrollController,
          thickness: _scrollbarThickness,
          thumbColor: Palette.ink22,
          radius: const Radius.circular(Shapes.radiusXs),
          child: Padding(
            padding: _pageMargins(constraints.maxHeight),
            child: NoteColumn(child: _page()),
          ),
        );
      },
    );
  }

  Widget _page() {
    return Stack(
      fit: StackFit.expand,
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
                style: TypographyTokens.noteBodyPlaceholder,
              );
            },
          ),
        ),
        EditableText(
          controller: _controller,
          focusNode: _focusNode,
          scrollController: _scrollController,
          style: TypographyTokens.noteBody,
          cursorColor: Palette.coral,
          backgroundCursorColor: Palette.muted,
          keyboardType: TextInputType.multiline,
          minLines: null,
          maxLines: null,
          expands: true,
        ),
      ],
    );
  }
}

EdgeInsets _pageMargins(double surfaceHeight) {
  return EdgeInsets.only(
    top: clampDouble(
      surfaceHeight * _pageTopPaddingShare,
      _pageTopPaddingMin,
      _pageTopPaddingMax,
    ),
    left: _pageHorizontalPadding,
    right: _pageHorizontalPadding,
    bottom: clampDouble(
      surfaceHeight * _pageBottomPaddingShare,
      _pageBottomPaddingMin,
      _pageBottomPaddingMax,
    ),
  );
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
