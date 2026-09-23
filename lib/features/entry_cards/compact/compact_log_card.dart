import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';
import '../../../domain/models/models.dart';
import '../../notes/render/note_photo_block.dart';
import '../cards/note_body.dart';
import '../cards/voice_body.dart';
import '../media/media_image.dart';
import '../media/media_placeholders.dart';
import '../media/media_resolver.dart';
import '../playback/audio_playback.dart';
import 'log_actions_pill.dart';
import 'log_preview.dart';

enum CompactLogDensity { feed, day }

const Key compactLogThumbnailKey = ValueKey<String>('compact-log-thumbnail');
const Key compactLogOpenLabelKey = ValueKey<String>('compact-log-open-label');

const String _photoUnavailableLabel = 'Photo unavailable';
const String _posterUnavailableLabel = 'Poster unavailable';
const String _playbackUnavailableLabel = 'Playback unavailable';

const double _tiltOddDegrees = -0.5;
const double _tiltEvenDegrees = 0.4;
const double _stampGap = 4;
const double _metaLabelGap = 8;
const double _shortNoteSize = 13.5;
const double _voiceUnavailableHeight = 64;
const double _hoverRise = 1;

const BorderRadius _cardRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

const TextStyle _dayStampStyle = TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: Palette.sage,
);

final class _DensityStyle {
  const _DensityStyle({
    required this.padding,
    required this.restShadow,
    required this.hoverShadow,
    required this.tilts,
    required this.risesOnHover,
    required this.leadStyle,
    required this.snippetStyle,
    required this.snippetGap,
    required this.thumbnailExtent,
    required this.thumbnailRadius,
    required this.thumbnailGap,
    required this.metaGap,
    required this.metaStyle,
    required this.openLabelStyle,
    required this.posterSize,
    required this.posterRadius,
    required this.playDiscExtent,
    required this.videoTitleStyle,
  });

  final EdgeInsets padding;
  final List<BoxShadow> restShadow;
  final List<BoxShadow> hoverShadow;
  final bool tilts;
  final bool risesOnHover;
  final TextStyle leadStyle;
  final TextStyle snippetStyle;
  final double snippetGap;
  final double thumbnailExtent;
  final BorderRadius thumbnailRadius;
  final double thumbnailGap;
  final double metaGap;
  final TextStyle metaStyle;
  final TextStyle openLabelStyle;
  final Size posterSize;
  final BorderRadius posterRadius;
  final double playDiscExtent;
  final TextStyle videoTitleStyle;
}

final _DensityStyle _feedStyle = _DensityStyle(
  padding: EdgeInsets.symmetric(vertical: 13, horizontal: 15),
  restShadow: Shadows.cardDefault,
  hoverShadow: <BoxShadow>[
    BoxShadow(
      color: Palette.ink.withValues(alpha: 0.24),
      offset: const Offset(3, 3),
    ),
  ],
  tilts: true,
  risesOnHover: false,
  leadStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 16.5,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: Palette.ink,
  ),
  snippetStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Palette.mutedDeep,
  ),
  snippetGap: 4,
  thumbnailExtent: 64,
  thumbnailRadius: BorderRadius.all(Radius.circular(10)),
  thumbnailGap: 14,
  metaGap: 9,
  metaStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Palette.muted,
  ),
  openLabelStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: Palette.coral,
  ),
  posterSize: Size(104, 64),
  posterRadius: BorderRadius.all(Radius.circular(10)),
  playDiscExtent: 28,
  videoTitleStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: Palette.ink,
  ),
);

const _DensityStyle _dayStyle = _DensityStyle(
  padding: EdgeInsets.symmetric(vertical: 11, horizontal: 13),
  restShadow: <BoxShadow>[
    BoxShadow(color: Palette.ink16, offset: Offset(1.5, 1.5)),
  ],
  hoverShadow: <BoxShadow>[
    BoxShadow(color: Palette.ink22, offset: Offset(3, 3)),
  ],
  tilts: false,
  risesOnHover: true,
  leadStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 15.5,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: Palette.ink,
  ),
  snippetStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: Palette.mutedDeep,
  ),
  snippetGap: 3,
  thumbnailExtent: 56,
  thumbnailRadius: BorderRadius.all(Radius.circular(Shapes.radiusThumb)),
  thumbnailGap: 12,
  metaGap: 7,
  metaStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: Palette.muted,
  ),
  openLabelStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Palette.coral,
  ),
  posterSize: Size(84, 52),
  posterRadius: BorderRadius.all(Radius.circular(8)),
  playDiscExtent: 22,
  videoTitleStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: Palette.ink,
  ),
);

_DensityStyle _styleFor(CompactLogDensity density) {
  switch (density) {
    case CompactLogDensity.feed:
      return _feedStyle;
    case CompactLogDensity.day:
      return _dayStyle;
  }
}

class CompactLogCard extends StatefulWidget {
  const CompactLogCard({
    super.key,
    required this.entry,
    required this.resolver,
    required this.density,
    required this.onOpen,
    this.onEdit,
    required this.onDelete,
    this.audioPlayerFactory,
  });

  final Entry entry;
  final MediaResolver resolver;
  final CompactLogDensity density;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final EntryAudioPlayerFactory? audioPlayerFactory;

  @override
  State<CompactLogCard> createState() => _CompactLogCardState();
}

class _CompactLogCardState extends State<CompactLogCard> {
  bool _hovered = false;

  void _onHover(bool hovered) {
    if (mounted && hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _DensityStyle style = _styleFor(widget.density);
    final LogPreview preview = logPreviewOf(widget.entry);
    final Widget sticker = StickerCard(
      surface: Palette.cardWarm,
      borderRadius: _cardRadius,
      shadow: _hovered ? style.hoverShadow : style.restShadow,
      padding: style.padding,
      rotationDegrees: style.tilts ? _tiltDegrees(widget.entry.id) : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _stamp(),
          const SizedBox(height: _stampGap),
          _body(context, style, preview),
        ],
      ),
    );
    final Widget lifted = _hovered && style.risesOnHover
        ? Transform.translate(
            offset: const Offset(0, -_hoverRise),
            child: sticker,
          )
        : sticker;
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            widget.onOpen();
            return null;
          },
        ),
      },
      child: LogActionsReveal(
        onEdit: widget.entry.type == EntryType.text ? widget.onEdit : null,
        onDelete: widget.onDelete,
        child: Semantics(
          container: true,
          button: true,
          onTap: widget.onOpen,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (PointerEnterEvent event) => _onHover(true),
            onExit: (PointerExitEvent event) => _onHover(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpen,
              child: lifted,
            ),
          ),
        ),
      ),
    );
  }

  double _tiltDegrees(String id) {
    final int codeUnitSum = id.codeUnits.fold<int>(
      0,
      (int total, int unit) => total + unit,
    );
    return codeUnitSum.isOdd ? _tiltOddDegrees : _tiltEvenDegrees;
  }

  Widget _stamp() {
    final String stamp = logStampFor(widget.entry.createdAt);
    final String type = logTypeLabelFor(widget.entry.type);
    switch (widget.density) {
      case CompactLogDensity.feed:
        return Row(
          children: <Widget>[
            Expanded(
              child: Text(
                stamp,
                style: TypographyTokens.stampAccent,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _typeChip(type),
          ],
        );
      case CompactLogDensity.day:
        return Text(
          stamp.isEmpty ? type : '$stamp · $type',
          style: _dayStampStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  Widget _typeChip(String type) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.coral12,
        borderRadius: BorderRadius.all(
          Radius.circular(Shapes.radiusIconButton),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
        child: Text(type.toUpperCase(), style: TypographyTokens.chipMicroSans),
      ),
    );
  }

  Widget _body(BuildContext context, _DensityStyle style, LogPreview preview) {
    switch (widget.entry.type) {
      case EntryType.text:
        return preview.isLong ? _longNote(style, preview) : _shortNote(context);
      case EntryType.voice:
        return _voice();
      case EntryType.video:
        return _video(style, preview);
    }
  }

  Widget _shortNote(BuildContext context) {
    final double bodySize = TypographyTokens.noteBody.fontSize!;
    final MediaQueryData media = MediaQuery.of(context);
    final double scale =
        media.textScaler.scale(bodySize) /
        bodySize *
        (_shortNoteSize / bodySize);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: NoteMediaScope(
        resolver: widget.resolver,
        child: NoteBody(text: widget.entry.textContent ?? ''),
      ),
    );
  }

  Widget _longNote(_DensityStyle style, LogPreview preview) {
    final String? photo = preview.firstPhotoReference;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (preview.lead.isNotEmpty)
                    Text(preview.lead, style: style.leadStyle),
                  if (preview.lead.isNotEmpty && preview.snippet.isNotEmpty)
                    SizedBox(height: style.snippetGap),
                  if (preview.snippet.isNotEmpty)
                    Text(preview.snippet, style: style.snippetStyle),
                ],
              ),
            ),
            if (photo != null) ...<Widget>[
              SizedBox(width: style.thumbnailGap),
              _thumbnail(style, photo),
            ],
          ],
        ),
        SizedBox(height: style.metaGap),
        _metaRow(style, preview),
      ],
    );
  }

  Widget _thumbnail(_DensityStyle style, String reference) {
    return SizedBox.square(
      key: compactLogThumbnailKey,
      dimension: style.thumbnailExtent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: style.thumbnailRadius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Palette.ink.withValues(alpha: 0.14),
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: _CompactMedia(
          resolver: widget.resolver,
          mediaId: reference,
          width: style.thumbnailExtent,
          height: style.thumbnailExtent,
          borderRadius: style.thumbnailRadius,
          variant: CrossHatchVariant.photo,
          errorLabel: _photoUnavailableLabel,
        ),
      ),
    );
  }

  Widget _metaRow(_DensityStyle style, LogPreview preview) {
    return Row(
      children: <Widget>[
        if (preview.meta.isNotEmpty) ...<Widget>[
          Flexible(
            child: Text(
              preview.meta,
              style: style.metaStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: _metaLabelGap),
        ],
        Text(
          '${preview.openLabel} ›',
          key: compactLogOpenLabelKey,
          style: style.openLabelStyle,
        ),
      ],
    );
  }

  Widget _voice() {
    final EntryAudioPlayerFactory? factory = widget.audioPlayerFactory;
    if (factory == null) {
      return const CorruptMediaPlaceholder(
        label: _playbackUnavailableLabel,
        height: _voiceUnavailableHeight,
      );
    }
    return VoiceBody(
      entry: widget.entry,
      resolver: widget.resolver,
      playerFactory: factory,
    );
  }

  Widget _video(_DensityStyle style, LogPreview preview) {
    final DateTime at = DateTime.fromMillisecondsSinceEpoch(
      widget.entry.createdAt,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            _poster(style),
            SizedBox(width: style.thumbnailGap),
            Expanded(
              child: Text(
                'A video from the ${partOfDayFor(at.hour)}',
                style: style.videoTitleStyle,
              ),
            ),
          ],
        ),
        SizedBox(height: style.metaGap),
        _metaRow(style, preview),
      ],
    );
  }

  Widget _poster(_DensityStyle style) {
    final double disc = style.playDiscExtent;
    return SizedBox.fromSize(
      key: compactLogThumbnailKey,
      size: style.posterSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: _CompactMedia(
              resolver: widget.resolver,
              mediaId: widget.entry.thumbnailMediaId,
              width: style.posterSize.width,
              height: style.posterSize.height,
              borderRadius: style.posterRadius,
              variant: CrossHatchVariant.video,
              errorLabel: _posterUnavailableLabel,
            ),
          ),
          SizedBox.square(
            dimension: disc,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.cardBright.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Shapes.outline,
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(left: disc * 0.08),
                  child: CustomPaint(
                    size: Size.square(disc * 0.36),
                    painter: const _PlayTrianglePainter(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayTrianglePainter extends CustomPainter {
  const _PlayTrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Path triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, Paint()..color = Palette.ink);
  }

  @override
  bool shouldRepaint(_PlayTrianglePainter oldDelegate) => false;
}

class _CompactMedia extends StatefulWidget {
  const _CompactMedia({
    required this.resolver,
    required this.mediaId,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.variant,
    required this.errorLabel,
  });

  final MediaResolver resolver;
  final String? mediaId;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final CrossHatchVariant variant;
  final String errorLabel;

  @override
  State<_CompactMedia> createState() => _CompactMediaState();
}

class _CompactMediaState extends State<_CompactMedia> {
  ResolvedMedia? _media;
  bool _decodeFailed = false;

  @override
  void initState() {
    super.initState();
    _media = _start();
  }

  @override
  void didUpdateWidget(_CompactMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId == widget.mediaId &&
        oldWidget.resolver == widget.resolver) {
      return;
    }
    _decodeFailed = false;
    _media = _start();
  }

  ResolvedMedia? _start() {
    final String? id = widget.mediaId;
    if (id == null || id.isEmpty) {
      return const ResolvedMedia.missing();
    }
    final ResolvedMedia? memo = widget.resolver.resolved(id);
    if (memo != null) {
      return memo;
    }
    widget.resolver
        .resolve(id)
        .then(
          (ResolvedMedia media) => _arrive(id, media),
          onError: (Object error, StackTrace stackTrace) =>
              _arrive(id, const ResolvedMedia.missing()),
        );
    return null;
  }

  void _arrive(String id, ResolvedMedia media) {
    if (!mounted || widget.mediaId != id) {
      return;
    }
    setState(() => _media = media);
  }

  void _onDecodeError() {
    if (mounted && !_decodeFailed) {
      setState(() => _decodeFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ResolvedMedia? media = _media;
    final File? file = media?.file;
    if (media == null || !media.isAvailable || file == null || _decodeFailed) {
      return CrossHatchPlaceholder(
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
        variant: widget.variant,
      );
    }
    return MediaImage(
      resolver: widget.resolver,
      mediaId: widget.mediaId,
      errorLabel: widget.errorLabel,
      width: widget.width,
      height: widget.height,
      borderRadius: widget.borderRadius,
      fit: BoxFit.cover,
      border: Shapes.outline,
      onDecodeError: _onDecodeError,
    );
  }
}
