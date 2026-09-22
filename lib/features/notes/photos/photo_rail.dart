import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

import '../model/photo_placement.dart';
import '../notes_providers.dart';
import '../render/note_photo_plan.dart';
import 'photo_caption_sheet.dart';
import 'photo_line_edits.dart';
import 'photo_options_sheet.dart';
import 'photo_placement_diagram.dart';

const String photoRailLabel = 'Photos in this note';
const String photoRailAddLabel = 'Add photo';
const String photoRailAddingLabel = 'Adding…';
const String photoRailMissingLabel = 'Missing';
const String photoRailOptionsHint = 'Opens photo options';
const String photoRailHint =
    'Tap a photo, or put the caret on its line, to place it.';
const String photoRemovedMessage = 'Photo removed';
const String photoRemovedUndoLabel = 'Undo';
const String photoAddFailedMessage =
    'Could not add that photo. Please try again.';

const Duration photoRemovedNoticeLifetime = Duration(seconds: 6);
const Duration photoErrorNoticeLifetime = Duration(seconds: 5);

const Key photoRailKey = ValueKey<String>('photo-rail');
const Key photoRailAddKey = ValueKey<String>('photo-rail-add');
const Key photoRailControlsKey = ValueKey<String>('photo-rail-controls');
const Key photoRailNoticeKey = ValueKey<String>('photo-rail-notice');

Key photoRailThumbKey(int ordinal) =>
    ValueKey<String>('photo-rail-thumb-$ordinal');

const double photoRailThumbExtent = 56;
const double photoRailAddWidth = 72;
const double photoRailPadding = 8;
const double photoRailRowGap = 6;
const double photoRailCompactHeight =
    photoRailThumbExtent + 2 * photoRailPadding;
const double photoRailFullHeight = photoRailCompactHeight +
    photoRailRowGap +
    photoControlTarget +
    photoRailRowGap +
    photoDiagramHeight;
const double photoRailFullMinWidth = photoInlineControlsWidth;
const double photoRailSlimHeight = 36;

const double _thumbGap = 8;
const double _activeBorderWidth = 3;
const double _focusBorderWidth = 3;
const double _plusExtent = 16;
const double _plusStroke = 2;
const double _busyOpacity = 0.5;
const Border _activeBorder = Border.fromBorderSide(
  BorderSide(color: Palette.coral, width: _activeBorderWidth),
);
const Border _focusBorder = Border.fromBorderSide(
  BorderSide(color: Palette.ink, width: _focusBorderWidth),
);

typedef PhotoImporter = Future<List<String>> Function();

@immutable
final class _RailNotice {
  const _RailNotice({required this.message, this.removed});

  final String message;
  final RemovedPhotoLine? removed;
}

class PhotoRail extends StatefulWidget {
  const PhotoRail({
    super.key,
    required this.controller,
    required this.onPickPhotos,
    required this.measure,
    this.resolver,
    this.editorFocusNode,
    this.maxHeight = double.infinity,
  });

  final TextEditingController controller;
  final PhotoImporter onPickPhotos;
  final double measure;
  final MediaResolver? resolver;
  final FocusNode? editorFocusNode;
  final double maxHeight;

  @override
  State<PhotoRail> createState() => _PhotoRailState();
}

class _PhotoRailState extends State<PhotoRail> {
  final FocusNode _addFocus = FocusNode(debugLabel: photoRailAddLabel);
  bool _busy = false;
  bool _addFocused = false;
  _RailNotice? _notice;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _addFocus.dispose();
    super.dispose();
  }

  TextEditingValue get _value => widget.controller.value;

  void _apply(TextEditingValue next) {
    if (next != _value) {
      widget.controller.value = next;
    }
  }

  NotePhotoLine? _activeLine() => photoLineAtCaret(_value);

  NotePhotoLine? _lineAt(int ordinal) {
    final List<NotePhotoLine> lines = notePhotoLines(_value.text);
    return ordinal < lines.length ? lines[ordinal] : null;
  }

  PhotoControlActions get _actions => PhotoControlActions(
        onSide: _setSide,
        onSize: _setSize,
        onMoveUp: _moveUp,
        onMoveDown: _moveDown,
        onReplace: () => unawaited(_replace()),
        onRemove: _remove,
        onCaption: () => unawaited(_caption()),
      );

  void _setSide(PhotoSide side) {
    final NotePhotoLine? line = _activeLine();
    if (line != null) {
      _apply(setPhotoSide(_value, line, side));
    }
  }

  void _setSize(PhotoSize size) {
    final NotePhotoLine? line = _activeLine();
    if (line != null) {
      _apply(setPhotoSize(_value, line, size));
    }
  }

  void _moveUp() {
    final NotePhotoLine? line = _activeLine();
    if (line != null) {
      _apply(movePhotoUp(_value, line));
    }
  }

  void _moveDown() {
    final NotePhotoLine? line = _activeLine();
    if (line != null) {
      _apply(movePhotoDown(_value, line));
    }
  }

  void _remove() {
    final NotePhotoLine? line = _activeLine();
    if (line == null) {
      return;
    }
    final PhotoLineRemoval removal = removePhotoLine(_value, line);
    _apply(removal.value);
    _showNotice(
      _RailNotice(message: photoRemovedMessage, removed: removal.removed),
      photoRemovedNoticeLifetime,
    );
  }

  void _undoRemove() {
    final RemovedPhotoLine? removed = _notice?.removed;
    _clearNotice();
    if (removed != null) {
      _apply(restorePhotoLine(_value, removed));
    }
  }

  Future<void> _caption() async {
    final NotePhotoLine? line = _activeLine();
    if (line == null) {
      return;
    }
    final String? caption = await showPhotoCaptionSheet(
      context,
      caption: line.caption,
    );
    if (caption == null || !mounted) {
      return;
    }
    final NotePhotoLine? target = _lineAt(line.ordinal);
    if (target != null) {
      _apply(setPhotoCaption(_value, target, caption));
    }
  }

  Future<void> _replace() async {
    final NotePhotoLine? line = _activeLine();
    if (line == null) {
      return;
    }
    final List<String>? picked = await _pick();
    if (picked == null || picked.isEmpty || !mounted) {
      return;
    }
    final NotePhotoLine? target = _lineAt(line.ordinal);
    if (target != null) {
      _apply(replacePhotoReference(_value, target, picked.first));
    }
  }

  Future<void> _add() async {
    final bool fromKeyboard = _addFocus.hasFocus;
    final List<String>? picked = await _pick();
    if (picked == null || picked.isEmpty || !mounted) {
      return;
    }
    _apply(insertPhotoLinesAtCaret(_value, picked));
    if (fromKeyboard) {
      widget.editorFocusNode?.requestFocus();
    }
  }

  Future<List<String>?> _pick() async {
    if (_busy) {
      return null;
    }
    setState(() => _busy = true);
    try {
      return await widget.onPickPhotos();
    } on PhotoPickException catch (error) {
      _reportPickFailure(error.message);
      return null;
    } catch (error, stackTrace) {
      debugPrint('Adding a photo to a note failed: $error\n$stackTrace');
      _reportPickFailure(photoAddFailedMessage);
      return null;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool get _slim => widget.maxHeight < photoRailCompactHeight;

  void _reportPickFailure(String message) {
    if (!mounted) {
      return;
    }
    if (_slim) {
      showTransientToast(context, message, glyph: IconStickerGlyph.close);
      return;
    }
    _showNotice(_RailNotice(message: message), photoErrorNoticeLifetime);
  }

  void _showNotice(_RailNotice notice, Duration lifetime) {
    if (!mounted) {
      return;
    }
    _noticeTimer?.cancel();
    setState(() => _notice = notice);
    _noticeTimer = Timer(lifetime, _clearNotice);
  }

  void _clearNotice() {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    if (mounted && _notice != null) {
      setState(() => _notice = null);
    }
  }

  void _onThumbTap(int ordinal, {required bool openOptions}) {
    final NotePhotoLine? line = _lineAt(ordinal);
    if (line == null) {
      return;
    }
    _apply(selectPhotoLine(_value, line));
    if (openOptions) {
      unawaited(
        showPhotoOptionsSheet(
          context,
          value: widget.controller,
          measure: widget.measure,
          resolver: widget.resolver,
          actions: _actions,
        ),
      );
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
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (BuildContext context, TextEditingValue value, Widget? _) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                _rail(context, value, constraints.maxWidth),
          );
        },
      ),
    );
  }

  Widget _rail(BuildContext context, TextEditingValue value, double width) {
    if (_slim) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: _addTile(
          width: photoRailSlimHeight,
          height: photoRailSlimHeight,
        ),
      );
    }
    final bool inline = width >= photoRailFullMinWidth &&
        widget.maxHeight >= photoRailFullHeight;
    final List<NotePhotoLine> lines = notePhotoLines(value.text);
    final int? activeOrdinal = photoLineIndexIn(lines, value.selection);
    final NotePhotoLine? active =
        activeOrdinal == null ? null : lines[activeOrdinal];
    final bool controls = inline && lines.isNotEmpty;
    final _RailNotice? notice = _notice;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: photoRailLabel,
      child: SizedBox(
        key: photoRailKey,
        height: controls ? photoRailFullHeight : photoRailCompactHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: photoRailPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    height: photoRailThumbExtent,
                    child: _strip(lines, activeOrdinal, openOptions: !inline),
                  ),
                  if (controls) _controls(context, value, active),
                ],
              ),
            ),
            if (notice != null)
              Positioned(
                right: 0,
                bottom: photoRailPadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width),
                  child: _noticeToast(notice),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controls(
    BuildContext context,
    TextEditingValue value,
    NotePhotoLine? active,
  ) {
    final double em = NoteColumn.emOf(context);
    if (active == null) {
      return _controlsFor(
        value,
        null,
        planFloat(
          measure: widget.measure,
          em: em,
          side: defaultPhotoSide,
          size: defaultPhotoSize,
        ),
      );
    }
    return PhotoPlanBuilder(
      line: active,
      measure: widget.measure,
      em: em,
      resolver: widget.resolver,
      builder: (BuildContext context, PhotoPlan plan) =>
          _controlsFor(value, active, plan),
    );
  }

  Widget _controlsFor(
    TextEditingValue value,
    NotePhotoLine? active,
    PhotoPlan plan,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: photoRailRowGap),
        Align(
          alignment: Alignment.centerLeft,
          child: PhotoControls(
            key: photoRailControlsKey,
            plan: plan,
            actions: active == null ? null : _actions,
            canMoveUp: active != null && canMovePhotoUp(value.text, active),
            canMoveDown:
                active != null && canMovePhotoDown(value.text, active),
          ),
        ),
        const SizedBox(height: photoRailRowGap),
        SizedBox(
          height: photoDiagramHeight,
          child: active == null
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child:
                      Text(photoRailHint, style: TypographyTokens.captionSans),
                )
              : PhotoPlacementDiagram(plan: plan),
        ),
      ],
    );
  }

  Widget _strip(
    List<NotePhotoLine> lines,
    int? activeOrdinal, {
    required bool openOptions,
  }) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: lines.length + 1,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(width: _thumbGap),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _addTile(
            width: photoRailAddWidth,
            height: photoRailThumbExtent,
          );
        }
        final NotePhotoLine line = lines[index - 1];
        return _thumb(
          line,
          count: lines.length,
          selected: line.ordinal == activeOrdinal,
          openOptions: openOptions,
        );
      },
    );
  }

  Widget _addTile({required double width, required double height}) {
    final bool enabled = !_busy;
    final bool labelled = height >= photoRailThumbExtent;
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
        label: photoRailAddLabel,
        child: GestureDetector(
          key: photoRailAddKey,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => unawaited(_add()) : null,
          child: ExcludeSemantics(
            child: SizedBox(
              width: width,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.cardBright,
                  border: _addFocused ? _focusBorder : Shapes.outline,
                  borderRadius: Shapes.buttonBorderRadius,
                ),
                child: Opacity(
                  opacity: enabled ? 1 : _busyOpacity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox.square(
                        dimension: _plusExtent,
                        child: CustomPaint(painter: _PlusPainter()),
                      ),
                      if (labelled) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          enabled ? photoRailAddLabel : photoRailAddingLabel,
                          style: TypographyTokens.caption10Sans.copyWith(
                            color: Palette.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _thumb(
    NotePhotoLine line, {
    required int count,
    required bool selected,
    required bool openOptions,
  }) {
    final String caption = line.caption;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Photo ${line.ordinal + 1} of $count'
          '${caption.isEmpty ? '' : ', $caption'}',
      hint: openOptions ? photoRailOptionsHint : null,
      child: GestureDetector(
        key: photoRailThumbKey(line.ordinal),
        behavior: HitTestBehavior.opaque,
        onTap: () => _onThumbTap(line.ordinal, openOptions: openOptions),
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: photoRailThumbExtent,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: selected ? _activeBorder : Shapes.outline,
                borderRadius: Shapes.buttonBorderRadius,
              ),
              child: _thumbImage(line),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbImage(NotePhotoLine line) {
    final MediaResolver? resolver = widget.resolver;
    if (resolver == null) {
      return const NeutralMediaPlaceholder(
        width: photoRailThumbExtent,
        height: photoRailThumbExtent,
        borderRadius: Shapes.buttonBorderRadius,
      );
    }
    return MediaImage(
      resolver: resolver,
      mediaId: line.reference,
      errorLabel: photoRailMissingLabel,
      width: photoRailThumbExtent,
      height: photoRailThumbExtent,
      borderRadius: Shapes.buttonBorderRadius,
    );
  }

  Widget _noticeToast(_RailNotice notice) {
    return Semantics(
      key: photoRailNoticeKey,
      container: true,
      liveRegion: true,
      child: Toast(
        message: notice.message,
        action: notice.removed == null
            ? null
            : ToastAction(
                label: photoRemovedUndoLabel,
                onPressed: _undoRemove,
              ),
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

class ComposerPhotoRail extends ConsumerWidget {
  const ComposerPhotoRail({
    super.key,
    required this.controller,
    required this.measure,
    this.editorFocusNode,
    this.maxHeight = double.infinity,
  });

  final TextEditingController controller;
  final double measure;
  final FocusNode? editorFocusNode;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhotoRail(
      controller: controller,
      measure: measure,
      resolver: ref.watch(notesMediaResolverProvider).value,
      editorFocusNode: editorFocusNode,
      maxHeight: maxHeight,
      onPickPhotos: () => importNotePhotos(ref),
    );
  }
}

Future<List<String>> importNotePhotos(WidgetRef ref) async {
  final PhotoPicker picker = ref.read(notePhotoPickerProvider);
  final List<CaptureMedia> picked = await picker.pickFromLibrary();
  if (picked.isEmpty) {
    return const <String>[];
  }
  final NotePhotoStore store = await ref.read(notePhotoStoreProvider.future);
  final List<String> references = <String>[];
  for (final CaptureMedia photo in picked) {
    references.add(await store.importPhoto(photo));
  }
  return List<String>.unmodifiable(references);
}
