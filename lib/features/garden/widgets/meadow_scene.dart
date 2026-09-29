import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/features/garden/sky/sky_scene.dart';

import '../model/garden_data.dart';
import '../model/garden_insect.dart';
import '../model/garden_motion.dart';
import '../model/meadow_layout.dart';
import '../paint/meadow_painter.dart';
import '../paint/meadow_sprites.dart';

String _meadowDescription({required int blooms, required int sprouts}) {
  final String bloomPart = blooms == 1 ? '1 bloom' : '$blooms blooms';
  final String sproutPart = sprouts == 1 ? '1 sprout' : '$sprouts sprouts';
  return 'Garden meadow with $bloomPart and $sproutPart';
}

class MeadowScene extends StatefulWidget {
  const MeadowScene({
    super.key,
    required this.blooms,
    required this.sky,
    this.sprouts = const <String>[],
    this.seed = 0,
    this.compact = false,
    this.motion,
  });

  final List<GardenBloomData> blooms;
  final SkyScene sky;
  final List<String> sprouts;
  final int seed;
  final bool compact;
  final GardenMotionProfile? motion;

  @override
  State<MeadowScene> createState() => _MeadowSceneState();
}

class _LayoutInputs {
  const _LayoutInputs({
    required this.blooms,
    required this.sprouts,
    required this.seed,
    required this.compact,
    required this.size,
  });

  final List<GardenBloomData> blooms;
  final List<String> sprouts;
  final int seed;
  final bool compact;
  final Size size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LayoutInputs &&
          seed == other.seed &&
          compact == other.compact &&
          size == other.size &&
          listEquals(blooms, other.blooms) &&
          listEquals(sprouts, other.sprouts);

  @override
  int get hashCode => Object.hash(
    seed,
    compact,
    size,
    Object.hashAll(blooms),
    Object.hashAll(sprouts),
  );
}

class _MeadowSceneState extends State<MeadowScene>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Duration> _clock = ValueNotifier<Duration>(Duration.zero);
  late final Ticker _ticker = createTicker(_tick);
  GardenMotionProfile _motion = GardenMotionProfile.reduced;
  _LayoutInputs? _laidOut;
  MeadowLayout _layout = MeadowLayout.empty;
  MeadowSprites? _sprites;
  MeadowLayout? _spritedLayout;
  double? _spritedRatio;
  late List<SkyStar> _stars = skyStarsFor(widget.seed);
  late List<GardenFirefly> _fireflies = gardenFirefliesFor(widget.seed);

  void _tick(Duration elapsed) {
    _clock.value = elapsed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant MeadowScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed) {
      _stars = skyStarsFor(widget.seed);
      _fireflies = gardenFirefliesFor(widget.seed);
    }
    _syncMotion();
  }

  void _syncMotion() {
    _motion =
        widget.motion ??
        resolveGardenMotion(
          reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
          bloomCount: widget.blooms.length + widget.sprouts.length,
        );
    final bool animate = _motion == GardenMotionProfile.full;
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  MeadowLayout _layoutFor(Size size) {
    final _LayoutInputs inputs = _LayoutInputs(
      blooms: widget.blooms,
      sprouts: widget.sprouts,
      seed: widget.seed,
      compact: widget.compact,
      size: size,
    );
    if (inputs == _laidOut) {
      return _layout;
    }
    _laidOut = inputs;
    _layout = layoutMeadowByDepth(
      blooms: widget.blooms,
      sprouts: widget.sprouts,
      size: size,
      seed: widget.seed,
      compact: widget.compact,
    );
    return _layout;
  }

  MeadowSprites _spritesFor(MeadowLayout layout, double devicePixelRatio) {
    final MeadowSprites? current = _sprites;
    if (current != null &&
        identical(layout, _spritedLayout) &&
        devicePixelRatio == _spritedRatio) {
      return current;
    }
    final MeadowSprites built = MeadowSprites.build(layout, devicePixelRatio);
    _sprites = built;
    _spritedLayout = layout;
    _spritedRatio = devicePixelRatio;
    current?.dispose();
    return built;
  }

  @override
  void dispose() {
    _sprites?.dispose();
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool animate = _motion == GardenMotionProfile.full;
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final MeadowLayout layout = _layoutFor(size);
        return Semantics(
          container: true,
          label: _meadowDescription(
            blooms: widget.blooms.length,
            sprouts: widget.sprouts.length,
          ),
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: MeadowPainter(
                layout: layout,
                sprites: _spritesFor(layout, devicePixelRatio),
                sky: widget.sky,
                compact: widget.compact,
                stars: _stars,
                fireflies: _fireflies,
                insects: gardenInsectsFor(compact: widget.compact),
                animate: animate,
                clock: _clock,
              ),
            ),
          ),
        );
      },
    );
  }
}
