import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/flowers/garden_art_colors.dart';
import 'package:field_notes/design/flowers/garden_plant_painter.dart';
import 'package:field_notes/design/flowers/garden_plant_spec.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'a day';
const String _title = 'How was today, honestly?';
const String _happyCaptionSidebar =
    "that's your peony from earlier · pick another if today felt different";
const String _happyCaptionBottomBar = 'your peony · swipe for nine more →';
const String _otherCaptionSidebar = 'one flower a day · nobody else sees this';
const String _otherCaptionBottomBar = 'one flower a day · swipe for more →';

const Key dayMoodRowKey = ValueKey<String>('day-mood-row');
const Key daySoilKey = ValueKey<String>('day-soil');
const Key dayCardKey = ValueKey<String>('day-card');

Key dayMoodKey(Mood mood) => ValueKey<String>('day-mood-${mood.id}');

Key dayPlantKey(FlowerKind kind) => ValueKey<String>('day-plant-${kind.name}');

const int _mask = 0xFFFFFFFF;
const int _seedStep = 0x6D2B79F5;
const double _seedRange = 4294967296;

const double _tileBorder = 2;
const double _cardBorder = 1.5;
const double _plantRoom = 12;
const double _captionSide = 16;

const Duration _headingRise = Duration(milliseconds: 500);
const Duration _tilePop = Duration(milliseconds: 450);
const Duration _tilePopDelay = Duration(milliseconds: 350);
const int _tileStaggerMs = 60;
const Duration _tileShift = Duration(milliseconds: 150);
const Duration _captionFade = Duration(milliseconds: 600);
const Duration _captionDelay = Duration(milliseconds: 1400);
const Duration _cardPop = Duration(milliseconds: 450);
const Duration _cardDelay = Duration(milliseconds: 800);
const Duration _plantGrow = Duration(milliseconds: 900);
const Duration _swayDelay = Duration(milliseconds: 1400);
const Duration _swayPeriod = Duration(seconds: 5);

const double _riseDistance = 14;
const Cubic _tileCurve = Cubic(0.2, 0.9, 0.3, 1.2);
const Cubic _growCurve = Cubic(0.3, 0.8, 0.3, 1);
const double _popPeak = 0.6;
const double _popFrom = 0.2;
const double _popOver = 1.08;
const double _growFrom = 0.82;
const double _growSpill = 0.2;
const double _swayDegrees = 2.2;
const double _swayStartPhase = 0.25;

const Color _soilTop = Color(0xFF7D5838);
const Color _soilMid = Color(0xFF5E3F27);
const Color _soilDeep = Color(0xFF3F2A1A);
const Color _soilShade = Color(0x592A1A0E);
const Color _soilShadeClear = Color(0x002A1A0E);
const Color _soilCrust = Color(0xCCA37B52);
const Color _soilHole = Color(0xBF2E1D10);
const Color _speckDark = Color(0xFF3A2616);
const Color _speckLight = Color(0xFFA3794E);
const Color _pebbleFill = Color(0xFFB7A68B);
const Color _pebbleEdge = Color(0xFF7A6A54);
const Color _pebbleShine = Color(0xB3D8CCB6);

const List<double> _grassSpots = <double>[0.05, 0.13, 0.84, 0.93, 0.24, 0.74];

String _caption(ShellLayout layout, Mood mood) =>
    switch ((layout, mood == Mood.happy)) {
      (ShellLayout.sidebar, true) => _happyCaptionSidebar,
      (ShellLayout.bottomBar, true) => _happyCaptionBottomBar,
      (ShellLayout.sidebar, false) => _otherCaptionSidebar,
      (ShellLayout.bottomBar, false) => _otherCaptionBottomBar,
    };

@immutable
class _DayMetrics {
  const _DayMetrics({
    required this.centred,
    required this.snaps,
    required this.headingGap,
    required this.rowTop,
    required this.rowBottom,
    required this.rowSide,
    required this.tileWidth,
    required this.tileHeight,
    required this.tileGap,
    required this.tileRadius,
    required this.flower,
    required this.labelGap,
    required this.labelSize,
    required this.tileShadow,
    required this.captionGap,
    required this.captionSize,
    required this.captionFades,
    required this.soilHeight,
    required this.plantBottom,
    required this.plantHeight,
    required this.cardBottom,
    required this.cardFromCentre,
    required this.cardRight,
    required this.cardPadding,
    required this.cardRadius,
    required this.cardShadow,
    required this.cardLabelSize,
    required this.cardFlowerSize,
  });

  static const _DayMetrics sidebar = _DayMetrics(
    centred: true,
    snaps: false,
    headingGap: 42,
    rowTop: 6,
    rowBottom: 10,
    rowSide: 30,
    tileWidth: 76,
    tileHeight: 88,
    tileGap: 8,
    tileRadius: 16,
    flower: 40,
    labelGap: 6,
    labelSize: 11.5,
    tileShadow: Offset(2, 2),
    captionGap: 6,
    captionSize: 17,
    captionFades: true,
    soilHeight: 120,
    plantBottom: 92,
    plantHeight: 250,
    cardBottom: 210,
    cardFromCentre: 96,
    cardRight: null,
    cardPadding: EdgeInsets.fromLTRB(12, 6, 12, 5),
    cardRadius: 8,
    cardShadow: Offset(2, 2),
    cardLabelSize: 18,
    cardFlowerSize: 15,
  );

  static const _DayMetrics bottomBar = _DayMetrics(
    centred: false,
    snaps: true,
    headingGap: 14,
    rowTop: 4,
    rowBottom: 6,
    rowSide: 18,
    tileWidth: 62,
    tileHeight: 70,
    tileGap: 7,
    tileRadius: 13,
    flower: 32,
    labelGap: 3,
    labelSize: 10,
    tileShadow: Offset(2, 2),
    captionGap: 0,
    captionSize: 14,
    captionFades: false,
    soilHeight: 100,
    plantBottom: 76,
    plantHeight: 200,
    cardBottom: 190,
    cardFromCentre: null,
    cardRight: 14,
    cardPadding: EdgeInsets.fromLTRB(9, 4, 9, 3),
    cardRadius: 7,
    cardShadow: Offset(1.5, 1.5),
    cardLabelSize: 14,
    cardFlowerSize: 12,
  );

  static _DayMetrics of(ShellLayout layout) => switch (layout) {
    ShellLayout.sidebar => sidebar,
    ShellLayout.bottomBar => bottomBar,
  };

  final bool centred;
  final bool snaps;
  final double headingGap;
  final double rowTop;
  final double rowBottom;
  final double rowSide;
  final double tileWidth;
  final double tileHeight;
  final double tileGap;
  final double tileRadius;
  final double flower;
  final double labelGap;
  final double labelSize;
  final Offset tileShadow;
  final double captionGap;
  final double captionSize;
  final bool captionFades;
  final double soilHeight;
  final double plantBottom;
  final double plantHeight;
  final double cardBottom;
  final double? cardFromCentre;
  final double? cardRight;
  final EdgeInsets cardPadding;
  final double cardRadius;
  final Offset cardShadow;
  final double cardLabelSize;
  final double cardFlowerSize;

  double get rowWidth =>
      moodOrder.length * tileWidth + (moodOrder.length - 1) * tileGap;
}

final _SoilArt _sidebarSoil = _SoilArt.grow(width: 924, height: 120, seed: 19);
final _SoilArt _bottomBarSoil = _SoilArt.grow(width: 300, height: 100, seed: 7);

_SoilArt _soilFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarSoil,
  ShellLayout.bottomBar => _bottomBarSoil,
};

class DayChapter extends ConsumerWidget {
  const DayChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingFlow flow = ref.watch(onboardingControllerProvider);
    if (flow is! OnboardingFlowRunning) {
      return const SizedBox.expand();
    }
    final Mood mood = flow.draft.mood;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );
    final _DayMetrics metrics = _DayMetrics.of(layout);
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Rise(
            duration: _headingRise,
            child: OnboardingHeading(
              layout: layout,
              kicker: _kicker,
              title: _title,
            ),
          ),
          SizedBox(height: metrics.headingGap),
          _MoodRow(
            metrics: metrics,
            selected: mood,
            onChoose: controller.chooseMood,
          ),
          SizedBox(height: metrics.captionGap),
          _Caption(text: _caption(layout, mood), metrics: metrics),
          Expanded(
            child: _Stage(
              metrics: metrics,
              mood: mood,
              soil: _soilFor(layout),
              onGrown: () => controller.markPlantGrown(mood),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodRow extends StatelessWidget {
  const _MoodRow({
    required this.metrics,
    required this.selected,
    required this.onChoose,
  });

  final _DayMetrics metrics;
  final Mood selected;
  final ValueChanged<Mood> onChoose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double rowWidth = metrics.rowWidth;
        final double side = metrics.centred && width >= rowWidth
            ? (width - rowWidth) / 2
            : metrics.rowSide;
        return SingleChildScrollView(
          key: dayMoodRowKey,
          scrollDirection: Axis.horizontal,
          physics: metrics.snaps
              ? _SnapPhysics(
                  lead: side,
                  extent: metrics.tileWidth,
                  step: metrics.tileWidth + metrics.tileGap,
                )
              : null,
          padding: EdgeInsets.fromLTRB(
            side,
            metrics.rowTop,
            side,
            metrics.rowBottom,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final (int index, Mood mood)
                  in moodOrder.indexed) ...<Widget>[
                if (index > 0) SizedBox(width: metrics.tileGap),
                _MoodTile(
                  mood: mood,
                  selected: mood == selected,
                  metrics: metrics,
                  delay:
                      _tilePopDelay +
                      Duration(milliseconds: index * _tileStaggerMs),
                  onTap: () => onChoose(mood),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.selected,
    required this.metrics,
    required this.delay,
    required this.onTap,
  });

  final Mood mood;
  final bool selected;
  final _DayMetrics metrics;
  final Duration delay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(metrics.tileRadius);
    final Widget face = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _tileShift,
      decoration: BoxDecoration(
        color: selected ? colors.cardLight : colors.cardWarm,
        border: Border.all(
          color: selected ? Palette.coral : colors.ink18,
          width: _tileBorder,
        ),
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: selected
                ? colors.shadow
                : colors.shadow.withValues(alpha: 0),
            offset: metrics.tileShadow,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FlowerBloom.forMood(mood, size: metrics.flower),
          SizedBox(height: metrics.labelGap),
          Text(
            mood.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontFamily: TypographyTokens.sans,
              fontSize: metrics.labelSize,
              fontWeight: FontWeight.w600,
              color: selected ? colors.accentInk : colors.ink,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      key: dayMoodKey(mood),
      container: true,
      button: true,
      selected: selected,
      label: mood.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FocusRing(
          onPressed: onTap,
          borderRadius: radius,
          child: SizedBox(
            width: metrics.tileWidth,
            height: metrics.tileHeight,
            child: ExcludeSemantics(
              child: _Pop(
                duration: _tilePop,
                delay: delay,
                curve: _tileCurve,
                child: face,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text, required this.metrics});

  final String text;
  final _DayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final Widget caption = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _captionSide),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: TypographyTokens.accent,
          fontSize: metrics.captionSize,
          fontWeight: FontWeight.w600,
          color: context.colors.mutedDeep,
        ),
      ),
    );
    if (!metrics.captionFades) {
      return caption;
    }
    return _Fade(duration: _captionFade, delay: _captionDelay, child: caption);
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.metrics,
    required this.mood,
    required this.soil,
    required this.onGrown,
  });

  final _DayMetrics metrics;
  final Mood mood;
  final _SoilArt soil;
  final VoidCallback onGrown;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final GardenPlantSpec spec = gardenPlantSpecFor(mood.flower);
        final double plantHeight = (height - metrics.plantBottom - _plantRoom)
            .clamp(0.0, metrics.plantHeight);
        final double reach = plantHeight / metrics.plantHeight;
        final double cardBottom =
            metrics.plantBottom +
            (metrics.cardBottom - metrics.plantBottom) * reach;
        final double? fromCentre = metrics.cardFromCentre;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: math.min(metrics.soilHeight, height),
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: daySoilKey,
                    painter: _SoilPainter(soil),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: metrics.plantBottom,
              height: plantHeight,
              child: ExcludeSemantics(
                child: _Sway(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: KeyedSubtree(
                      key: dayPlantKey(mood.flower),
                      child: _Grow(
                        spec: spec,
                        size: Size(plantHeight / spec.ratio, plantHeight),
                        onGrown: onGrown,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: fromCentre == null ? null : width / 2 + fromCentre,
              right: metrics.cardRight,
              bottom: cardBottom,
              child: _Pop(
                duration: _cardPop,
                delay: _cardDelay,
                curve: Curves.ease,
                child: _MoodCard(mood: mood, metrics: metrics),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.mood, required this.metrics});

  final Mood mood;
  final _DayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      key: dayCardKey,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.composerPaper,
          border: Border.all(color: colors.line, width: _cardBorder),
          borderRadius: BorderRadius.circular(metrics.cardRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadowTint(0x40),
              offset: metrics.cardShadow,
            ),
          ],
        ),
        child: Padding(
          padding: metrics.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                mood.label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: TypographyTokens.serif,
                  fontSize: metrics.cardLabelSize,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: colors.ink,
                ),
              ),
              Text(
                mood.flower.label.toLowerCase(),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: TypographyTokens.accent,
                  fontSize: metrics.cardFlowerSize,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: colors.mutedDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DayPlantPainter extends CustomPainter {
  const DayPlantPainter({required this.spec, required this.growth});

  final GardenPlantSpec spec;
  final double growth;

  @override
  void paint(Canvas canvas, Size size) {
    if (growth <= 0 || size.isEmpty) {
      return;
    }
    final double width = size.width;
    final double height = size.height;
    canvas.save();
    canvas.translate(width / 2, height);
    canvas.scale(1, _growFrom + (1 - _growFrom) * growth);
    canvas.translate(-width / 2, -height);
    canvas.clipRect(
      Rect.fromLTRB(
        -width * _growSpill * growth,
        height * (1 - (1 + _growSpill) * growth),
        width * (1 + _growSpill * growth),
        height,
      ),
    );
    GardenPlantPainter(spec).paint(canvas, size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(DayPlantPainter oldDelegate) =>
      oldDelegate.spec != spec || oldDelegate.growth != growth;
}

class _Grow extends StatefulWidget {
  const _Grow({required this.spec, required this.size, required this.onGrown});

  final GardenPlantSpec spec;
  final Size size;
  final VoidCallback onGrown;

  @override
  State<_Grow> createState() => _GrowState();
}

class _GrowState extends State<_Grow> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _plantGrow,
  )..addStatusListener(_onGrowth);

  void _onGrowth(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      scheduleMicrotask(_reportGrown);
    }
  }

  void _reportGrown() {
    if (mounted) {
      widget.onGrown();
    }
  }

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
      builder: (BuildContext context, Widget? child) => CustomPaint(
        size: widget.size,
        painter: DayPlantPainter(
          spec: widget.spec,
          growth: _growCurve.transform(_clock.value),
        ),
      ),
    );
  }
}

class _Sway extends StatefulWidget {
  const _Sway({required this.child});

  final Widget child;

  @override
  State<_Sway> createState() => _SwayState();
}

class _SwayState extends State<_Sway> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  double _angle = 0;

  void _onTick(Duration elapsed) {
    final double angle = elapsed < _swayDelay ? 0 : _angleAt(elapsed);
    if (angle != _angle) {
      setState(() => _angle = angle);
    }
  }

  static double _angleAt(Duration elapsed) {
    final double phase =
        ((elapsed - _swayDelay).inMicroseconds / _swayPeriod.inMicroseconds +
            _swayStartPhase) %
        1;
    final double degrees = phase < 0.5
        ? -_swayDegrees +
              2 * _swayDegrees * Curves.easeInOut.transform(phase * 2)
        : _swayDegrees -
              2 * _swayDegrees * Curves.easeInOut.transform(phase * 2 - 1);
    return degrees * math.pi / 180;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ticker.stop();
      _angle = 0;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: _angle,
      alignment: Alignment.bottomCenter,
      child: widget.child,
    );
  }
}

class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({
    required this.lead,
    required this.extent,
    required this.step,
    super.parent,
  });

  static const double _coastDrag = 0.135;

  final double lead;
  final double extent;
  final double step;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) => _SnapPhysics(
    lead: lead,
    extent: extent,
    step: step,
    parent: buildParent(ancestor),
  );

  double _snap(ScrollMetrics position, double coast) {
    final double first = lead + extent / 2 - position.viewportDimension / 2;
    final double index = ((coast - first) / step).roundToDouble();
    return (first + index * step).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final Tolerance tolerance = toleranceFor(position);
    final double coast = velocity.abs() < tolerance.velocity
        ? position.pixels
        : FrictionSimulation(_coastDrag, position.pixels, velocity).finalX;
    final double target = _snap(position, coast);
    if ((target - position.pixels).abs() < tolerance.distance &&
        velocity.abs() < tolerance.velocity) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _Seeded {
  _Seeded(int seed) : _state = seed & _mask;

  int _state;

  static int _imul(int a, int b) => (a * b) & _mask;

  double next() {
    _state = (_state + _seedStep) & _mask;
    final int mixed = _imul(_state ^ (_state >> 15), 1 | _state);
    final int folded =
        ((mixed + _imul(mixed ^ (mixed >> 7), 61 | mixed)) & _mask) ^ mixed;
    return ((folded ^ (folded >> 14)) & _mask) / _seedRange;
  }
}

@immutable
class _Speck {
  const _Speck({required this.oval, required this.color});

  final Rect oval;
  final Color color;
}

@immutable
class _Pebble {
  const _Pebble({required this.body, required this.shine});

  final Rect body;
  final Rect shine;
}

@immutable
class _Blade {
  const _Blade({required this.path, required this.color});

  final Path path;
  final Color color;
}

@immutable
class _SoilArt {
  const _SoilArt({
    required this.width,
    required this.height,
    required this.ground,
    required this.groundTop,
    required this.crust,
    required this.specks,
    required this.hole,
    required this.pebbles,
    required this.blades,
  });

  factory _SoilArt.grow({
    required double width,
    required double height,
    required int seed,
  }) {
    final _Seeded random = _Seeded(seed);
    final double peak = height * 0.2;
    double top(double x) {
      final double t = (x / width) * 2 - 1;
      return peak + (height * 0.55 - peak) * t * t;
    }

    final double stride = width / 24;
    final Path ground = Path()
      ..moveTo(0, height)
      ..lineTo(0, top(0));
    double groundTop = top(0);
    for (double x = 0; x <= width; x += stride) {
      final double y = top(x) + (random.next() - 0.5) * 2.2;
      groundTop = math.min(groundTop, y);
      ground.lineTo(x, y);
    }
    ground
      ..lineTo(width, height)
      ..close();

    final Path crust = Path()..moveTo(0, top(0));
    for (double x = 0; x <= width; x += stride) {
      crust.lineTo(x, top(x) + (random.next() - 0.5) * 2);
    }

    final List<_Speck> specks = <_Speck>[];
    for (int index = 0; index < (width / 4.5).round(); index++) {
      final double x = random.next() * width;
      final double y = top(x) + 3 + random.next() * (height - top(x) - 4);
      if (y >= height - 1) {
        continue;
      }
      final Color color = random.next() < 0.5 ? _speckDark : _speckLight;
      final double rx = 0.8 + random.next() * 1.8;
      final double ry = 0.6 + random.next() * 1.1;
      final double opacity = 0.35 + random.next() * 0.4;
      specks.add(
        _Speck(
          oval: Rect.fromCenter(
            center: Offset(x, y),
            width: rx * 2,
            height: ry * 2,
          ),
          color: color.withValues(alpha: opacity),
        ),
      );
    }

    final List<_Pebble> pebbles = <_Pebble>[];
    for (int index = 0; index < (width / 70).round(); index++) {
      final double x = width * 0.08 + random.next() * width * 0.84;
      final double y = top(x) + 6 + random.next() * (height - top(x) - 10);
      if ((x - width / 2).abs() < width * 0.06) {
        continue;
      }
      final double rx = 2 + random.next() * 3.5;
      pebbles.add(
        _Pebble(
          body: Rect.fromCenter(
            center: Offset(x, y),
            width: rx * 2,
            height: rx * 0.62 * 2,
          ),
          shine: Rect.fromCenter(
            center: Offset(x - rx * 0.3, y - rx * 0.2),
            width: rx * 0.35 * 2,
            height: rx * 0.18 * 2,
          ),
        ),
      );
    }

    final List<_Blade> blades = <_Blade>[];
    for (final (int spot, double share) in _grassSpots.indexed) {
      if (width < 300 && spot > 3) {
        continue;
      }
      final double gx = width * share;
      final double gy = top(gx) + 2;
      final int count = 4 + (random.next() * 3).floor();
      for (int blade = 0; blade < count; blade++) {
        final double lean =
            (blade - (count - 1) / 2) * 4 + (random.next() - 0.5) * 3;
        final double tall = height * 0.14 + random.next() * height * 0.12;
        blades.add(
          _Blade(
            path: Path()
              ..moveTo(gx + blade * 1.6 - count, gy)
              ..quadraticBezierTo(
                gx + lean * 0.4,
                gy - tall * 0.6,
                gx + lean,
                gy - tall,
              ),
            color: blade.isOdd
                ? GardenArtColors.grassMeadow
                : GardenArtColors.grassDry,
          ),
        );
      }
    }

    final double centre = width / 2;
    return _SoilArt(
      width: width,
      height: height,
      ground: ground,
      groundTop: groundTop,
      crust: crust,
      specks: List<_Speck>.unmodifiable(specks),
      hole: Rect.fromCenter(
        center: Offset(centre, top(centre) + 2.5),
        width: width * 0.035 * 2,
        height: 2.6 * 2,
      ),
      pebbles: List<_Pebble>.unmodifiable(pebbles),
      blades: List<_Blade>.unmodifiable(blades),
    );
  }

  final double width;
  final double height;
  final Path ground;
  final double groundTop;
  final Path crust;
  final List<_Speck> specks;
  final Rect hole;
  final List<_Pebble> pebbles;
  final List<_Blade> blades;
}

class _SoilPainter extends CustomPainter {
  const _SoilPainter(this.art);

  final _SoilArt art;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final double width = art.width;
    final double height = art.height;
    canvas.save();
    canvas.scale(size.width / width, size.height / height);

    canvas.save();
    canvas.translate(width / 2, height - 2);
    canvas.scale(width * 0.52, height * 0.16);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[_soilShade, _soilShadeClear],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
    );
    canvas.restore();

    canvas.drawPath(
      art.ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_soilTop, _soilMid, _soilDeep],
          stops: <double>[0, 0.55, 1],
        ).createShader(Rect.fromLTRB(0, art.groundTop, width, height)),
    );
    for (final _Speck speck in art.specks) {
      canvas.drawOval(speck.oval, Paint()..color = speck.color);
    }
    canvas.drawPath(
      art.crust,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = _soilCrust,
    );
    canvas.drawOval(art.hole, Paint()..color = _soilHole);
    final Paint pebbleFill = Paint()..color = _pebbleFill;
    final Paint pebbleEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _pebbleEdge;
    final Paint pebbleShine = Paint()..color = _pebbleShine;
    for (final _Pebble pebble in art.pebbles) {
      canvas
        ..drawOval(pebble.body, pebbleFill)
        ..drawOval(pebble.body, pebbleEdge)
        ..drawOval(pebble.shine, pebbleShine);
    }
    for (final _Blade blade in art.blades) {
      canvas.drawPath(
        blade.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = blade.color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SoilPainter oldDelegate) => oldDelegate.art != art;
}

typedef _EntranceFrame = Widget Function(double progress, Widget child);

class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.duration,
    required this.delay,
    required this.frame,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final _EntranceFrame frame;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
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

  double get _progress {
    final int delay = widget.delay.inMicroseconds;
    final int duration = widget.duration.inMicroseconds;
    final double elapsed = _clock.value * (delay + duration);
    return duration == 0 ? 1 : ((elapsed - delay) / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) =>
          widget.frame(_progress, child!),
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  static Widget _frame(double progress, Widget child) {
    final double eased = Curves.ease.transform(progress);
    return Opacity(
      opacity: eased,
      alwaysIncludeSemantics: true,
      child: Transform.translate(
        offset: Offset(0, _riseDistance * (1 - eased)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: duration,
      delay: Duration.zero,
      frame: _frame,
      child: child,
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({
    required this.duration,
    required this.delay,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final Widget child;

  static Widget _frame(double progress, Widget child) => Opacity(
    opacity: Curves.ease.transform(progress),
    alwaysIncludeSemantics: true,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: duration,
      delay: delay,
      frame: _frame,
      child: child,
    );
  }
}

class _Pop extends StatelessWidget {
  const _Pop({
    required this.duration,
    required this.delay,
    required this.curve,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Widget child;

  Widget _frame(double progress, Widget child) {
    final bool rising = progress < _popPeak;
    final double eased = rising
        ? curve.transform(progress / _popPeak)
        : curve.transform((progress - _popPeak) / (1 - _popPeak));
    final double scale = rising
        ? _popFrom + (_popOver - _popFrom) * eased
        : _popOver + (1 - _popOver) * eased;
    return Opacity(
      opacity: rising ? eased.clamp(0.0, 1.0) : 1,
      alwaysIncludeSemantics: true,
      child: Transform.scale(scale: scale, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: duration,
      delay: delay,
      frame: _frame,
      child: child,
    );
  }
}
