import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/keyboard/shortcut_modifier.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/capture_service.dart'
    show CaptureMedia;
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;
import 'package:field_notes/features/notes/photos/photo_import.dart';

import 'composer_footer.dart';
import 'composer_header_layout.dart';
import 'editor/format_bar.dart';
import 'editor/note_editor.dart';

const Key composerCloseKey = ValueKey<String>('composer-close');

const Key composerSaveKey = ValueKey<String>('composer-save');

const double composerMeasureEm = 45;

const Key composerWritingSurfaceKey = ValueKey<String>(
  'composer-writing-surface',
);

const String emptySaveGuardMessage = 'Write something first';

enum ComposerExit { cancel, back }

const double _headerVerticalPadding = 16;
const double _headerHorizontalPadding = 18;
const double _headerGap = 14;
const double _headerRuleThickness = 1.5;
const double _titleLineHeight = 1.05;
const double _exitPillHeight = 34;
const double _phoneHeaderButtonHeight = 40;
const double _headerTargetInset =
    (kMinInteractiveDimension - _exitPillHeight) / 2;
const double _exitPillStartPadding = 8;
const double _exitPillEndPadding = 12;
const double _exitPillVerticalPadding = 4;
const BorderRadius _exitPillBorderRadius = BorderRadius.all(
  Radius.circular(10),
);
const double _exitGlyphSize = 15;
const double _exitGlyphGap = 4;
const double _exitStrokeWidth = 2.2;
const double _exitViewBox = 24;
const double _backChevronStrokeWidth = 2;
const double _backChevronArm = 5;
const double _saveVerticalPadding = 7;
const double _saveHorizontalPadding = 15;
const double _disabledOpacity = 0.5;
const BorderRadius _saveBorderRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusPill),
);
const double _phoneSaveHorizontalPadding = 14;
const BorderRadius _phoneSaveBorderRadius = BorderRadius.all(
  Radius.circular(12),
);
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
const double _editorRingOutset = 2;
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
  final GlobalKey _dockedFooterKey = GlobalKey();
  final GlobalKey _dockedBarKey = GlobalKey();

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
    return ToastClearance(
      anchors: <GlobalKey>[_dockedFooterKey, _dockedBarKey],
      child: LayoutBuilder(builder: _layout),
    );
  }

  Widget _layout(BuildContext context, BoxConstraints constraints) {
    final bool roomy = _hasRoomForFormatBar(context, constraints.maxHeight);
    final bool sidebar =
        resolveShellLayout(Theme.of(context).platform) == ShellLayout.sidebar;
    final Widget formatBar = _formatBar(trailing: roomy ? null : _compactAdd());
    return CallbackShortcuts(
      bindings: _shortcuts(context),
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            _header(
              context,
              middle: roomy ? null : formatBar,
              below: roomy && sidebar ? formatBar : null,
            ),
            DashedDivider(
              thickness: _headerRuleThickness,
              color: context.colors.ink25,
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
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(BuildContext context) {
    final TargetPlatform platform = Theme.of(context).platform;
    void save() => _handleSaveShortcut(context);
    return <ShortcutActivator, VoidCallback>{
      primaryShortcut(LogicalKeyboardKey.enter, platform): save,
      primaryShortcut(LogicalKeyboardKey.numpadEnter, platform): save,
      const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
    };
  }

  void _handleSaveShortcut(BuildContext context) {
    if (widget.isSaving) {
      return;
    }
    _handleSaveTap(context);
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
        NoteColumn.emOf(context) * context.textStyles.noteBody.height!;
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

  Widget _header(
    BuildContext context, {
    required Widget? middle,
    Widget? below,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _headerHorizontalPadding,
        vertical: _headerVerticalPadding - _headerTargetInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (middle == null)
            ComposerHeaderLayout(
              leading: _exitPill(),
              title: _headerMiddle(_titleBlock()),
              trailing: _saveButton(context),
            )
          else
            Row(
              children: <Widget>[
                _exitPill(),
                Expanded(child: _headerMiddle(middle)),
                _saveButton(context),
              ],
            ),
          ?below,
        ],
      ),
    );
  }

  Widget _headerMiddle(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(vertical: _headerTargetInset),
    child: child,
  );

  Widget _headerAction({
    required String label,
    required VoidCallback? onTap,
    required BorderRadius focusRadius,
    required FocusRingSurface hoverSurface,
    required Widget child,
  }) {
    return TextFieldTapRegion(
      child: Pressable(
        label: label,
        onPressed: onTap,
        borderRadius: focusRadius,
        placement: FocusRingPlacement.edge,
        paintsHover: false,
        builder: (BuildContext context, bool hovered) => ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kMinInteractiveDimension,
            minHeight: kMinInteractiveDimension,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: HoverFill(
              hovered: hovered,
              surface: hoverSurface,
              borderRadius: focusRadius,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _exitPill() {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    final bool back = widget.exit == ComposerExit.back;
    return _headerAction(
      label: back ? 'Back' : 'Cancel',
      onTap: widget.isSaving ? null : widget.onCancel,
      focusRadius: _exitPillBorderRadius,
      hoverSurface: FocusRingSurface.light,
      child: Container(
        key: composerCloseKey,
        constraints: BoxConstraints(
          minHeight: _onPhone(context)
              ? _phoneHeaderButtonHeight
              : _exitPillHeight,
        ),
        padding: const EdgeInsets.only(
          left: _exitPillStartPadding,
          right: _exitPillEndPadding,
          top: _exitPillVerticalPadding,
          bottom: _exitPillVerticalPadding,
        ),
        decoration: BoxDecoration(
          color: colors.cardWarm,
          border: shadows.outline,
          borderRadius: _exitPillBorderRadius,
          boxShadow: shadows.chip,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: _exitGlyphSize,
              child: CustomPaint(
                painter: back
                    ? _BackChevronPainter(color: colors.ink)
                    : _CloseGlyphPainter(color: colors.ink),
              ),
            ),
            const SizedBox(width: _exitGlyphGap),
            Text(
              back ? 'Back' : 'Cancel',
              style: context.textStyles.captureLabelSans.copyWith(
                color: colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleBlock() {
    final FieldNotesTextStyles textStyles = context.textStyles;
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
              style: textStyles.stampAccent.copyWith(
                color: context.colors.accentInk,
              ),
            ),
          Text(
            widget.title,
            style: textStyles.headlineSerif.copyWith(
              fontSize: 22,
              height: _titleLineHeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton(BuildContext context) {
    final FieldNotesShadows shadows = context.shadows;
    final bool enabled = !widget.isSaving;
    final bool phone = _onPhone(context);
    final BorderRadius radius = phone
        ? _phoneSaveBorderRadius
        : _saveBorderRadius;
    final Widget label = Text(
      widget.isSaving ? widget.savingLabel : widget.saveLabel,
      style: context.textStyles.captureLabelSans.copyWith(
        color: Palette.onAccent,
      ),
    );
    return _headerAction(
      label: widget.isSaving ? widget.savingLabel : widget.saveLabel,
      onTap: enabled ? () => _handleSaveTap(context) : null,
      focusRadius: radius,
      hoverSurface: FocusRingSurface.dark,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: DecoratedBox(
          key: composerSaveKey,
          decoration: BoxDecoration(
            color: Palette.coral,
            border: shadows.outline,
            borderRadius: radius,
            boxShadow: shadows.control,
          ),
          child: phone
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _phoneSaveHorizontalPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _phoneHeaderButtonHeight,
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: _exitPillVerticalPadding,
                        ),
                        child: label,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _saveHorizontalPadding,
                    vertical: _saveVerticalPadding,
                  ),
                  child: label,
                ),
        ),
      ),
    );
  }

  bool _onPhone(BuildContext context) =>
      resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;

  void _handleSaveTap(BuildContext context) {
    final String text = _controller.text;
    if (text.trim().isEmpty) {
      showTransientToast(context, emptySaveGuardMessage);
      return;
    }
    widget.onSave(text);
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
            ),
            child: DraftRestoredChip(
              onDiscard: widget.onDiscardDraft,
              verticalMargin: _chipVerticalPadding,
            ),
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
                  child: KeyedSubtree(
                    key: _dockedFooterKey,
                    child: ComposerFooterVeil(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _bodyHorizontalPadding,
                        ),
                        child: footer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (formatBar != null)
          KeyedSubtree(key: _dockedBarKey, child: formatBar),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(
              left: _bodyHorizontalPadding,
              right: _bodyHorizontalPadding,
              top: _errorGap,
            ),
            child: Text(
              errorMessage,
              style: context.textStyles.captionSans.copyWith(
                color: context.colors.dangerInk,
              ),
            ),
          ),
        if (formatBar != null || errorMessage != null)
          const SizedBox(height: _bodyBottomPadding),
      ],
    );
  }

  Widget _writingSurface({required bool footer}) {
    final FieldNotesColors colors = context.colors;
    return KeyedSubtree(
      key: composerWritingSurfaceKey,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.composerPaper),
        child: Column(
          children: <Widget>[
            DashedDivider(
              thickness: _surfaceRuleThickness,
              color: colors.ink20,
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
          thumbColor: context.colors.ink22,
          radius: const Radius.circular(Shapes.radiusXs),
          child: Padding(
            padding: _pageMargins(constraints.maxHeight),
            child: NoteColumn(
              maxEm: composerMeasureEm,
              child: _page(
                bottomInset: _pageEndInset(
                  MediaQuery.textScalerOf(context),
                  footer: footer,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _page({required double bottomInset}) {
    return _EditorFocusOutline(
      focusNode: _focusNode,
      child: _editorView(bottomInset: bottomInset),
    );
  }

  Widget _editorView({required double bottomInset}) {
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

class _EditorFocusOutline extends StatefulWidget {
  const _EditorFocusOutline({required this.focusNode, required this.child});

  final FocusNode focusNode;
  final Widget child;

  @override
  State<_EditorFocusOutline> createState() => _EditorFocusOutlineState();
}

class _EditorFocusOutlineState extends State<_EditorFocusOutline> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_update);
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
    _shown = _shouldShow();
  }

  @override
  void didUpdateWidget(_EditorFocusOutline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      oldWidget.focusNode.removeListener(_update);
      widget.focusNode.addListener(_update);
      _update();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_update);
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  bool _shouldShow() =>
      widget.focusNode.hasFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _onHighlightMode(FocusHighlightMode _) => _update();

  void _update() {
    final bool shown = _shouldShow();
    if (shown != _shown && mounted) {
      setState(() => _shown = shown);
    }
  }

  @override
  Widget build(BuildContext context) {
    const FocusRingSurface surface = FocusRingSurface.light;
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: <Widget>[
        widget.child,
        if (_shown)
          Positioned.fill(
            left: -_editorRingOutset,
            top: -_editorRingOutset,
            right: -_editorRingOutset,
            bottom: -_editorRingOutset,
            child: IgnorePointer(
              child: DecoratedBox(
                key: focusRingKey,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: surface.colorIn(context.colors),
                    width: surface.width,
                  ),
                  borderRadius: Shapes.buttonBorderRadius,
                ),
              ),
            ),
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
  );
}

double _pageEndInset(TextScaler scaler, {required bool footer}) =>
    (footer ? scaler.scale(composerFooterHeight) : 0) + _pageEndGap;

class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
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
  bool shouldRepaint(_CloseGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _BackChevronPainter extends CustomPainter {
  const _BackChevronPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
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
  bool shouldRepaint(_BackChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}
