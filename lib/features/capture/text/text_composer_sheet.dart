import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/capture_service.dart'
    show CaptureMedia;
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;
import 'package:field_notes/features/notes/photos/photo_import.dart';

import 'composer_footer.dart';
import 'editor/format_bar.dart';
import 'editor/note_editor.dart';

const Key composerCloseKey = ValueKey<String>('composer-close');

const double composerMeasureEm = 45;

const Key composerWritingSurfaceKey =
    ValueKey<String>('composer-writing-surface');

const String emptySaveGuardMessage = 'Write something first';

enum ComposerExit { cancel, back }


const double _headerVerticalPadding = 16;
const double _headerHorizontalPadding = 18;
const double _headerGap = 14;
const double _headerRuleThickness = 1.5;
const double _titleLineHeight = 1.05;
const double _exitPillHeight = 34;
const double _exitPillStartPadding = 8;
const double _exitPillEndPadding = 12;
const double _exitPillRadius = 10;
const double _exitGlyphSize = 15;
const double _exitGlyphGap = 4;
const double _exitStrokeWidth = 2.2;
const double _exitViewBox = 24;
const double _backChevronStrokeWidth = 2;
const double _backChevronArm = 5;
const double _saveVerticalPadding = 7;
const double _saveHorizontalPadding = 15;
const double _disabledOpacity = 0.5;
const double _bodyHorizontalPadding = 18;
const double _bodyBottomPadding = 14;
const double _surfaceRuleThickness = 1;
const double _pageTopPaddingShare = 0.10;
const double _pageTopPaddingMin = 8;
const double _pageTopPaddingMax = 44;
const double _pageHorizontalPadding = 38;
const double _pageEndGap = 12;
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
    this.kicker = '',
    this.exit = ComposerExit.cancel,
    this.hintText = 'Start writing…',
    this.saveLabel = 'Save',
    this.savingLabel = 'Saving…',
    this.onAddPhoto,
    this.spellCheckEnabled = false,
    this.photoMediaImporter,
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
  final String kicker;
  final ComposerExit exit;
  final String hintText;
  final String saveLabel;
  final String savingLabel;
  final PhotoImporter? onAddPhoto;
  final bool spellCheckEnabled;
  final Future<String> Function(CaptureMedia photo)? photoMediaImporter;

  @override
  State<TextComposerSheet> createState() => _TextComposerSheetState();
}

class _TextComposerSheetState extends State<TextComposerSheet> {
  late final NoteEditorController _controller;
  late final bool _ownsController;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  late final UndoHistoryController _undoController;
  final GlobalKey _footerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final TextEditingController? external = widget.controller;
    _ownsController = external is! NoteEditorController;
    _controller = switch (external) {
      null => NoteEditorController(text: widget.initialText),
      NoteEditorController() => external,
      _ => NoteEditorController.attachedTo(external),
    };
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _undoController = UndoHistoryController();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
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
        final Widget formatBar = _formatBar(
          trailing: roomy ? null : _compactAdd(),
        );
        return CallbackShortcuts(
          bindings: _shortcuts(context),
          child: Focus(
            autofocus: true,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                _header(
                  middle: roomy ? _titleBlock() : formatBar,
                  below: roomy && sidebar ? formatBar : null,
                ),
                const DashedDivider(
                  thickness: _headerRuleThickness,
                  color: Palette.ink25,
                ),
                Expanded(
                  child: _body(
                    formatBar: roomy && !sidebar ? formatBar : null,
                    footer: roomy ? _footer(showHints: true) : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(BuildContext context) {
    final bool apple = switch (Theme.of(context).platform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    final VoidCallback save = _handleSaveShortcut;
    return <ShortcutActivator, VoidCallback>{
      SingleActivator(
        LogicalKeyboardKey.enter,
        meta: apple,
        control: !apple,
      ): save,
      SingleActivator(
        LogicalKeyboardKey.numpadEnter,
        meta: apple,
        control: !apple,
      ): save,
      const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
    };
  }

  void _handleSaveShortcut() {
    if (widget.isSaving) {
      return;
    }
    _handleSaveTap();
  }

  void _handleEscape() {
    if (widget.isSaving) {
      return;
    }
    widget.onCancel();
  }

  Widget? _compactAdd() => _footer(showHints: false, compact: true);

  Widget? _footer({required bool showHints, bool compact = false}) {
    final PhotoImporter? importer = widget.onAddPhoto;
    if (importer == null) {
      return null;
    }
    return ComposerFooter(
      key: _footerKey,
      controller: _controller,
      onAddPhoto: importer,
      editorFocusNode: _focusNode,
      showHints: showHints,
      compact: compact,
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
            composerFooterHeight +
            formatBarHeight +
            _minimumWritingLines * line;
  }

  Widget _formatBar({Widget? trailing}) {
    return FormatBar(
      controller: _controller,
      undoController: _undoController,
      trailing: trailing,
    );
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
              _exitPill(),
              Expanded(child: middle),
              _saveButton(),
            ],
          ),
          ?below,
        ],
      ),
    );
  }

  Widget _exitPill() {
    final bool back = widget.exit == ComposerExit.back;
    return GestureDetector(
      key: composerCloseKey,
      behavior: HitTestBehavior.opaque,
      onTap: widget.isSaving ? null : widget.onCancel,
      child: Container(
        height: _exitPillHeight,
        padding: const EdgeInsets.only(
          left: _exitPillStartPadding,
          right: _exitPillEndPadding,
        ),
        decoration: BoxDecoration(
          color: Palette.cardWarm,
          border: Shapes.outline,
          borderRadius: BorderRadius.circular(_exitPillRadius),
          boxShadow: Shadows.chip,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: _exitGlyphSize,
              child: CustomPaint(
                painter: back
                    ? const _BackChevronPainter()
                    : const _CloseGlyphPainter(),
              ),
            ),
            const SizedBox(width: _exitGlyphGap),
            Text(
              back ? 'Back' : 'Cancel',
              style: TypographyTokens.captureLabelSans
                  .copyWith(color: Palette.ink),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleBlock() {
    final String kicker = widget.kicker;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _headerGap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (kicker.isNotEmpty)
            Text(
              kicker,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypographyTokens.stampAccent
                  .copyWith(color: Palette.coral),
            ),
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypographyTokens.headlineSerif.copyWith(
              fontSize: 22,
              height: _titleLineHeight,
            ),
          ),
        ],
      ),
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

  Widget _body({Widget? formatBar, Widget? footer}) {
    final String? errorMessage = widget.errorMessage;
    return Column(
      mainAxisSize: MainAxisSize.max,
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
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: _writingSurface(footer: footer != null)),
              if (footer != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ComposerFooterVeil(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _bodyHorizontalPadding,
                      ),
                      child: footer,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ?formatBar,
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(
              left: _bodyHorizontalPadding,
              right: _bodyHorizontalPadding,
              top: _errorGap,
            ),
            child: Text(
              errorMessage,
              style:
                  TypographyTokens.captionSans.copyWith(color: Palette.danger),
            ),
          ),
        if (formatBar != null || errorMessage != null)
          const SizedBox(height: _bodyBottomPadding),
      ],
    );
  }

  Widget _writingSurface({required bool footer}) {
    return KeyedSubtree(
      key: composerWritingSurfaceKey,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Palette.composerPaper),
        child: Column(
          children: <Widget>[
            const DashedDivider(
              thickness: _surfaceRuleThickness,
              color: Palette.ink20,
            ),
            Expanded(child: _editor(footer: footer)),
          ],
        ),
      ),
    );
  }

  Widget _editor({required bool footer}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return RawScrollbar(
          controller: _scrollController,
          thickness: _scrollbarThickness,
          thumbColor: Palette.ink22,
          radius: const Radius.circular(Shapes.radiusXs),
          child: Padding(
            padding: _pageMargins(constraints.maxHeight),
            child: NoteColumn(
              maxEm: composerMeasureEm,
              child: _page(bottomInset: _pageEndInset(footer: footer)),
            ),
          ),
        );
      },
    );
  }

  Widget _page({required double bottomInset}) {
    return noteEditorFor(
      NoteEditorConfig(
        controller: _controller,
        focusNode: _focusNode,
        undoController: _undoController,
        scrollController: _scrollController,
        hintText: widget.hintText,
        photoImporter: widget.onAddPhoto,
        bottomInset: bottomInset,
        spellCheckEnabled: widget.spellCheckEnabled,
        photoMediaImporter: widget.photoMediaImporter,
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
  );
}

double _pageEndInset({required bool footer}) =>
    (footer ? composerFooterHeight : 0) + _pageEndGap;

class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _exitStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / _exitViewBox);
    canvas.drawLine(const Offset(6, 6), const Offset(18, 18), stroke);
    canvas.drawLine(const Offset(18, 6), const Offset(6, 18), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloseGlyphPainter oldDelegate) => false;
}

class _BackChevronPainter extends CustomPainter {
  const _BackChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _backChevronStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final Path path = Path()
      ..moveTo(cx + _backChevronArm / 2, cy - _backChevronArm)
      ..lineTo(cx - _backChevronArm / 2, cy)
      ..lineTo(cx + _backChevronArm / 2, cy + _backChevronArm);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_BackChevronPainter oldDelegate) => false;
}
