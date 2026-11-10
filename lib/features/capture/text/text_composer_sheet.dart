import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/focus/keyboard_focus_builder.dart';
import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/keyboard/shortcut_modifier.dart';
import 'package:field_notes/design/motion/motion_tokens.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart'
    show IconStickerGlyph, IconStickerGlyphIcon;
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show plainTextOfTree;
import 'package:field_notes/domain/services/capture_service.dart'
    show CaptureMedia;
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/capture/core/journal_note_writer.dart'
    show
        NoteSourceParts,
        composeNoteSource,
        readTitledNoteSource,
        splitNoteSource;
import 'package:field_notes/features/capture/immersive/stage_phase.dart'
    show stageLayoutOf;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;
import 'package:field_notes/features/notes/photos/photo_import.dart';

import 'composer_footer.dart';
import 'editor/format_bar.dart';
import 'editor/note_editor.dart';

export 'composer_footer.dart' show composerSaveKey;

const Key composerCloseKey = ValueKey<String>('composer-close');

const Key composerTitleFieldKey = ValueKey<String>('composer-title-field');

const double composerMeasureEm = 45;

const Key composerWritingSurfaceKey = ValueKey<String>(
  'composer-writing-surface',
);

const String emptySaveGuardMessage = 'Write something first';

const String composerTitleHint = 'Add a title';

const String composerKeepNewLabel = 'Keep this';

const String composerRestingStatus = 'There’s no wrong way to say it.';

const Duration composerChromeRest = Duration(milliseconds: 1500);

const Key _titleSlotKey = ValueKey<String>('composer-title-slot');
const Key _pageSlotKey = ValueKey<String>('composer-page-slot');
const Key _writingSlotKey = ValueKey<String>('composer-writing-slot');

enum ComposerExit { cancel, back }

const double _compactWidth = 560;
const double _hintsMinWidth = 640;
const double _statusFloor = 520;
const double _footerFloor = 360;
const double _stripFloor = 300;
const double _toolbarFloor = 200;
const double _titleFloor = 200;
const double _bandHorizontalPadding = 16;
const double _bandVerticalPadding = 12;
const double _bandGap = 12;
const double _compactPrivacyReach = 64;
const double _widePrivacyReach = 120;
const double _privacySize = 13;
const double _lockSize = 14;
const double _lockGap = 6;
const double _lockStroke = 1.8;
const double _lockViewBox = 24;
const double _leaveGlyphSize = 18;
const double _leaveGap = 6;
const double _leaveHorizontalPadding = 10;
const double _hintGap = 12;
const double _hintKeyGap = 4;
const double _hintKeyRadius = 6;
const double _hintKeySize = 11;
const double _hintTextSize = 12;
const EdgeInsets _hintKeyPadding = EdgeInsets.symmetric(
  horizontal: 6,
  vertical: 3,
);
const double _titleSidePadding = 24;
const double _titleMaxWidth = 560;
const double _titleHeight = 44;
const double _titleSize = 24;
const double _titleCompactSize = 20;
const double _titleLineHeight = 1.25;
const double _pageMaxWidth = 720;
const double _pageSidePadding = 24;
const double _pageVerticalPadding = 8;
const double _toolbarTopPadding = 4;
const double _toolbarBottomPadding = 8;
const double _editorSidePadding = 8;
const double _editorWideSidePadding = 16;
const double _editorTopPadding = 12;
const double _editorEndInset = 40;
const double _scrollbarThickness = 9;
const double _statusMinHeight = 34;
const double _statusSize = 22;
const double _statusCompactSize = 18;
const double _statusLineHeight = 1.2;
const EdgeInsets _statusPadding = EdgeInsets.fromLTRB(24, 6, 24, 2);
const double _stripSidePadding = 8;
const double _chipVerticalMargin = 6;
const double _ringOutset = 2;
const double _ringWidth = 2;
const double _backChevronStrokeWidth = 2;
const double _backChevronArm = 5;
const BorderRadius _fieldRadius = BorderRadius.all(
  Radius.circular(Shapes.radius8),
);

final RegExp _writtenWord = RegExp(r'\S+');
final RegExp _lineBreaks = RegExp(r'[\r\n]');

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
    this.saveLabel = composerKeepNewLabel,
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
  late final TextEditingController _source;
  late final bool _ownsSource;
  late final NoteSourceParts _origin;
  late final TextEditingController _titleController;
  late final TextEditingController _bodySource;
  late final NoteEditorController _controller;
  late String _seenTitle;
  late String _seenBody;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final UndoHistoryController _undoController = UndoHistoryController();
  final ValueNotifier<int> _typing = ValueNotifier<int>(0);
  late final _TitleThenPagePolicy _titleThenPage = _TitleThenPagePolicy(
    title: _titleFocusNode,
    page: _focusNode,
  );
  final GlobalKey _actionsKey = GlobalKey();
  final GlobalKey _statusKey = GlobalKey();
  ComposerPhotoAdder? _photoAdder;
  Timer? _pointerRest;
  bool _pointerResting = false;
  bool _chromeHidden = false;
  bool _keepChromeVisible = false;
  bool _mirroring = false;
  bool _traversing = false;

  bool get _editing => widget.saveLabel != composerKeepNewLabel;

  @override
  void initState() {
    super.initState();
    final TextEditingController? external = widget.controller;
    _ownsSource = external == null;
    _source = external ?? TextEditingController(text: widget.initialText);
    _origin = splitNoteSource(_source.text);
    _seenTitle = _origin.title;
    _seenBody = _origin.body;
    _titleController = TextEditingController(text: _origin.title);
    _bodySource = TextEditingController(text: _origin.body);
    _controller = NoteEditorController.attachedTo(_bodySource);
    _source.addListener(_followSource);
    _titleController.addListener(_onFieldsChanged);
    _bodySource.addListener(_onFieldsChanged);
    FocusManager.instance.addEarlyKeyEventHandler(_noticeKey);
    _photoAdder = widget.onAddPhoto == null
        ? null
        : ComposerPhotoAdder(
            controller: _controller,
            importer: () => widget.onAddPhoto!(),
            editorFocusNode: _focusNode,
            report: _reportPhotoProblem,
          );
    _restartPointerRest();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _openingFocus.requestFocus();
      }
    });
  }

  FocusNode get _openingFocus => !_editing && _titleFocusNode.context != null
      ? _titleFocusNode
      : _focusNode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keepChromeVisible = MediaQuery.accessibleNavigationOf(context);
    if (_keepChromeVisible) {
      _chromeHidden = false;
    }
  }

  @override
  void dispose() {
    _pointerRest?.cancel();
    FocusManager.instance.removeEarlyKeyEventHandler(_noticeKey);
    _source.removeListener(_followSource);
    _titleController.removeListener(_onFieldsChanged);
    _bodySource.removeListener(_onFieldsChanged);
    _photoAdder?.dispose();
    _controller.dispose();
    _bodySource.dispose();
    _titleController.dispose();
    if (_ownsSource) {
      _source.dispose();
    }
    _focusNode.dispose();
    _titleFocusNode.dispose();
    _scrollController.dispose();
    _undoController.dispose();
    _typing.dispose();
    super.dispose();
  }

  void _reportPhotoProblem(String message) {
    if (mounted) {
      showTransientToast(
        _actionsKey.currentContext ?? context,
        message,
        glyph: IconStickerGlyph.close,
      );
    }
  }

  NoteSourceParts _partsOf(String source) {
    final NoteSourceParts titled = readTitledNoteSource(source);
    if (titled.carriesTitle) {
      return titled;
    }
    final NoteSourceParts opening = _origin;
    return opening.carriesTitle && source.startsWith(opening.lead)
        ? NoteSourceParts(
            title: opening.title,
            body: source.substring(opening.lead.length),
            lead: opening.lead,
          )
        : NoteSourceParts(title: '', body: source);
  }

  void _followSource() {
    if (_mirroring) {
      return;
    }
    final NoteSourceParts parts = _partsOf(_source.text);
    _mirroring = true;
    if (_titleController.text != parts.title) {
      _titleController.text = parts.title;
    }
    if (_bodySource.text != parts.body) {
      _bodySource.text = parts.body;
    }
    _mirroring = false;
    _seenTitle = parts.title;
    _seenBody = parts.body;
  }

  void _onFieldsChanged() {
    if (_mirroring) {
      return;
    }
    final String title = _titleController.text;
    final String body = _bodySource.text;
    if (title == _seenTitle && body == _seenBody) {
      return;
    }
    _seenTitle = title;
    _seenBody = body;
    _mirrorOut(title, body);
    _typing.value += 1;
    _setTraversing(false);
    if (_pointerResting && !_keepChromeVisible) {
      _setChromeHidden(true);
    }
  }

  String? _keptTitle(String title) =>
      title.trim().isEmpty && !_origin.carriesTitle ? null : title;

  void _mirrorOut(String title, String body) {
    final String composed = title == _origin.title && _origin.carriesTitle
        ? '${_origin.lead}$body'
        : composeNoteSource(title: _keptTitle(title), body: body);
    if (_source.text == composed) {
      return;
    }
    _mirroring = true;
    _source.text = composed;
    _mirroring = false;
  }

  KeyEventResult _noticeKey(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
      _setTraversing(true);
      _setChromeHidden(false);
    }
    return KeyEventResult.ignored;
  }

  void _noticePointer(PointerEvent _) {
    _restartPointerRest();
    _setChromeHidden(false);
  }

  void _noticePointerDown(PointerDownEvent event) {
    _setTraversing(false);
    _noticePointer(event);
  }

  void _restartPointerRest() {
    _pointerResting = false;
    _pointerRest?.cancel();
    _pointerRest = Timer(composerChromeRest, () => _pointerResting = true);
  }

  void _setTraversing(bool value) {
    if (_traversing != value && mounted) {
      setState(() => _traversing = value);
    }
  }

  void _setChromeHidden(bool value) {
    if (_chromeHidden != value && mounted) {
      setState(() => _chromeHidden = value);
    }
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

  void _handleSaveTap(BuildContext context) {
    final String body = _controller.text;
    if (body.trim().isEmpty) {
      showTransientToast(context, emptySaveGuardMessage);
      return;
    }
    widget.onSave(
      composeNoteSource(title: _keptTitle(_titleController.text), body: body),
    );
  }

  VoidCallback? _keepAction(BuildContext context) {
    final bool blocked =
        widget.isSaving || (!_editing && _controller.text.trim().isEmpty);
    return blocked ? null : () => _handleSaveTap(context);
  }

  VoidCallback? get _leaveAction => widget.isSaving ? null : widget.onCancel;

  int get _words => _writtenWord
      .allMatches(
        plainTextOfTree(_controller.state.tree, _controller.state.source),
      )
      .length;

  String get _roomLabel => widget.kicker.isEmpty
      ? widget.title
      : '${widget.title}, ${widget.kicker}';

  @override
  Widget build(BuildContext context) {
    return ToastClearance(
      anchors: <GlobalKey>[_statusKey, _actionsKey],
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: _roomLabel,
        child: Builder(
          builder: (BuildContext cleared) => CallbackShortcuts(
            bindings: _shortcuts(cleared),
            child: Focus(
              autofocus: true,
              skipTraversal: true,
              child: FocusTraversalGroup(
                policy: _titleThenPage,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _noticePointerDown,
                  onPointerMove: _noticePointer,
                  onPointerHover: _noticePointer,
                  onPointerSignal: _noticePointer,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ComposerStageGround(typing: _typing),
                      LayoutBuilder(builder: _layout),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, BoxConstraints constraints) {
    final MediaQueryData media = MediaQuery.of(context);
    final double top = math.max(media.padding.top, media.viewPadding.top);
    final double bottom = math.max(
      media.viewInsets.bottom,
      math.max(media.padding.bottom, media.viewPadding.bottom),
    );
    final double room = constraints.maxHeight - top - bottom;
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    final bool compact = !sidebar || constraints.maxWidth < _compactWidth;
    final bool strip =
        room < _stripFloor && constraints.maxWidth >= _compactWidth;
    final bool keepInBand = !strip && room < _footerFloor;
    final bool short = room < _statusFloor;
    final ComposerFooterRoom footerRoom = short || media.viewInsets.bottom > 0
        ? ComposerFooterRoom.tight
        : compact
        ? ComposerFooterRoom.phone
        : ComposerFooterRoom.desktop;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _faded(
            strip
                ? _strip(context)
                : _topBand(
                    context,
                    compact: compact,
                    width: constraints.maxWidth,
                    keepInBand: keepInBand,
                  ),
          ),
          if (room >= _titleFloor) _titleField(context, compact: compact),
          if (widget.draftRestored)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pageSidePadding),
              child: DraftRestoredChip(
                onDiscard: widget.onDiscardDraft,
                verticalMargin: _chipVerticalMargin,
              ),
            ),
          Expanded(
            key: _pageSlotKey,
            child: _page(
              context,
              toolbar: !strip && room >= _toolbarFloor,
              editorSidePadding:
                  constraints.maxWidth - 2 * _pageSidePadding >= _pageMaxWidth
                  ? _editorWideSidePadding
                  : _editorSidePadding,
            ),
          ),
          if (!strip)
            KeyedSubtree(
              key: _statusKey,
              child: _statusLine(context, compact: compact, short: short),
            ),
          if (!strip && !keepInBand)
            _faded(
              KeyedSubtree(
                key: _actionsKey,
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (BuildContext context, Widget? _) => ComposerFooter(
                    leaveLabel: _editing ? 'Discard edits' : 'Let it go',
                    keepLabel: widget.saveLabel,
                    words: _words,
                    onLeave: _leaveAction,
                    onKeep: _keepAction(context),
                    room: footerRoom,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _faded(Widget child) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      ignoring: _chromeHidden,
      child: AnimatedOpacity(
        opacity: _chromeHidden ? 0 : 1,
        duration: still ? Duration.zero : Motion.fade,
        curve: Curves.ease,
        alwaysIncludeSemantics: true,
        child: child,
      ),
    );
  }

  Widget _topBand(
    BuildContext context, {
    required bool compact,
    required double width,
    required bool keepInBand,
  }) {
    final bool hints = !keepInBand && !compact && width >= _hintsMinWidth;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _bandHorizontalPadding,
        vertical: _bandVerticalPadding,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _leaveControl(context, iconOnly: compact),
              if (hints) _hints(context),
              if (keepInBand) _keepButton(),
            ],
          ),
          if (!keepInBand)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? _compactPrivacyReach : _widePrivacyReach,
              ),
              child: _privacy(context, compact: compact),
            ),
        ],
      ),
    );
  }

  Widget _keepButton() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? _) => StickerButton(
        key: composerSaveKey,
        label: widget.saveLabel,
        variant: StickerButtonVariant.keep,
        onPressed: _keepAction(context),
      ),
    );
  }

  Widget _strip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _stripSidePadding),
      child: Row(
        children: <Widget>[
          _leaveControl(context, iconOnly: true),
          const SizedBox(width: _bandGap),
          Expanded(child: _toolbar()),
          const SizedBox(width: _bandGap),
          _keepButton(),
        ],
      ),
    );
  }

  Widget _leaveControl(BuildContext context, {required bool iconOnly}) {
    final ComposerStageInks inks = ComposerStageInks.of(context);
    final bool back = widget.exit == ComposerExit.back;
    final String label = back ? 'Back' : 'Leave';
    final TargetPlatform platform = Theme.of(context).platform;
    final double target = iconOnly
        ? minIconTargetOn(platform)
        : minButtonTargetOn(platform);
    final Widget glyph = back
        ? SizedBox.square(
            dimension: _leaveGlyphSize,
            child: CustomPaint(painter: _BackChevronPainter(color: inks.ink)),
          )
        : IconStickerGlyphIcon(
            glyph: IconStickerGlyph.close,
            color: inks.ink,
            size: _leaveGlyphSize,
          );
    return TextFieldTapRegion(
      child: Pressable(
        key: composerCloseKey,
        label: label,
        onPressed: _leaveAction,
        borderRadius: _fieldRadius,
        placement: FocusRingPlacement.edge,
        iconOnly: iconOnly,
        child: iconOnly
            ? SizedBox.square(
                dimension: target,
                child: Center(child: glyph),
              )
            : ConstrainedBox(
                constraints: BoxConstraints(minHeight: target),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _leaveHorizontalPadding,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      glyph,
                      const SizedBox(width: _leaveGap),
                      Text(
                        label,
                        style: context.textStyles.buttonSans.copyWith(
                          color: inks.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _privacy(BuildContext context, {required bool compact}) {
    final ComposerStageInks inks = ComposerStageInks.of(context);
    return Semantics(
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox.square(
            dimension: _lockSize,
            child: CustomPaint(painter: _LockPainter(color: inks.chrome)),
          ),
          const SizedBox(width: _lockGap),
          Flexible(
            child: Text(
              compact
                  ? 'Only you will read this'
                  : 'Private · only you will read this',
              textAlign: TextAlign.center,
              style: context.textStyles.captionSans.copyWith(
                fontSize: _privacySize,
                fontWeight: FontWeight.w500,
                color: inks.chrome,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hints(BuildContext context) {
    final String keep = usesCommandKey(Theme.of(context).platform)
        ? '⌘ Return'
        : 'Ctrl Enter';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _hint(context, keep, 'keep'),
        const SizedBox(width: _hintGap),
        _hint(context, 'Esc', 'leave'),
      ],
    );
  }

  Widget _hint(BuildContext context, String key, String action) {
    final ComposerStageInks inks = ComposerStageInks.of(context);
    final FieldNotesTextStyles styles = context.textStyles;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: _hintKeyPadding,
          decoration: BoxDecoration(
            border: Border.all(color: inks.line),
            borderRadius: BorderRadius.circular(_hintKeyRadius),
          ),
          child: Text(
            key,
            style: styles.captionSans.copyWith(
              fontSize: _hintKeySize,
              fontWeight: FontWeight.w500,
              color: inks.ink,
            ),
          ),
        ),
        const SizedBox(width: _hintKeyGap),
        Text(
          action,
          style: styles.captionSans.copyWith(
            fontSize: _hintTextSize,
            color: inks.chrome,
          ),
        ),
      ],
    );
  }

  Widget _titleField(BuildContext context, {required bool compact}) {
    final ComposerStageInks inks = ComposerStageInks.of(context);
    final double fontSize = compact ? _titleCompactSize : _titleSize;
    final TextStyle style = context.textStyles.headlineSerif.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      height: _titleLineHeight,
      color: inks.ink,
    );
    final double fieldHeight = <double>[
      _titleHeight,
      minIconTargetOn(Theme.of(context).platform),
      MediaQuery.textScalerOf(context).scale(fontSize) * _titleLineHeight,
    ].reduce(math.max);
    return Padding(
      key: _titleSlotKey,
      padding: const EdgeInsets.symmetric(horizontal: _titleSidePadding),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _titleMaxWidth),
          child: _StageFieldRing(
            focusNode: _titleFocusNode,
            armed: _traversing,
            child: SizedBox(
              height: fieldHeight,
              child: Semantics(
                label: 'Title',
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    key: composerTitleFieldKey,
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    readOnly: widget.isSaving,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: inks.caret,
                    style: style,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.deny(_lineBreaks),
                    ],
                    decoration: InputDecoration.collapsed(
                      hintText: composerTitleHint,
                      hintStyle: style.copyWith(color: inks.chrome),
                    ),
                    onEditingComplete: _focusNode.requestFocus,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _page(
    BuildContext context, {
    required bool toolbar,
    required double editorSidePadding,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _pageSidePadding,
        vertical: toolbar ? _pageVerticalPadding : 0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (toolbar)
                _faded(
                  Padding(
                    padding: const EdgeInsets.only(
                      top: _toolbarTopPadding,
                      bottom: _toolbarBottomPadding,
                    ),
                    child: _toolbar(),
                  ),
                ),
              Expanded(
                key: _writingSlotKey,
                child: _writingSurface(context, editorSidePadding),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar() {
    final ComposerPhotoAdder? adder = _photoAdder;
    return FormatBar(
      controller: _controller,
      undoController: _undoController,
      editorFocusNode: _focusNode,
      onAddPhoto: adder == null ? null : () => unawaited(adder.add()),
      addingPhoto: adder?.busy,
    );
  }

  Widget _writingSurface(BuildContext context, double editorSidePadding) {
    final ComposerStageInks inks = ComposerStageInks.of(context);
    final ThemeData theme = Theme.of(context);
    final Widget surface = KeyedSubtree(
      key: composerWritingSurfaceKey,
      child: _StageFieldRing(
        focusNode: _focusNode,
        armed: _traversing,
        child: RawScrollbar(
          controller: _scrollController,
          thickness: _scrollbarThickness,
          thumbColor: inks.line,
          radius: const Radius.circular(Shapes.radiusXs),
          child: NoteColumn(
            maxEm: composerMeasureEm,
            child: Padding(
              padding: EdgeInsets.only(
                left: editorSidePadding,
                right: editorSidePadding,
                top: _editorTopPadding,
              ),
              child: noteEditorFor(
                NoteEditorConfig(
                  controller: _controller,
                  focusNode: _focusNode,
                  undoController: _undoController,
                  scrollController: _scrollController,
                  hintText: widget.hintText,
                  hintStyle: context.textStyles.noteBodyPlaceholder.copyWith(
                    color: inks.chrome,
                  ),
                  cursorColor: inks.caret,
                  photoImporter: widget.onAddPhoto,
                  bottomInset: _editorEndInset,
                  spellCheckEnabled: widget.spellCheckEnabled,
                  photoMediaImporter: widget.photoMediaImporter,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Theme(
      data: theme.copyWith(
        extensions: theme.extensions.values
            .where(
              (ThemeExtension<dynamic> extension) =>
                  extension is! FieldNotesColors,
            )
            .followedBy(<ThemeExtension<dynamic>>[
              context.colors.copyWith(placeholder: inks.chrome),
            ]),
      ),
      child: surface,
    );
  }

  Widget _statusLine(
    BuildContext context, {
    required bool compact,
    required bool short,
  }) {
    final String? error = widget.errorMessage;
    final bool urgent = error != null || widget.isSaving;
    final String? line =
        error ??
        (widget.isSaving
            ? widget.savingLabel
            : short
            ? null
            : composerRestingStatus);
    if (line == null) {
      return const SizedBox.shrink();
    }
    final ComposerStageInks inks = ComposerStageInks.of(context);
    final Widget status = Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _statusMinHeight),
        child: Padding(
          padding: _statusPadding,
          child: Text(
            line,
            textAlign: TextAlign.center,
            style: context.textStyles.hintAccent.copyWith(
              fontSize: compact ? _statusCompactSize : _statusSize,
              height: _statusLineHeight,
              color: error != null ? context.colors.dangerInk : inks.status,
            ),
          ),
        ),
      ),
    );
    return urgent ? status : _faded(status);
  }
}

class _TitleThenPagePolicy extends ReadingOrderTraversalPolicy {
  _TitleThenPagePolicy({required this.title, required this.page});

  final FocusNode title;
  final FocusNode page;

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final List<FocusNode> reading = super
        .sortDescendants(descendants, currentNode)
        .toList(growable: false);
    if (!reading.contains(title) || !reading.contains(page)) {
      return reading;
    }
    final List<FocusNode> withoutTitle = <FocusNode>[
      for (final FocusNode node in reading)
        if (!identical(node, title)) node,
    ];
    final int pageAt = withoutTitle.indexOf(page);
    return <FocusNode>[
      ...withoutTitle.take(pageAt),
      title,
      ...withoutTitle.skip(pageAt),
    ];
  }
}

class _StageFieldRing extends StatelessWidget {
  const _StageFieldRing({
    required this.focusNode,
    required this.armed,
    required this.child,
  });

  final FocusNode focusNode;
  final bool armed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color ring = ComposerStageInks.of(context).focus;
    return KeyboardFocusBuilder(
      focusNode: focusNode,
      builder: (BuildContext context, bool keyboardFocused) => Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: <Widget>[
          child,
          if (keyboardFocused && armed)
            Positioned(
              left: -_ringOutset,
              top: -_ringOutset,
              right: -_ringOutset,
              bottom: -_ringOutset,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: focusRingKey,
                  decoration: BoxDecoration(
                    border: Border.all(color: ring, width: _ringWidth),
                    borderRadius: _fieldRadius,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LockPainter extends CustomPainter {
  const _LockPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lockStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / _lockViewBox);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5.5, 10.5, 13, 9.5),
        const Radius.circular(2),
      ),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8.5, 10.5)
        ..lineTo(8.5, 8)
        ..arcToPoint(const Offset(15.5, 8), radius: const Radius.circular(3.5))
        ..lineTo(15.5, 10.5),
      stroke,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LockPainter oldDelegate) => oldDelegate.color != color;
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
