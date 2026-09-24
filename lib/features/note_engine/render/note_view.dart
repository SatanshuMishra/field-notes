import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/photo_figure.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

Key notePhotoKey(String reference, int occurrence) =>
    ValueKey<String>('photo-$reference-$occurrence');

Future<Size?> readImageFileSize(File file) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final int width = descriptor.width;
    final int height = descriptor.height;
    return width > 0 && height > 0
        ? Size(width.toDouble(), height.toDouble())
        : null;
  } on Object {
    return null;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}

class NoteView extends StatefulWidget {
  const NoteView({
    super.key,
    required this.source,
    required this.tree,
    required this.visibleText,
    required this.runLayout,
    this.mediaResolver,
    this.activeLine,
    this.selection,
    this.composing = TextRange.empty,
    this.focused = false,
    this.readOnly = false,
    this.scrollController,
    this.bottomInset = 0,
    this.hintText = '',
    this.hintStyle = TypographyTokens.noteBodyPlaceholder,
    this.cursorColor = Palette.coral,
    this.selectionColor,
    this.platformValue,
    this.platformValueStart = 0,
    this.delegate,
    this.startHandleLayerLink,
    this.endHandleLayerLink,
    this.toolbarLayerLink,
    this.selectedCaptionHidden = false,
    this.decorations = const <NoteViewDecoration>[],
    this.renderKey,
    this.onFontsChanged,
  });

  final String source;
  final MdTree tree;
  final VisibleText visibleText;
  final NoteLayoutRunner runLayout;
  final MediaResolver? mediaResolver;
  final int? activeLine;
  final NoteSelection? selection;
  final TextRange composing;
  final bool focused;
  final bool readOnly;
  final ScrollController? scrollController;
  final double bottomInset;
  final String hintText;
  final TextStyle hintStyle;
  final Color cursorColor;
  final Color? selectionColor;
  final TextEditingValue? platformValue;
  final int platformValueStart;
  final NoteViewDelegate? delegate;
  final LayerLink? startHandleLayerLink;
  final LayerLink? endHandleLayerLink;
  final LayerLink? toolbarLayerLink;
  final bool selectedCaptionHidden;
  final List<NoteViewDecoration> decorations;
  final GlobalKey? renderKey;
  final VoidCallback? onFontsChanged;

  @override
  State<NoteView> createState() => _NoteViewState();
}

final class _PhotoBlock {
  const _PhotoBlock({
    required this.line,
    required this.range,
    required this.occurrence,
  });

  final MdPhotoLine line;
  final TextRange range;
  final int occurrence;
}

List<_PhotoBlock> _photoBlocksOf(MdTree tree, String source) {
  final Map<String, int> seen = <String, int>{};
  final List<_PhotoBlock> photos = <_PhotoBlock>[];
  for (final MdBlock block in tree.blocks) {
    if (block.kind != MdBlockKind.photoLine) {
      continue;
    }
    final MdPhotoLine line = MdPhotoLine.ofBlock(block, source);
    final int occurrence = seen[line.reference] ?? 0;
    seen[line.reference] = occurrence + 1;
    photos.add(
      _PhotoBlock(
        line: line,
        range: TextRange(
          start: block.sourceRange.start,
          end: block.sourceRange.end,
        ),
        occurrence: occurrence,
      ),
    );
  }
  return List<_PhotoBlock>.unmodifiable(photos);
}

class _NoteViewState extends State<NoteView> {
  List<_PhotoBlock> _photos = const <_PhotoBlock>[];
  Map<String, ResolvedMedia> _media = const <String, ResolvedMedia>{};
  Set<String> _requested = const <String>{};
  Map<String, Size> _readSizes = const <String, Size>{};
  Set<String> _sizeReads = const <String>{};
  Set<String> _undecodable = const <String>{};
  bool _laidOut = false;
  LayoutInputs? _lastInputs;
  LaidOutNote? _lastLayout;
  String? _readerSource;
  MdTree? _readerTree;
  VisibleText? _readerVisible;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_handleFontsChanged);
    _photos = _photoBlocksOf(widget.tree, widget.source);
    _syncMedia();
  }

  @override
  void didUpdateWidget(NoteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.mediaResolver, widget.mediaResolver)) {
      _media = const <String, ResolvedMedia>{};
      _requested = const <String>{};
      _readSizes = const <String, Size>{};
      _sizeReads = const <String>{};
      _undecodable = const <String>{};
    }
    if (!identical(oldWidget.tree, widget.tree) ||
        oldWidget.source != widget.source) {
      _photos = _photoBlocksOf(widget.tree, widget.source);
    }
    _syncMedia();
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_handleFontsChanged);
    super.dispose();
  }

  void _handleFontsChanged() {
    widget.onFontsChanged?.call();
    setState(() {
      _lastInputs = null;
      _lastLayout = null;
    });
  }

  Set<String> get _resolvableReferences => <String>{
    for (final _PhotoBlock photo in _photos)
      if (photo.line.canResolve) photo.line.reference,
  };

  void _syncMedia() {
    final MediaResolver? resolver = widget.mediaResolver;
    if (resolver == null) {
      return;
    }
    final Map<String, ResolvedMedia> known = <String, ResolvedMedia>{..._media};
    for (final String reference in _resolvableReferences) {
      if (known.containsKey(reference)) {
        continue;
      }
      final ResolvedMedia? memoized = resolver.resolved(reference);
      if (memoized != null) {
        known[reference] = memoized;
      } else if (!_requested.contains(reference)) {
        _request(resolver, reference);
      }
    }
    _media = Map<String, ResolvedMedia>.unmodifiable(known);
    _startSizeReads();
  }

  void _request(MediaResolver resolver, String reference) {
    _requested = Set<String>.unmodifiable(<String>{..._requested, reference});
    Future<ResolvedMedia>.sync(() => resolver.resolve(reference))
        .catchError((Object _) => const ResolvedMedia.missing())
        .then((ResolvedMedia media) {
          if (!mounted || !identical(widget.mediaResolver, resolver)) {
            return;
          }
          setState(() {
            _media = Map<String, ResolvedMedia>.unmodifiable(
              <String, ResolvedMedia>{..._media, reference: media},
            );
          });
          _startSizeReads();
        });
  }

  void _startSizeReads() {
    final MediaResolver? resolver = widget.mediaResolver;
    for (final MapEntry<String, ResolvedMedia> entry in _media.entries) {
      final String reference = entry.key;
      final ResolvedMedia media = entry.value;
      final File? file = media.file;
      if (!media.isAvailable ||
          file == null ||
          _dimensionsOf(media) != null ||
          _sizeReads.contains(reference)) {
        continue;
      }
      _sizeReads = Set<String>.unmodifiable(<String>{..._sizeReads, reference});
      readImageFileSize(file).then((Size? read) {
        if (read == null ||
            !mounted ||
            !identical(widget.mediaResolver, resolver)) {
          return;
        }
        setState(() {
          _readSizes = Map<String, Size>.unmodifiable(<String, Size>{
            ..._readSizes,
            reference: read,
          });
        });
      });
    }
  }

  static Size? _dimensionsOf(ResolvedMedia media) {
    final int? width = media.blob?.width;
    final int? height = media.blob?.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return Size(width.toDouble(), height.toDouble());
  }

  void _markUndecodable(String reference) {
    if (_undecodable.contains(reference) || !mounted) {
      return;
    }
    setState(() {
      _undecodable = Set<String>.unmodifiable(<String>{
        ..._undecodable,
        reference,
      });
    });
  }

  bool get _mediaReady {
    if (_laidOut || widget.mediaResolver == null) {
      return true;
    }
    return _resolvableReferences.every(_media.containsKey);
  }

  ({Map<String, Size> dimensions, Set<String> unavailable}) _mediaInputs() {
    final Map<String, Size> dimensions = <String, Size>{};
    final Set<String> unavailable = <String>{};
    for (final _PhotoBlock photo in _photos) {
      final String reference = photo.line.reference;
      if (!photo.line.canResolve || _undecodable.contains(reference)) {
        unavailable.add(reference);
        continue;
      }
      final ResolvedMedia? media = _media[reference];
      if (media == null) {
        continue;
      }
      if (!media.isAvailable) {
        unavailable.add(reference);
        continue;
      }
      final Size? size = _dimensionsOf(media) ?? _readSizes[reference];
      if (size != null) {
        dimensions[reference] = size;
      }
    }
    return (dimensions: dimensions, unavailable: unavailable);
  }

  VisibleText _visibleTextFor() {
    if (!widget.readOnly || widget.visibleText.activeLine == null) {
      return widget.visibleText;
    }
    final VisibleText? cached = _readerVisible;
    if (cached != null &&
        identical(_readerSource, widget.source) &&
        identical(_readerTree, widget.tree)) {
      return cached;
    }
    final VisibleText projected = const NoteVisibleProjector().project(
      widget.source,
      widget.tree,
      null,
    );
    _readerSource = widget.source;
    _readerTree = widget.tree;
    _readerVisible = projected;
    return projected;
  }

  LaidOutNote _layoutFor(LayoutInputs inputs) {
    final LayoutInputs? last = _lastInputs;
    final LaidOutNote? laidOut = _lastLayout;
    if (last != null && laidOut != null && last == inputs) {
      return laidOut;
    }
    final LaidOutNote fresh = widget.runLayout(inputs);
    _lastInputs = inputs;
    _lastLayout = fresh;
    _laidOut = true;
    return fresh;
  }

  Color _selectionColorOf(BuildContext context) {
    final Color? given = widget.selectionColor;
    if (given != null) {
      return given;
    }
    final Color? inherited = DefaultSelectionStyle.of(context).selectionColor;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return inherited ??
            CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.4);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return inherited ??
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.4);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_mediaReady) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        assert(constraints.maxWidth.isFinite, 'NoteView needs a finite width.');
        final bool readOnly = widget.readOnly;
        final int? activeLine = readOnly ? null : widget.activeLine;
        final VisibleText visibleText = _visibleTextFor();
        final ({Map<String, Size> dimensions, Set<String> unavailable}) media =
            _mediaInputs();
        final LaidOutNote layout = _layoutFor(
          LayoutInputs(
            source: widget.source,
            tree: widget.tree,
            visibleText: visibleText,
            activeLine: activeLine,
            columnWidth: constraints.maxWidth,
            textScaler: MediaQuery.textScalerOf(context),
            boldText: MediaQuery.boldTextOf(context),
            locale:
                Localizations.maybeLocaleOf(context) ??
                const Locale('en', 'US'),
            readerMode: readOnly,
            mediaDimensions: media.dimensions,
            unavailableMedia: media.unavailable,
          ),
        );
        final List<Widget> children = _photoChildren(layout);
        final Color selectionColor = _selectionColorOf(context);
        final TextDirection textDirection = Directionality.of(context);
        final TextScaler textScaler = MediaQuery.textScalerOf(context);
        final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        Widget body(ViewportOffset? offset) {
          final Widget view = NoteViewBody(
            key: widget.renderKey,
            source: widget.source,
            tree: widget.tree,
            visibleText: visibleText,
            layout: layout,
            activeLine: activeLine,
            selection: widget.selection,
            composing: widget.composing,
            focused: widget.focused,
            readOnly: readOnly,
            offset: offset,
            bottomInset: widget.bottomInset,
            hintText: widget.hintText,
            hintStyle: widget.hintStyle,
            textScaler: textScaler,
            textDirection: textDirection,
            devicePixelRatio: devicePixelRatio,
            cursorColor: widget.cursorColor,
            selectionColor: selectionColor,
            platformValue: widget.platformValue,
            platformValueStart: widget.platformValueStart,
            delegate: widget.delegate,
            startHandleLayerLink: widget.startHandleLayerLink,
            endHandleLayerLink: widget.endHandleLayerLink,
            decorations: widget.decorations,
            children: children,
          );
          final LayerLink? toolbarLink = widget.toolbarLayerLink;
          return toolbarLink == null
              ? view
              : CompositedTransformTarget(link: toolbarLink, child: view);
        }

        final ScrollController? controller = widget.scrollController;
        if (controller == null) {
          return body(null);
        }
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Scrollable(
            controller: controller,
            axisDirection: AxisDirection.down,
            viewportBuilder: (BuildContext context, ViewportOffset offset) =>
                body(offset),
          ),
        );
      },
    );
  }

  List<Widget> _photoChildren(LaidOutNote layout) {
    final Map<(int, int), PhotoRect> rects = <(int, int), PhotoRect>{
      for (final PhotoRect rect in layout.photoRects)
        (rect.sourceRange.start, rect.sourceRange.end): rect,
    };
    final TextRange? selectedRange = noteSelectedPhotoRange(
      widget.tree,
      widget.source,
      widget.selection,
    );
    final MediaResolver? resolver = widget.mediaResolver;
    final NoteViewDelegate? delegate = widget.delegate;
    return <Widget>[
      for (final _PhotoBlock photo in _photos)
        if (rects[(photo.range.start, photo.range.end)]
            case final PhotoRect rect)
          _photoSlot(
            photo,
            rect,
            selected: photo.range == selectedRange,
            resolver: resolver,
            delegate: widget.readOnly ? null : delegate,
          ),
    ];
  }

  Widget _photoSlot(
    _PhotoBlock photo,
    PhotoRect rect, {
    required bool selected,
    required MediaResolver? resolver,
    required NoteViewDelegate? delegate,
  }) {
    final String reference = photo.line.reference;
    final int lineStart = photo.range.start;
    final ResolvedMedia? media = resolver == null
        ? null
        : _undecodable.contains(reference)
        ? const ResolvedMedia.missing()
        : _media[reference];
    return NotePhotoSlot(
      key: notePhotoKey(reference, photo.occurrence),
      figureRect: rect.rect,
      lineRange: photo.range,
      selected: selected,
      child: PhotoFigure(
        line: photo.line,
        rect: rect,
        media: media,
        resolver: resolver,
        selected: selected,
        captionHidden: selected && widget.selectedCaptionHidden,
        onActivate: delegate == null
            ? null
            : () => delegate.selectPhoto(lineStart),
        semanticsSortKey: OrdinalSortKey(lineStart.toDouble()),
        onDecodeError: () => _markUndecodable(reference),
      ),
    );
  }
}
