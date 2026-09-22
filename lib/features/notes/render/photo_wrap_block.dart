import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/media_blob.dart';
import 'package:field_notes/domain/notes/notes.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/notes/inline_span_slice.dart';
import 'package:field_notes/features/entry_cards/notes/note_block_widgets.dart';
import 'package:field_notes/features/entry_cards/notes/note_inline_span.dart';

import '../model/photo_placement.dart';
import 'float_split_cache.dart';
import 'note_photo_block.dart';
import 'note_photo_plan.dart';
import 'note_render_budget.dart';

const Key photoWrapFloatKey = ValueKey<String>('photo-wrap-float');
const Key photoWrapFigureKey = ValueKey<String>('photo-wrap-figure');
const Key photoWrapHeadKey = ValueKey<String>('photo-wrap-head');
const Key photoWrapTailKey = ValueKey<String>('photo-wrap-tail');

const TextStyle _boldText = TextStyle(fontWeight: FontWeight.bold);

FloatSplit? measureFloatSplit({
  required TextPainter painter,
  required InlineSpan span,
  required TextScaler scaler,
  required int bucket,
  required double width,
  required double floatHeight,
}) {
  final List<LineMetrics> lines = painter.computeLineMetrics();
  if (lines.isEmpty) {
    return null;
  }
  final List<double> tops = <double>[
    for (final LineMetrics line in lines) line.baseline - line.ascent,
  ];
  final int beside =
      tops.where((double top) => lineStartsBeside(top, floatHeight)).length;
  final List<double> kept = tops.sublist(0, math.min(tops.length, beside + 2));
  if (beside >= lines.length) {
    return FloatSplit(
      span: span,
      scaler: scaler,
      bucket: bucket,
      width: width,
      offset: plainLengthOf(span),
      head: span,
      tail: null,
      lines: lines.length,
      lineTops: kept,
    );
  }
  final LineMetrics next = lines[beside];
  final int offset = painter
      .getLineBoundary(
        painter.getPositionForOffset(Offset(next.left, next.baseline)),
      )
      .start;
  if (offset <= 0) {
    return null;
  }
  final (InlineSpan head, InlineSpan? tail) = sliceInlineSpan(span, offset);
  return FloatSplit(
    span: span,
    scaler: scaler,
    bucket: bucket,
    width: width,
    offset: offset,
    head: head,
    tail: tail,
    lines: beside,
    lineTops: kept,
  );
}

@immutable
final class _TextSetup {
  const _TextSetup({
    required this.base,
    required this.bold,
    required this.scaler,
    required this.direction,
    required this.align,
    required this.widthBasis,
    required this.heightBehavior,
    required this.locale,
  });

  factory _TextSetup.of(BuildContext context) {
    final DefaultTextStyle defaults = DefaultTextStyle.of(context);
    return _TextSetup(
      base: defaults.style,
      bold: MediaQuery.boldTextOf(context),
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
      align: defaults.textAlign ?? TextAlign.start,
      widthBasis: defaults.textWidthBasis,
      heightBehavior: defaults.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
  }

  final TextStyle base;
  final bool bold;
  final TextScaler scaler;
  final TextDirection direction;
  final TextAlign align;
  final TextWidthBasis widthBasis;
  final TextHeightBehavior? heightBehavior;
  final Locale? locale;

  TextStyle effective(TextStyle? style) {
    final TextStyle merged = base.merge(style);
    return bold ? merged.merge(_boldText) : merged;
  }

  bool shapesLike(_TextSetup other) =>
      base == other.base &&
      bold == other.bold &&
      direction == other.direction &&
      align == other.align &&
      widthBasis == other.widthBasis &&
      heightBehavior == other.heightBehavior &&
      locale == other.locale;

  void configure(TextPainter painter, InlineSpan span, TextAlign align) {
    painter
      ..text = span
      ..textAlign = align
      ..textDirection = direction
      ..textScaler = scaler
      ..textWidthBasis = widthBasis
      ..textHeightBehavior = heightBehavior
      ..locale = locale;
  }

  Widget text(InlineSpan span, {required Key key}) {
    return Text.rich(
      span,
      key: key,
      textAlign: align,
      textDirection: direction,
      locale: locale,
      softWrap: true,
      overflow: TextOverflow.clip,
      textScaler: scaler,
      textWidthBasis: widthBasis,
      textHeightBehavior: heightBehavior,
    );
  }
}

@immutable
final class _ParagraphSpan {
  const _ParagraphSpan({
    required this.paragraph,
    required this.style,
    required this.setup,
    required this.span,
  });

  final ParagraphBlock paragraph;
  final TextStyle style;
  final _TextSetup setup;
  final InlineSpan span;

  bool builtFrom(
    ParagraphBlock block,
    TextStyle blockStyle,
    _TextSetup other,
  ) =>
      identical(paragraph, block) &&
      style == blockStyle &&
      setup.shapesLike(other);
}

class PhotoWrapBlock extends StatefulWidget {
  const PhotoWrapBlock({
    super.key,
    required this.photo,
    required this.paragraph,
    required this.resolver,
    this.style = TypographyTokens.noteBody,
  });

  final PhotoBlock photo;
  final ParagraphBlock paragraph;
  final MediaResolver resolver;
  final TextStyle style;

  @override
  State<PhotoWrapBlock> createState() => _PhotoWrapBlockState();
}

class _PhotoWrapBlockState extends State<PhotoWrapBlock> {
  final TextPainter _paragraphPainter = TextPainter();
  final TextPainter _captionPainter = TextPainter();
  final FloatSplitCache _splits = FloatSplitCache();
  final StaticSelectionContainerDelegate _selection =
      StaticSelectionContainerDelegate();
  Future<ResolvedMedia>? _resolving;
  _ParagraphSpan? _paragraphSpan;
  bool _decodeFailed = false;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_systemFontsChanged);
  }

  void _onFigureDecodeError() {
    if (mounted && !_decodeFailed) {
      setState(() => _decodeFailed = true);
    }
  }

  void _systemFontsChanged() {
    setState(() {
      _paragraphPainter.markNeedsLayout();
      _captionPainter.markNeedsLayout();
      _splits.clear();
    });
  }

  @override
  void didUpdateWidget(PhotoWrapBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.reference != widget.photo.reference) {
      _decodeFailed = false;
    }
    if (oldWidget.photo.reference != widget.photo.reference ||
        !identical(oldWidget.resolver, widget.resolver)) {
      _resolving = null;
    }
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_systemFontsChanged);
    _paragraphPainter.dispose();
    _captionPainter.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!NoteRenderBudget.floatEnabledOf(context) || _decodeFailed) {
      return _stacked(context);
    }
    final ResolvedMedia? memo = widget.resolver.resolved(
      widget.photo.reference,
    );
    if (memo != null) {
      return _resolved(memo);
    }
    return FutureBuilder<ResolvedMedia>(
      future: _resolving ??= widget.resolver.resolve(widget.photo.reference),
      builder: (BuildContext context, AsyncSnapshot<ResolvedMedia> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _stacked(context);
        }
        return _resolved(snapshot.data ?? const ResolvedMedia.missing());
      },
    );
  }

  Widget _resolved(ResolvedMedia media) {
    final MediaBlob? blob = media.blob;
    final double? aspect = photoAspectOf(blob?.width, blob?.height);
    if (!media.isAvailable || aspect == null) {
      return Builder(builder: _stacked);
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double em = noteEmOf(context, widget.style);
        final PhotoPlacement placement = widget.photo.placement;
        final PhotoPlan plan = planFloat(
          measure: noteMeasureFor(maxWidth: constraints.maxWidth, em: em),
          em: em,
          side: placement.side,
          size: placement.size,
          aspect: aspect,
          nextIsParagraph: true,
        );
        if (plan.isStacked) {
          return _stacked(context);
        }
        final _TextSetup setup = _TextSetup.of(context);
        final FloatSplit? split = _splitFor(
          _spanFor(setup),
          setup,
          plan,
          em,
          _figureHeight(plan, setup),
        );
        if (split == null) {
          return _stacked(context);
        }
        return _floated(context, setup, plan, media, split);
      },
    );
  }

  Widget _stacked(BuildContext context) {
    final double em = noteEmOf(context, widget.style);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StackedPhoto(
          block: widget.photo,
          resolver: widget.resolver,
          style: widget.style,
        ),
        SizedBox(height: noteBlockGapEm(widget.photo, widget.paragraph) * em),
        NoteBlockView(block: widget.paragraph, style: widget.style),
      ],
    );
  }

  InlineSpan _spanFor(_TextSetup setup) {
    final _ParagraphSpan? current = _paragraphSpan;
    if (current != null &&
        current.builtFrom(widget.paragraph, widget.style, setup)) {
      return current.span;
    }
    final InlineSpan span = TextSpan(
      style: setup.effective(null),
      children: <InlineSpan>[
        buildNoteInlineSpan(widget.paragraph.inlines, widget.style),
      ],
    );
    _splits.clear();
    _paragraphSpan = _ParagraphSpan(
      paragraph: widget.paragraph,
      style: widget.style,
      setup: setup,
      span: span,
    );
    return span;
  }

  double _figureHeight(PhotoPlan plan, _TextSetup setup) {
    final String caption = widget.photo.caption;
    if (caption.isEmpty) {
      return plan.height;
    }
    setup.configure(
      _captionPainter,
      TextSpan(text: caption, style: setup.effective(notePhotoCaptionStyle)),
      notePhotoCaptionAlign,
    );
    _captionPainter.layout(minWidth: plan.width, maxWidth: plan.width);
    return plan.height + notePhotoCaptionGap + _captionPainter.height;
  }

  FloatSplit? _splitFor(
    InlineSpan span,
    _TextSetup setup,
    PhotoPlan plan,
    double em,
    double floatHeight,
  ) {
    final int bucket = floatBandBucket(band: plan.band, em: em);
    final FloatSplit? cached = _splits.lookup(
      span: span,
      scaler: setup.scaler,
      bucket: bucket,
      floatHeight: floatHeight,
    );
    if (cached != null) {
      return cached;
    }
    final double width = floatBandWidth(
      band: plan.band,
      bucket: bucket,
      em: em,
    );
    setup.configure(_paragraphPainter, span, setup.align);
    _paragraphPainter.layout(maxWidth: width);
    final FloatSplit? split = measureFloatSplit(
      painter: _paragraphPainter,
      span: span,
      scaler: setup.scaler,
      bucket: bucket,
      width: width,
      floatHeight: floatHeight,
    );
    return split == null ? null : _splits.store(split);
  }

  Widget _floated(
    BuildContext context,
    _TextSetup setup,
    PhotoPlan plan,
    ResolvedMedia media,
    FloatSplit split,
  ) {
    final Widget figure = _readAt(
      0,
      SelectionContainer.disabled(
        child: SizedBox(
          key: photoWrapFigureKey,
          width: plan.width,
          child: NotePhotoFigure(
            key: ValueKey<String>(widget.photo.reference),
            block: widget.photo,
            resolver: widget.resolver,
            media: media,
            plan: plan,
            onDecodeError: _onFigureDecodeError,
          ),
        ),
      ),
    );
    final Widget head = _readAt(
      1,
      SizedBox(
        width: split.width,
        child: setup.text(split.head, key: photoWrapHeadKey),
      ),
    );
    final InlineSpan? tail = split.tail;
    final Widget float = Semantics(
      container: true,
      explicitChildNodes: true,
      child: Align(
        key: photoWrapFloatKey,
        alignment: Alignment.topLeft,
        heightFactor: 1,
        child: SizedBox(
          width: plan.measure,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: plan.side == PhotoSide.left
                    ? <Widget>[figure, SizedBox(width: plan.gutter), head]
                    : <Widget>[head, const Spacer(), figure],
              ),
              if (tail != null)
                _readAt(2, setup.text(tail, key: photoWrapTailKey)),
            ],
          ),
        ),
      ),
    );
    if (SelectionContainer.maybeOf(context) == null) {
      return float;
    }
    return SelectionContainer(delegate: _selection, child: float);
  }

  Widget _readAt(double order, Widget child) => Semantics(
        container: true,
        sortKey: OrdinalSortKey(order),
        child: child,
      );
}
