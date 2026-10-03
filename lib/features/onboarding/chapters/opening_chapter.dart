import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/bloom_part.dart';
import 'package:field_notes/design/flowers/bloom_part_painter.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/onboarding/chapters/garden_scene.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_swipe.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'field notes';
const String _title = "Most days won't feel like a story.";
const String _subtitle =
    "Write them down anyway. Each one becomes a flower, and they're yours "
    'to keep.';
const String _plantLabel = 'Plant your first seed';
const String _hintSidebar = 'click anywhere to plant your first seed';
const String _hintBottomBar = 'tap anywhere to plant your first seed';
const String _hintEnter = 'or press Enter';

const Key openingHintKey = ValueKey<String>('opening-hint');
const Key openingHeadingKey = ValueKey<String>('opening-heading');

const Duration _hintDelay = Duration(milliseconds: 300);
const Duration _hintFadeIn = Duration(milliseconds: 800);
const Duration _hintFadeOut = Duration(milliseconds: 250);
const Duration _headingStart = Duration(milliseconds: 2600);
const Duration _headingRise = Duration(milliseconds: 800);

const double _riseDistance = 14;

const Size _arrowViewBox = Size(44, 84);
const double _arrowStroke = 2.3;

const List<BloomPart> _arrowParts = <BloomPart>[
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(24, 4),
      BloomCubicTo(10, 22, 34, 40, 22, 76),
    ],
  ),
  BloomShape(
    commands: <BloomCmd>[
      BloomMoveTo(12, 64),
      BloomLineTo(22, 77),
      BloomLineTo(31, 62),
    ],
  ),
];

typedef _Planting = ({bool planted, bool grown});

_Planting? _plantingOf(OnboardingFlow flow) => switch (flow) {
  OnboardingFlowRunning(:final OnboardingDraft draft) => (
    planted: draft.planted,
    grown: draft.grown,
  ),
  OnboardingFlowHidden() || OnboardingFlowMap() => null,
};

double _phase(double elapsed, Duration start, Duration length) =>
    ((elapsed - start.inMicroseconds) / length.inMicroseconds).clamp(0.0, 1.0);

@immutable
class _OpeningMetrics {
  const _OpeningMetrics({
    required this.headingTop,
    required this.insetHeading,
    required this.headingSide,
    required this.kickerSize,
    required this.titleSize,
    required this.titleHeight,
    required this.titleSpacing,
    required this.titleGap,
    required this.subtitleSize,
    required this.subtitleGap,
    required this.subtitleWidth,
    required this.hint,
    required this.hintBottom,
    required this.hintSide,
    required this.hintWidth,
    required this.hintSize,
    required this.hintHeight,
    required this.hintGap,
    required this.showEnter,
    required this.arrowSize,
  });

  static const _OpeningMetrics sidebar = _OpeningMetrics(
    headingTop: 78,
    insetHeading: false,
    headingSide: 40,
    kickerSize: 26,
    titleSize: 48,
    titleHeight: 1.06,
    titleSpacing: -0.48,
    titleGap: 10,
    subtitleSize: 16,
    subtitleGap: 10,
    subtitleWidth: 500,
    hint: _hintSidebar,
    hintBottom: 273,
    hintSide: 24,
    hintWidth: double.infinity,
    hintSize: 32,
    hintHeight: null,
    hintGap: 6,
    showEnter: true,
    arrowSize: Size(44, 84),
  );

  static const _OpeningMetrics bottomBar = _OpeningMetrics(
    headingTop: 58,
    insetHeading: true,
    headingSide: 26,
    kickerSize: 24,
    titleSize: 32,
    titleHeight: 1.1,
    titleSpacing: 0,
    titleGap: 10,
    subtitleSize: 14,
    subtitleGap: 10,
    subtitleWidth: 280,
    hint: _hintBottomBar,
    hintBottom: 282,
    hintSide: 24,
    hintWidth: 260,
    hintSize: 28,
    hintHeight: 1.1,
    hintGap: 2,
    showEnter: false,
    arrowSize: Size(36, 70),
  );

  static _OpeningMetrics of(ShellLayout layout) => switch (layout) {
    ShellLayout.sidebar => sidebar,
    ShellLayout.bottomBar => bottomBar,
  };

  final double headingTop;
  final bool insetHeading;
  final double headingSide;
  final double kickerSize;
  final double titleSize;
  final double titleHeight;
  final double titleSpacing;
  final double titleGap;
  final double subtitleSize;
  final double subtitleGap;
  final double subtitleWidth;
  final String hint;
  final double hintBottom;
  final double hintSide;
  final double hintWidth;
  final double hintSize;
  final double? hintHeight;
  final double hintGap;
  final bool showEnter;
  final Size arrowSize;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double fit = math.min(
      size.width / _arrowViewBox.width,
      size.height / _arrowViewBox.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - _arrowViewBox.width * fit) / 2,
      (size.height - _arrowViewBox.height * fit) / 2,
    );
    canvas.scale(fit);
    BloomPartPainter(
      strokeColor: color,
      strokeWidth: _arrowStroke,
    ).paintAll(canvas, _arrowParts);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}

class _BalancedText extends StatelessWidget {
  const _BalancedText({
    required this.text,
    required this.style,
    required this.maxWidth,
  });

  final String text;
  final TextStyle style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double room = math.min(maxWidth, constraints.maxWidth);
        final TextScaler scaler = MediaQuery.textScalerOf(context);
        final TextDirection direction = Directionality.of(context);
        int linesAt(double width) {
          final TextPainter painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textAlign: TextAlign.center,
            textDirection: direction,
            textScaler: scaler,
          )..layout(maxWidth: width);
          final int lines = painter.computeLineMetrics().length;
          painter.dispose();
          return lines;
        }

        final double width = room.isFinite ? _narrowest(room, linesAt) : room;
        return SizedBox(
          width: width.isFinite ? width : null,
          child: Text(text, textAlign: TextAlign.center, style: style),
        );
      },
    );
  }

  static double _narrowest(double room, int Function(double width) linesAt) {
    final int lines = linesAt(room);
    if (lines <= 1) {
      return room;
    }
    double low = room / lines;
    double high = room;
    for (int step = 0; step < 12; step++) {
      final double middle = (low + high) / 2;
      if (linesAt(middle) > lines) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return high.ceilToDouble();
  }
}

class OpeningChapter extends ConsumerStatefulWidget {
  const OpeningChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  ConsumerState<OpeningChapter> createState() => _OpeningChapterState();
}

class _OpeningChapterState extends ConsumerState<OpeningChapter>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _hintDelay + _hintFadeIn,
  );
  late final AnimationController _growth = AnimationController(
    vsync: this,
    duration: gardenPlantingLength,
  );
  late final Listenable _hintMotion = Listenable.merge(<Listenable>[
    _entrance,
    _growth,
  ]);
  bool _still = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      if (_still) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
      _follow(_plantingOf(ref.read(onboardingControllerProvider)));
    } else if (_still) {
      _entrance.value = 1;
      if (_growth.isAnimating) {
        _growth.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _growth.dispose();
    _entrance.dispose();
    super.dispose();
  }

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  double get _elapsed => _growth.value * gardenPlantingLength.inMicroseconds;

  void _plant() => _controller.plant();

  void _follow(_Planting? planting) {
    if (planting == null) {
      return;
    }
    if (!planting.planted) {
      _growth.value = 0;
    } else if (planting.grown || _still) {
      _growth.value = 1;
    } else if (_growth.isDismissed) {
      _growth.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<_Planting?>(
      onboardingControllerProvider.select(_plantingOf),
      (_Planting? previous, _Planting? next) => _follow(next),
    );
    final _Planting? planting = ref.watch(
      onboardingControllerProvider.select(_plantingOf),
    );
    if (planting == null) {
      return const SizedBox.expand();
    }
    final bool planted = planting.planted;
    final _OpeningMetrics metrics = _OpeningMetrics.of(widget.layout);
    final FieldNotesColors colors = context.colors;
    final double top =
        metrics.headingTop +
        (metrics.insetHeading ? MediaQuery.paddingOf(context).top : 0);
    final Widget heading = _heading(metrics, colors, planted: planted);
    return SizedBox.expand(
      child: Semantics(
        container: true,
        button: planted ? null : true,
        label: planted ? null : _plantLabel,
        onTap: planted ? null : _plant,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: planted ? null : _plant,
          child: FocusRing(
            enabled: !planted,
            onPressed: planted ? null : _plant,
            placement: FocusRingPlacement.edge,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  left: metrics.hintSide,
                  right: metrics.hintSide,
                  bottom: metrics.hintBottom,
                  child: _hint(metrics, colors),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  child: planted
                      ? OnboardingSwipeLayer(child: heading)
                      : heading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(
    _OpeningMetrics metrics,
    FieldNotesColors colors, {
    required bool planted,
  }) {
    return AnimatedBuilder(
      key: openingHeadingKey,
      animation: _growth,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: metrics.headingSide),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              container: true,
              child: Text(
                _kicker,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TypographyTokens.accent,
                  fontSize: metrics.kickerSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: colors.accentInk,
                ),
              ),
            ),
            SizedBox(height: metrics.titleGap),
            Semantics(
              container: true,
              header: true,
              child: Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TypographyTokens.serif,
                  fontSize: metrics.titleSize,
                  fontWeight: FontWeight.w500,
                  height: metrics.titleHeight,
                  letterSpacing: metrics.titleSpacing,
                  color: colors.ink,
                ),
              ),
            ),
            SizedBox(height: metrics.subtitleGap),
            Semantics(
              container: true,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metrics.subtitleWidth),
                child: Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: TypographyTokens.sans,
                    fontSize: metrics.subtitleSize,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: colors.mutedDeep,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        final double shown = Curves.ease.transform(
          _phase(_elapsed, _headingStart, _headingRise),
        );
        return Opacity(
          opacity: shown,
          alwaysIncludeSemantics: planted,
          child: Transform.translate(
            offset: Offset(0, _riseDistance * (1 - shown)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _hint(_OpeningMetrics metrics, FieldNotesColors colors) {
    return AnimatedBuilder(
      key: openingHintKey,
      animation: _hintMotion,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _BalancedText(
              text: metrics.hint,
              maxWidth: metrics.hintWidth,
              style: TextStyle(
                fontFamily: TypographyTokens.accent,
                fontSize: metrics.hintSize,
                fontWeight: FontWeight.w600,
                height: metrics.hintHeight,
                color: colors.ink,
              ),
            ),
            if (metrics.showEnter) ...<Widget>[
              SizedBox(height: metrics.hintGap),
              Text(
                _hintEnter,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.muted,
                ),
              ),
            ],
            SizedBox(height: metrics.hintGap),
            SizedBox.fromSize(
              size: metrics.arrowSize,
              child: CustomPaint(painter: _ArrowPainter(colors.ink)),
            ),
          ],
        ),
      ),
      builder: (BuildContext context, Widget? child) {
        final double gone = Curves.ease.transform(
          _phase(_elapsed, Duration.zero, _hintFadeOut),
        );
        if (gone >= 1) {
          return const SizedBox.shrink();
        }
        final double shown = Curves.ease.transform(
          _phase(
            _entrance.value * (_hintDelay + _hintFadeIn).inMicroseconds,
            _hintDelay,
            _hintFadeIn,
          ),
        );
        return Opacity(opacity: shown * (1 - gone), child: child);
      },
    );
  }
}
