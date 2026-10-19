import 'dart:math' as math;

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';
import '../../../domain/models/models.dart';
import '../../notes/render/note_photo_block.dart' show NoteMediaScope;
import '../cards/note_body.dart';
import '../cards/voice_body.dart';
import '../cards/voice_waveform.dart';
import '../media/hatched_media_image.dart';
import '../media/media_placeholders.dart';
import '../media/media_resolver.dart';
import '../playback/audio_playback.dart';
import '../util/duration_format.dart';
import 'log_actions_pill.dart';
import 'log_preview.dart';

enum CompactLogDensity { feed, day }

const Key compactLogThumbnailKey = ValueKey<String>('compact-log-thumbnail');
const Key compactLogOpenLabelKey = ValueKey<String>('compact-log-open-label');
const Key compactLogPlayKey = ValueKey<String>('compact-log-play');

const String _photoUnavailableLabel = 'Photo unavailable';
const String _posterUnavailableLabel = 'Poster unavailable';
const String _playbackUnavailableLabel = 'Playback unavailable';
const String _playLabel = 'Play';

const double _tiltOddDegrees = -0.5;
const double _tiltEvenDegrees = 0.4;
const double _stampGap = 4;
const double _metaLabelGap = 8;
const double _shortNoteSize = 13.5;
const double _voiceUnavailableHeight = 64;
const double _hoverRise = 1;

const double _playToggleSize = 38;
const double _playToggleTarget = 48;
const double _playToggleGap = 12;
const double _playToggleGlyphOffset = 2;
const BorderRadius _playToggleRadius = BorderRadius.all(
  Radius.circular(_playToggleSize / 2),
);
const double _voiceLabelGap = 12;
const double _voiceLabelMinWidth = 62;
const double _posterPlayTarget = 44;

const BorderRadius _cardRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

TextStyle _dayStampStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: colors.sage,
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

_DensityStyle _feedStyle(FieldNotesColors colors) => _DensityStyle(
  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 15),
  restShadow: FieldNotesShadows(colors).cardDefault,
  hoverShadow: <BoxShadow>[
    BoxShadow(
      color: colors.shadowTintBase.withValues(alpha: 0.24),
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
    color: colors.ink,
  ),
  snippetStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: colors.mutedDeep,
  ),
  snippetGap: 4,
  thumbnailExtent: 64,
  thumbnailRadius: const BorderRadius.all(Radius.circular(10)),
  thumbnailGap: 14,
  metaGap: 9,
  metaStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: colors.muted,
  ),
  openLabelStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: colors.accentInk,
  ),
  posterSize: const Size(104, 64),
  posterRadius: const BorderRadius.all(Radius.circular(10)),
  playDiscExtent: 28,
  videoTitleStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: colors.ink,
  ),
);

_DensityStyle _dayStyle(FieldNotesColors colors) => _DensityStyle(
  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
  restShadow: <BoxShadow>[
    BoxShadow(color: colors.shadowTint(0x29), offset: const Offset(1.5, 1.5)),
  ],
  hoverShadow: <BoxShadow>[
    BoxShadow(color: colors.shadowTint(0x38), offset: const Offset(3, 3)),
  ],
  tilts: false,
  risesOnHover: true,
  leadStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 15.5,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: colors.ink,
  ),
  snippetStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: colors.mutedDeep,
  ),
  snippetGap: 3,
  thumbnailExtent: 56,
  thumbnailRadius: const BorderRadius.all(Radius.circular(Shapes.radiusThumb)),
  thumbnailGap: 12,
  metaGap: 7,
  metaStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: colors.muted,
  ),
  openLabelStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: colors.accentInk,
  ),
  posterSize: const Size(84, 52),
  posterRadius: const BorderRadius.all(Radius.circular(8)),
  playDiscExtent: 22,
  videoTitleStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: colors.ink,
  ),
);

_DensityStyle _styleFor(CompactLogDensity density, FieldNotesColors colors) {
  switch (density) {
    case CompactLogDensity.feed:
      return _feedStyle(colors);
    case CompactLogDensity.day:
      return _dayStyle(colors);
  }
}

const double _conflictLabelGap = 6;

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
    this.onToggleTask,
    this.semanticIndex,
    this.onPlay,
  });

  final Entry entry;
  final MediaResolver resolver;
  final CompactLogDensity density;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final EntryAudioPlayerFactory? audioPlayerFactory;
  final ValueChanged<int>? onToggleTask;
  final int? semanticIndex;
  final VoidCallback? onPlay;

  @override
  State<CompactLogCard> createState() => _CompactLogCardState();
}

class _CompactLogCardState extends State<CompactLogCard> {
  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final _DensityStyle style = _styleFor(widget.density, colors);
    final LogPreview preview = logPreviewOf(widget.entry);
    final double tilt = style.tilts ? _tiltDegrees(widget.entry.id) : 0;
    Widget lifted(bool hovered) => Transform.translate(
      offset: Offset(0, hovered && style.risesOnHover ? -_hoverRise : 0),
      child: StickerCard(
        surface: colors.cardWarm,
        borderRadius: _cardRadius,
        shadow: hovered ? style.hoverShadow : style.restShadow,
        padding: style.padding,
        rotationDegrees: tilt,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _stamp(),
            const SizedBox(height: _stampGap),
            _body(context, style, preview),
          ],
        ),
      ),
    );
    return LogActionsReveal(
      onOpen: widget.onOpen,
      onEdit: widget.entry.type == EntryType.text ? widget.onEdit : null,
      onDelete: widget.onDelete,
      semanticIndex: widget.semanticIndex,
      borderRadius: _cardRadius,
      builder: (BuildContext context, bool hovered) => lifted(hovered),
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
    final String stamp = logStampFor(context, widget.entry.createdAt);
    final String type = logTypeLabelFor(widget.entry.type);
    switch (widget.density) {
      case CompactLogDensity.feed:
        return Row(
          children: <Widget>[
            Expanded(
              child: Text(
                stamp,
                style: context.textStyles.stampAccent,
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
          style: _dayStampStyle(context.colors),
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
        child: Text(
          type.toUpperCase(),
          style: context.textStyles.chipMicroSans,
        ),
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
    final double bodySize = context.textStyles.noteBody.fontSize!;
    final MediaQueryData media = MediaQuery.of(context);
    final double scale =
        media.textScaler.scale(bodySize) /
        bodySize *
        (_shortNoteSize / bodySize);
    final ValueChanged<int>? onToggleTask = widget.onToggleTask;
    final String text = widget.entry.textContent ?? '';
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: onToggleTask == null
          ? IgnorePointer(
              child: NoteMediaScope(
                resolver: widget.resolver,
                child: NoteBody(
                  text: text,
                  conflictSourceDevice: widget.entry.conflictSourceDevice,
                ),
              ),
            )
          : NoteMediaScope(
              resolver: widget.resolver,
              child: NoteBody(
                text: text,
                selectable: false,
                onToggleTask: onToggleTask,
                conflictSourceDevice: widget.entry.conflictSourceDevice,
              ),
            ),
    );
  }

  Widget _longNote(_DensityStyle style, LogPreview preview) {
    final String? photo = preview.firstPhotoReference;
    final String? conflictDevice = widget.entry.conflictSourceDevice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (conflictDevice != null) ...<Widget>[
          ConflictCopyLabel(deviceName: conflictDevice),
          const SizedBox(height: _conflictLabelGap),
        ],
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
              color: context.colors.shadowTintBase.withValues(alpha: 0.14),
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: HatchedMediaImage(
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
    final VoidCallback? onPlay = widget.onPlay;
    if (factory == null && onPlay != null) {
      return _staticVoice(onPlay);
    }
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

  Widget _staticVoice(VoidCallback onPlay) {
    return Row(
      children: <Widget>[
        _CardPlayToggle(onTap: onPlay),
        const SizedBox(
          width: _playToggleSize + _playToggleGap - _playToggleTarget,
        ),
        Expanded(
          child: VoiceWaveform(
            peaks: widget.entry.peaks,
            active: false,
            progress: 0,
          ),
        ),
        const SizedBox(width: _voiceLabelGap),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _voiceLabelMinWidth),
          child: Text(
            formatMediaDuration(widget.entry.durationMs),
            textAlign: TextAlign.right,
            style: context.textStyles.caption11Sans.copyWith(
              color: context.colors.muted,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
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
            child: HatchedMediaImage(
              resolver: widget.resolver,
              mediaId: widget.entry.thumbnailMediaId,
              width: style.posterSize.width,
              height: style.posterSize.height,
              borderRadius: style.posterRadius,
              variant: CrossHatchVariant.video,
              errorLabel: _posterUnavailableLabel,
            ),
          ),
          _posterPlay(disc),
        ],
      ),
    );
  }

  Widget _posterPlay(double disc) {
    final FieldNotesColors colors = context.colors;
    final Widget face = SizedBox.square(
      dimension: disc,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardBright.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: context.shadows.outline,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(left: disc * 0.08),
            child: CustomPaint(
              size: Size.square(disc * 0.36),
              painter: _PlayTrianglePainter(color: colors.ink),
            ),
          ),
        ),
      ),
    );
    final VoidCallback? onPlay = widget.onPlay;
    if (onPlay == null) {
      return face;
    }
    final BorderRadius round = BorderRadius.circular(disc / 2);
    return Pressable(
      key: compactLogPlayKey,
      label: _playLabel,
      onPressed: onPlay,
      shape: HoverShape.circle,
      borderRadius: round,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => SizedBox.square(
        dimension: math.max(disc, _posterPlayTarget),
        child: Center(
          child: HoverFill(
            hovered: hovered,
            shape: HoverShape.circle,
            borderRadius: round,
            child: face,
          ),
        ),
      ),
    );
  }
}

class _CardPlayToggle extends StatelessWidget {
  const _CardPlayToggle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: compactLogPlayKey,
      label: _playLabel,
      onPressed: onTap,
      shape: HoverShape.circle,
      borderRadius: _playToggleRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => SizedBox.square(
        dimension: _playToggleTarget,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: HoverFill(
            hovered: hovered,
            surface: FocusRingSurface.dark,
            shape: HoverShape.circle,
            borderRadius: _playToggleRadius,
            child: Container(
              width: _playToggleSize,
              height: _playToggleSize,
              decoration: BoxDecoration(
                color: Palette.coral,
                shape: BoxShape.circle,
                border: context.shadows.outline,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: _playToggleGlyphOffset),
                  child: PlayPauseGlyph(
                    playing: false,
                    color: FieldNotesColors.light.cardBright,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayTrianglePainter extends CustomPainter {
  const _PlayTrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PlayTrianglePainter oldDelegate) =>
      color != oldDelegate.color;
}
