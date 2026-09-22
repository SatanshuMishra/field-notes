import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/notes/photos/photo_import.dart';

import 'composer_footer.dart';
import 'editor/editor.dart';

const Key composerCloseKey = ValueKey<String>('composer-close');

const double composerMeasureEm = 45;

const Key composerWritingSurfaceKey =
    ValueKey<String>('composer-writing-surface');

const String emptySaveGuardMessage = 'Write something first';


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
const double _surfaceHeightShare = 0.68;
const double _surfaceMinCap = 440;
const double _surfaceMaxCap = 860;
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
const double _chipVerticalPadding = 10;
const double _composerChromeHeight = 104;
const int _minimumWritingLines = 4;

class TextComposerSheet extends StatefulWidget {
  const TextComposerSheet({
    super.key,
    required this.onSave,
    required this.onCancel,
    this.controller,
    this.initialText = '',
    this.draftRestored = false,
    this.onDiscardDraft,
    this.errorMessage,
    this.isSaving = false,
    this.title = 'Write a note',
    this.metaText = '',
    this.hintText = 'Start writing…',
    this.saveLabel = 'Save',
    this.savingLabel = 'Saving…',
    this.onAddPhoto,
  });

  final ValueChanged<String> onSave;
  final VoidCallback onCancel;
  final TextEditingController? controller;
  final String initialText;
  final bool draftRestored;
  final VoidCallback? onDiscardDraft;
  final String? errorMessage;
  final bool isSaving;
  final String title;
  final String metaText;
  final String hintText;
  final String saveLabel;
  final String savingLabel;
  final PhotoImporter? onAddPhoto;

  @override
  State<TextComposerSheet> createState() => _TextComposerSheetState();
}

class _TextComposerSheetState extends State<TextComposerSheet> {
  late final MarkdownStyleController _controller;
  late final bool _ownsController;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  late final UndoHistoryController _undoController;

  @override
  void initState() {
    super.initState();
    final TextEditingController? external = widget.controller;
    _ownsController = external is! MarkdownStyleController;
    _controller = switch (external) {
      null => MarkdownStyleController(text: widget.initialText),
      MarkdownStyleController() => external,
      _ => MarkdownStyleController.attachedTo(external),
    };
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _undoController = UndoHistoryController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    _scrollController.dispose();
    _undoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool roomy = _hasRoomForFormatBar(
          context,
          constraints.maxHeight,
        );
        final bool sidebar = resolveShellLayout(Theme.of(context).platform) ==
            ShellLayout.sidebar;
        final Widget formatBar = _formatBar();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _header(
              middle: roomy ? _titleBlock() : formatBar,
              below: roomy && sidebar ? formatBar : null,
            ),
            const DashedDivider(
              thickness: _headerRuleThickness,
              color: Palette.ink25,
            ),
            Flexible(
              child: _body(
                surfaceCap: _surfaceCap(constraints.maxHeight),
                formatBar: roomy && !sidebar ? formatBar : null,
                footer: _footer(showHints: roomy),
              ),
            ),
          ],
        );
      },
    );
  }

  double _surfaceCap(double available) {
    if (!available.isFinite) {
      return _surfaceMinCap;
    }
    return clampDouble(
      available * _surfaceHeightShare,
      _surfaceMinCap,
      _surfaceMaxCap,
    );
  }

  Widget? _footer({required bool showHints}) {
    final PhotoImporter? importer = widget.onAddPhoto;
    if (importer == null) {
      return null;
    }
    return ComposerFooter(
      controller: _controller,
      onAddPhoto: importer,
      editorFocusNode: _focusNode,
      showHints: showHints,
    );
  }

  bool _hasRoomForFormatBar(BuildContext context, double available) {
    if (!available.isFinite) {
      return true;
    }
    final double line =
        NoteColumn.emOf(context) * TypographyTokens.noteBody.height!;
    return available >=
        _composerChromeHeight +
            _footerHeight +
            formatBarHeight +
            _minimumWritingLines * line;
  }

  double get _footerHeight =>
      widget.onAddPhoto == null ? 0 : composerFooterHeight;

  Widget _formatBar() {
    return FormatBar(controller: _controller, undoController: _undoController);
  }

  Widget _header({required Widget middle, Widget? below}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _headerHorizontalPadding,
        vertical: _headerVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              _closeButton(),
              Expanded(child: middle),
              _saveButton(),
            ],
          ),
          ?below,
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
    showTransientToast(context, emptySaveGuardMessage);
  }

  Widget _body({
    required double surfaceCap,
    Widget? formatBar,
    Widget? footer,
  }) {
    final String? errorMessage = widget.errorMessage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.draftRestored)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _bodyHorizontalPadding,
              vertical: _chipVerticalPadding,
            ),
            child: DraftRestoredChip(onDiscard: widget.onDiscardDraft),
          ),
        Flexible(child: _writingSurface(surfaceCap)),
        ?formatBar,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _bodyHorizontalPadding,
            ),
            child: footer,
          ),
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _writingSurface(double cap) {
    return ConstrainedBox(
      key: composerWritingSurfaceKey,
      constraints: BoxConstraints(maxHeight: cap),
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
            child: NoteColumn(maxEm: composerMeasureEm, child: _page()),
          ),
        );
      },
    );
  }

  Widget _page() {
    return noteEditorFor(
      NoteEditorConfig(
        controller: _controller,
        focusNode: _focusNode,
        undoController: _undoController,
        scrollController: _scrollController,
        hintText: widget.hintText,
      ),
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
