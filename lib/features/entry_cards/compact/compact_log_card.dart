import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/design/feedback/feedback.dart'
    show showTransientToast;
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/features/today/today_providers.dart'
    show todayVideoPlayerFactoryProvider;
import 'package:field_notes/state/state.dart' show journalRepositoryProvider;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderContainer, UncontrolledProviderScope;

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/widgets.dart';
import '../../../domain/models/models.dart';
import '../../../domain/platform/desktop_platform.dart';
import '../../notes/render/note_photo_block.dart' show NoteMediaScope;
import '../cards/note_body.dart';
import '../cards/video_body.dart';
import '../cards/video_controls_overlay.dart';
import '../cards/voice_body.dart';
import '../cards/voice_waveform.dart';
import '../media/hatched_media_image.dart';
import '../media/media_placeholders.dart';
import '../media/media_resolver.dart';
import '../playback/audio_playback.dart';
import '../playback/video_playback.dart';
import '../playback/video_slots.dart';
import '../playback/video_slots_provider.dart';
import '../transport/transport.dart';
import '../util/duration_format.dart';
import 'log_actions_pill.dart';
import 'log_preview.dart';

enum CompactLogDensity { feed, day, row }

const Key compactLogThumbnailKey = ValueKey<String>('compact-log-thumbnail');
const Key compactLogOpenLabelKey = ValueKey<String>('compact-log-open-label');
const Key compactLogPlayKey = ValueKey<String>('compact-log-play');
const Key compactLogTitleKey = ValueKey<String>('compact-log-title');
const Key compactLogTitleFieldKey = ValueKey<String>('compact-log-title-field');
const Key compactLogPosterKey = ValueKey<String>('compact-log-poster');
const Key compactLogVideoPlayKey = ValueKey<String>('compact-log-video-play');

const String compactLogTitleFieldLabel = 'Title';
const String compactLogRenameFailedMessage =
    "Couldn't save that title. Please try again.";

const String _photoUnavailableLabel = 'Photo unavailable';
const String _posterUnavailableLabel = 'Poster unavailable';
const String _playbackUnavailableLabel = 'Playback unavailable';
const String _playLabel = 'Play';

const double _tiltOddDegrees = -0.5;
const double _tiltEvenDegrees = 0.4;
const double _tiltTextProbe = 1;
const double _stampChipGap = 8;
const double _titleTopGap = 1;
const double _titleBottomGap = 3;
const double _noteTopGap = 2;
const double _mediaTopGap = 6;
const double _metaLabelGap = 8;
const double _shortNoteSize = 13.5;
const double _voiceUnavailableHeight = 64;
const double _hoverRise = 1;
const int _longNoteSnippetLines = 3;

const double _playToggleSize = 38;
const double _playToggleTarget = 48;
const double _playToggleGap = 12;
const double _playToggleGlyphOffset = 2;
const BorderRadius _playToggleRadius = BorderRadius.all(
  Radius.circular(_playToggleSize / 2),
);
const double _voiceLabelGap = 12;
const double _voiceLabelMinWidth = 62;

const double _rowLineGap = 2;
const double _rowChipGap = 6;
const double _rowWaveHeight = 20;
const double _rowWaveBarsHeight = 16;
const double _rowWaveLabelGap = 8;
const double _rowBadgeInset = 4;
const double _rowBadgeFontSize = 10;
const EdgeInsets _rowBadgePadding = EdgeInsets.symmetric(
  vertical: 2,
  horizontal: 4,
);

const double _chipFontSize = 10;
const double _chipLetterSpacing = 0.8;
const EdgeInsets _chipPadding = EdgeInsets.symmetric(
  vertical: 3,
  horizontal: 7,
);

const double _sideBySideMinWidth = 480;
const double _widePosterMinWidth = 640;
const double _mediumPosterMinWidth = 540;
const double _widePosterWidth = 216;
const double _mediumPosterWidth = 184;
const double _narrowPosterWidth = 152;
const double _sideBySideGap = 16;
const double _stackedGap = 8;
const double _posterStageMinWidth = 320;
const double _posterDiscExtent = 48;
const double _posterGlyphExtent = 24;
const double _posterDiscAlpha = 0.58;
const double _posterBadgeAlpha = 0.66;
const double _posterBadgeInset = 6;
const double _posterBadgeFontSize = 11;
const EdgeInsets _posterBadgePadding = EdgeInsets.symmetric(
  vertical: 3,
  horizontal: 6,
);
const BorderRadius _cardPosterRadius = BorderRadius.all(
  Radius.circular(Shapes.radius10),
);
const BorderRadius _posterBadgeRadius = BorderRadius.all(
  Radius.circular(Shapes.radius8),
);

const BorderRadius _cardRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

TextStyle _dayStampStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: colors.sage,
);

void _absorbGesture() {}

final class _DensityStyle {
  const _DensityStyle({
    required this.padding,
    required this.restShadow,
    required this.hoverShadow,
    required this.tilts,
    required this.risesOnHover,
    required this.titleStyle,
    required this.snippetStyle,
    required this.thumbnailExtent,
    required this.thumbnailRadius,
    required this.thumbnailGap,
    required this.metaGap,
    required this.metaStyle,
    required this.openLabelStyle,
    required this.posterSize,
    required this.posterRadius,
    required this.playDiscExtent,
  });

  final EdgeInsets padding;
  final List<BoxShadow> restShadow;
  final List<BoxShadow> hoverShadow;
  final bool tilts;
  final bool risesOnHover;
  final TextStyle titleStyle;
  final TextStyle snippetStyle;
  final double thumbnailExtent;
  final BorderRadius thumbnailRadius;
  final double thumbnailGap;
  final double metaGap;
  final TextStyle metaStyle;
  final TextStyle openLabelStyle;
  final Size posterSize;
  final BorderRadius posterRadius;
  final double playDiscExtent;
}

_DensityStyle _feedStyle(FieldNotesColors colors) => _DensityStyle(
  padding: const EdgeInsets.fromLTRB(15, 9, 12, 13),
  restShadow: FieldNotesShadows(colors).cardDefault,
  hoverShadow: <BoxShadow>[
    BoxShadow(
      color: colors.shadowTintBase.withValues(alpha: 0.24),
      offset: const Offset(3, 3),
    ),
  ],
  tilts: true,
  risesOnHover: false,
  titleStyle: TextStyle(
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
);

_DensityStyle _dayStyle(FieldNotesColors colors) => _DensityStyle(
  padding: const EdgeInsets.fromLTRB(13, 7, 10, 11),
  restShadow: <BoxShadow>[
    BoxShadow(color: colors.shadowTint(0x29), offset: const Offset(1.5, 1.5)),
  ],
  hoverShadow: <BoxShadow>[
    BoxShadow(color: colors.shadowTint(0x38), offset: const Offset(3, 3)),
  ],
  tilts: false,
  risesOnHover: true,
  titleStyle: TextStyle(
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
);

_DensityStyle _rowStyle(FieldNotesColors colors) => _DensityStyle(
  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
  restShadow: <BoxShadow>[
    BoxShadow(color: colors.shadowTint(0x29), offset: const Offset(1.5, 1.5)),
  ],
  hoverShadow: <BoxShadow>[
    BoxShadow(color: colors.shadowTint(0x38), offset: const Offset(3, 3)),
  ],
  tilts: false,
  risesOnHover: true,
  titleStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 15.5,
    fontWeight: FontWeight.w500,
    height: 1.25,
    color: colors.ink,
  ),
  snippetStyle: TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: colors.mutedDeep,
  ),
  thumbnailExtent: 52,
  thumbnailRadius: const BorderRadius.all(Radius.circular(Shapes.radiusThumb)),
  thumbnailGap: 10,
  metaGap: _rowLineGap,
  metaStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    color: colors.muted,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  ),
  openLabelStyle: TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: colors.accentInk,
  ),
  posterSize: const Size(72, 52),
  posterRadius: const BorderRadius.all(Radius.circular(8)),
  playDiscExtent: 24,
);

_DensityStyle _styleFor(CompactLogDensity density, FieldNotesColors colors) {
  switch (density) {
    case CompactLogDensity.feed:
      return _feedStyle(colors);
    case CompactLogDensity.day:
      return _dayStyle(colors);
    case CompactLogDensity.row:
      return _rowStyle(colors);
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
  final ValueNotifier<bool> _innerHovered = ValueNotifier<bool>(false);
  final GlobalKey _moreKey = GlobalKey(debugLabel: 'log more');
  bool _renaming = false;
  ({String? title})? _pendingTitle;

  late final ProviderContainer? _scope = context
      .findAncestorWidgetOfExactType<UncontrolledProviderScope>()
      ?.container;

  @override
  void didUpdateWidget(CompactLogCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.title != widget.entry.title) {
      _pendingTitle = null;
    }
  }

  @override
  void dispose() {
    _innerHovered.dispose();
    super.dispose();
  }

  void _setInnerHovered(bool hovered) => _innerHovered.value = hovered;

  bool get _textEnlarged =>
      MediaQuery.textScalerOf(context).scale(_tiltTextProbe) > _tiltTextProbe;

  Text _boundedText(
    String text, {
    required TextStyle? style,
    int lines = 1,
    Key? key,
  }) => Text(
    text,
    key: key,
    style: style,
    maxLines: _textEnlarged ? null : lines,
    overflow: _textEnlarged ? null : TextOverflow.ellipsis,
  );

  String? get _savedTitle {
    final ({String? title})? pending = _pendingTitle;
    return pending == null ? logOwnTitle(widget.entry) : pending.title;
  }

  List<LogMenuItem> _menuItems() {
    final VoidCallback? edit = widget.entry.type == EntryType.text
        ? widget.onEdit
        : null;
    return <LogMenuItem>[
      if (_scope != null)
        LogMenuItem(
          key: logActionsRenameKey,
          label: _savedTitle == null
              ? logActionsAddTitleLabel
              : logActionsRenameLabel,
          glyph: LogMenuGlyph.title,
          onSelected: _startRename,
        ),
      if (edit != null)
        LogMenuItem(
          key: logActionsEditKey,
          label: logActionsEditLabel,
          glyph: LogMenuGlyph.edit,
          onSelected: edit,
        ),
      LogMenuItem(
        key: logActionsDeleteKey,
        label: logMenuDeleteLabel,
        glyph: LogMenuGlyph.trash,
        danger: true,
        onSelected: widget.onDelete,
      ),
    ];
  }

  void _openMore() {
    final BuildContext? anchor = _moreKey.currentContext;
    if (anchor != null) {
      unawaited(showLogActionsMenu(anchor, items: _menuItems()));
    }
  }

  void _startRename() {
    if (mounted) {
      setState(() => _renaming = true);
    }
  }

  void _cancelRename() {
    if (mounted) {
      setState(() => _renaming = false);
    }
  }

  Future<void> _saveTitle(String typed) async {
    if (!mounted) {
      return;
    }
    final String trimmed = typed.trim();
    final String? title = trimmed.isEmpty ? null : trimmed;
    final ProviderContainer? scope = _scope;
    if (scope == null || title == _savedTitle) {
      _cancelRename();
      return;
    }
    final JournalRepository repository = scope.read(journalRepositoryProvider);
    final BuildContext toastContext =
        ModalRoute.of(context)?.subtreeContext ?? context;
    setState(() {
      _renaming = false;
      _pendingTitle = (title: title);
    });
    try {
      await repository.setEntryTitle(widget.entry.id, title);
    } catch (error, stackTrace) {
      debugPrint('Log rename failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _pendingTitle = null);
      }
      if (toastContext.mounted) {
        showTransientToast(toastContext, compactLogRenameFailedMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final _DensityStyle style = _styleFor(widget.density, colors);
    final LogPreview preview = logPreviewOf(widget.entry);
    final double tilt = style.tilts && !_textEnlarged
        ? _tiltDegrees(widget.entry.id)
        : 0;
    final Widget content = widget.density == CompactLogDensity.row
        ? _rowContent(style, preview)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _stampRow(),
              ..._titleLine(style, preview),
              SizedBox(
                height: widget.entry.type == EntryType.text
                    ? _noteTopGap
                    : _mediaTopGap,
              ),
              _body(context, style, preview),
            ],
          );
    return LogCardFrame(
      onOpen: widget.onOpen,
      onLongPress: _openMore,
      semanticActions: <CustomSemanticsAction, VoidCallback>{
        for (final LogMenuItem item in _menuItems())
          CustomSemanticsAction(label: item.label): item.onSelected,
      },
      semanticIndex: widget.semanticIndex,
      borderRadius: _cardRadius,
      builder: (BuildContext context, bool hovered) =>
          ValueListenableBuilder<bool>(
            valueListenable: _innerHovered,
            child: content,
            builder: (BuildContext context, bool inner, Widget? child) {
              final bool highlighted = hovered && !inner;
              return LogCardHighlight(
                active: highlighted,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    highlighted && style.risesOnHover ? -_hoverRise : 0,
                  ),
                  child: StickerCard(
                    surface: colors.cardWarm,
                    borderRadius: _cardRadius,
                    shadow: highlighted ? style.hoverShadow : style.restShadow,
                    padding: style.padding,
                    rotationDegrees: tilt,
                    child: child!,
                  ),
                ),
              );
            },
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

  Widget _cardActions({required bool withOpen}) {
    return _PlayerZone(
      onHover: _setInnerHovered,
      child: LogCardActions(
        onOpen: withOpen ? widget.onOpen : null,
        onMore: _openMore,
        moreAnchorKey: _moreKey,
      ),
    );
  }

  Widget _stampRow() {
    final String stamp = logStampFor(context, widget.entry.createdAt);
    final String type = logTypeLabelFor(widget.entry.type);
    switch (widget.density) {
      case CompactLogDensity.feed:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: _boundedText(
                      stamp,
                      style: context.textStyles.stampAccent,
                    ),
                  ),
                  const SizedBox(width: _stampChipGap),
                  _typeChip(type),
                ],
              ),
            ),
            _cardActions(withOpen: true),
          ],
        );
      case CompactLogDensity.day:
        return Row(
          children: <Widget>[
            Expanded(
              child: _boundedText(
                stamp.isEmpty ? type : '$stamp · $type',
                style: _dayStampStyle(context.colors),
              ),
            ),
            _cardActions(withOpen: true),
          ],
        );
      case CompactLogDensity.row:
        return Row(
          children: <Widget>[
            if (stamp.isNotEmpty) ...<Widget>[
              Flexible(
                child: _boundedText(
                  stamp,
                  style: context.textStyles.stampAccent,
                ),
              ),
              const SizedBox(width: _rowChipGap),
            ],
            _typeChip(type),
          ],
        );
    }
  }

  Widget _rowContent(_DensityStyle style, LogPreview preview) {
    final Widget? lead = _rowLead(style);
    final String? photo = widget.entry.type == EntryType.text
        ? preview.firstPhotoReference
        : null;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: style.thumbnailExtent),
      child: Row(
        children: <Widget>[
          if (lead != null) ...<Widget>[
            lead,
            SizedBox(
              width: widget.entry.type == EntryType.voice
                  ? _playToggleSize + style.thumbnailGap - _playToggleTarget
                  : style.thumbnailGap,
            ),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[_stampRow(), ..._rowLines(style, preview)],
            ),
          ),
          if (photo != null) ...<Widget>[
            SizedBox(width: style.thumbnailGap),
            _thumbnail(style, photo),
          ],
          _cardActions(withOpen: false),
        ],
      ),
    );
  }

  Widget? _rowLead(_DensityStyle style) {
    final VoidCallback? onPlay = widget.onPlay;
    switch (widget.entry.type) {
      case EntryType.text:
        return null;
      case EntryType.voice:
        return onPlay == null
            ? null
            : _PlayerZone(
                onHover: _setInnerHovered,
                child: _CardPlayToggle(onTap: onPlay),
              );
      case EntryType.video:
        if (onPlay == null) {
          return _poster(style, hovered: false, badge: true);
        }
        return _PlayerZone(
          onHover: _setInnerHovered,
          child: Pressable(
            key: compactLogPlayKey,
            label: _playLabel,
            onPressed: onPlay,
            borderRadius: style.posterRadius,
            paintsHover: false,
            builder: (BuildContext context, bool hovered) =>
                _poster(style, hovered: hovered, badge: true),
          ),
        );
    }
  }

  String _rowTitle(LogPreview preview) {
    final ({String? title})? pending = _pendingTitle;
    return pending == null ? preview.title : pending.title ?? '';
  }

  List<Widget> _rowLines(_DensityStyle style, LogPreview preview) {
    final String title = _rowTitle(preview);
    final String? conflictDevice = widget.entry.type == EntryType.text
        ? widget.entry.conflictSourceDevice
        : null;
    final Widget? detail = _rowDetail(style, preview);
    return <Widget>[
      if (_renaming) ...<Widget>[
        const SizedBox(height: _rowLineGap),
        _CardTitleField(
          initial: _savedTitle ?? '',
          style: style.titleStyle,
          onSubmit: _saveTitle,
          onCancel: _cancelRename,
        ),
      ] else if (title.isNotEmpty) ...<Widget>[
        const SizedBox(height: _rowLineGap),
        _boundedText(title, key: compactLogTitleKey, style: style.titleStyle),
      ],
      if (conflictDevice != null) ...<Widget>[
        SizedBox(height: style.metaGap),
        ConflictCopyLabel(deviceName: conflictDevice),
      ],
      if (detail != null) ...<Widget>[SizedBox(height: style.metaGap), detail],
    ];
  }

  Widget? _rowDetail(_DensityStyle style, LogPreview preview) {
    switch (widget.entry.type) {
      case EntryType.text:
        return preview.snippet.isEmpty
            ? null
            : _boundedText(preview.snippet, style: style.snippetStyle);
      case EntryType.voice:
        return Row(
          children: <Widget>[
            Expanded(
              child: IgnorePointer(
                child: VoiceWaveform(
                  peaks: widget.entry.peaks,
                  active: false,
                  progress: 0,
                  height: _rowWaveHeight,
                  barsHeight: _rowWaveBarsHeight,
                ),
              ),
            ),
            const SizedBox(width: _rowWaveLabelGap),
            Text(
              formatMediaDuration(widget.entry.durationMs),
              style: style.metaStyle,
            ),
          ],
        );
      case EntryType.video:
        return null;
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
        padding: _chipPadding,
        child: Text(
          type.toUpperCase(),
          style: context.textStyles.chipMicroSans.copyWith(
            fontSize: _chipFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: _chipLetterSpacing,
          ),
        ),
      ),
    );
  }

  String _shownTitle(LogPreview preview) {
    final ({String? title})? pending = _pendingTitle;
    if (pending != null) {
      return pending.title ?? '';
    }
    final bool shortNote =
        widget.entry.type == EntryType.text && !preview.isLong;
    return shortNote ? logOwnTitle(widget.entry) ?? '' : preview.title;
  }

  List<Widget> _titleLine(_DensityStyle style, LogPreview preview) {
    if (_renaming) {
      return <Widget>[
        _CardTitleField(
          initial: _savedTitle ?? '',
          style: style.titleStyle,
          onSubmit: _saveTitle,
          onCancel: _cancelRename,
        ),
      ];
    }
    final String title = _shownTitle(preview);
    if (title.isEmpty) {
      return const <Widget>[];
    }
    return <Widget>[
      const SizedBox(height: _titleTopGap),
      _boundedText(title, key: compactLogTitleKey, style: style.titleStyle),
      const SizedBox(height: _titleBottomGap),
    ];
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
              child: _boundedText(
                preview.snippet,
                style: style.snippetStyle,
                lines: _longNoteSnippetLines,
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
          Flexible(child: _boundedText(preview.meta, style: style.metaStyle)),
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
      return _PlayerZone(
        onHover: _setInnerHovered,
        child: _staticVoice(onPlay),
      );
    }
    if (factory == null) {
      return const CorruptMediaPlaceholder(
        label: _playbackUnavailableLabel,
        height: _voiceUnavailableHeight,
      );
    }
    return _PlayerZone(
      onHover: _setInnerHovered,
      child: VoiceBody(
        entry: widget.entry,
        resolver: widget.resolver,
        playerFactory: factory,
      ),
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
    final VoidCallback? onPlay = widget.onPlay;
    final ProviderContainer? scope = _scope;
    if (onPlay == null && scope != null) {
      return _PlayerZone(
        onHover: _setInnerHovered,
        child: _CardVideo(
          entry: widget.entry,
          resolver: widget.resolver,
          playerFactory: scope.read(todayVideoPlayerFactoryProvider),
          slots: scope.read(videoSlotsProvider),
        ),
      );
    }
    return Row(
      children: <Widget>[
        if (onPlay == null)
          _poster(style, hovered: false)
        else
          _PlayerZone(
            onHover: _setInnerHovered,
            child: Pressable(
              key: compactLogPlayKey,
              label: _playLabel,
              onPressed: onPlay,
              borderRadius: style.posterRadius,
              paintsHover: false,
              builder: (BuildContext context, bool hovered) =>
                  _poster(style, hovered: hovered),
            ),
          ),
        SizedBox(width: style.thumbnailGap),
        Expanded(child: _metaRow(style, preview)),
      ],
    );
  }

  Widget _poster(
    _DensityStyle style, {
    required bool hovered,
    bool badge = false,
  }) {
    final double disc = style.playDiscExtent;
    final int? durationMs = widget.entry.durationMs;
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
          HoverFill(
            hovered: hovered,
            shape: HoverShape.circle,
            borderRadius: BorderRadius.circular(disc / 2),
            child: _posterDisc(disc),
          ),
          if (badge && durationMs != null)
            PositionedDirectional(
              end: _rowBadgeInset,
              bottom: _rowBadgeInset,
              child: _DurationBadge(
                durationMs: durationMs,
                fontSize: _rowBadgeFontSize,
                padding: _rowBadgePadding,
              ),
            ),
        ],
      ),
    );
  }

  Widget _posterDisc(double disc) {
    final FieldNotesColors colors = context.colors;
    return SizedBox.square(
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
  }
}

class _PlayerZone extends StatelessWidget {
  const _PlayerZone({required this.onHover, required this.child});

  final ValueChanged<bool> onHover;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (PointerEnterEvent event) => onHover(true),
      onExit: (PointerExitEvent event) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _absorbGesture,
        onLongPress: _absorbGesture,
        child: child,
      ),
    );
  }
}

class _CardTitleField extends StatefulWidget {
  const _CardTitleField({
    required this.initial,
    required this.style,
    required this.onSubmit,
    required this.onCancel,
  });

  final String initial;
  final TextStyle style;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<_CardTitleField> createState() => _CardTitleFieldState();
}

class _CardTitleFieldState extends State<_CardTitleField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.length,
        );
  final FocusNode _focus = FocusNode(debugLabel: 'log title');
  final Map<Type, Action<Intent>> _fieldKeepsKeys = <Type, Action<Intent>>{
    ActivateIntent: DoNothingAction(consumesKey: false),
  };
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    if (_settled) {
      return;
    }
    _settled = true;
    widget.onSubmit(_controller.text);
  }

  void _cancel() {
    if (_settled) {
      return;
    }
    _settled = true;
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: _absorbGesture,
      onLongPress: _absorbGesture,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minButtonTargetOn(Theme.of(context).platform),
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape): _cancel,
            },
            child: Actions(
              actions: _fieldKeepsKeys,
              child: Semantics(
                label: compactLogTitleFieldLabel,
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    key: compactLogTitleFieldKey,
                    controller: _controller,
                    focusNode: _focus,
                    style: widget.style,
                    cursorColor: colors.accentInk,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration.collapsed(
                      hintText: logActionsAddTitleLabel,
                      hintStyle: widget.style.copyWith(
                        color: colors.placeholder,
                      ),
                    ),
                    onSubmitted: (String text) => _commit(),
                    onTapOutside: (PointerDownEvent event) => _commit(),
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

class _CardVideo extends StatefulWidget {
  const _CardVideo({
    required this.entry,
    required this.resolver,
    required this.playerFactory,
    required this.slots,
  });

  final Entry entry;
  final MediaResolver resolver;
  final EntryVideoPlayerFactory playerFactory;
  final VideoSlots slots;

  @override
  State<_CardVideo> createState() => _CardVideoState();
}

class _CardVideoState extends State<_CardVideo> {
  final VideoControlsHandle _handle = VideoControlsHandle();
  final ValueNotifier<VideoControlsState?> _controls =
      ValueNotifier<VideoControlsState?>(null);
  final ValueNotifier<bool> _posterHovered = ValueNotifier<bool>(false);
  final FocusNode _posterFocus = FocusNode(
    debugLabel: 'log video poster',
    skipTraversal: true,
  );
  bool _started = false;
  bool _playOnArrival = false;
  Duration? _seekOnArrival;

  @override
  void initState() {
    super.initState();
    _handle.addListener(_onControls);
  }

  @override
  void dispose() {
    _handle
      ..removeListener(_onControls)
      ..dispose();
    _controls.dispose();
    _posterHovered.dispose();
    _posterFocus.dispose();
    super.dispose();
  }

  void _onControls() {
    final VideoControlsState? state = _handle.state;
    if (state == null) {
      return;
    }
    _actOnArrival(state);
    _controls.value = state;
  }

  void _actOnArrival(VideoControlsState state) {
    final VoidCallback? start = state.onToggle;
    if (_playOnArrival && start != null) {
      _playOnArrival = false;
      if (!state.isPlaying) {
        start();
      }
    }
    final Duration? target = _seekOnArrival;
    final ValueChanged<Duration>? seek = state.onSeek;
    if (target != null && seek != null) {
      _seekOnArrival = null;
      seek(target);
    }
  }

  void _requestPlay() {
    final VoidCallback? toggle = _handle.state?.onToggle;
    if (toggle != null) {
      toggle();
      return;
    }
    setState(() {
      _started = true;
      _playOnArrival = true;
    });
  }

  void _queueSeek(Duration target) {
    setState(() => _seekOnArrival = target);
    _requestPlay();
  }

  Duration? get _declaredTotal {
    final int? declared = widget.entry.durationMs;
    return declared == null || declared <= 0
        ? null
        : Duration(milliseconds: declared);
  }

  TransportValue _transportValue(VideoControlsState? state) {
    return TransportValue(
      position: _seekOnArrival ?? state?.position ?? Duration.zero,
      total: state?.total ?? _declaredTotal,
      isPlaying: state?.isPlaying ?? false,
      onToggle: state == null
          ? (_started ? null : _requestPlay)
          : state.onToggle,
      onSeek: state?.onSeek ?? _queueSeek,
      onScrubUpdate: state?.onScrubUpdate,
      onScrubEnd: state?.onScrubEnd,
    );
  }

  double _sidePosterWidth(double available) {
    if (available >= _widePosterMinWidth) {
      return _widePosterWidth;
    }
    return available >= _mediumPosterMinWidth
        ? _mediumPosterWidth
        : _narrowPosterWidth;
  }

  Widget _cover() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          HatchedMediaImage(
            resolver: widget.resolver,
            mediaId: widget.entry.thumbnailMediaId,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            borderRadius: _cardPosterRadius,
            variant: CrossHatchVariant.video,
            errorLabel: _posterUnavailableLabel,
          ),
          Pressable(
            key: compactLogPosterKey,
            label: videoSurfacePointerLabel,
            focusNode: _posterFocus,
            onPressed: _requestPlay,
            paintsHover: false,
            borderRadius: _cardPosterRadius,
            placement: FocusRingPlacement.edge,
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }

  Widget _stage() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = math.max(
          constraints.maxWidth,
          _posterStageMinWidth,
        );
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: width,
            height: width / defaultVideoAspectRatio,
            child: VideoBody(
              entry: widget.entry,
              resolver: widget.resolver,
              playerFactory: widget.playerFactory,
              slots: widget.slots,
              handle: _handle,
              controlModel: VideoControlModel.pointer,
              aspectRatio: defaultVideoAspectRatio,
              controls: (BuildContext context, VideoControlsState state) =>
                  const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _poster(VideoControlsState? state) {
    return MouseRegion(
      onEnter: (PointerEnterEvent event) => _posterHovered.value = true,
      onExit: (PointerExitEvent event) => _posterHovered.value = false,
      child: DecoratedBox(
        key: compactLogThumbnailKey,
        decoration: BoxDecoration(
          borderRadius: _cardPosterRadius,
          boxShadow: context.shadows.chip,
        ),
        child: AspectRatio(
          aspectRatio: defaultVideoAspectRatio,
          child: ClipRRect(
            borderRadius: _cardPosterRadius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (_started) _stage() else _cover(),
                IgnorePointer(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _posterHovered,
                    builder:
                        (BuildContext context, bool hovered, Widget? child) =>
                            _PosterFace(
                              playing: state?.isPlaying ?? false,
                              hovered: hovered,
                              durationMs: widget.entry.durationMs,
                            ),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: _cardPosterRadius,
                      border: context.shadows.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool desktop = isDesktopPlatform(Theme.of(context).platform);
    return ValueListenableBuilder<VideoControlsState?>(
      valueListenable: _controls,
      builder:
          (BuildContext context, VideoControlsState? state, Widget? child) =>
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double available = constraints.maxWidth;
                  final bool stacked =
                      !desktop || available < _sideBySideMinWidth;
                  return Flex(
                    direction: stacked ? Axis.vertical : Axis.horizontal,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: stacked
                        ? CrossAxisAlignment.stretch
                        : CrossAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: stacked ? null : _sidePosterWidth(available),
                        child: _poster(state),
                      ),
                      SizedBox(
                        width: stacked ? 0 : _sideBySideGap,
                        height: stacked ? _stackedGap : 0,
                      ),
                      Flexible(
                        flex: stacked ? 0 : 1,
                        fit: FlexFit.tight,
                        child: Transport(
                          kind: TransportKind.video,
                          mode: TransportMode.card,
                          value: _transportValue(state),
                          mediaPath: state?.mediaPath,
                          tuning: state?.tuning,
                          playKey: compactLogVideoPlayKey,
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }
}

class _PosterFace extends StatelessWidget {
  const _PosterFace({
    required this.playing,
    required this.hovered,
    required this.durationMs,
  });

  final bool playing;
  final bool hovered;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    if (playing) {
      return const SizedBox.shrink();
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Center(
          child: SizedBox.square(
            dimension: _posterDiscExtent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: hovered
                    ? Palette.coral
                    : Palette.mediaBlack.withValues(alpha: _posterDiscAlpha),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: PlayPauseGlyph(
                  playing: false,
                  color: Palette.mediaInk,
                  size: _posterGlyphExtent,
                ),
              ),
            ),
          ),
        ),
        if (durationMs != null)
          PositionedDirectional(
            end: _posterBadgeInset,
            bottom: _posterBadgeInset,
            child: _DurationBadge(
              durationMs: durationMs,
              fontSize: _posterBadgeFontSize,
              padding: _posterBadgePadding,
            ),
          ),
      ],
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({
    required this.durationMs,
    required this.fontSize,
    required this.padding,
  });

  final int? durationMs;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.mediaBlack.withValues(alpha: _posterBadgeAlpha),
        borderRadius: _posterBadgeRadius,
      ),
      child: Padding(
        padding: padding,
        child: Text(
          formatMediaDuration(durationMs),
          style: TextStyle(
            fontFamily: TypographyTokens.sans,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Palette.mediaInk,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
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
