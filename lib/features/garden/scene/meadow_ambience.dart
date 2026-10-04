import 'dart:math' as math;
import 'dart:ui';

import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/garden/model/meadow_random.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';

const int _beeCount = 3;
const int _butterflyCount = 2;
const int _fireflyCount = 28;
const int meadowButterflyKinds = 4;
const double _brightButterflyMean = 0.6;
const Offset _awayHive = Offset(-40, 420);
const double _awayHiveScale = 0.4;
const double _butterflyStartScale = 0.35;
const double _longestStep = 0.05;
const double _dayHidden = 0.05;
const double _fireflyHidden = 0.02;
const double _quickWingPeriod = 0.13;
const double _butterflyRestWingPeriod = 1.7;
const double _butterflyFlightWingPeriod = 0.2;
const double _pocketFlashPeriod = 2.1;
const double _pocketPhaseSpread = 0.07;
const double _brightScore = 60000;
const double _positiveScore = 15000;
const double _verticalWeight = 1.6;
const double _fullCircle = 6.28;
const int _beeRecent = 5;
const int _butterflyRecent = 6;
const double _degrees = math.pi / 180;
const double _settleSeconds = 0.35;
const double _swayShare = 0.3;

const Set<Mood> _openMoods = <Mood>{
  Mood.warm,
  Mood.anxious,
  Mood.hopeful,
  Mood.grateful,
  Mood.happy,
  Mood.calm,
  Mood.love,
};

enum MeadowFlyerActivity { away, flying, perched }

class MeadowFlyerPose {
  const MeadowFlyerPose({
    required this.position,
    required this.scale,
    required this.facing,
    required this.rotation,
    required this.opacity,
    required this.wingPeriod,
    required this.wingPhase,
    required this.variant,
    required this.activity,
    required this.flower,
    this.left,
    this.progress = 0,
  });

  final Offset position;
  final double scale;
  final double facing;
  final double rotation;
  final double opacity;
  final double wingPeriod;
  final double wingPhase;
  final int variant;
  final MeadowFlyerActivity activity;
  final int? flower;
  final int? left;
  final double progress;

  double get flowerHold => switch (activity) {
    MeadowFlyerActivity.perched => 1,
    MeadowFlyerActivity.flying => _ease(1 - (1 - progress) / _swayShare),
    MeadowFlyerActivity.away => 0,
  };

  double get leftHold => activity == MeadowFlyerActivity.flying
      ? _ease(1 - progress / _swayShare)
      : 0;
}

class MeadowFireflyPose {
  const MeadowFireflyPose({
    required this.position,
    required this.size,
    required this.opacity,
    required this.inMist,
  });

  final Offset position;
  final double size;
  final double opacity;
  final bool inMist;
}

class MeadowAmbience {
  factory MeadowAmbience({
    required int seed,
    required MeadowTerrain terrain,
    required MeadowPlants plants,
    required MeadowYear year,
  }) {
    final MeadowRandom random = MeadowRandom(
      meadowPartSeed(seed, MeadowPart.ambience),
    );
    final MeadowOldSpruce? spruce = terrain.forest.oldSpruce;
    final _Home home = spruce == null
        ? _Home(_awayHive.dx, _awayHive.dy, _awayHiveScale)
        : _Home(spruce.hive.dx, spruce.hive.dy, meadowNearScale / spruce.depth);
    final MeadowWindow? brightest = year.brightest;
    final int beeCount = _beeCount + (spruce == null ? 0 : 1);
    final int butterflyCount =
        _butterflyCount +
        (brightest != null && brightest.mean > _brightButterflyMean ? 1 : 0);
    final List<_Flyer> bees = <_Flyer>[
      for (int i = 0; i < beeCount; i++)
        _Flyer(
          x: home.x,
          y: home.y,
          s: home.s,
          state: _State.away,
          wait: random.between(0, 4),
          phase: random.between(0, 6),
          variant: 0,
          wingPeriod: _quickWingPeriod,
          size: _beeSize(home.s),
        ),
    ];
    final List<Offset> butterflyHomes = terrain.sky.butterflyHomes;
    final List<_Flyer> butterflies = <_Flyer>[
      for (int i = 0; i < butterflyCount; i++)
        _Flyer(
          x: butterflyHomes[i % butterflyHomes.length].dx,
          y: butterflyHomes[i % butterflyHomes.length].dy,
          s: _butterflyStartScale,
          state: _State.away,
          wait: random.between(0, 3),
          phase: random.between(0, 6),
          variant: i % meadowButterflyKinds,
          wingPeriod: _quickWingPeriod,
          size: _butterflySize(_butterflyStartScale),
        ),
    ];
    final List<MeadowFireflyHome> homes = plants.fireflyHomes;
    final List<_Firefly> fireflies = <_Firefly>[
      if (homes.isNotEmpty)
        for (int i = 0; i < _fireflyCount; i++)
          _Firefly.around(random, homes[random.nextInt(homes.length)]),
    ];
    return MeadowAmbience._(
      random: random,
      home: home,
      brightest: brightest,
      bees: bees,
      butterflies: butterflies,
      fireflies: fireflies,
    );
  }

  MeadowAmbience._({
    required this._random,
    required this._home,
    required this._brightest,
    required this._bees,
    required this._butterflies,
    required this._fireflies,
  }) {
    _pose(fireflies: 0);
  }

  final MeadowRandom _random;
  final _Home _home;
  final MeadowWindow? _brightest;
  final List<_Flyer> _bees;
  final List<_Flyer> _butterflies;
  final List<_Firefly> _fireflies;
  double _time = 0;
  List<MeadowFlyerPose> _beePoses = const <MeadowFlyerPose>[];
  List<MeadowFlyerPose> _butterflyPoses = const <MeadowFlyerPose>[];
  List<MeadowFireflyPose> _fireflyPoses = const <MeadowFireflyPose>[];

  List<MeadowFlyerPose> get bees => _beePoses;

  List<MeadowFlyerPose> get butterflies => _butterflyPoses;

  List<MeadowFireflyPose> get fireflies => _fireflyPoses;

  void step(
    double seconds, {
    required List<MeadowPlant> targets,
    required double dayLife,
    required double fireflies,
  }) {
    final double dt = math.min(_longestStep, math.max(0.0, seconds));
    _time += dt;
    for (final _Flyer bee in _bees) {
      bee.flap(dt);
      if (dayLife < _dayHidden) {
        bee.opacity = 0;
      } else {
        _stepBee(bee, dt, targets);
      }
    }
    final List<MeadowPlant> open = <MeadowPlant>[
      for (final MeadowPlant plant in targets)
        if (_openMoods.contains(plant.mood)) plant,
    ];
    for (final _Flyer butterfly in _butterflies) {
      butterfly.flap(dt);
      if (dayLife < _dayHidden) {
        butterfly.opacity = 0;
      } else {
        _stepButterfly(butterfly, dt, open);
      }
    }
    _pose(fireflies: fireflies);
  }

  void _stepBee(_Flyer bee, double dt, List<MeadowPlant> targets) {
    final double opacity = bee.state == _State.away ? 0 : 1;
    switch (bee.state) {
      case _State.flying:
        bee.t += dt / bee.duration;
        bee.place();
        if (bee.t >= 1) {
          if (bee.goingHome) {
            bee.state = _State.away;
            bee.wait = _random.between(3, 7);
            bee.goingHome = false;
          } else {
            bee.land(_random.between(1.2, 3.4));
          }
        }
      case _State.perched:
        bee.wait -= dt;
        bee.perchedFor += dt;
        if (bee.wait <= 0) {
          bee.visits++;
          if (bee.visits > _random.between(4, 8)) {
            bee.visits = 0;
            bee.goingHome = true;
            _flyTo(
              bee,
              _home.x,
              _home.y,
              _home.s,
              _random.between(150, 210),
              0.25,
              null,
            );
          } else {
            final _Pick? next = _pick(bee.x, bee.y, targets, 6, bee.recent);
            if (next != null) {
              bee.recent = _remember(next.plant, bee.recent, _beeRecent);
              _flyTo(
                bee,
                next.head.dx,
                next.head.dy,
                next.plant.scale,
                _random.between(130, 200),
                0.3,
                next.plant.dayIndex,
              );
            }
          }
        }
      case _State.away:
        bee.wait -= dt;
        if (bee.wait <= 0 && targets.isNotEmpty) {
          final _Pick? next = _pick(_home.x, _home.y, targets, 10, bee.recent);
          if (next != null) {
            _flyTo(
              bee,
              next.head.dx,
              next.head.dy,
              next.plant.scale,
              _random.between(150, 210),
              0.3,
              next.plant.dayIndex,
            );
          } else {
            bee.wait = 2;
          }
        }
    }
    final double time = _time;
    final double reach = bee.s / meadowNearScale;
    final double hover = bee.hover;
    bee.offsetX = math.sin(time * 3 + bee.phase) * 2.2 * reach * hover;
    bee.offsetY =
        (math.cos(time * 4.2 + bee.phase) * 1.4 * reach - 2) * hover +
        math.sin(time * 18 + bee.phase) * 1.2 * bee.flight;
    bee.rotation = 0;
    bee.opacity = opacity;
    bee.size = _beeSize(bee.s);
  }

  void _stepButterfly(_Flyer butterfly, double dt, List<MeadowPlant> open) {
    switch (butterfly.state) {
      case _State.flying:
        butterfly.t += dt / butterfly.duration;
        butterfly.place();
        if (butterfly.t >= 1) {
          butterfly.land(_random.between(2.5, 6));
          butterfly.wingPeriod = _butterflyRestWingPeriod;
        }
      case _State.perched:
        butterfly.wait -= dt;
        butterfly.perchedFor += dt;
        if (butterfly.wait <= 0) {
          final _Pick? next = _pick(
            butterfly.x,
            butterfly.y,
            open,
            6,
            butterfly.recent,
            _brightnessScore,
          );
          butterfly.wingPeriod = _butterflyFlightWingPeriod;
          if (next != null) {
            butterfly.recent = _remember(
              next.plant,
              butterfly.recent,
              _butterflyRecent,
            );
            _flyTo(
              butterfly,
              next.head.dx,
              next.head.dy - 3,
              next.plant.scale,
              _random.between(60, 95),
              0.55,
              next.plant.dayIndex,
            );
          } else {
            butterfly.wait = 2;
          }
        }
      case _State.away:
        butterfly.wait -= dt;
        if (butterfly.wait <= 0 && open.isNotEmpty) {
          final _Pick? next = _pick(
            butterfly.x,
            butterfly.y,
            open,
            14,
            butterfly.recent,
          );
          butterfly.wingPeriod = _butterflyFlightWingPeriod;
          if (next != null) {
            _flyTo(
              butterfly,
              next.head.dx,
              next.head.dy - 3,
              next.plant.scale,
              _random.between(60, 95),
              0.5,
              next.plant.dayIndex,
            );
          }
        }
    }
    final double time = _time;
    final double flight = butterfly.flight;
    butterfly.offsetX = 0;
    butterfly.offsetY =
        math.sin(time * 6.5 + butterfly.phase) *
        7 *
        (butterfly.s / meadowNearScale + 0.3) *
        flight;
    butterfly.rotation =
        math.sin(time * 3 + butterfly.phase) * 10 * _degrees * flight;
    butterfly.opacity = butterfly.state == _State.away ? 0 : 1;
    butterfly.size = _butterflySize(butterfly.s);
  }

  double _brightnessScore(MeadowPlant plant) {
    final MeadowWindow? bright = _brightest;
    final bool inside =
        bright != null &&
        plant.dayIndex >= bright.first &&
        plant.dayIndex <= bright.last;
    return (inside ? _brightScore : 0) +
        (plant.valence > 0 ? _positiveScore : 0);
  }

  _Pick? _pick(
    double x,
    double y,
    List<MeadowPlant> plants,
    int nearest,
    List<int> recent, [
    double Function(MeadowPlant plant)? score,
  ]) {
    if (plants.isEmpty) {
      return null;
    }
    final List<_Pick> candidates = <_Pick>[];
    for (int i = 0; i < plants.length; i++) {
      final MeadowPlant plant = plants[i];
      final int choice = _random.nextInt(plant.heads.length);
      final Offset head = plant.heads.isEmpty
          ? plant.base
          : plant.heads[choice];
      if (recent.contains(plant.dayIndex)) {
        continue;
      }
      final double dx = head.dx - x;
      final double dy = (head.dy - y) * _verticalWeight;
      candidates.add(
        _Pick(
          plant: plant,
          head: head,
          cost: dx * dx + dy * dy - (score == null ? 0 : score(plant)),
          order: i,
        ),
      );
    }
    candidates.sort((_Pick a, _Pick b) {
      final int byCost = a.cost.compareTo(b.cost);
      return byCost != 0 ? byCost : a.order.compareTo(b.order);
    });
    final int index = _random.nextInt(math.min(nearest, candidates.length));
    return index < candidates.length ? candidates[index] : null;
  }

  void _flyTo(
    _Flyer flyer,
    double tx,
    double ty,
    double ts,
    double speed,
    double arc,
    int? flower,
  ) {
    final int? left = flyer.state == _State.perched ? flyer.flower : null;
    final double hover = flyer.hover;
    final double dx = tx - flyer.x;
    final double dy = ty - flyer.y;
    final double hypot = math.sqrt(dx * dx + dy * dy);
    final double distance = hypot == 0 ? 1 : hypot;
    final double bendX = _random.between(-arc, arc);
    final double bendY = _random.between(-arc, arc);
    final double lift = _random.between(20, 60);
    flyer
      ..fromX = flyer.x
      ..fromY = flyer.y
      ..fromS = flyer.s
      ..toX = tx
      ..toY = ty
      ..toS = ts
      ..controlX = (flyer.x + tx) / 2 - dy / distance * distance * bendX
      ..controlY = (flyer.y + ty) / 2 + dx / distance * distance * bendY - lift
      ..t = 0
      ..duration = math.max(0.7, distance / speed)
      ..state = _State.flying
      ..flower = flower
      ..left = left
      ..hoverFrom = hover;
  }

  void _pose({required double fireflies}) {
    _beePoses = List<MeadowFlyerPose>.unmodifiable(<MeadowFlyerPose>[
      for (final _Flyer bee in _bees) bee.pose(facing: bee.direction),
    ]);
    _butterflyPoses = List<MeadowFlyerPose>.unmodifiable(<MeadowFlyerPose>[
      for (final _Flyer butterfly in _butterflies) butterfly.pose(facing: 1),
    ]);
    _fireflyPoses = List<MeadowFireflyPose>.unmodifiable(<MeadowFireflyPose>[
      for (final _Firefly firefly in _fireflies) firefly.pose(_time, fireflies),
    ]);
  }
}

double _beeSize(double s) => s + 0.14;

double _butterflySize(double s) => s / meadowNearScale * 0.85 + 0.18;

double _ease(double share) {
  final double k = share.clamp(0.0, 1.0);
  return k * k * (3 - 2 * k);
}

List<int> _remember(MeadowPlant plant, List<int> recent, int keep) =>
    List<int>.unmodifiable(<int>[plant.dayIndex, ...recent].take(keep));

enum _State { away, flying, perched }

class _Home {
  const _Home(this.x, this.y, this.s);

  final double x;
  final double y;
  final double s;
}

class _Pick {
  const _Pick({
    required this.plant,
    required this.head,
    required this.cost,
    required this.order,
  });

  final MeadowPlant plant;
  final Offset head;
  final double cost;
  final int order;
}

class _Flyer {
  _Flyer({
    required this.x,
    required this.y,
    required this.s,
    required this.state,
    required this.wait,
    required this.phase,
    required this.variant,
    required this.wingPeriod,
    required this.size,
  }) : fromX = x,
       fromY = y,
       fromS = s,
       toX = x,
       toY = y,
       toS = s,
       controlX = x,
       controlY = y;

  double x;
  double y;
  double s;
  _State state;
  double wait;
  final double phase;
  final int variant;
  double wingPeriod;
  double wingPhase = 0;
  double fromX;
  double fromY;
  double fromS;
  double toX;
  double toY;
  double toS;
  double controlX;
  double controlY;
  double t = 0;
  double duration = 1;
  double direction = 1;
  int visits = 0;
  bool goingHome = false;
  List<int> recent = const <int>[];
  int? flower;
  int? left;
  double hoverFrom = 0;
  double perchedFor = 0;
  double offsetX = 0;
  double offsetY = 0;
  double rotation = 0;
  double opacity = 0;
  double size;

  double get flown => math.min(1.0, t) * duration;

  double get flight => state == _State.flying
      ? _ease(flown / _settleSeconds) *
            _ease((duration - flown) / _settleSeconds)
      : 0;

  double get hover => switch (state) {
    _State.perched => _ease(perchedFor / _settleSeconds),
    _State.flying => hoverFrom * (1 - _ease(flown / _settleSeconds)),
    _State.away => 0,
  };

  void land(double rest) {
    state = _State.perched;
    wait = rest;
    perchedFor = 0;
  }

  void flap(double dt) {
    wingPhase = (wingPhase + dt / wingPeriod) % 1;
  }

  void place() {
    final double k = math.min(1.0, t);
    final double e = k < 0.5
        ? 2 * k * k
        : 1 - math.pow(-2 * k + 2, 2).toDouble() / 2;
    final double u = 1 - e;
    x = u * u * fromX + 2 * u * e * controlX + e * e * toX;
    y = u * u * fromY + 2 * u * e * controlY + e * e * toY;
    s = fromS + (toS - fromS) * e;
    direction = toX - fromX >= 0 ? 1 : -1;
  }

  MeadowFlyerPose pose({required double facing}) => MeadowFlyerPose(
    position: Offset(x + offsetX, y + offsetY),
    scale: size,
    facing: facing,
    rotation: rotation,
    opacity: opacity,
    wingPeriod: wingPeriod,
    wingPhase: wingPhase,
    variant: variant,
    activity: switch (state) {
      _State.away => MeadowFlyerActivity.away,
      _State.flying => MeadowFlyerActivity.flying,
      _State.perched => MeadowFlyerActivity.perched,
    },
    flower: state == _State.away ? null : flower,
    left: state == _State.flying ? left : null,
    progress: math.min(1.0, t),
  );
}

class _Firefly {
  const _Firefly({
    required this.homeX,
    required this.homeY,
    required this.reach,
    required this.f1,
    required this.f2,
    required this.f3,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.period,
    required this.offset,
    required this.size,
    required this.inMist,
  });

  factory _Firefly.around(MeadowRandom random, MeadowFireflyHome home) {
    final double homeX = home.x + random.between(-30, 30);
    final double reach =
        random.between(14, 46) * math.min(1.3, home.scale + 0.3);
    final double f1 = random.between(0.08, 0.2);
    final double f2 = random.between(0.2, 0.45);
    final double f3 = random.between(0.1, 0.3);
    final double p1 = random.between(0, 6);
    final double p2 = random.between(0, 6);
    final double p3 = random.between(0, 6);
    final double period = home.sync
        ? _pocketFlashPeriod
        : random.between(2.6, 5.2);
    final double offset = home.sync
        ? random.between(0, _pocketPhaseSpread)
        : random.next();
    return _Firefly(
      homeX: homeX,
      homeY: home.y,
      reach: reach,
      f1: f1,
      f2: f2,
      f3: f3,
      p1: p1,
      p2: p2,
      p3: p3,
      period: period,
      offset: offset,
      size: math.max(2.2, 4.2 * math.min(1.2, home.scale + 0.25)),
      inMist: home.sync,
    );
  }

  final double homeX;
  final double homeY;
  final double reach;
  final double f1;
  final double f2;
  final double f3;
  final double p1;
  final double p2;
  final double p3;
  final double period;
  final double offset;
  final double size;
  final bool inMist;

  MeadowFireflyPose pose(double time, double visibility) {
    final double x =
        homeX +
        math.sin(time * f1 * _fullCircle + p1) * reach +
        math.sin(time * f2 * _fullCircle + p2) * reach * 0.45;
    final double y =
        homeY + math.sin(time * f3 * _fullCircle + p3) * reach * 0.4;
    final double phase = (time / period + offset) % 1;
    final double flash = math
        .pow(math.max(0.0, math.sin(phase * math.pi * 2)), 6)
        .toDouble();
    return MeadowFireflyPose(
      position: Offset(x, y),
      size: size,
      opacity: visibility < _fireflyHidden
          ? 0
          : (0.08 + 0.92 * flash) * visibility,
      inMist: inMist,
    );
  }
}
