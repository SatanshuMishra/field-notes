import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/media_blob.dart';
import 'package:field_notes/domain/notes/notes.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';

import '../model/photo_placement.dart';
import 'note_photo_plan.dart';

const String notePhotoUnavailableLabel = 'Photo unavailable';
const String notePhotoSemanticsLabel = 'Photo';
const Key notePhotoFrameKey = ValueKey<String>('note-photo-frame');
const Key notePhotoUnavailableKey = ValueKey<String>('note-photo-unavailable');

const double notePhotoFramePadding = 6;
const double notePhotoCaptionGap = 8;
const double notePhotoUnavailableHeight = 56;
const TextStyle notePhotoCaptionStyle = TypographyTokens.captionSans;
const TextAlign notePhotoCaptionAlign = TextAlign.center;
const List<double> notePhotoTiltsDegrees = <double>[-1.2, -0.6, 0.5, 1.1];

const double _shadowReach = 2;
const int _fnvOffset = 0x811c9dc5;
const int _fnvPrime = 0x01000193;
const int _hashMask = 0xffffffff;

class NoteMediaScope extends InheritedWidget {
  const NoteMediaScope({
    super.key,
    required this.resolver,
    required super.child,
  });

  final MediaResolver resolver;

  static MediaResolver? maybeResolverOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NoteMediaScope>()
        ?.resolver;
  }

  @override
  bool updateShouldNotify(NoteMediaScope oldWidget) =>
      !identical(resolver, oldWidget.resolver);
}

double notePhotoTiltDegrees(String reference) {
  int hash = _fnvOffset;
  for (final int unit in blobPrefixOf(reference.toLowerCase()).codeUnits) {
    hash = ((hash ^ unit) * _fnvPrime) & _hashMask;
  }
  return notePhotoTiltsDegrees[hash % notePhotoTiltsDegrees.length];
}

double notePhotoFitScale(double width, double height, double radians) {
  if (width <= 0 || height <= 0) {
    return 1;
  }
  final double cos = math.cos(radians).abs();
  final double sin = math.sin(radians).abs();
  final double spanX = width * cos + height * sin;
  final double spanY = width * sin + height * cos;
  final double scale = math.min(
    (width - 2 * _shadowReach) / spanX,
    (height - 2 * _shadowReach) / spanY,
  );
  return scale.clamp(0.0, 1.0);
}

class StackedPhoto extends StatelessWidget {
  const StackedPhoto({
    super.key,
    required this.block,
    required this.resolver,
    this.style = TypographyTokens.noteBody,
  });

  final PhotoBlock block;
  final MediaResolver resolver;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final ResolvedMedia? memo = resolver.resolved(block.reference);
    if (memo != null) {
      return _laidOut(memo);
    }
    return FutureBuilder<ResolvedMedia>(
      future: resolver.resolve(block.reference),
      builder: (BuildContext context, AsyncSnapshot<ResolvedMedia> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _laidOut(null);
        }
        return _laidOut(snapshot.data ?? const ResolvedMedia.missing());
      },
    );
  }

  Widget _laidOut(ResolvedMedia? media) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double em = MediaQuery.textScalerOf(context)
            .scale(style.fontSize ?? TypographyTokens.noteBody.fontSize!);
        final double measure = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : NoteColumn.measureEm * em;
        final PhotoPlacement placement = block.placement;
        final MediaBlob? blob = media?.blob;
        final PhotoPlan plan = planFloat(
          measure: measure,
          em: em,
          side: placement.side,
          size: placement.size,
          aspect: photoAspectOf(blob?.width, blob?.height),
        );
        return Center(
          child: NotePhotoFigure(
            block: block,
            resolver: resolver,
            media: media,
            plan: plan,
          ),
        );
      },
    );
  }
}

class NotePhotoFigure extends StatelessWidget {
  const NotePhotoFigure({
    super.key,
    required this.block,
    required this.resolver,
    required this.media,
    required this.plan,
  });

  final PhotoBlock block;
  final MediaResolver resolver;
  final ResolvedMedia? media;
  final PhotoPlan plan;

  @override
  Widget build(BuildContext context) {
    final ResolvedMedia? media = this.media;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _photo(plan, media),
        if (block.caption.isNotEmpty)
          _caption(plan, labelsImage: media == null || media.isAvailable),
      ],
    );
  }

  Widget _photo(PhotoPlan plan, ResolvedMedia? media) {
    if (media != null && !media.isAvailable) {
      return CorruptMediaPlaceholder(
        key: notePhotoUnavailableKey,
        label: notePhotoUnavailableLabel,
        width: plan.width,
        height: notePhotoUnavailableHeight,
        borderRadius: Shapes.buttonBorderRadius,
      );
    }
    final String caption = block.caption;
    return Semantics(
      image: true,
      label: caption.isEmpty ? notePhotoSemanticsLabel : caption,
      child: ExcludeSemantics(
        child: SizedBox(
          key: notePhotoFrameKey,
          width: plan.width,
          height: plan.height,
          child: _tilted(plan, media == null ? _pending() : _image()),
        ),
      ),
    );
  }

  Widget _tilted(PhotoPlan plan, Widget content) {
    final double radians =
        notePhotoTiltDegrees(block.reference) * math.pi / 180;
    return Transform.rotate(
      angle: radians,
      child: Transform.scale(
        scale: notePhotoFitScale(plan.width, plan.height, radians),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Palette.cardBright,
            border: Shapes.outline,
            boxShadow: Shadows.cardDefault,
          ),
          child: Padding(
            padding: const EdgeInsets.all(notePhotoFramePadding),
            child: SizedBox.expand(child: content),
          ),
        ),
      ),
    );
  }

  Widget _pending() {
    return const NeutralMediaPlaceholder(borderRadius: BorderRadius.zero);
  }

  Widget _image() {
    return MediaImage(
      resolver: resolver,
      mediaId: block.reference,
      errorLabel: notePhotoUnavailableLabel,
      borderRadius: BorderRadius.zero,
    );
  }

  Widget _caption(PhotoPlan plan, {required bool labelsImage}) {
    return Padding(
      padding: const EdgeInsets.only(top: notePhotoCaptionGap),
      child: SizedBox(
        width: plan.width,
        child: ExcludeSemantics(
          excluding: labelsImage,
          child: Text(
            block.caption,
            style: notePhotoCaptionStyle,
            textAlign: notePhotoCaptionAlign,
          ),
        ),
      ),
    );
  }
}
