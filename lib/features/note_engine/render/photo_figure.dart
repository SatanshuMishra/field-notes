import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';

const String photoFigureUnavailableLabel = 'Photo unavailable';
const String photoFigureSemanticsLabel = 'Photo';
const Key photoFigureFrameKey = ValueKey<String>('note-photo-frame');
const Key photoFigureUnavailableKey = ValueKey<String>(
  'note-photo-unavailable',
);
const Key photoFigureCaptionKey = ValueKey<String>('note-photo-caption');
const Key photoFigureRingKey = ValueKey<String>('in-place-photo-ring');

const double photoFigureCaptionGap = 8;
const double photoFigureUnavailableHeight = 56;
const double photoFigureRingWidth = 2.5;
const List<double> photoFigureTiltsDegrees = <double>[-1.2, -0.6, 0.5, 1.1];

const double _shadowReach = 2;
const int _fnvOffset = 0x811c9dc5;
const int _fnvPrime = 0x01000193;
const int _hashMask = 0xffffffff;

const BoxDecoration _ring = BoxDecoration(
  border: Border.fromBorderSide(
    BorderSide(color: Palette.coral, width: photoFigureRingWidth),
  ),
  borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusSm)),
);

double photoFigureTiltDegrees(String reference) {
  int hash = _fnvOffset;
  for (final int unit in blobPrefixOf(reference.toLowerCase()).codeUnits) {
    hash = ((hash ^ unit) * _fnvPrime) & _hashMask;
  }
  return photoFigureTiltsDegrees[hash % photoFigureTiltsDegrees.length];
}

double photoFigureFitScale(double width, double height, double radians) {
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

String photoFigureSemanticsLabelFor(String caption) {
  final String trimmed = caption.trim();
  return trimmed.isEmpty
      ? photoFigureSemanticsLabel
      : '$photoFigureSemanticsLabel, $trimmed';
}

class PhotoFigure extends StatelessWidget {
  const PhotoFigure({
    super.key,
    required this.line,
    required this.rect,
    required this.media,
    this.resolver,
    this.selected = false,
    this.captionHidden = false,
    this.onActivate,
    this.semanticsSortKey,
    this.onDecodeError,
  });

  final MdPhotoLine line;
  final PhotoRect rect;
  final ResolvedMedia? media;
  final MediaResolver? resolver;
  final bool selected;
  final bool captionHidden;
  final VoidCallback? onActivate;
  final SemanticsSortKey? semanticsSortKey;
  final VoidCallback? onDecodeError;

  bool get _unavailable {
    final ResolvedMedia? known = media;
    return !line.canResolve || (known != null && !known.isAvailable);
  }

  @override
  Widget build(BuildContext context) {
    final double width = rect.imageRect.width;
    final bool unavailable = _unavailable;
    final Widget figure = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (unavailable) _placeholder(width) else _frame(width),
        if (line.caption.isNotEmpty) _caption(width),
      ],
    );
    final String label = photoFigureSemanticsLabelFor(line.caption);
    final String? value = unavailable ? photoFigureUnavailableLabel : null;
    final VoidCallback? activate = onActivate;
    if (activate == null) {
      return Semantics(
        container: true,
        image: true,
        label: label,
        value: value,
        sortKey: semanticsSortKey,
        child: ExcludeSemantics(child: figure),
      );
    }
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      value: value,
      sortKey: semanticsSortKey,
      onTap: activate,
      child: ExcludeSemantics(child: figure),
    );
  }

  Widget _placeholder(double width) {
    const Widget placeholderRing = IgnorePointer(
      child: DecoratedBox(key: photoFigureRingKey, decoration: _ring),
    );
    final Widget placeholder = CorruptMediaPlaceholder(
      key: photoFigureUnavailableKey,
      label: photoFigureUnavailableLabel,
      width: width,
      height: photoFigureUnavailableHeight,
      borderRadius: Shapes.buttonBorderRadius,
    );
    if (!selected) {
      return placeholder;
    }
    return Stack(
      children: <Widget>[
        placeholder,
        const Positioned.fill(child: placeholderRing),
      ],
    );
  }

  Widget _frame(double width) {
    final double height = rect.imageRect.height;
    final double radians =
        photoFigureTiltDegrees(line.reference) * math.pi / 180;
    final double scale = photoFigureFitScale(width, height, radians);
    return SizedBox(
      key: photoFigureFrameKey,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: radians,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: Transform.scale(
                scale: scale,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    boxShadow: Shadows.cardDefault,
                  ),
                  child: SizedBox.expand(child: _content()),
                ),
              ),
            ),
            if (selected)
              Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: width * scale,
                    height: height * scale,
                    child: const IgnorePointer(
                      child: DecoratedBox(
                        key: photoFigureRingKey,
                        decoration: _ring,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final ResolvedMedia? known = media;
    final MediaResolver? source = resolver;
    if (known == null || source == null) {
      return const NeutralMediaPlaceholder(borderRadius: BorderRadius.zero);
    }
    return MediaImage(
      resolver: source,
      mediaId: line.reference,
      errorLabel: photoFigureUnavailableLabel,
      borderRadius: BorderRadius.zero,
      onDecodeError: onDecodeError,
    );
  }

  Widget _caption(double width) {
    final Widget text = Text(
      line.caption,
      style: TypographyTokens.captionSans,
      textAlign: TextAlign.center,
    );
    return Padding(
      padding: const EdgeInsets.only(top: photoFigureCaptionGap),
      child: SizedBox(
        key: photoFigureCaptionKey,
        width: width,
        child: DefaultTextStyle(
          style: TypographyTokens.captionSans,
          child: captionHidden
              ? Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: text,
                )
              : text,
        ),
      ),
    );
  }
}
