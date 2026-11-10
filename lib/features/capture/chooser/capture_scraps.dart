import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/focus/keyboard_focus_builder.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';

const double captureScrapLift = 7;

const Key captureScrapPileKey = ValueKey<String>('capture-scrap-pile');

Key captureScrapKey(EntryType type) =>
    ValueKey<String>('capture-scrap-${type.id}');

Key captureScrapPaperKey(EntryType type) =>
    ValueKey<String>('capture-scrap-paper-${type.id}');

bool captureTextEnlarged(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(_textProbe) > _textProbe;

const double _textProbe = 1;

const double _scrapOverlap = 10;
const double _wrapGap = 10;
const double _wrapRunGap = 28;

const Duration _dealLength = Motion.stage;
const Duration _dealSpan = Duration(milliseconds: 600);
const double _dealRise = 46;
const double _dealExtraTilts = 3;

const double _labelSize = 26;
const double _descriptionSize = 17;
const double _descriptionLineHeight = 1.05;

const double _hoverShadowOffset = 3;
const double _hoverShadowAlpha = 0.24;

const double _firstSlipRule = 17;
const double _slipRulePeriod = 28;
const double _slipRuleThickness = 1;
const double _slipRuleAlpha = 0.22;
const double _slipMarginX = 27;
const double _slipMarginAlpha = 0.55;
const double _punchFirstX = 10;
const double _punchPeriod = 20;
const double _punchCentreY = 10;
const double _punchRadius = 4.2;
const double _punchRimRadius = 5.2;
const double _noteLabelLine = 24;
const double _noteDescriptionLine = 28;
const double _noteLabelBottom = 10;
const double _pencilTiltDegrees = 6;

const double _tagHoleSize = 13;
const double _tagHoleTop = 9;
const double _tagStringTop = -26;
const double _tagStringOffset = 13;
const Size _tagStringSize = Size(30, 42);
const double _tagStringWidth = 1.4;
const double _waveBarRadius = 2;
const List<double> _waveBars = <double>[
  .34,
  .62,
  .88,
  .46,
  .72,
  1,
  .58,
  .30,
  .76,
  .92,
  .48,
  .66,
  .38,
  .24,
];

const double _photoInkAlpha = 0.22;
const double _photoEdgeWidth = 1;
const Color _photoSkyTop = Color(0xFFF2B980);
const Color _photoSkyBottom = Color(0xFF8E6E86);
const Color _photoSun = Color(0xFFFFF1D2);
const Color _photoHill = Color(0xFF3F4D3C);
const Color _photoShutterDot = Color(0xFFC86075);
const double _photoShutterRingAlpha = 0.92;
const double _photoShutterRingWidth = 2.5;
const double _photoSunRight = 26;
const double _photoSunTop = 22;
const double _photoSunSize = 26;
const double _photoHillSpill = 0.1;
const double _photoHillBelow = 34;
const double _photoHillHeight = 84;

double _radians(double degrees) => degrees * math.pi / 180;

class _ScrapSpec {
  const _ScrapSpec({
    required this.size,
    required this.tiltDegrees,
    required this.drop,
    required this.dealDelay,
    required this.radius,
  });

  final Size size;
  final double tiltDegrees;
  final double drop;
  final Duration dealDelay;
  final double radius;
}

const _ScrapSpec _noteSpec = _ScrapSpec(
  size: Size(178, 200),
  tiltDegrees: -3.2,
  drop: 0,
  dealDelay: Duration(milliseconds: 40),
  radius: 3,
);

const _ScrapSpec _voiceSpec = _ScrapSpec(
  size: Size(158, 176),
  tiltDegrees: 2.6,
  drop: 16,
  dealDelay: Duration(milliseconds: 110),
  radius: Shapes.radius10,
);

const _ScrapSpec _videoSpec = _ScrapSpec(
  size: Size(172, 208),
  tiltDegrees: -1.5,
  drop: 5,
  dealDelay: Duration(milliseconds: 180),
  radius: 4,
);

_ScrapSpec _specFor(EntryType type) => switch (type) {
  EntryType.text => _noteSpec,
  EntryType.voice => _voiceSpec,
  EntryType.video => _videoSpec,
};

class _ScrapCopy {
  const _ScrapCopy({
    required this.label,
    required this.description,
    required this.available,
    required this.textEnlarged,
  });

  final String label;
  final String description;
  final bool available;
  final bool textEnlarged;
}

class CaptureScraps extends StatefulWidget {
  const CaptureScraps({
    super.key,
    required this.availableTypes,
    required this.unavailableLabel,
    required this.onSelected,
  });

  final Set<EntryType> availableTypes;
  final String unavailableLabel;
  final ValueChanged<EntryType> onSelected;

  @override
  State<CaptureScraps> createState() => _CaptureScrapsState();
}

class _CaptureScrapsState extends State<CaptureScraps>
    with SingleTickerProviderStateMixin {
  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: _dealSpan,
  );
  bool _dealStarted = false;
  EntryType? _raised;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dealStarted) {
      return;
    }
    _dealStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _deal.value = 1;
    } else {
      _deal.forward();
    }
  }

  @override
  void dispose() {
    _deal.dispose();
    super.dispose();
  }

  void _liftChanged(EntryType type, bool lifted) {
    final EntryType? raised = lifted
        ? type
        : (_raised == type ? null : _raised);
    if (raised != _raised) {
      setState(() => _raised = raised);
    }
  }

  Size _sizeOf(EntryType type) => _specFor(type).size;

  double _leftOf(int index) => captureOptions
      .take(index)
      .fold<double>(
        0,
        (double left, CaptureOption option) =>
            left + _sizeOf(option.type).width - _scrapOverlap,
      );

  double get _pileWidth => _leftOf(captureOptions.length) + _scrapOverlap;

  double get _pileHeight => captureOptions
      .map(
        (CaptureOption option) =>
            _sizeOf(option.type).height + _specFor(option.type).drop,
      )
      .reduce(math.max);

  Animation<double> _dealtFor(_ScrapSpec spec) => _deal.drive(
    CurveTween(
      curve: Interval(
        spec.dealDelay.inMilliseconds / _dealSpan.inMilliseconds,
        (spec.dealDelay + _dealLength).inMilliseconds /
            _dealSpan.inMilliseconds,
        curve: Motion.entranceCurve,
      ),
    ),
  );

  Widget _dealtScrap(
    CaptureOption option, {
    required bool textEnlarged,
    required double textScale,
  }) {
    final _ScrapSpec spec = _specFor(option.type);
    final Animation<double> dealt = _dealtFor(spec);
    final double tilt = textEnlarged ? 0 : spec.tiltDegrees;
    final bool available = widget.availableTypes.contains(option.type);
    return FadeTransition(
      opacity: dealt,
      alwaysIncludeSemantics: true,
      child: AnimatedBuilder(
        animation: dealt,
        builder: (BuildContext context, Widget? child) {
          final double left = 1 - dealt.value;
          return Transform.translate(
            offset: Offset(0, _dealRise * left),
            child: Transform.rotate(
              angle: _radians(tilt * _dealExtraTilts * left),
              child: child,
            ),
          );
        },
        child: _Scrap(
          option: option,
          spec: spec,
          width: _sizeOf(option.type).width * textScale,
          height: _sizeOf(option.type).height,
          tiltDegrees: tilt,
          copy: _ScrapCopy(
            label: option.label,
            description: available
                ? option.description
                : widget.unavailableLabel,
            available: available,
            textEnlarged: textEnlarged,
          ),
          onSelected: available ? widget.onSelected : null,
          onLiftChanged: (bool lifted) => _liftChanged(option.type, lifted),
        ),
      ),
    );
  }

  Widget _positioned(int index) {
    final CaptureOption option = captureOptions[index];
    return Positioned(
      key: ValueKey<EntryType>(option.type),
      left: _leftOf(index),
      top: _specFor(option.type).drop,
      child: _dealtScrap(option, textEnlarged: false, textScale: 1),
    );
  }

  Widget _pile() {
    final List<int> indexes = List<int>.generate(
      captureOptions.length,
      (int index) => index,
    );
    final List<int> raisedLast = <int>[
      for (final int index in indexes)
        if (captureOptions[index].type != _raised) index,
      for (final int index in indexes)
        if (captureOptions[index].type == _raised) index,
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: _pileWidth,
        height: _pileHeight,
        child: Stack(
          key: captureScrapPileKey,
          clipBehavior: Clip.none,
          children: <Widget>[
            for (final int index in raisedLast) _positioned(index),
          ],
        ),
      ),
    );
  }

  Widget _wrapped(double textScale) => Wrap(
    alignment: WrapAlignment.center,
    spacing: _wrapGap,
    runSpacing: _wrapRunGap,
    children: <Widget>[
      for (final CaptureOption option in captureOptions)
        _dealtScrap(option, textEnlarged: true, textScale: textScale),
    ],
  );

  @override
  Widget build(BuildContext context) => captureTextEnlarged(context)
      ? _wrapped(MediaQuery.textScalerOf(context).scale(_textProbe))
      : _pile();
}

class _Scrap extends StatefulWidget {
  const _Scrap({
    required this.option,
    required this.spec,
    required this.width,
    required this.height,
    required this.tiltDegrees,
    required this.copy,
    required this.onSelected,
    required this.onLiftChanged,
  });

  final CaptureOption option;
  final _ScrapSpec spec;
  final double width;
  final double height;
  final double tiltDegrees;
  final _ScrapCopy copy;
  final ValueChanged<EntryType>? onSelected;
  final ValueChanged<bool> onLiftChanged;

  @override
  State<_Scrap> createState() => _ScrapState();
}

class _ScrapState extends State<_Scrap> {
  final FocusNode _focusNode = FocusNode();
  bool _reportedLift = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _reportLift(bool lifted) {
    if (lifted == _reportedLift) {
      return;
    }
    _reportedLift = lifted;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        widget.onLiftChanged(lifted);
      }
    });
  }

  Widget _face() => switch (widget.option.type) {
    EntryType.text => _NoteSlip(widget.copy),
    EntryType.voice => _VoiceTag(widget.copy),
    EntryType.video => _InstantPhoto(widget.copy),
  };

  Color _surface(FieldNotesColors colors) => switch (widget.option.type) {
    EntryType.text => colors.cardLight,
    EntryType.voice => colors.cardWarm,
    EntryType.video => colors.cardBright,
  };

  @override
  Widget build(BuildContext context) {
    final EntryType type = widget.option.type;
    final ValueChanged<EntryType>? onSelected = widget.onSelected;
    final BorderRadius radius = BorderRadius.circular(widget.spec.radius);
    return KeyboardFocusBuilder(
      focusNode: _focusNode,
      builder: (BuildContext context, bool keyboardFocused) => Pressable(
        key: captureScrapKey(type),
        label: '${widget.copy.label}\n${widget.copy.description}',
        onPressed: onSelected == null ? null : () => onSelected(type),
        focusNode: _focusNode,
        borderRadius: radius,
        paintsHover: false,
        ringsFace: true,
        builder: (BuildContext context, bool hovered) {
          final bool lifted = hovered || keyboardFocused;
          _reportLift(lifted);
          return _ScrapPose(
            lifted: lifted,
            tiltDegrees: widget.tiltDegrees,
            child: FocusRingFace(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: widget.width,
                  maxWidth: widget.width,
                  minHeight: widget.height,
                ),
                child: _Paper(
                  key: captureScrapPaperKey(type),
                  surface: _surface(context.colors),
                  radius: radius,
                  available: widget.copy.available,
                  lifted: lifted,
                  child: _face(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScrapPose extends StatelessWidget {
  const _ScrapPose({
    required this.lifted,
    required this.tiltDegrees,
    required this.child,
  });

  final bool lifted;
  final double tiltDegrees;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: lifted ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Motion.fade,
      curve: Motion.entranceCurve,
      builder: (BuildContext context, double lift, Widget? paper) =>
          Transform.translate(
            offset: Offset(0, -captureScrapLift * lift),
            child: Transform.rotate(
              angle: _radians(tiltDegrees) * (1 - lift),
              child: paper,
            ),
          ),
      child: child,
    );
  }
}

class _Paper extends StatelessWidget {
  const _Paper({
    super.key,
    required this.surface,
    required this.radius,
    required this.available,
    required this.lifted,
    required this.child,
  });

  final Color surface;
  final BorderRadius radius;
  final bool available;
  final bool lifted;
  final Widget child;

  List<BoxShadow>? _shadow(BuildContext context) {
    if (!available) {
      return null;
    }
    if (!lifted) {
      return context.shadows.cardDefault;
    }
    return <BoxShadow>[
      BoxShadow(
        color: context.colors.shadowTintBase.withValues(
          alpha: _hoverShadowAlpha,
        ),
        offset: const Offset(_hoverShadowOffset, _hoverShadowOffset),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: available
            ? context.shadows.outline
            : Border.all(color: colors.dashMuted, width: Shapes.outlineWidth),
        borderRadius: radius,
        boxShadow: _shadow(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Shapes.outlineWidth),
        child: child,
      ),
    );
  }
}

class _ScrapText extends StatelessWidget {
  const _ScrapText({
    required this.copy,
    this.labelLine,
    this.labelBottom = 0,
    this.descriptionLine,
  });

  final _ScrapCopy copy;
  final double? labelLine;
  final double labelBottom;
  final double? descriptionLine;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final TextStyle hand = context.textStyles.accent;
    const double labelSize = _labelSize;
    const double descriptionSize = _descriptionSize;
    final double? labelLinePixels = labelLine;
    final double? descriptionLinePixels = descriptionLine;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(bottom: labelBottom),
          child: Text(
            copy.label,
            overflow: TextOverflow.visible,
            style: hand.copyWith(
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
              height: labelLinePixels == null ? 1 : labelLinePixels / labelSize,
              color: copy.available ? colors.ink : colors.muted,
            ),
          ),
        ),
        Text(
          copy.description,
          style: hand.copyWith(
            fontSize: descriptionSize,
            fontWeight: FontWeight.w500,
            height: descriptionLinePixels == null
                ? _descriptionLineHeight
                : descriptionLinePixels / descriptionSize,
            color: colors.muted,
          ),
        ),
      ],
    );
  }
}

class _NoteSlip extends StatelessWidget {
  const _NoteSlip(this.copy);

  final _ScrapCopy copy;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    const double pencilSize = 46;
    const double pencilRight = 10;
    const double pencilBottom = 10;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _NoteSlipPainter(
              rule: colors.ink.withValues(alpha: _slipRuleAlpha),
              margin: colors.accentBright.withValues(alpha: _slipMarginAlpha),
              punch: colors.line,
              punchRim: colors.cardBright,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            36,
            50,
            8,
            copy.textEnlarged ? pencilSize + pencilBottom : 0,
          ),
          child: _ScrapText(
            copy: copy,
            labelLine: _noteLabelLine,
            labelBottom: _noteLabelBottom,
            descriptionLine: _noteDescriptionLine,
          ),
        ),
        Positioned(
          right: pencilRight,
          bottom: pencilBottom,
          child: Transform.rotate(
            angle: copy.textEnlarged ? 0 : _radians(_pencilTiltDegrees),
            child: CaptureIcon(
              glyph: CaptureGlyph.pencil,
              color: copy.available ? colors.accentInk : colors.dashMuted,
              size: pencilSize,
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceTag extends StatelessWidget {
  const _VoiceTag(this.copy);

  final _ScrapCopy copy;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 30, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: 54,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    color: copy.available ? Palette.coral : colors.dashMuted,
                    gap: 3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ScrapText(copy: copy),
            ],
          ),
        ),
        Positioned(
          top: _tagStringTop,
          left: _tagStringOffset * 2,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox.fromSize(
              size: _tagStringSize,
              child: CustomPaint(painter: _TagStringPainter(colors.line)),
            ),
          ),
        ),
        Positioned(
          top: _tagHoleTop,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox.square(
              dimension: _tagHoleSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.cardBright,
                  border: copy.available
                      ? context.shadows.outline
                      : Border.all(
                          color: colors.dashMuted,
                          width: Shapes.outlineWidth,
                        ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InstantPhoto extends StatelessWidget {
  const _InstantPhoto(this.copy);

  final _ScrapCopy copy;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 128,
            child: CustomPaint(
              painter: _InstantPhotoPainter(
                developed: copy.available,
                blank: colors.hatchMid,
                blankShutter: colors.dashMuted,
                edge: colors.ink.withValues(alpha: _photoInkAlpha),
                shutterSize: 46,
                shutterDotSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 9),
          _ScrapText(copy: copy),
        ],
      ),
    );
  }
}

class _NoteSlipPainter extends CustomPainter {
  const _NoteSlipPainter({
    required this.rule,
    required this.margin,
    required this.punch,
    required this.punchRim,
  });

  final Color rule;
  final Color margin;
  final Color punch;
  final Color punchRim;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint rulePaint = Paint()..color = rule;
    for (double y = _firstSlipRule; y < size.height; y += _slipRulePeriod) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, _slipRuleThickness),
        rulePaint,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(_slipMarginX, 0, _slipRuleThickness, size.height),
      Paint()..color = margin,
    );
    final Paint rimPaint = Paint()..color = punchRim;
    final Paint punchPaint = Paint()..color = punch;
    for (
      double x = _punchFirstX;
      x + _punchRimRadius <= size.width;
      x += _punchPeriod
    ) {
      final Offset centre = Offset(x, _punchCentreY);
      canvas.drawCircle(centre, _punchRimRadius, rimPaint);
      canvas.drawCircle(centre, _punchRadius, punchPaint);
    }
  }

  @override
  bool shouldRepaint(_NoteSlipPainter oldDelegate) =>
      oldDelegate.rule != rule ||
      oldDelegate.margin != margin ||
      oldDelegate.punch != punch ||
      oldDelegate.punchRim != punchRim;
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.color, required this.gap});

  final Color color;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final double barWidth =
        (size.width - gap * (_waveBars.length - 1)) / _waveBars.length;
    final Paint paint = Paint()..color = color;
    for (final (int index, double level) in _waveBars.indexed) {
      final double height = size.height * level;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            index * (barWidth + gap),
            (size.height - height) / 2,
            barWidth,
            height,
          ),
          const Radius.circular(_waveBarRadius),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.gap != gap;
}

class _TagStringPainter extends CustomPainter {
  const _TagStringPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path string = Path()
      ..moveTo(2, 40)
      ..cubicTo(-2, 26, 4, 14, 12, 10)
      ..cubicTo(20, 6, 26, 12, 20, 20)
      ..cubicTo(14, 28, 4, 22, 6, 16);
    canvas.drawPath(
      string,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _tagStringWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TagStringPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _InstantPhotoPainter extends CustomPainter {
  const _InstantPhotoPainter({
    required this.developed,
    required this.blank,
    required this.blankShutter,
    required this.edge,
    required this.shutterSize,
    required this.shutterDotSize,
  });

  final bool developed;
  final Color blank;
  final Color blankShutter;
  final Color edge;
  final double shutterSize;
  final double shutterDotSize;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect frame = Offset.zero & size;
    canvas.save();
    canvas.clipRect(frame);
    if (developed) {
      _paintScene(canvas, size, frame);
    } else {
      canvas.drawRect(frame, Paint()..color = blank);
    }
    _paintShutter(canvas, size);
    canvas.restore();
    canvas.drawRect(
      frame.deflate(_photoEdgeWidth / 2),
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = _photoEdgeWidth,
    );
  }

  void _paintScene(Canvas canvas, Size size, Rect frame) {
    canvas.drawRect(
      frame,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_photoSkyTop, _photoSkyBottom],
        ).createShader(frame),
    );
    canvas.drawCircle(
      Offset(
        size.width - _photoSunRight - _photoSunSize / 2,
        _photoSunTop + _photoSunSize / 2,
      ),
      _photoSunSize / 2,
      Paint()..color = _photoSun,
    );
    final double spill = size.width * _photoHillSpill;
    canvas.drawOval(
      Rect.fromLTRB(
        -spill,
        size.height + _photoHillBelow - _photoHillHeight,
        size.width + spill,
        size.height + _photoHillBelow,
      ),
      Paint()..color = _photoHill,
    );
  }

  void _paintShutter(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    canvas.drawCircle(
      centre,
      shutterSize / 2 - _photoShutterRingWidth / 2,
      Paint()
        ..color = developed
            ? Palette.mediaInk.withValues(alpha: _photoShutterRingAlpha)
            : blankShutter
        ..style = PaintingStyle.stroke
        ..strokeWidth = _photoShutterRingWidth,
    );
    canvas.drawCircle(
      centre,
      shutterDotSize / 2,
      Paint()..color = developed ? _photoShutterDot : blankShutter,
    );
  }

  @override
  bool shouldRepaint(_InstantPhotoPainter oldDelegate) =>
      oldDelegate.developed != developed ||
      oldDelegate.blank != blank ||
      oldDelegate.blankShutter != blankShutter ||
      oldDelegate.edge != edge ||
      oldDelegate.shutterSize != shutterSize ||
      oldDelegate.shutterDotSize != shutterDotSize;
}

class RuledPaper extends StatelessWidget {
  const RuledPaper({
    super.key,
    required this.color,
    required this.firstRule,
    required this.period,
    required this.child,
    this.inset = 0,
    this.cornerRadius = 0,
  });

  final Color color;
  final double firstRule;
  final double period;
  final double inset;
  final double cornerRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RuledPaperPainter(
        color: color,
        firstRule: firstRule,
        period: period,
        inset: inset,
        cornerRadius: cornerRadius,
      ),
      child: child,
    );
  }
}

class _RuledPaperPainter extends CustomPainter {
  const _RuledPaperPainter({
    required this.color,
    required this.firstRule,
    required this.period,
    required this.inset,
    required this.cornerRadius,
  });

  final Color color;
  final double firstRule;
  final double period;
  final double inset;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect paper = (Offset.zero & size).deflate(inset);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        paper,
        Radius.circular(math.max(0, cornerRadius - inset)),
      ),
    );
    final Paint paint = Paint()..color = color;
    for (double y = paper.top + firstRule; y < paper.bottom; y += period) {
      canvas.drawRect(Rect.fromLTWH(paper.left, y, paper.width, 1), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RuledPaperPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.firstRule != firstRule ||
      oldDelegate.period != period ||
      oldDelegate.inset != inset ||
      oldDelegate.cornerRadius != cornerRadius;
}
