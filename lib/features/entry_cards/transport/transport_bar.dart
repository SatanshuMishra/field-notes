import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/focus/focus_ring.dart';
import '../../../design/focus/input_modality.dart';
import '../../../design/interaction/hover_fill.dart';
import '../../../design/interaction/hover_style.dart';
import '../../../design/interaction/min_target.dart';
import '../../../design/interaction/pressable.dart';
import '../../../design/motion/motion.dart';
import '../../../design/tokens/tokens.dart';
import '../../../domain/platform/desktop_platform.dart';
import '../playback/video_playback.dart';
import '../util/duration_format.dart';
import 'transport_keys.dart';

const Duration transportReadoutHold = Duration(milliseconds: 700);

const Key transportBack10Key = ValueKey<String>('transport-back-10');
const Key transportForward10Key = ValueKey<String>('transport-forward-10');
const Key transportMuteKey = ValueKey<String>('transport-mute');
const Key transportVolumeKey = ValueKey<String>('transport-volume');
const Key transportSpeedKey = ValueKey<String>('transport-speed');
const Key transportSpeedMenuKey = ValueKey<String>('transport-speed-menu');
const Key transportFullScreenKey = ValueKey<String>('transport-full-screen');
const Key transportDockBackKey = ValueKey<String>('transport-dock-back');
const Key transportDockMoreKey = ValueKey<String>('transport-dock-more');

Key transportSpeedChoiceKey(double speed) =>
    ValueKey<String>('transport-speed-$speed');

const double _iconSize = 20;
const double _dockSkipSize = 26;
const double _dockPlayDiameter = 64;
const double _playGlyphShare = 0.42;
const double _playGlyphNudge = 0.05;
const double _disabledAlpha = 0.5;
const double _playGap = 4;
const double _timeInset = 8;
const double _timeSize = 13;
const double _speedPadding = 8;
const double _speedMenuWidth = 112;
const double _speedMenuGap = 8;
const double _speedItemInset = 10;
const double _volumeTrack = 72;
const double _volumeHeight = 24;
const double _volumeGapBefore = 2;
const double _volumeGapAfter = 8;
const double _volumeRailHeight = 4;
const double _volumeKnobRadius = 6;
const double _strokeWidth = 1.7;
const double _viewBox = 24;
const double _tenFontSize = 7.5;
const double _tenBaseline = 16.2;
const double _dockRowGap = 4;
const double _readoutBorder = 1;
const double _readoutFontSize = 16;
const double _readoutFadeIn = 0.18;
const double _readoutFadeOut = 0.7;
const EdgeInsets _readoutPadding = EdgeInsets.symmetric(
  horizontal: 18,
  vertical: 12,
);
const EdgeInsets _speedMenuPadding = EdgeInsets.all(4);
const BorderRadius _iconRadius = BorderRadius.all(
  Radius.circular(Shapes.radius8),
);
const BorderRadius _circleRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusFull),
);
const BorderRadius _speedRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusFull),
);
const BorderRadius _menuRadius = BorderRadius.all(
  Radius.circular(Shapes.radius12),
);
const BorderRadius _menuItemRadius = BorderRadius.all(
  Radius.circular(Shapes.radius8),
);
const BorderRadius _readoutRadius = BorderRadius.all(
  Radius.circular(Shapes.radius12),
);
const List<FontFeature> _tabular = <FontFeature>[FontFeature.tabularFigures()];

String transportSpeedLabel(double speed) =>
    speed == speed.truncateToDouble() ? '${speed.toInt()}x' : '${speed}x';

String transportVolumePhrase(double volume) => '${(volume * 100).round()}%';

@immutable
final class TransportValue {
  const TransportValue({
    required this.position,
    required this.total,
    required this.isPlaying,
    this.active = true,
    this.onToggle,
    this.onSeek,
    this.onScrubUpdate,
    this.onScrubEnd,
  });

  final Duration position;
  final Duration? total;
  final bool isPlaying;
  final bool active;
  final VoidCallback? onToggle;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<Duration>? onScrubUpdate;
  final VoidCallback? onScrubEnd;
}

class PlayPauseGlyph extends StatelessWidget {
  const PlayPauseGlyph({
    super.key,
    required this.playing,
    required this.color,
    this.size = 15,
  });

  final bool playing;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PlayPauseGlyphPainter(playing: playing, color: color),
    );
  }
}

class _PlayPauseGlyphPainter extends CustomPainter {
  const _PlayPauseGlyphPainter({required this.playing, required this.color});

  final bool playing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = color;
    if (playing) {
      final double barWidth = size.width * 0.3;
      canvas.drawRect(Rect.fromLTWH(0, 0, barWidth, size.height), fill);
      canvas.drawRect(
        Rect.fromLTWH(size.width - barWidth, 0, barWidth, size.height),
        fill,
      );
      return;
    }
    final Path triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, fill);
  }

  @override
  bool shouldRepaint(_PlayPauseGlyphPainter oldDelegate) =>
      playing != oldDelegate.playing || color != oldDelegate.color;
}

enum TransportGlyph {
  back10,
  forward10,
  volume,
  muted,
  fullScreen,
  exitFullScreen,
  back,
  more,
}

class TransportGlyphIcon extends StatelessWidget {
  const TransportGlyphIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = _iconSize,
  });

  final TransportGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TransportGlyphPainter(glyph: glyph, color: color),
    );
  }
}

class _TransportGlyphPainter extends CustomPainter {
  const _TransportGlyphPainter({required this.glyph, required this.color});

  final TransportGlyph glyph;
  final Color color;

  static Path _speaker() => Path()
    ..moveTo(4, 9.8)
    ..lineTo(4, 14.2)
    ..lineTo(7, 14.2)
    ..lineTo(11.2, 17.8)
    ..lineTo(11.2, 6.2)
    ..lineTo(7, 9.8)
    ..close();

  static Path _corners(List<List<Offset>> runs) {
    final Path path = Path();
    for (final List<Offset> run in runs) {
      path.moveTo(run.first.dx, run.first.dy);
      for (final Offset point in run.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  Path _stroked() => switch (glyph) {
    TransportGlyph.back10 =>
      Path()
        ..moveTo(12, 5)
        ..arcToPoint(
          const Offset(4.6, 10),
          radius: const Radius.circular(8),
          largeArc: true,
        )
        ..moveTo(12.2, 2)
        ..lineTo(8.8, 5)
        ..lineTo(12.2, 8),
    TransportGlyph.forward10 =>
      Path()
        ..moveTo(12, 5)
        ..arcToPoint(
          const Offset(19.4, 10),
          radius: const Radius.circular(8),
          largeArc: true,
          clockwise: false,
        )
        ..moveTo(11.8, 2)
        ..lineTo(15.2, 5)
        ..lineTo(11.8, 8),
    TransportGlyph.volume =>
      Path()
        ..moveTo(15, 9)
        ..arcToPoint(const Offset(15, 15), radius: const Radius.circular(4.2))
        ..moveTo(17.6, 6.6)
        ..arcToPoint(
          const Offset(17.6, 17.4),
          radius: const Radius.circular(7.6),
        ),
    TransportGlyph.muted => _corners(const <List<Offset>>[
      <Offset>[Offset(15.5, 9.5), Offset(20.5, 14.5)],
      <Offset>[Offset(20.5, 9.5), Offset(15.5, 14.5)],
    ]),
    TransportGlyph.fullScreen => _corners(const <List<Offset>>[
      <Offset>[Offset(5, 9.5), Offset(5, 5), Offset(9.5, 5)],
      <Offset>[Offset(19, 9.5), Offset(19, 5), Offset(14.5, 5)],
      <Offset>[Offset(5, 14.5), Offset(5, 19), Offset(9.5, 19)],
      <Offset>[Offset(19, 14.5), Offset(19, 19), Offset(14.5, 19)],
    ]),
    TransportGlyph.exitFullScreen => _corners(const <List<Offset>>[
      <Offset>[Offset(9.5, 5), Offset(9.5, 9.5), Offset(5, 9.5)],
      <Offset>[Offset(14.5, 5), Offset(14.5, 9.5), Offset(19, 9.5)],
      <Offset>[Offset(9.5, 19), Offset(9.5, 14.5), Offset(5, 14.5)],
      <Offset>[Offset(14.5, 19), Offset(14.5, 14.5), Offset(19, 14.5)],
    ]),
    TransportGlyph.back => _corners(const <List<Offset>>[
      <Offset>[Offset(19, 12), Offset(5.5, 12)],
      <Offset>[Offset(11, 6), Offset(5, 12), Offset(11, 18)],
    ]),
    TransportGlyph.more => Path(),
  };

  void _paintTen(Canvas canvas) {
    final TextPainter ten = TextPainter(
      text: TextSpan(
        text: '10',
        style: TextStyle(
          fontFamily: TypographyTokens.sans,
          fontSize: _tenFontSize,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ten.paint(
      canvas,
      Offset(
        (_viewBox - ten.width) / 2,
        _tenBaseline -
            ten.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      ),
    );
    ten.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint fill = Paint()..color = color;
    if (glyph == TransportGlyph.volume || glyph == TransportGlyph.muted) {
      canvas.drawPath(_speaker(), fill);
    }
    if (glyph == TransportGlyph.more) {
      for (final double x in const <double>[6, 12, 18]) {
        canvas.drawCircle(Offset(x, 12), 1.6, fill);
      }
    }
    canvas.drawPath(_stroked(), stroke);
    if (glyph == TransportGlyph.back10 || glyph == TransportGlyph.forward10) {
      _paintTen(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TransportGlyphPainter oldDelegate) =>
      glyph != oldDelegate.glyph || color != oldDelegate.color;
}

class TransportIconButton extends StatelessWidget {
  const TransportIconButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.onPressed,
    this.shortcut,
    this.glyphSize = _iconSize,
  });

  final TransportGlyph glyph;
  final String label;
  final VoidCallback? onPressed;
  final String? shortcut;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final String? keyName = shortcut;
    return Pressable(
      label: label,
      tooltip: keyName == null ? label : '$label ($keyName)',
      iconOnly: true,
      onPressed: onPressed,
      borderRadius: _iconRadius,
      builder: (BuildContext context, bool hovered) => SizedBox.square(
        dimension: minIconTargetOn(Theme.of(context).platform),
        child: Center(
          child: Opacity(
            opacity: onPressed == null ? _disabledAlpha : 1,
            child: TransportGlyphIcon(
              glyph: glyph,
              color: hovered ? colors.ink : colors.inkSoft,
              size: glyphSize,
            ),
          ),
        ),
      ),
    );
  }
}

enum TransportPlayFace { accent, quiet, cta }

class TransportPlayButton extends StatelessWidget {
  const TransportPlayButton({
    super.key,
    required this.face,
    required this.playing,
    required this.onPressed,
    this.diameter,
  });

  final TransportPlayFace face;
  final bool playing;
  final VoidCallback? onPressed;
  final double? diameter;

  Color _fill(FieldNotesColors colors, bool hovered) => switch (face) {
    TransportPlayFace.accent => Palette.coral,
    TransportPlayFace.quiet => const Color(0x00000000),
    TransportPlayFace.cta => hovered ? colors.mediaCtaHover : colors.mediaCta,
  };

  Color _glyph(FieldNotesColors colors) => switch (face) {
    TransportPlayFace.accent => FieldNotesColors.light.cardBright,
    TransportPlayFace.quiet => colors.ink,
    TransportPlayFace.cta => colors.mediaCtaInk,
  };

  FocusRingSurface get _hoverSurface => face == TransportPlayFace.accent
      ? FocusRingSurface.dark
      : FocusRingSurface.light;

  Widget _disc(BuildContext context, double extent, bool hovered) {
    final FieldNotesColors colors = context.colors;
    final bool accent = face == TransportPlayFace.accent;
    return HoverFill(
      hovered: hovered && face != TransportPlayFace.cta,
      surface: _hoverSurface,
      shape: HoverShape.circle,
      borderRadius: _circleRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _fill(colors, hovered),
          shape: BoxShape.circle,
          border: accent ? context.shadows.outline : null,
          boxShadow: accent ? context.shadows.chip : null,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(
              left: playing ? 0 : extent * _playGlyphNudge,
            ),
            child: PlayPauseGlyph(
              playing: playing,
              color: _glyph(colors),
              size: extent * _playGlyphShare,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double extent =
        diameter ?? minIconTargetOn(Theme.of(context).platform);
    final String label = playing ? 'Pause' : 'Play';
    return Pressable(
      label: label,
      tooltip: '$label (Space)',
      iconOnly: true,
      onPressed: onPressed,
      shape: HoverShape.circle,
      borderRadius: _circleRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => SizedBox.square(
        dimension: extent,
        child: Opacity(
          opacity: onPressed == null ? _disabledAlpha : 1,
          child: _disc(context, extent, hovered),
        ),
      ),
    );
  }
}

class TransportTimeLabel extends StatelessWidget {
  const TransportTimeLabel({
    super.key,
    required this.position,
    required this.total,
  });

  final Duration position;
  final Duration? total;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Text.rich(
      TextSpan(
        text: formatMediaDuration(position.inMilliseconds),
        children: <InlineSpan>[
          TextSpan(
            text: ' / ${formatMediaDuration(total?.inMilliseconds)}',
            style: TextStyle(color: colors.muted),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
      style: transportTimeStyle(context),
    );
  }
}

TextStyle transportTimeStyle(BuildContext context) =>
    context.textStyles.captionSans.copyWith(
      color: context.colors.ink,
      fontSize: _timeSize,
      fontWeight: FontWeight.w500,
      fontFeatures: _tabular,
    );

class TransportVolume extends StatefulWidget {
  const TransportVolume({
    super.key,
    required this.tuning,
    required this.rail,
    required this.alwaysOpen,
  });

  final PlaybackTuning tuning;
  final Color rail;
  final bool alwaysOpen;

  @override
  State<TransportVolume> createState() => _TransportVolumeState();
}

class _TransportVolumeState extends State<TransportVolume> {
  bool _hovered = false;
  bool _focusWithin = false;

  bool get _open => widget.alwaysOpen || _hovered || _focusWithin;

  void _onFocusWithin(bool focused) {
    if (focused != _focusWithin) {
      setState(() => _focusWithin = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final PlaybackTuning tuning = widget.tuning;
    final bool silent = tuning.audibleVolume == 0;
    final String muteLabel = tuning.muted ? 'Unmute' : 'Mute';
    return MouseRegion(
      opaque: false,
      onEnter: (PointerEnterEvent event) => setState(() => _hovered = true),
      onExit: (PointerExitEvent event) => setState(() => _hovered = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: _onFocusWithin,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TransportIconButton(
              key: transportMuteKey,
              glyph: silent ? TransportGlyph.muted : TransportGlyph.volume,
              label: muteLabel,
              shortcut: 'M',
              onPressed: tuning.toggleMute,
            ),
            AnimatedContainer(
              duration: still ? Duration.zero : Motion.fade,
              curve: Motion.entranceCurve,
              width: _open
                  ? _volumeTrack + _volumeGapBefore + _volumeGapAfter
                  : 0,
              height: _volumeHeight,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: _volumeTrack + _volumeGapBefore + _volumeGapAfter,
                maxWidth: _volumeTrack + _volumeGapBefore + _volumeGapAfter,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: _volumeGapBefore,
                    right: _volumeGapAfter,
                  ),
                  child: _VolumeSlider(tuning: tuning, rail: widget.rail),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider({required this.tuning, required this.rail});

  final PlaybackTuning tuning;
  final Color rail;

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  final FocusNode _pressFocus = FocusNode(
    debugLabel: 'transport volume press',
    skipTraversal: true,
  );
  bool _focused = false;

  bool get _ringed => _focused && InputModality.instance.traversing;

  @override
  void initState() {
    super.initState();
    InputModality.instance.addListener(_onModalityChanged);
  }

  @override
  void dispose() {
    InputModality.instance.removeListener(_onModalityChanged);
    _pressFocus.dispose();
    super.dispose();
  }

  void _onModalityChanged() {
    if (mounted && _focused) {
      setState(() {});
    }
  }

  void _setFrom(double dx) =>
      widget.tuning.setVolume((dx / _volumeTrack).clamp(0.0, 1.0));

  void _onFocusHighlight(bool focused) {
    if (focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  void _nudge(double delta) =>
      widget.tuning.setVolume(widget.tuning.volume + delta);

  double _nudged(double delta) =>
      (widget.tuning.volume + delta).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final PlaybackTuning tuning = widget.tuning;
    final FieldNotesColors colors = context.colors;
    return FocusableActionDetector(
      includeFocusSemantics: false,
      onShowFocusHighlight: _onFocusHighlight,
      child: Semantics(
        container: true,
        slider: true,
        label: 'Volume',
        value: transportVolumePhrase(tuning.audibleVolume),
        increasedValue: transportVolumePhrase(_nudged(transportVolumeStep)),
        decreasedValue: transportVolumePhrase(_nudged(-transportVolumeStep)),
        onIncrease: () => _nudge(transportVolumeStep),
        onDecrease: () => _nudge(-transportVolumeStep),
        child: ExcludeSemantics(
          child: Pressable(
            key: transportVolumeKey,
            label: 'Volume',
            onPressedAt: (Offset local) => _setFrom(local.dx),
            paintsHover: false,
            focusNode: _pressFocus,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onHorizontalDragStart: (DragStartDetails details) =>
                  _setFrom(details.localPosition.dx),
              onHorizontalDragUpdate: (DragUpdateDetails details) =>
                  _setFrom(details.localPosition.dx),
              child: SizedBox(
                width: _volumeTrack,
                height: _volumeHeight,
                child: CustomPaint(
                  key: _ringed ? focusRingKey : null,
                  painter: _VolumePainter(
                    level: tuning.audibleVolume,
                    rail: widget.rail,
                    fill: colors.ink,
                    ring: _ringed ? colors.ink : null,
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

class _VolumePainter extends CustomPainter {
  const _VolumePainter({
    required this.level,
    required this.rail,
    required this.fill,
    required this.ring,
  });

  final double level;
  final Color rail;
  final Color fill;
  final Color? ring;

  @override
  void paint(Canvas canvas, Size size) {
    final double top = (size.height - _volumeRailHeight) / 2;
    const Radius radius = Radius.circular(_volumeRailHeight / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, _volumeRailHeight),
        radius,
      ),
      Paint()..color = rail,
    );
    final double filled = size.width * level;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, filled, _volumeRailHeight),
        radius,
      ),
      Paint()..color = fill,
    );
    canvas.drawCircle(
      Offset(filled, size.height / 2),
      _volumeKnobRadius,
      Paint()..color = fill,
    );
    final Color? outline = ring;
    if (outline != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(Shapes.radius8),
        ),
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_VolumePainter oldDelegate) =>
      level != oldDelegate.level ||
      rail != oldDelegate.rail ||
      fill != oldDelegate.fill ||
      ring != oldDelegate.ring;
}

class TransportSpeedButton extends StatefulWidget {
  const TransportSpeedButton({super.key, required this.tuning});

  final PlaybackTuning tuning;

  @override
  State<TransportSpeedButton> createState() => _TransportSpeedButtonState();
}

class _TransportSpeedButtonState extends State<TransportSpeedButton> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final Object _tapGroup = Object();
  final List<FocusNode> _choiceFocus = <FocusNode>[
    for (final double speed in playbackSpeeds)
      FocusNode(debugLabel: 'transport speed $speed'),
  ];
  FocusNode? _returnFocus;
  bool _open = false;

  @override
  void dispose() {
    for (final FocusNode node in _choiceFocus) {
      node.dispose();
    }
    super.dispose();
  }

  int get _currentIndex {
    final int index = playbackSpeeds.indexOf(widget.tuning.speed);
    return index < 0 ? 0 : index;
  }

  void _toggle() {
    if (_open) {
      _close();
      return;
    }
    _returnFocus = FocusManager.instance.primaryFocus;
    setState(() {
      _open = true;
      _portal.show();
    });
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted && _open) {
        _choiceFocus[_currentIndex].requestFocus();
      }
    });
  }

  void _close() {
    if (!_open) {
      return;
    }
    setState(() {
      _open = false;
      _portal.hide();
    });
    final FocusNode? previous = _returnFocus;
    _returnFocus = null;
    if (previous != null &&
        previous.context != null &&
        previous.canRequestFocus) {
      previous.requestFocus();
    }
  }

  void _pick(double speed) {
    widget.tuning.setSpeed(speed);
    _close();
  }

  void _moveFocus(int step) {
    final int count = _choiceFocus.length;
    final int focused = _choiceFocus.indexWhere(
      (FocusNode node) => node.hasPrimaryFocus,
    );
    final int from = focused < 0 ? _currentIndex : focused;
    _choiceFocus[(from + step) % count].requestFocus();
  }

  KeyEventResult _onMenuKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _menu(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.topRight,
        followerAnchor: Alignment.bottomRight,
        offset: const Offset(0, -_speedMenuGap),
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (PointerDownEvent event) => _close(),
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            includeSemantics: false,
            onKeyEvent: _onMenuKey,
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                key: transportSpeedMenuKey,
                width: _speedMenuWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.cardBright,
                    borderRadius: _menuRadius,
                    border: context.shadows.outline,
                    boxShadow: context.shadows.hero,
                  ),
                  child: Padding(
                    padding: _speedMenuPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (
                          int index = 0;
                          index < playbackSpeeds.length;
                          index++
                        )
                          _speedChoice(context, index),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _speedChoice(BuildContext context, int index) {
    final FieldNotesColors colors = context.colors;
    final double speed = playbackSpeeds[index];
    final bool chosen = speed == widget.tuning.speed;
    return Pressable(
      key: transportSpeedChoiceKey(speed),
      label: transportSpeedLabel(speed),
      selected: chosen,
      focusNode: _choiceFocus[index],
      onPressed: () => _pick(speed),
      borderRadius: _menuItemRadius,
      placement: FocusRingPlacement.edge,
      builder: (BuildContext context, bool hovered) => ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minIconTargetOn(Theme.of(context).platform),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _speedItemInset),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              transportSpeedLabel(speed),
              style: transportTimeStyle(context)
                  .copyWith(color: chosen ? colors.accentInk : colors.ink),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final double target = minIconTargetOn(Theme.of(context).platform);
    final String label = transportSpeedLabel(widget.tuning.speed);
    return TapRegion(
      groupId: _tapGroup,
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _menu,
          child: Pressable(
            key: transportSpeedKey,
            label: 'Playback speed',
            value: label,
            tooltip: 'Playback speed',
            iconOnly: true,
            onPressed: _toggle,
            shape: HoverShape.pill,
            borderRadius: _speedRadius,
            builder: (BuildContext context, bool hovered) => ConstrainedBox(
              constraints: BoxConstraints(minWidth: target, minHeight: target),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _speedPadding),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: transportTimeStyle(context)
                        .copyWith(color: hovered ? colors.ink : colors.inkSoft),
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

class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.value,
    required this.tuning,
    required this.face,
    required this.rail,
    required this.volumeAlwaysOpen,
    required this.onBack10,
    required this.onForward10,
    this.playKey,
    this.onFullScreen,
    this.fullScreen = false,
    this.showSpeed = true,
  });

  final bool showSpeed;
  final TransportValue value;
  final PlaybackTuning tuning;
  final TransportPlayFace face;
  final Color rail;
  final bool volumeAlwaysOpen;
  final VoidCallback? onBack10;
  final VoidCallback? onForward10;
  final Key? playKey;
  final VoidCallback? onFullScreen;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final TargetPlatform platform = Theme.of(context).platform;
    final VoidCallback? full = onFullScreen;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minIconTargetOn(platform)),
      child: Row(
        children: <Widget>[
          TransportPlayButton(
            key: playKey,
            face: face,
            playing: value.isPlaying,
            onPressed: value.onToggle,
          ),
          const SizedBox(width: _playGap),
          TransportIconButton(
            key: transportBack10Key,
            glyph: TransportGlyph.back10,
            label: 'Back 10 seconds',
            shortcut: 'J',
            onPressed: onBack10,
          ),
          TransportIconButton(
            key: transportForward10Key,
            glyph: TransportGlyph.forward10,
            label: 'Forward 10 seconds',
            shortcut: 'L',
            onPressed: onForward10,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _timeInset),
              child: TransportTimeLabel(
                position: value.position,
                total: value.total,
              ),
            ),
          ),
          if (isDesktopPlatform(platform))
            TransportVolume(
              tuning: tuning,
              rail: rail,
              alwaysOpen: volumeAlwaysOpen,
            ),
          if (showSpeed) TransportSpeedButton(tuning: tuning),
          if (full != null)
            TransportIconButton(
              key: transportFullScreenKey,
              glyph: fullScreen
                  ? TransportGlyph.exitFullScreen
                  : TransportGlyph.fullScreen,
              label: fullScreen ? 'Exit full screen' : 'Full screen',
              shortcut: 'F',
              onPressed: full,
            ),
        ],
      ),
    );
  }
}

class TransportDock extends StatelessWidget {
  const TransportDock({
    super.key,
    required this.value,
    required this.tuning,
    required this.onBack10,
    required this.onForward10,
    this.playKey,
    this.onBack,
    this.backLabel = 'Back',
    this.onMore,
  });

  final TransportValue value;
  final PlaybackTuning tuning;
  final VoidCallback? onBack10;
  final VoidCallback? onForward10;
  final Key? playKey;
  final VoidCallback? onBack;
  final String backLabel;
  final VoidCallback? onMore;

  Widget _slot(Widget? child) =>
      Expanded(child: Center(child: child ?? const SizedBox.shrink()));

  @override
  Widget build(BuildContext context) {
    final VoidCallback? back = onBack;
    final VoidCallback? more = onMore;
    final TextStyle now = transportTimeStyle(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              formatMediaDuration(value.position.inMilliseconds),
              style: now,
            ),
            TransportSpeedButton(tuning: tuning),
            Text(
              formatMediaDuration(value.total?.inMilliseconds),
              style: now.copyWith(color: context.colors.muted),
            ),
          ],
        ),
        const SizedBox(height: _dockRowGap),
        Row(
          children: <Widget>[
            _slot(
              back == null
                  ? null
                  : TransportIconButton(
                      key: transportDockBackKey,
                      glyph: TransportGlyph.back,
                      label: backLabel,
                      onPressed: back,
                    ),
            ),
            _slot(
              TransportIconButton(
                key: transportBack10Key,
                glyph: TransportGlyph.back10,
                label: 'Back 10 seconds',
                glyphSize: _dockSkipSize,
                onPressed: onBack10,
              ),
            ),
            _slot(
              TransportPlayButton(
                key: playKey,
                face: TransportPlayFace.cta,
                playing: value.isPlaying,
                diameter: _dockPlayDiameter,
                onPressed: value.onToggle,
              ),
            ),
            _slot(
              TransportIconButton(
                key: transportForward10Key,
                glyph: TransportGlyph.forward10,
                label: 'Forward 10 seconds',
                glyphSize: _dockSkipSize,
                onPressed: onForward10,
              ),
            ),
            _slot(
              more == null
                  ? null
                  : TransportIconButton(
                      key: transportDockMoreKey,
                      glyph: TransportGlyph.more,
                      label: 'More',
                      onPressed: more,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

double _readoutOpacity(double progress) {
  if (progress < _readoutFadeIn) {
    return progress / _readoutFadeIn;
  }
  if (progress < _readoutFadeOut) {
    return 1;
  }
  return (1 - progress) / (1 - _readoutFadeOut);
}

class TransportReadout extends StatelessWidget {
  const TransportReadout({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.mediaBubble,
        borderRadius: _readoutRadius,
        border: Border.all(color: colors.ink22, width: _readoutBorder),
      ),
      child: Padding(
        padding: _readoutPadding,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: context.textStyles.captionSans.copyWith(
            color: colors.mediaBubbleInk,
            fontSize: _readoutFontSize,
            fontWeight: FontWeight.w500,
            height: 1,
            fontFeatures: _tabular,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: still
            ? face
            : TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: transportReadoutHold,
                builder: (
                  BuildContext context,
                  double progress,
                  Widget? child,
                ) => Opacity(opacity: _readoutOpacity(progress), child: child),
                child: face,
              ),
      ),
    );
  }
}
