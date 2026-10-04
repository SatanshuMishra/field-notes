import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/motion/waveform_bob.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_frame.dart';
import 'package:flutter/widgets.dart';

const String _kicker = 'a moment';
const String _title = 'Some days are easier said.';
const String otherWaysToast =
    'Voice, video and photos all live on Today. Try them after setup.';
const String _videoLength = '0:12';

const Key otherWaysSpeakKey = ValueKey<String>('other-ways-speak');
const Key otherWaysFilmKey = ValueKey<String>('other-ways-film');
const Key otherWaysSnapKey = ValueKey<String>('other-ways-snap');

const Duration otherWaysToastLifetime = Duration(milliseconds: 3200);

const Duration _headingRise = Duration(milliseconds: 500);
const Duration _blockRise = Duration(milliseconds: 500);
const List<Duration> _blockDelays = <Duration>[
  Duration(milliseconds: 100),
  Duration(milliseconds: 200),
  Duration(milliseconds: 300),
];
const Duration _breathLength = Duration(milliseconds: 1600);

const double _riseDistance = 14;
const double _headingSide = 20;
const double _blocksTop = 14;
const double _blocksSide = 12;
const double _blocksGap = 9;
const double _blocksClearance = 12;
const double _blockRadius = 22;
const double _blockBorder = 1.5;
const Offset _blockShadow = Offset(3, 3);
const EdgeInsets _blockPadding = EdgeInsets.fromLTRB(20, 0, 16, 0);
const double _artGap = 12;

const List<double> _waveHeights = <double>[
  0.35,
  0.6,
  0.9,
  0.5,
  0.75,
  1,
  0.55,
  0.4,
  0.8,
  0.65,
  0.95,
  0.45,
  0.7,
  0.5,
];
const List<Duration> _waveBeats = <Duration>[
  Duration(milliseconds: 1100),
  Duration(milliseconds: 1280),
  Duration(milliseconds: 1460),
  Duration(milliseconds: 1640),
];

const Color _speakFill = Palette.coral;
const Color _filmFill = Color(0xFF2F2A25);
const Color _snapFill = Palette.snapSage;
const Color _white = Color(0xFFFFFFFF);
const Color _cream = Palette.creamOnSoil;
const Color _filmBody = Color(0xFFCBB99F);
const Color _stripeDark = Color(0xFF3A352E);
const Color _stripeLight = Color(0xFF443F37);
const Color _bracket = Color(0xFFF3E6D1);
const Color _recordDot = Color(0xFFE2573E);
const Color _photoShadow = Color.fromRGBO(0, 0, 0, 0.5);

@immutable
class _BlockInk {
  const _BlockInk({
    required this.kicker,
    required this.kickerAlpha,
    required this.title,
    required this.body,
    required this.bodyAlpha,
  });

  final Color kicker;
  final double kickerAlpha;
  final Color title;
  final Color body;
  final double bodyAlpha;
}

const _BlockInk _onColour = _BlockInk(
  kicker: _white,
  kickerAlpha: 0.9,
  title: _white,
  body: _white,
  bodyAlpha: 0.92,
);

_BlockInk _onDark(Color kicker) => _BlockInk(
  kicker: kicker,
  kickerAlpha: 1,
  title: _cream,
  body: _filmBody,
  bodyAlpha: 1,
);

class OtherWaysPanel extends StatelessWidget {
  const OtherWaysPanel({super.key, required this.layout});

  final ShellLayout layout;

  void _tell(BuildContext context) => showOnboardingToast(
    context,
    otherWaysToast,
    lifetime: otherWaysToastLifetime,
  );

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double gesture = math.max(
      media.padding.bottom,
      media.viewPadding.bottom,
    );
    final List<Widget> blocks = <Widget>[
      _Block(
        key: otherWaysSpeakKey,
        fill: _speakFill,
        ink: _onColour,
        kicker: 'speak',
        title: 'Say it out loud',
        body: 'On a walk, in the car. Hold it like a call.',
        art: const _Waveform(),
        onTap: () => _tell(context),
      ),
      _Block(
        key: otherWaysFilmKey,
        fill: _filmFill,
        ink: _onDark(context.colors.accentBright),
        kicker: 'film',
        title: 'Point and keep',
        body: 'Flip to the front camera, or turn it off and just talk.',
        art: const _Viewfinder(),
        onTap: () => _tell(context),
      ),
      _Block(
        key: otherWaysSnapKey,
        fill: _snapFill,
        ink: _onColour,
        kicker: 'snap',
        title: 'Add a photo',
        body: 'Straight from the camera, or one from earlier.',
        art: const _Photos(),
        onTap: () => _tell(context),
      ),
    ];
    return Padding(
      padding: EdgeInsets.only(
        top: media.padding.top + onboardingPhoneTitleTop,
        bottom: gesture + onboardingControlBarReserve + _blocksClearance,
      ),
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _Rise(
                  delay: Duration.zero,
                  duration: _headingRise,
                  child: _Heading(),
                ),
                const SizedBox(height: _blocksTop),
                for (final (int index, Widget block)
                    in blocks.indexed) ...<Widget>[
                  if (index > 0) const SizedBox(height: _blocksGap),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _blocksSide,
                      ),
                      child: _Rise(
                        delay: _blockDelays[index],
                        duration: _blockRise,
                        child: block,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _headingSide),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _kicker,
            style: TextStyle(
              fontFamily: TypographyTokens.accent,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.accentInk,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              _title,
              style: TextStyle(
                fontFamily: TypographyTokens.serif,
                fontSize: 28,
                fontWeight: FontWeight.w500,
                height: 1.08,
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    super.key,
    required this.fill,
    required this.ink,
    required this.kicker,
    required this.title,
    required this.body,
    required this.art,
    required this.onTap,
  });

  final Color fill;
  final _BlockInk ink;
  final String kicker;
  final String title;
  final String body;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    const BorderRadius radius = BorderRadius.all(Radius.circular(_blockRadius));
    return Semantics(
      button: true,
      label: title,
      hint: body,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FocusRing(
          onPressed: onTap,
          borderRadius: radius,
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: _blockPadding,
            decoration: BoxDecoration(
              color: fill,
              border: Border.all(color: colors.line, width: _blockBorder),
              borderRadius: radius,
              boxShadow: <BoxShadow>[
                BoxShadow(color: colors.shadow, offset: _blockShadow),
              ],
            ),
            child: ExcludeSemantics(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          kicker,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: TypographyTokens.accent,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: ink.kicker.withValues(
                              alpha: ink.kickerAlpha,
                            ),
                          ),
                        ),
                        Text(
                          title,
                          maxLines: 2,
                          style: TextStyle(
                            fontFamily: TypographyTokens.serif,
                            fontSize: 23,
                            fontWeight: FontWeight.w500,
                            height: 1.05,
                            color: ink.title,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TypographyTokens.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            color: ink.body.withValues(alpha: ink.bodyAlpha),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: _artGap),
                  art,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 72,
      child: Center(
        child: WaveformBars(
          heights: _waveHeights,
          perBarDurations: _waveBeats,
          barWidth: 4,
          spacing: 3,
          maxHeight: 64,
          barRadius: 2,
          color: _white.withValues(alpha: 0.92),
          animate: !MediaQuery.disableAnimationsOf(context),
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(14));
    return SizedBox(
      width: 78,
      height: 104,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: _bracket.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: CustomPaint(
          painter: const _StripePainter(),
          child: Stack(
            children: <Widget>[
              for (final Alignment corner in const <Alignment>[
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ])
                Positioned(
                  left: corner.x < 0 ? 7 : null,
                  right: corner.x > 0 ? 7 : null,
                  top: corner.y < 0 ? 7 : null,
                  bottom: corner.y > 0 ? 7 : null,
                  width: 12,
                  height: 12,
                  child: CustomPaint(painter: _BracketPainter(corner)),
                ),
              const Positioned(
                left: 0,
                right: 0,
                top: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _BreathingDot(),
                    SizedBox(width: 5),
                    Text(
                      _videoLength,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: TypographyTokens.sans,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _bracket,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  static const double _band = 7;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _stripeDark);
    final Paint light = Paint()..color = _stripeLight;
    final double reach = size.width + size.height;
    final double step = _band * 2 * math.sqrt2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double start = -reach; start < reach; start += step) {
      canvas.drawPath(
        Path()
          ..moveTo(start + _band * math.sqrt2, 0)
          ..lineTo(start + 2 * _band * math.sqrt2, 0)
          ..lineTo(start + 2 * _band * math.sqrt2 - reach, reach)
          ..lineTo(start + _band * math.sqrt2 - reach, reach)
          ..close(),
        light,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => false;
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter(this.corner);

  final Alignment corner;

  @override
  void paint(Canvas canvas, Size size) {
    final double x = corner.x < 0 ? 1 : size.width - 1;
    final double y = corner.y < 0 ? 1 : size.height - 1;
    final double across = corner.x < 0 ? size.width : 0;
    final double down = corner.y < 0 ? size.height : 0;
    canvas.drawPath(
      Path()
        ..moveTo(across, y)
        ..lineTo(x, y)
        ..lineTo(x, down),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _bracket,
    );
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) =>
      oldDelegate.corner != corner;
}

class _BreathingDot extends StatefulWidget {
  const _BreathingDot();

  @override
  State<_BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<_BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _breathLength,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        final double phase = _pulse.value;
        final double swing = phase < 0.5 ? phase * 2 : 2 - phase * 2;
        return Opacity(
          opacity: 0.55 + 0.45 * Curves.easeInOut.transform(swing),
          child: child,
        );
      },
      child: const SizedBox.square(
        dimension: 7,
        child: DecoratedBox(
          decoration: BoxDecoration(color: _recordDot, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 118,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 4,
            top: 14,
            child: _Print(turn: -9, painter: MomentJettyPainter(0)),
          ),
          Positioned(
            right: 2,
            top: 6,
            child: _Print(turn: 7, painter: MomentDuskPainter(0)),
          ),
        ],
      ),
    );
  }
}

class _Print extends StatelessWidget {
  const _Print({required this.turn, required this.painter});

  final double turn;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: turn * math.pi / 180,
      child: Container(
        width: 70,
        height: 80,
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 16),
        decoration: const BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.all(Radius.circular(4)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _photoShadow,
              offset: Offset(0, 6),
              blurRadius: 14,
              spreadRadius: -6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          child: CustomPaint(painter: painter, child: const SizedBox.expand()),
        ),
      ),
    );
  }
}

class _Rise extends StatefulWidget {
  const _Rise({
    required this.delay,
    required this.duration,
    required this.child,
  });

  final Duration delay;
  final Duration duration;
  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (_clock.isDismissed) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final int delay = widget.delay.inMicroseconds;
        final int duration = widget.duration.inMicroseconds;
        final double elapsed = _clock.value * (delay + duration);
        final double eased = Curves.ease.transform(
          ((elapsed - delay) / duration).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: eased,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, _riseDistance * (1 - eased)),
            child: child,
          ),
        );
      },
    );
  }
}
