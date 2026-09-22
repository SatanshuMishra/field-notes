import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/media_blob.dart';
import 'package:field_notes/domain/notes/notes.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/notes.dart';

import 'markdown_style_controller.dart';
import 'note_editor.dart';
import 'photo_bands.dart';
import 'photo_caption_field.dart';
import 'photo_line_keys.dart';
import 'photo_toolbar.dart';
import 'photo_wrap.dart';
import 'single_field_note_editor.dart';

const double photoBandPadding = 12;
const double inPlacePhotoRingWidth = 2.5;
const double inPlacePhotoFallbackAspect = 4 / 3;
const double noteCaretMargin = 3;
const double inPlaceCaretWidth = 2;
const Duration inPlaceCaretBlink = Duration(milliseconds: 500);
const Color _hiddenCaret = Color(0x00000000);
const double _ringInset = 0;

Key inPlacePhotoKey(int ordinal) => ValueKey<String>('in-place-photo-$ordinal');

const Key inPlacePhotoRingKey = ValueKey<String>('in-place-photo-ring');

const Key inPlaceCaretKey = ValueKey<String>('in-place-caret');

class ComposerMediaScope extends InheritedWidget {
  const ComposerMediaScope({
    super.key,
    required this.resolver,
    required super.child,
  });

  final MediaResolver? resolver;

  static MediaResolver? maybeResolverOf(BuildContext context) {
    final ComposerMediaScope? scope =
        context.dependOnInheritedWidgetOfExactType<ComposerMediaScope>();
    return scope == null
        ? NoteMediaScope.maybeResolverOf(context)
        : scope.resolver;
  }

  @override
  bool updateShouldNotify(ComposerMediaScope oldWidget) =>
      !identical(resolver, oldWidget.resolver);
}

@immutable
class InPlacePhoto {
  const InPlacePhoto({
    required this.line,
    required this.plan,
    required this.media,
    required this.photoHeight,
    required this.figureSize,
    required this.alignX,
    this.wrap,
  });

  final NotePhotoLine line;
  final PhotoPlan plan;
  final ResolvedMedia? media;
  final double photoHeight;
  final Size figureSize;
  final double alignX;
  final PhotoWrap? wrap;

  bool get wraps => wrap != null;

  double get band => figureSize.height + 2 * photoBandPadding;

  double get topPad => wraps ? 0 : photoBandPadding;

  int get anchor => wrap?.anchor ?? line.lineEnd - 1;

  PhotoBand get photoBand =>
      PhotoBand(start: line.lineStart, end: line.lineEnd, height: band);
}

@immutable
class InPlaceLayout {
  const InPlaceLayout({
    required this.photos,
    required this.patches,
    required this.caretFixes,
  });

  static const InPlaceLayout empty = InPlaceLayout(
    photos: <InPlacePhoto>[],
    patches: PhotoPatches.none,
    caretFixes: <PhotoCaretFix>[],
  );

  final List<InPlacePhoto> photos;
  final PhotoPatches patches;
  final List<PhotoCaretFix> caretFixes;
}

InPlaceLayout inPlaceLayoutFor(
  String text, {
  required double measure,
  required double em,
  required TextScaler scaler,
  required PhotoWrapEnv env,
  MediaResolver? resolver,
  int? captionOrdinal,
}) {
  final List<NotePhotoLine> lines = notePhotoLines(text);
  if (lines.isEmpty) {
    return InPlaceLayout.empty;
  }
  final Set<int> starts = <int>{
    for (final NotePhotoLine line in lines) line.lineStart,
  };
  final List<InPlacePhoto> photos = <InPlacePhoto>[];
  final List<PhotoBand> bands = <PhotoBand>[];
  final List<PhotoSpacer> spacers = <PhotoSpacer>[];
  final List<PhotoKern> kerns = <PhotoKern>[];
  final List<PhotoCaretFix> fixes = <PhotoCaretFix>[];
  final Set<int> carriers = <int>{};

  for (final NotePhotoLine line in lines) {
    final bool captioning = line.ordinal == captionOrdinal;
    InPlacePhoto photo = _inPlacePhoto(
      line,
      measure,
      em,
      scaler,
      resolver,
      captioning: captioning,
    );
    PhotoWrap? wrap;
    if (!photo.plan.isStacked) {
      wrap = planPhotoWrap(
        text: text,
        line: line,
        plan: photo.plan,
        figureHeight: photo.figureSize.height,
        env: env,
        photoLineStarts: starts,
      );
      if (wrap == null) {
        photo = _inPlacePhoto(
          line,
          measure,
          em,
          scaler,
          resolver,
          stacked: true,
          captioning: captioning,
        );
      } else {
        photo = InPlacePhoto(
          line: photo.line,
          plan: photo.plan,
          media: photo.media,
          photoHeight: photo.photoHeight,
          figureSize: photo.figureSize,
          alignX: photo.alignX,
          wrap: wrap,
        );
      }
    }
    photos.add(photo);
    final bool carried = carriers.contains(line.lineStart);
    if (wrap == null) {
      final PhotoBand band = photo.photoBand;
      if (!carried) {
        bands.add(band);
      } else if (band.start + 1 < band.end) {
        bands.add(
          PhotoBand(
            start: band.start + 1,
            end: band.end,
            height: band.height,
          ),
        );
      }
      continue;
    }
    for (final PhotoBand band in wrap.patches.bands) {
      if (!carried || band.start != line.lineStart) {
        bands.add(band);
      } else if (band.start + 1 < band.end) {
        bands.add(
          PhotoBand(
            start: band.start + 1,
            end: band.end,
            height: band.height,
          ),
        );
      }
    }
    spacers.addAll(wrap.patches.spacers);
    kerns.addAll(wrap.patches.kerns);
    fixes.addAll(wrap.caretFixes);
    if (wrap.carrier != null) {
      carriers.add(wrap.carrier!);
    }
  }

  return InPlaceLayout(
    photos: photos,
    patches: PhotoPatches(bands: bands, spacers: spacers, kerns: kerns),
    caretFixes: fixes,
  );
}

InPlacePhoto _inPlacePhoto(
  NotePhotoLine line,
  double measure,
  double em,
  TextScaler scaler,
  MediaResolver? resolver, {
  bool stacked = false,
  bool captioning = false,
}) {
  final PhotoPlacement placement = line.placement;
  final ResolvedMedia? media = resolver?.resolved(line.reference);
  final MediaBlob? blob = media?.blob;
  final bool unavailable = media != null && !media.isAvailable;
  final PhotoPlan plan = planFloat(
    measure: measure,
    em: em,
    side: placement.side,
    size: placement.size,
    aspect: photoAspectOf(blob?.width, blob?.height) ??
        inPlacePhotoFallbackAspect,
    nextIsParagraph: line.wrapsParagraph &&
        placement.isValid &&
        !stacked &&
        !unavailable,
  );
  final double photoHeight =
      unavailable ? notePhotoUnavailableHeight : plan.height;
  final double caption = captioning
      ? notePhotoCaptionGap + photoCaptionLineHeight(scaler)
      : line.caption.isEmpty
          ? 0
          : notePhotoCaptionGap +
              _captionHeight(line.caption, plan.width, scaler);
  return InPlacePhoto(
    line: line,
    plan: plan,
    media: media,
    photoHeight: photoHeight,
    figureSize: Size(plan.width, photoHeight + caption),
    alignX: plan.isStacked
        ? 0.5
        : placement.side == PhotoSide.left
            ? 0
            : 1,
  );
}

double _captionHeight(String caption, double width, TextScaler scaler) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: caption, style: notePhotoCaptionStyle),
    textAlign: notePhotoCaptionAlign,
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout(maxWidth: width);
  final double height = painter.height;
  painter.dispose();
  return height;
}

TextSelection? photoCaretSettled(
  TextSelection selection,
  List<PhotoSpacer> spacers,
) {
  if (!selection.isValid || !selection.isCollapsed) {
    return null;
  }
  final int offset = selection.baseOffset;
  for (final PhotoSpacer spacer in spacers) {
    if (spacer.role == PhotoSpacerRole.trailing &&
        offset == spacer.index + 1 &&
        selection.affinity == TextAffinity.upstream) {
      return TextSelection.collapsed(offset: spacer.index);
    }
    if (spacer.role == PhotoSpacerRole.indent &&
        spacer.width > 0 &&
        offset == spacer.index &&
        selection.affinity == TextAffinity.downstream) {
      return TextSelection.collapsed(offset: spacer.index + 1);
    }
  }
  return null;
}

class InPlacePhotoEditor extends NoteEditor {
  const InPlacePhotoEditor({super.key, required super.config});

  @override
  Widget build(BuildContext context) => _InPlacePhotoField(config: config);
}

class _InPlacePhotoField extends StatefulWidget {
  const _InPlacePhotoField({required this.config});

  final NoteEditorConfig config;

  @override
  State<_InPlacePhotoField> createState() => _InPlacePhotoFieldState();
}

class _InPlacePhotoFieldState extends State<_InPlacePhotoField> {
  final GlobalKey _fieldKey = GlobalKey();
  final Set<String> _resolving = <String>{};
  String? _layoutText;
  PhotoWrapEnv? _layoutEnv;
  InPlaceLayout _layout = InPlaceLayout.empty;
  List<Rect> _figures = const <Rect>[];
  int? _layoutCaption;
  int? _captionFor;

  NoteEditorConfig get _config => widget.config;

  MarkdownStyleController get _controller => _config.controller;

  @override
  void initState() {
    super.initState();
    _config.focusNode.addListener(_rebuild);
    _config.scrollController.addListener(_scrolled);
  }

  @override
  void dispose() {
    _config.focusNode.removeListener(_rebuild);
    _config.scrollController.removeListener(_scrolled);
    dismissTransientToast();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrolled() {
    if (_selectedPhoto(_layout.photos, _controller.selection) != null) {
      _rebuild();
    }
  }

  void _figuresLaidOut(List<Rect> rects) {
    if (_sameRects(_figures, rects)) {
      return;
    }
    _figures = rects;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _rebuild());
  }

  @override
  Widget build(BuildContext context) {
    final MediaResolver? resolver = ComposerMediaScope.maybeResolverOf(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle style = unmergedFromTheMaterialTextTheme(_config.style);
    final StrutStyle strut =
        StrutStyle.fromTextStyle(style, forceStrutHeight: false);
    final double em = scaler.scale(
      style.fontSize ?? TypographyTokens.noteBody.fontSize!,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double viewport =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 0;
        final PhotoWrapEnv env = PhotoWrapEnv(
          textWidth: width - noteCaretMargin,
          style: style,
          strut: strut,
          scaler: scaler,
          styleLimit: _controller.styleLimit,
        );
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (BuildContext context, TextEditingValue value, Widget? _) {
            final InPlaceLayout layout = _layoutFor(
              value.text,
              width: width,
              em: em,
              scaler: scaler,
              env: env,
              resolver: resolver,
            );
            _resolveMissing(layout.photos, resolver);
            final PhotoCaretFix? fix = _fixFor(layout, value.selection);
            final bool hideCaret =
                fix != null || _caretOnPhoto(layout.photos, value.selection);
            final int? selected =
                _selectedPhoto(layout.photos, value.selection);
            final double inset = _config.bottomInset;
            final ToolbarSpot? toolbar = selected == null
                ? null
                : _toolbarSpot(selected, math.max(0, viewport - inset));
            return _PhotoKeys(
              controller: _controller,
              spacers: layout.patches.spacers,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                ),
                child: SingleChildScrollView(
                  controller: _config.scrollController,
                  child: Stack(
                    children: <Widget>[
                      _PhotoCanvas(
                        minHeight: viewport,
                        bottomInset: inset,
                        placements: <PhotoSpot>[
                          for (final InPlacePhoto photo in layout.photos)
                            PhotoSpot(
                              anchor: photo.anchor,
                              size: photo.figureSize,
                              alignX: photo.alignX,
                              top: photo.topPad,
                              bottom: photo.topPad,
                            ),
                        ],
                        caret: fix == null || !_config.focusNode.hasFocus
                            ? null
                            : CaretSpot(
                                offset: value.selection.baseOffset,
                                dx: fix.dx,
                                upstream: fix.upstream,
                              ),
                        toolbar: toolbar,
                        onFigures: _figuresLaidOut,
                        children: <Widget>[
                          PhotoBandScope(
                            patches: layout.patches,
                            child: KeyedSubtree(
                              key: _fieldKey,
                              child: noteTextField(
                                context,
                                _config,
                                cursorColor: hideCaret ? _hiddenCaret : null,
                                inputFormatters: const <TextInputFormatter>[
                                  PhotoLineGuard(),
                                ],
                                strutStyle: strut,
                                selectionHeightStyle: BoxHeightStyle.max,
                                scrolls: false,
                                onTap: _settleCaret,
                              ),
                            ),
                          ),
                          for (final InPlacePhoto photo in layout.photos)
                            TextFieldTapRegion(
                              child: _InPlaceFigure(
                                key: inPlacePhotoKey(photo.line.ordinal),
                                photo: photo,
                                resolver: resolver,
                                selected: selectionTouchesPhoto(
                                  photo.line,
                                  value.selection,
                                ),
                                onTap: () => _select(photo.line.ordinal),
                                caption: _captionFieldFor(photo, scaler),
                              ),
                            ),
                          if (fix != null && _config.focusNode.hasFocus)
                            _BlinkingCaret(
                              key: ValueKey<int>(value.selection.baseOffset),
                              color: _config.cursorColor,
                            ),
                          if (toolbar != null)
                            _toolbarFor(
                              layout.photos[toolbar.index],
                              width,
                              em,
                            ),
                        ],
                      ),
                      if (value.text.isEmpty)
                        Positioned(
                          left: 0,
                          top: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Text(
                              _config.hintText,
                              style: _config.hintStyle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InPlaceLayout _layoutFor(
    String text, {
    required double width,
    required double em,
    required TextScaler scaler,
    required PhotoWrapEnv env,
    MediaResolver? resolver,
  }) {
    if (_layoutText == text &&
        _layoutEnv == env &&
        _layoutCaption == _captionFor) {
      return _layout;
    }
    _layout = inPlaceLayoutFor(
      text,
      measure: width,
      em: em,
      scaler: scaler,
      env: env,
      resolver: resolver,
      captionOrdinal: _captionFor,
    );
    _layoutText = text;
    _layoutEnv = env;
    _layoutCaption = _captionFor;
    return _layout;
  }

  PhotoCaretFix? _fixFor(InPlaceLayout layout, TextSelection selection) {
    if (!selection.isValid || !selection.isCollapsed) {
      return null;
    }
    for (final PhotoCaretFix fix in layout.caretFixes) {
      if (fix.covers(selection.baseOffset)) {
        return fix;
      }
    }
    return null;
  }

  int? _selectedPhoto(List<InPlacePhoto> photos, TextSelection selection) {
    int? only;
    for (int i = 0; i < photos.length; i++) {
      if (!selectionTouchesPhoto(photos[i].line, selection)) {
        continue;
      }
      if (only != null) {
        return null;
      }
      only = i;
    }
    return only;
  }

  ToolbarSpot? _toolbarSpot(int index, double viewport) {
    if (index >= _figures.length) {
      return null;
    }
    final Rect figure = _figures[index];
    if (figure.isEmpty) {
      return null;
    }
    final double top = _config.scrollController.hasClients
        ? _config.scrollController.offset
        : 0;
    if (viewport > 0 &&
        (figure.bottom + photoBandPadding <= top ||
            figure.top - photoBandPadding >= top + viewport)) {
      return null;
    }
    return ToolbarSpot(index: index, viewportTop: top);
  }

  Widget _toolbarFor(InPlacePhoto photo, double measure, double em) {
    return TextFieldTapRegion(
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onToolbarKey,
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: PhotoToolbar(
            controller: _controller,
            line: photo.line,
            measure: measure,
            em: em,
            media: photo.media,
            importer: _config.photoImporter,
            onCaption: () => _openCaption(photo.line.ordinal),
            onRemove: _config.focusNode.requestFocus,
          ),
        ),
      ),
    );
  }

  KeyEventResult _onToolbarKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final TextEditingValue? next = deselectPhoto(_controller.value);
    _config.focusNode.requestFocus();
    if (next != null) {
      _controller.value = next;
    }
    return KeyEventResult.handled;
  }

  Widget? _captionFieldFor(InPlacePhoto photo, TextScaler scaler) {
    final int ordinal = photo.line.ordinal;
    if (_captionFor != ordinal) {
      return null;
    }
    return PhotoCaptionField(
      caption: photo.line.caption,
      width: photo.plan.width,
      height: photoCaptionLineHeight(scaler),
      onCommit: (String caption) => _commitCaption(ordinal, caption),
      onCancel: _closeCaption,
    );
  }

  void _openCaption(int ordinal) {
    if (_captionFor != ordinal) {
      setState(() => _captionFor = ordinal);
    }
  }

  void _closeCaption() {
    if (_captionFor != null) {
      setState(() => _captionFor = null);
    }
    _config.focusNode.requestFocus();
  }

  void _commitCaption(int ordinal, String caption) {
    final List<NotePhotoLine> lines = notePhotoLines(_controller.text);
    if (ordinal < lines.length) {
      _controller.value = setPhotoCaption(
        _controller.value,
        lines[ordinal],
        caption,
      );
    }
    _closeCaption();
  }

  bool _caretOnPhoto(List<InPlacePhoto> photos, TextSelection selection) {
    if (!selection.isValid || !selection.isCollapsed) {
      return false;
    }
    return photos.any(
      (InPlacePhoto photo) => photo.line.containsOffset(selection.baseOffset),
    );
  }

  void _settleCaret() {
    final TextSelection? next = photoCaretSettled(
      _controller.selection,
      _layout.patches.spacers,
    );
    if (next != null) {
      _controller.selection = next;
    }
  }

  void _select(int ordinal) {
    final TextEditingValue value = _controller.value;
    final List<NotePhotoLine> lines = notePhotoLines(value.text);
    if (ordinal >= lines.length) {
      return;
    }
    _config.focusNode.requestFocus();
    _controller.value = selectPhotoLine(value, lines[ordinal]);
  }

  void _resolveMissing(List<InPlacePhoto> photos, MediaResolver? resolver) {
    if (resolver == null) {
      return;
    }
    for (final InPlacePhoto photo in photos) {
      final String reference = photo.line.reference;
      if (photo.media != null || !_resolving.add(reference)) {
        continue;
      }
      resolver.resolve(reference).whenComplete(() {
        if (mounted) {
          setState(() {
            _layoutText = null;
          });
        }
      });
    }
  }
}

class _PhotoKeys extends StatelessWidget {
  const _PhotoKeys({
    required this.controller,
    required this.spacers,
    required this.child,
  });

  final TextEditingController controller;
  final List<PhotoSpacer> spacers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: Actions(
        actions: <Type, Action<Intent>>{
          DeleteCharacterIntent: _PhotoDeleteAction(controller),
          ExtendSelectionByCharacterIntent: _PhotoStepAction(controller),
          ExtendSelectionVerticallyToAdjacentLineIntent: _PhotoSettleAction<
              ExtendSelectionVerticallyToAdjacentLineIntent>(
            controller,
            spacers,
          ),
          ExtendSelectionToLineBreakIntent:
              _PhotoSettleAction<ExtendSelectionToLineBreakIntent>(
            controller,
            spacers,
          ),
        },
        child: child,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final TextEditingValue? next = deselectPhoto(controller.value);
    if (next == null) {
      return KeyEventResult.ignored;
    }
    controller.value = next;
    return KeyEventResult.handled;
  }
}

class _PhotoDeleteAction extends ContextAction<DeleteCharacterIntent> {
  _PhotoDeleteAction(this.controller);

  final TextEditingController controller;

  @override
  Object? invoke(DeleteCharacterIntent intent, [BuildContext? context]) {
    final TextEditingValue? next =
        photoAwareDelete(controller.value, forward: intent.forward);
    if (next == null) {
      return callingAction?.invoke(intent);
    }
    controller.value = next;
    return null;
  }
}

class _PhotoStepAction extends ContextAction<ExtendSelectionByCharacterIntent> {
  _PhotoStepAction(this.controller);

  final TextEditingController controller;

  @override
  Object? invoke(
    ExtendSelectionByCharacterIntent intent, [
    BuildContext? context,
  ]) {
    final TextEditingValue? next = photoAwareStep(
      controller.value,
      forward: intent.forward,
      collapse: intent.collapseSelection,
    );
    if (next == null) {
      return callingAction?.invoke(intent);
    }
    controller.value = next;
    return null;
  }
}

class _PhotoSettleAction<T extends Intent> extends ContextAction<T> {
  _PhotoSettleAction(this.controller, this.spacers);

  final TextEditingController controller;
  final List<PhotoSpacer> spacers;

  @override
  Object? invoke(T intent, [BuildContext? context]) {
    final Object? result = callingAction?.invoke(intent);
    final TextSelection? next = photoCaretSettled(
      controller.selection,
      spacers,
    );
    if (next != null) {
      controller.selection = next;
    }
    return result;
  }
}

@immutable
class PhotoSpot {
  const PhotoSpot({
    required this.anchor,
    required this.size,
    required this.alignX,
    required this.top,
    required this.bottom,
  });

  final int anchor;
  final Size size;
  final double alignX;
  final double top;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoSpot &&
          anchor == other.anchor &&
          size == other.size &&
          alignX == other.alignX &&
          top == other.top &&
          bottom == other.bottom;

  @override
  int get hashCode => Object.hash(anchor, size, alignX, top, bottom);
}

@immutable
class CaretSpot {
  const CaretSpot({
    required this.offset,
    required this.dx,
    required this.upstream,
  });

  final int offset;
  final double dx;
  final bool upstream;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaretSpot &&
          offset == other.offset &&
          dx == other.dx &&
          upstream == other.upstream;

  @override
  int get hashCode => Object.hash(offset, dx, upstream);
}

@immutable
class ToolbarSpot {
  const ToolbarSpot({required this.index, required this.viewportTop});

  final int index;
  final double viewportTop;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolbarSpot &&
          index == other.index &&
          viewportTop == other.viewportTop;

  @override
  int get hashCode => Object.hash(index, viewportTop);
}

class _PhotoCanvas extends MultiChildRenderObjectWidget {
  const _PhotoCanvas({
    required this.placements,
    required this.minHeight,
    required this.bottomInset,
    required this.caret,
    required this.toolbar,
    required this.onFigures,
    required super.children,
  });

  final List<PhotoSpot> placements;
  final double minHeight;
  final double bottomInset;
  final CaretSpot? caret;
  final ToolbarSpot? toolbar;
  final ValueChanged<List<Rect>> onFigures;

  @override
  RenderPhotoCanvas createRenderObject(BuildContext context) {
    return RenderPhotoCanvas(
      spots: placements,
      height: minHeight,
      reserved: bottomInset,
      spot: caret,
      bar: toolbar,
      figures: onFigures,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPhotoCanvas renderObject,
  ) {
    renderObject
      ..placements = placements
      ..minHeight = minHeight
      ..bottomInset = bottomInset
      ..caret = caret
      ..toolbar = toolbar
      ..onFigures = onFigures;
  }
}

bool _sameRects(List<Rect> a, List<Rect> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

class _CanvasParentData extends ContainerBoxParentData<RenderBox> {
  bool visible = true;
}

class RenderPhotoCanvas extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CanvasParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CanvasParentData> {
  RenderPhotoCanvas({
    required List<PhotoSpot> spots,
    required double height,
    required double reserved,
    required CaretSpot? spot,
    required ToolbarSpot? bar,
    required ValueChanged<List<Rect>> figures,
  })  : _placements = spots,
        _minHeight = height,
        _inset = reserved,
        _caret = spot,
        _toolbar = bar,
        _onFigures = figures;

  static bool _sameSpots(List<PhotoSpot> a, List<PhotoSpot> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  List<PhotoSpot> _placements;
  double _minHeight;
  double _inset;
  CaretSpot? _caret;
  ToolbarSpot? _toolbar;
  ValueChanged<List<Rect>> _onFigures;

  set toolbar(ToolbarSpot? value) {
    if (_toolbar == value) {
      return;
    }
    _toolbar = value;
    markNeedsLayout();
  }

  set onFigures(ValueChanged<List<Rect>> value) => _onFigures = value;

  set placements(List<PhotoSpot> value) {
    if (_sameSpots(_placements, value)) {
      return;
    }
    _placements = value;
    markNeedsLayout();
  }

  set minHeight(double value) {
    if (_minHeight == value) {
      return;
    }
    _minHeight = value;
    markNeedsLayout();
  }

  set bottomInset(double value) {
    if (_inset == value) {
      return;
    }
    _inset = value;
    markNeedsLayout();
  }

  set caret(CaretSpot? value) {
    if (_caret == value) {
      return;
    }
    _caret = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CanvasParentData) {
      child.parentData = _CanvasParentData();
    }
  }

  @override
  void performLayout() {
    final List<RenderBox> children = getChildrenAsList();
    if (children.isEmpty) {
      size = constraints.smallest;
      return;
    }
    final double width = constraints.maxWidth;
    final RenderBox field = children.first;
    field.layout(
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: math.max(0, _minHeight - _inset),
      ),
      parentUsesSize: true,
    );
    _data(field).offset = Offset.zero;
    final RenderEditable? editable = _editableUnder(field);
    double bottom = field.size.height;
    final List<Rect> figures = <Rect>[];
    for (int i = 0; i < _placements.length; i++) {
      final int index = i + 1;
      if (index >= children.length) {
        break;
      }
      final PhotoSpot placement = _placements[i];
      final RenderBox child = children[index];
      child.layout(BoxConstraints.tight(placement.size), parentUsesSize: true);
      final _CanvasParentData data = _data(child);
      final double? top = _anchorTop(editable, placement.anchor);
      data.visible = top != null;
      if (top == null) {
        data.offset = Offset.zero;
        figures.add(Rect.zero);
        continue;
      }
      data.offset = Offset(
        (width - placement.size.width) * placement.alignX,
        top + placement.top,
      );
      figures.add(data.offset & placement.size);
      bottom = math.max(
        bottom,
        data.offset.dy + placement.size.height + placement.bottom,
      );
    }
    _onFigures(figures);
    final int caretIndex = _placements.length + 1;
    if (caretIndex < children.length) {
      final RenderBox caretBox = children[caretIndex];
      final Rect? rect = _caretRect(editable);
      final _CanvasParentData data = _data(caretBox);
      data.visible = rect != null;
      caretBox.layout(
        BoxConstraints.tight(
          Size(inPlaceCaretWidth, rect?.height ?? 0),
        ),
      );
      data.offset = rect?.topLeft ?? Offset.zero;
    }
    final double content = math.max(_minHeight, bottom + _inset);
    _layOutToolbar(children, figures, width, content);

    size = constraints.constrain(Size(width, content));
  }

  void _layOutToolbar(
    List<RenderBox> children,
    List<Rect> figures,
    double width,
    double content,
  ) {
    final int index = _placements.length + (_caret == null ? 1 : 2);
    if (index >= children.length) {
      return;
    }
    final RenderBox bar = children[index];
    bar.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    final _CanvasParentData data = _data(bar);
    final ToolbarSpot? spot = _toolbar;
    final Rect? figure = spot != null && spot.index < figures.length
        ? figures[spot.index]
        : null;
    data.visible = figure != null && !figure.isEmpty;
    if (figure == null || figure.isEmpty) {
      data.offset = Offset.zero;
      return;
    }
    data.offset = Offset(
      (figure.center.dx - bar.size.width / 2)
          .clamp(0.0, math.max(0.0, width - bar.size.width)),
      _besideFigure(
        figure,
        spot!.viewportTop.clamp(0.0, math.max(0.0, content - _minHeight)),
        bar.size.height,
      ),
    );
  }

  double _besideFigure(Rect figure, double viewportTop, double height) {
    final double above = figure.top - photoToolbarGap - height;
    if (_minHeight <= 0) {
      return above;
    }
    final double top = viewportTop + photoToolbarGap;
    final double bottom =
        viewportTop + _minHeight - _inset - photoToolbarGap - height;
    if (bottom <= top) {
      return top;
    }
    if (above >= top) {
      return math.min(above, bottom);
    }
    final double below = figure.bottom + photoToolbarGap;
    if (below <= bottom) {
      return math.max(below, top);
    }
    return math.max(top, math.min(figure.top + photoToolbarGap, bottom));
  }


  Rect? _caretRect(RenderEditable? editable) {
    final CaretSpot? spot = _caret;
    if (editable == null || spot == null || !editable.hasSize) {
      return null;
    }
    final int offset = spot.offset;
    if (offset < 0 || offset > editable.plainText.length) {
      return null;
    }
    final Offset origin = _originOf(editable);
    if (!spot.upstream && offset < editable.plainText.length) {
      final TextBox? box = _boxAt(editable, offset, offset + 1, last: false);
      if (box == null) {
        return null;
      }
      return Rect.fromLTWH(
        box.left + spot.dx + origin.dx,
        box.top + origin.dy,
        inPlaceCaretWidth,
        box.bottom - box.top,
      );
    }
    final TextBox? box = _boxAt(editable, offset - 1, offset, last: true);
    if (box == null) {
      return null;
    }
    final double height = box.bottom - box.top;
    if (spot.upstream) {
      return Rect.fromLTWH(
        box.right + spot.dx + origin.dx,
        box.top + origin.dy,
        inPlaceCaretWidth,
        height,
      );
    }
    return Rect.fromLTWH(
      spot.dx + origin.dx,
      box.bottom + origin.dy,
      inPlaceCaretWidth,
      height,
    );
  }

  TextBox? _boxAt(
    RenderEditable editable,
    int from,
    int to, {
    required bool last,
  }) {
    if (from < 0 || to > editable.plainText.length) {
      return null;
    }
    final List<TextBox> boxes = editable.getBoxesForSelection(
      TextSelection(baseOffset: from, extentOffset: to),
    );
    if (boxes.isEmpty) {
      return null;
    }
    return last ? boxes.last : boxes.first;
  }

  double? _anchorTop(RenderEditable? editable, int anchor) {
    if (editable == null || !editable.hasSize || anchor < 0) {
      return null;
    }
    if (anchor + 1 > editable.plainText.length) {
      return null;
    }
    final List<TextBox> boxes = editable.getBoxesForSelection(
      TextSelection(baseOffset: anchor, extentOffset: anchor + 1),
    );
    if (boxes.isEmpty) {
      return null;
    }
    return boxes.first.top + _originOf(editable).dy;
  }

  Offset _originOf(RenderEditable editable) =>
      MatrixUtils.transformPoint(editable.getTransformTo(this), Offset.zero);

  _CanvasParentData _data(RenderBox child) =>
      child.parentData! as _CanvasParentData;

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderBox? child = firstChild;
    while (child != null) {
      final _CanvasParentData data = _data(child);
      if (data.visible) {
        context.paintChild(child, data.offset + offset);
      }
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final _CanvasParentData data = _data(child);
      if (data.visible) {
        final bool hit = result.addWithPaintOffset(
          offset: data.offset,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) =>
              child!.hitTest(result, position: transformed),
        );
        if (hit) {
          return true;
        }
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final Offset offset = _data(child).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
}

RenderEditable? _editableUnder(RenderObject? root) {
  if (root == null) {
    return null;
  }
  if (root is RenderEditable) {
    return root;
  }
  RenderEditable? found;
  root.visitChildren((RenderObject child) {
    found ??= _editableUnder(child);
  });
  return found;
}

class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret({super.key, required this.color});

  final Color color;

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret> {
  Timer? _timer;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    if (!EditableText.debugDeterministicCursor) {
      _timer = Timer.periodic(inPlaceCaretBlink, (Timer _) {
        if (mounted) {
          setState(() => _on = !_on);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: _on ? 1 : 0,
        child: DecoratedBox(
          key: inPlaceCaretKey,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: const BorderRadius.all(Radius.circular(1)),
          ),
        ),
      ),
    );
  }
}

class _InPlaceFigure extends StatelessWidget {
  const _InPlaceFigure({
    super.key,
    required this.photo,
    required this.resolver,
    required this.selected,
    required this.onTap,
    required this.caption,
  });

  final InPlacePhoto photo;
  final MediaResolver? resolver;
  final bool selected;
  final VoidCallback onTap;
  final Widget? caption;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DefaultTextStyle(
          style: notePhotoCaptionStyle,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (caption == null) _figure(photo.line.block) else _captioning(),
              if (selected)
                Positioned(
                  left: -_ringInset,
                  top: -_ringInset,
                  width: photo.plan.width + 2 * _ringInset,
                  height: photo.photoHeight + 2 * _ringInset,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      key: inPlacePhotoRingKey,
                      decoration: BoxDecoration(
                        border: Border.fromBorderSide(
                          BorderSide(
                            color: Palette.coral,
                            width: inPlacePhotoRingWidth,
                          ),
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(Shapes.radiusSm),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _captioning() {
    return SizedBox(
      width: photo.plan.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _figure(_uncaptioned(photo.line.block)),
          const SizedBox(height: notePhotoCaptionGap),
          caption!,
        ],
      ),
    );
  }

  Widget _figure(PhotoBlock block) {
    final MediaResolver? resolver = this.resolver;
    if (resolver == null) {
      return SizedBox(
        width: photo.plan.width,
        height: photo.photoHeight,
        child: const NeutralMediaPlaceholder(
          borderRadius: BorderRadius.zero,
        ),
      );
    }
    return NotePhotoFigure(
      block: block,
      resolver: resolver,
      media: photo.media,
      plan: photo.plan,
    );
  }
}

PhotoBlock _uncaptioned(PhotoBlock block) => PhotoBlock(
      alt: '',
      reference: block.reference,
      attributes: block.attributes,
      altRange: block.altRange,
      referenceRange: block.referenceRange,
      attributesRange: block.attributesRange,
      sourceRange: block.sourceRange,
      markerRanges: block.markerRanges,
    );
