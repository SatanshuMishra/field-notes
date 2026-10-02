import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/theme_context.dart';
import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/features/garden/model/garden_motion.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/render/meadow_creature_art.dart';
import 'package:field_notes/features/garden/render/meadow_layers.dart';
import 'package:field_notes/features/garden/render/meadow_motion.dart';
import 'package:field_notes/features/garden/render/meadow_plant_atlas.dart';
import 'package:field_notes/features/garden/render/meadow_rays.dart';
import 'package:field_notes/features/garden/render/meadow_stage_painter.dart';
import 'package:field_notes/features/garden/scene/meadow_ambience.dart';
import 'package:field_notes/features/garden/scene/meadow_grass.dart';
import 'package:field_notes/features/garden/scene/meadow_pacer.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_plants.dart';
import 'package:field_notes/features/garden/scene/meadow_stage_tooltip.dart';
import 'package:field_notes/features/garden/scene/meadow_terrain.dart'
    hide MeadowRange;
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/sky/sky_scene.dart';

const String meadowLoadingMessage = 'Growing your meadow…';
const String meadowStageHint = 'Drag to look around · tap a flower';

const Duration _fadeIn = Duration(milliseconds: 300);
const double _dragSlop = 5;
const double _headReach = 5;
const double _headSpread = 24;
const double _tipLift = 14;
const double _spotDrop = 14;
const double _spruceSlack = 6;
const double _spruceTipRow = 0.15;
const double _tipInset = 8;
const double _fullTipBottom = 54;
const double _hintTop = 8;
const double _fullHintBottom = 18;
const double _settleSeconds = 6;
const double _settleStep = 1 / 20;
const double _revealWindow = meadowRevealSeconds;
const Color _hintFill = Color.fromRGBO(30, 24, 18, 0.5);
const Color _hintInk = Color(0xFFFFFFFF);
const TextStyle _hintStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  color: _hintInk,
);

String meadowStageLabel(MeadowYear year) {
  final String counts = meadowCountPhrase(year.blooms, year.sprouts);
  final String growing = year.limit < year.daysInYear ? ' so far' : '';
  return 'Meadow, ${year.year}: $counts$growing';
}

class MeadowStage extends StatefulWidget {
  const MeadowStage({
    super.key,
    required this.year,
    required this.seed,
    required this.sky,
    required this.morning,
    required this.mode,
    required this.compact,
    this.growthPoint,
    this.growAnimated = false,
    this.highlight,
    this.motion,
    this.readyOverlay,
    this.semanticLabel,
    this.onDragged,
  });

  final MeadowYear year;
  final int seed;
  final SkyScene sky;
  final bool morning;
  final MeadowSceneMode mode;
  final bool compact;
  final int? growthPoint;
  final bool growAnimated;
  final MeadowRange? highlight;
  final GardenMotionProfile? motion;
  final Widget? readyOverlay;
  final String? semanticLabel;
  final VoidCallback? onDragged;

  int get resolvedGrowthPoint => growthPoint ?? year.limit;

  bool get covers => compact || mode == MeadowSceneMode.full;

  @override
  State<MeadowStage> createState() => MeadowStageState();
}

class MeadowStageState extends State<MeadowStage>
    with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: _fadeIn,
  );
  late final AppLifecycleListener _lifecycle;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  int _generation = 0;
  _Geometry? _geometry;
  _SceneImages? _scene;
  _Build? _build;
  int _buildSteps = 0;
  int _buildFrames = 0;
  int _recolourPieces = 0;
  int _recolourFrames = 0;
  int _opening = 0;
  int _openingBatches = 0;
  int _openingWaited = 0;
  Duration _openingGpu = Duration.zero;
  Duration _openingLargestBatch = Duration.zero;
  int? _stepCallback;
  bool _covered = false;
  Size? _box;
  double _ratio = 1;
  late MeadowPalette _palette;
  GardenMotionProfile _motion = GardenMotionProfile.reduced;
  bool _resumed = true;
  MeadowAmbience? _ambience;
  List<MeadowPlant> _targets = const <MeadowPlant>[];
  double _time = 0;
  Duration _lastElapsed = Duration.zero;
  Map<int, double> _reveals = const <int, double>{};
  MeadowRange? _previousHighlight;
  double _highlightSince = double.negativeInfinity;
  double? _pan;
  MeadowViewport? _viewport;
  double _dragFrom = 0;
  double _dragTravel = 0;
  bool _dragging = false;
  double? _pressX;
  double _pressTravel = 0;
  _Hit? _hit;
  bool _hintDismissed = false;

  @visibleForTesting
  int get debugImageBytes =>
      (_scene?.imageBytes ?? 0) + (_build?.imageBytes ?? 0);

  @visibleForTesting
  bool get debugIsReady => _scene != null;

  @visibleForTesting
  int get debugBuildSteps => _buildSteps;

  @visibleForTesting
  int get debugBuildFrames => _buildFrames;

  @visibleForTesting
  int get debugRecolourPieces => _recolourPieces;

  @visibleForTesting
  int get debugRecolourFrames => _recolourFrames;

  @visibleForTesting
  bool get debugIsRecolouring => _scene?.layers.isRecolouring ?? false;

  @visibleForTesting
  int get debugOpeningBatches => _openingBatches;

  @visibleForTesting
  int get debugOpeningWaited => _openingWaited;

  @visibleForTesting
  Duration get debugOpeningGpu => _openingGpu;

  @visibleForTesting
  Duration get debugOpeningLargestBatch => _openingLargestBatch;

  @visibleForTesting
  bool get debugIsTicking => _ticker.isTicking;

  @visibleForTesting
  double? get debugSceneDensity => _scene?.key.density;

  @visibleForTesting
  MeadowViewport? get debugViewport => _viewport;

  @visibleForTesting
  double get debugTime => _time;

  @visibleForTesting
  int get debugGenerations => _generation;

  bool get _animate => _motion == GardenMotionProfile.full;

  @override
  void initState() {
    super.initState();
    _palette = _paletteOf(widget);
    _resumed = _isResumed(WidgetsBinding.instance.lifecycleState);
    _lifecycle = AppLifecycleListener(onStateChange: _lifecycleChanged);
    _generate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final double ratio = MediaQuery.devicePixelRatioOf(context);
    if (ratio != _ratio) {
      _ratio = ratio;
      _scheduleStep();
    }
    _syncCover();
    _syncMotion();
  }

  @override
  void didUpdateWidget(MeadowStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool seedChanged = oldWidget.seed != widget.seed;
    if (seedChanged ||
        (!identical(oldWidget.year, widget.year) &&
            !listEquals(oldWidget.year.days, widget.year.days))) {
      _regenerate(dropScene: seedChanged);
    }
    if (oldWidget.mode != widget.mode || oldWidget.compact != widget.compact) {
      _scheduleStep();
    }
    _syncPalette();
    _syncGrowth(oldWidget.resolvedGrowthPoint);
    if (oldWidget.highlight != widget.highlight) {
      _previousHighlight = oldWidget.highlight;
      _highlightSince = _time;
    }
    if (oldWidget.compact != widget.compact) {
      _hit = null;
    }
    _syncMotion();
  }

  @override
  void dispose() {
    _generation++;
    final int? callback = _stepCallback;
    if (callback != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callback);
    }
    _pacer.leave(this);
    _lifecycle.dispose();
    _ticker.dispose();
    _fade.dispose();
    _frame.dispose();
    _build?.dispose();
    _scene?.dispose();
    super.dispose();
  }

  void _generate() {
    final int generation = ++_generation;
    final MeadowYear year = widget.year;
    final int seed = widget.seed;
    _generateGeometry(seed, year).then(
      (_Parts parts) {
        if (!mounted || generation != _generation) {
          return;
        }
        _geometry = _Geometry(
          seed: seed,
          year: year,
          terrain: parts.terrain,
          plants: parts.plants,
          grass: parts.grass,
        );
        _scheduleStep();
      },
      onError: (Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'meadow stage',
            context: ErrorDescription('while generating the meadow'),
          ),
        );
      },
    );
  }

  void _regenerate({required bool dropScene}) {
    _build?.dispose();
    _build = null;
    _geometry = null;
    if (dropScene) {
      _scene?.dispose();
      _scene = null;
      _ambience = null;
      _targets = const <MeadowPlant>[];
      _reveals = const <int, double>{};
      _hit = null;
      _pan = null;
      _viewport = null;
      _fade.value = 0;
      _syncTicker();
    }
    _generate();
  }

  void _scheduleStep() {
    if (_stepCallback != null) {
      return;
    }
    _stepCallback = SchedulerBinding.instance.scheduleFrameCallback(_step);
  }

  void _step(Duration timeStamp) {
    _stepCallback = null;
    if (!mounted) {
      return;
    }
    final Duration frame = _frameInterval;
    final MeadowLayers? shown = _scene?.layers;
    if (shown != null && shown.isRecolouring) {
      if (_covered) {
        _pacer.waitTurn(this, _takeTurn);
        _scheduleStep();
        return;
      }
      final MeadowPacer pacer = _pacer;
      if (!pacer.isBehind && pacer.takeFrame()) {
        _sendPieces(shown, frame);
      }
      if (shown.isRecolouring || _build != null || _wantsBuild) {
        _scheduleStep();
      }
      return;
    }
    final _Build? running = _build;
    if (running == null) {
      final _ImageKey? wanted = _wanted();
      if (wanted != null && _scene?.key != wanted) {
        _build = _Build(wanted);
        _buildSteps = 0;
        _buildFrames = 0;
        _opening++;
        _openingBatches = 0;
        _openingWaited = 0;
        _openingGpu = Duration.zero;
        _openingLargestBatch = Duration.zero;
        _scheduleStep();
      }
      return;
    }
    if (_covered) {
      _pacer.waitTurn(this, _takeTurn);
      _scheduleStep();
      return;
    }
    final MeadowPacer pacer = _pacer;
    if (pacer.isBehind || !pacer.takeFrame()) {
      _openingWaited++;
      _scheduleStep();
      return;
    }
    _sendBuild(running, frame);
  }

  Duration get _frameInterval => MeadowPacer.frameInterval(
    View.maybeOf(context)?.display.refreshRate ?? 0,
  );

  bool get _wantsBuild {
    final _ImageKey? wanted = _wanted();
    return wanted != null && _scene?.key != wanted;
  }

  bool get _hasWork =>
      (_scene?.layers.isRecolouring ?? false) || _build != null;

  void _sendPieces(MeadowLayers shown, Duration frame) {
    final MeadowPacer pacer = _pacer;
    final int allowed = pacer.allowance(MeadowWork.piece, share: frame ~/ 2);
    final int started = pacer.nowMicros();
    final MeadowBatch batch = pacer.begin(MeadowWork.piece, frame: frame);
    int drawn = 0;
    try {
      while (drawn < allowed &&
          shown.isRecolouring &&
          MeadowPacer.keepBuilding(
            spent: Duration(microseconds: pacer.nowMicros() - started),
            advanced: drawn,
            frame: frame,
          )) {
        shown.step();
        drawn++;
        _recolourPieces++;
      }
    } finally {
      pacer.end(batch, steps: drawn);
    }
    _recolourFrames++;
    _frame.value++;
  }

  void _sendBuild(_Build running, Duration frame) {
    final MeadowPacer pacer = _pacer;
    final MeadowWork kind = running.nextWork;
    final int allowed = pacer.allowance(kind, share: frame);
    final int started = pacer.nowMicros();
    final MeadowBatch batch = pacer.begin(kind, frame: frame);
    final int opening = _opening;
    _openingBatches++;
    _buildFrames++;
    int advances = 0;
    int steps = 0;
    int pieces = 0;
    _Advance advanced = _Advance.step;
    try {
      do {
        _buildSteps++;
        advances++;
        advanced = running.advance(_palette);
        if (advanced != _Advance.created) {
          steps++;
        }
        if (advanced == _Advance.piece) {
          pieces++;
        }
      } while (advanced != _Advance.finished &&
          advanced != _Advance.layersBuilt &&
          steps < allowed &&
          running.nextWork == kind &&
          MeadowPacer.keepBuilding(
            spent: Duration(microseconds: pacer.nowMicros() - started),
            advanced: advances,
            frame: frame,
          ));
    } finally {
      pacer.end(
        batch,
        steps: steps,
        answered: (Duration? cost) => _openingAnswered(opening, cost),
      );
    }
    if (pieces > 0) {
      _recolourPieces += pieces;
      _recolourFrames++;
    }
    if (advanced != _Advance.finished) {
      _scheduleStep();
      return;
    }
    _build = null;
    final _SceneImages next = running.finish();
    _show(next);
    if (next.layers.isRecolouring || _wantsBuild) {
      _scheduleStep();
    }
  }

  void _openingAnswered(int opening, Duration? cost) {
    if (!mounted || opening != _opening || cost == null) {
      return;
    }
    if (cost <= Duration.zero) {
      return;
    }
    _openingGpu += cost;
    if (cost > _openingLargestBatch) {
      _openingLargestBatch = cost;
    }
  }

  bool _takeTurn() {
    if (!mounted) {
      return false;
    }
    final Duration frame = _frameInterval;
    final MeadowLayers? shown = _scene?.layers;
    final _Build? running = _build;
    if (shown != null && shown.isRecolouring) {
      _sendPieces(shown, frame);
    } else if (running != null) {
      _sendBuild(running, frame);
    } else {
      return false;
    }
    _scheduleStep();
    return true;
  }

  void _syncCover() {
    final bool covered = ModalRoute.of(context)?.isCurrent == false;
    if (covered == _covered) {
      return;
    }
    _covered = covered;
    if (!covered && _hasWork) {
      _scheduleStep();
    }
  }

  _ImageKey? _wanted() {
    final _Geometry? geometry = _geometry;
    final Size? box = _box;
    if (geometry == null || box == null) {
      return null;
    }
    return _ImageKey(
      geometry: geometry,
      density: _densityOf(box),
      full: widget.mode == MeadowSceneMode.full,
    );
  }

  void _show(_SceneImages next) {
    final _SceneImages? previous = _scene;
    final bool sameGeometry =
        previous != null && identical(previous.key.geometry, next.key.geometry);
    setState(() {
      _scene = next;
      if (!sameGeometry) {
        final _Geometry geometry = next.key.geometry;
        _ambience = MeadowAmbience(
          seed: geometry.seed,
          terrain: geometry.terrain,
          plants: geometry.plants,
          year: geometry.year,
        );
        _hit = null;
        _syncTargets();
        if (!_animate) {
          _settleAmbience();
        }
      }
    });
    previous?.dispose();
    if (previous == null) {
      _fade.forward(from: 0);
    }
    _syncTicker();
  }

  void _settleAmbience() {
    final MeadowAmbience? ambience = _ambience;
    if (ambience == null) {
      return;
    }
    for (double t = 0; t < _settleSeconds; t += _settleStep) {
      ambience.step(
        _settleStep,
        targets: _targets,
        dayLife: _palette.dayLife,
        fireflies: _palette.fireflies,
      );
    }
  }

  double _densityOf(Size box) =>
      MeadowViewport.resolve(box: box, cover: widget.covers, focusX: 0).scale *
      _ratio;

  void _syncPalette() {
    final MeadowPalette next = _paletteOf(widget);
    if (next == _palette) {
      return;
    }
    _palette = next;
    _scene?.layers.recolour(next);
    _scene?.rays.recolour(next);
    _build?.recolour(next);
    if (_scene?.layers.isRecolouring ?? false) {
      _scheduleStep();
    }
    if (!_animate) {
      _ambience?.step(
        0,
        targets: _targets,
        dayLife: next.dayLife,
        fireflies: next.fireflies,
      );
    }
  }

  void _syncGrowth(int before) {
    final int after = widget.resolvedGrowthPoint;
    if (after == before) {
      return;
    }
    if (_scene != null) {
      _reveals = Map<int, double>.unmodifiable(<int, double>{
        for (final MapEntry<int, double> reveal in _reveals.entries)
          if (reveal.key < after && _time - reveal.value < _revealWindow)
            reveal.key: reveal.value,
        for (int day = before; day < after; day++) day: _time,
      });
    }
    final _Hit? hit = _hit;
    if (hit != null && !hit.visibleAt(after)) {
      _hit = null;
    }
    _syncTargets();
  }

  void _syncTargets() {
    final _Geometry? geometry = _scene?.key.geometry;
    if (geometry == null) {
      _targets = const <MeadowPlant>[];
      return;
    }
    final int growthPoint = widget.resolvedGrowthPoint;
    _targets = List<MeadowPlant>.unmodifiable(<MeadowPlant>[
      for (final MeadowPlant plant in geometry.plants.plants)
        if (!plant.hidden && plant.mood != null && plant.dayIndex < growthPoint)
          plant,
    ]);
  }

  void _syncMotion() {
    _motion =
        widget.motion ??
        resolveGardenMotion(
          reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
          bloomCount: widget.year.blooms + widget.year.sprouts,
        );
    _syncTicker();
  }

  void _syncTicker() {
    final bool run = _animate && _scene != null && _resumed;
    if (run && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _lifecycleChanged(AppLifecycleState state) {
    final bool resumed = _isResumed(state);
    if (resumed == _resumed) {
      return;
    }
    _resumed = resumed;
    _syncTicker();
  }

  void _tick(Duration elapsed) {
    final double seconds =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    if (seconds <= 0) {
      return;
    }
    _time += seconds;
    _ambience?.step(
      seconds,
      targets: _targets,
      dayLife: _palette.dayLife,
      fireflies: _palette.fireflies,
    );
    _frame.value++;
  }

  void _resize(Size box) {
    if (box == _box) {
      return;
    }
    _box = box;
    _scheduleStep();
  }

  MeadowViewport _viewportOf(Size box, _Geometry geometry) {
    final MeadowViewport viewport = MeadowViewport.resolve(
      box: box,
      cover: widget.covers,
      pan: _pan,
      focusX: geometry.terrain.sky.focusX,
    );
    _viewport = viewport;
    return viewport;
  }

  void _setHit(_Hit? hit) {
    if (hit == _hit) {
      return;
    }
    setState(() {
      _hit = hit;
    });
  }

  _Hit? _hitAt(Offset local) {
    final _SceneImages? scene = _scene;
    final MeadowViewport? viewport = _viewport;
    if (scene == null || viewport == null) {
      return null;
    }
    return _hitTest(
      viewport.toWorld(local),
      geometry: scene.key.geometry,
      growthPoint: widget.resolvedGrowthPoint,
    );
  }

  void _hover(PointerHoverEvent event) {
    if (widget.compact || _dragging) {
      return;
    }
    _setHit(_hitAt(event.localPosition));
  }

  void _exit(PointerExitEvent event) {
    if (!widget.compact) {
      _setHit(null);
    }
  }

  void _pressed(PointerDownEvent event) {
    _pressX = event.localPosition.dx;
    _pressTravel = 0;
  }

  void _moved(PointerMoveEvent event) {
    final double? from = _pressX;
    if (from == null) {
      return;
    }
    _pressTravel = math.max(
      _pressTravel,
      (event.localPosition.dx - from).abs(),
    );
  }

  void _tapped(TapUpDetails details) {
    if (!widget.compact || _pressTravel > _dragSlop) {
      return;
    }
    setState(() {
      _hintDismissed = true;
      _hit = _hitAt(details.localPosition);
    });
  }

  void _dragStarted(DragStartDetails details) {
    _dragFrom = _viewport?.pan ?? 0;
    _dragTravel = 0;
  }

  void _dragged(DragUpdateDetails details) {
    final MeadowViewport? viewport = _viewport;
    final _SceneImages? scene = _scene;
    final Size? box = _box;
    if (viewport == null || scene == null || box == null) {
      return;
    }
    _dragTravel += details.delta.dx;
    if (!_dragging && _dragTravel.abs() <= _dragSlop) {
      return;
    }
    final bool starting = !_dragging;
    _dragging = true;
    if (starting) {
      widget.onDragged?.call();
    }
    final double pan = MeadowViewport.resolve(
      box: box,
      cover: widget.covers,
      pan: _dragFrom - _dragTravel / viewport.scale,
      focusX: scene.key.geometry.terrain.sky.focusX,
    ).pan;
    if (starting || pan != _pan) {
      setState(() {
        _pan = pan;
        _hit = null;
        _hintDismissed = true;
      });
    }
  }

  void _dragFinished(DragEndDetails details) {
    _dragEnded();
  }

  void _dragEnded() {
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final Widget? overlay = widget.readyOverlay;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          container: true,
          image: true,
          label: widget.semanticLabel ?? meadowStageLabel(widget.year),
          excludeSemantics: true,
          child: LayoutBuilder(builder: _layout),
        ),
        if (overlay != null && _scene != null)
          FadeTransition(opacity: _fade, child: overlay),
      ],
    );
  }

  Widget _layout(BuildContext context, BoxConstraints constraints) {
    final Size box = constraints.biggest;
    if (!box.isFinite || box.isEmpty) {
      return const SizedBox.shrink();
    }
    _resize(box);
    final _SceneImages? scene = _scene;
    if (scene == null) {
      return Center(
        child: Text(
          meadowLoadingMessage,
          textAlign: TextAlign.center,
          style: context.textStyles.captionSans,
        ),
      );
    }
    final _Geometry geometry = scene.key.geometry;
    final MeadowViewport viewport = _viewportOf(box, geometry);
    final _Hit? hit = _hit;
    final bool full = widget.mode == MeadowSceneMode.full;
    return MouseRegion(
      onHover: _hover,
      onExit: _exit,
      child: Listener(
        onPointerDown: _pressed,
        onPointerMove: _moved,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: _gestures(context),
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                FadeTransition(
                  opacity: _fade,
                  child: RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: _frame,
                      builder: (BuildContext context, Widget? child) =>
                          CustomPaint(
                            size: box,
                            painter: _painter(scene, viewport, hit),
                          ),
                    ),
                  ),
                ),
                if (hit != null) _tooltip(hit, geometry, viewport, full),
                if (widget.compact && !_hintDismissed)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: full ? null : _hintTop,
                    bottom: full ? _fullHintBottom : null,
                    child: const IgnorePointer(
                      child: Center(
                        child: MeadowHintPill(text: meadowStageHint),
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

  Map<Type, GestureRecognizerFactory> _gestures(BuildContext context) {
    final DeviceGestureSettings? settings = MediaQuery.maybeGestureSettingsOf(
      context,
    );
    return <Type, GestureRecognizerFactory>{
      if (widget.compact)
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(debugOwner: this),
              (TapGestureRecognizer recognizer) {
                recognizer
                  ..onTapUp = _tapped
                  ..gestureSettings = settings;
              },
            ),
      if (widget.covers)
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              HorizontalDragGestureRecognizer
            >(() => HorizontalDragGestureRecognizer(debugOwner: this), (
              HorizontalDragGestureRecognizer recognizer,
            ) {
              recognizer
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = _dragStarted
                ..onUpdate = _dragged
                ..onEnd = _dragFinished
                ..onCancel = _dragEnded
                ..gestureSettings = settings;
            }),
    };
  }

  MeadowStagePainter _painter(
    _SceneImages scene,
    MeadowViewport viewport,
    _Hit? hit,
  ) {
    final _Geometry geometry = scene.key.geometry;
    final MeadowAmbience? ambience = _ambience;
    final int growthPoint = widget.resolvedGrowthPoint;
    return MeadowStagePainter(
      layers: scene.layers,
      layersRevision: scene.layers.revision,
      atlas: scene.atlas,
      creatures: scene.creatures,
      rays: scene.rays,
      terrain: geometry.terrain,
      plants: geometry.plants,
      palette: _palette,
      viewport: viewport,
      time: _time,
      animate: _animate,
      growthPoint: growthPoint,
      mode: widget.mode,
      heaviest: geometry.year.heaviest,
      bees: ambience?.bees ?? const <MeadowFlyerPose>[],
      butterflies: ambience?.butterflies ?? const <MeadowFlyerPose>[],
      fireflies: ambience?.fireflies ?? const <MeadowFireflyPose>[],
      growAnimated: widget.growAnimated,
      reveals: _reveals,
      highlight: widget.highlight,
      previousHighlight: _previousHighlight,
      highlightSince: _highlightSince,
      spot: hit == null ? null : hit.anchor + const Offset(0, _spotDrop),
      caption: meadowStageCaption(
        year: widget.year.year,
        growthPoint: growthPoint,
        daysInYear: widget.year.daysInYear,
        mode: widget.mode,
      ),
    );
  }

  Widget _tooltip(
    _Hit hit,
    _Geometry geometry,
    MeadowViewport viewport,
    bool full,
  ) {
    final MeadowTip tip = hit.tip(geometry.year);
    if (widget.compact) {
      return Positioned(
        left: _tipInset,
        right: _tipInset,
        bottom: full ? _fullTipBottom : _tipInset,
        child: IgnorePointer(
          child: MeadowStageTooltip(tip: tip, compact: true),
        ),
      );
    }
    final Offset at = viewport.toLocal(hit.anchor);
    return Positioned(
      left: at.dx,
      top: at.dy,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(-0.5, -1),
          child: MeadowStageTooltip(tip: tip, compact: false),
        ),
      ),
    );
  }
}

class MeadowHintPill extends StatelessWidget {
  const MeadowHintPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _hintFill,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(text, maxLines: 1, softWrap: false, style: _hintStyle),
      ),
    );
  }
}

MeadowPacer get _pacer => meadowPacer;

bool _isResumed(AppLifecycleState? state) =>
    state == null || state == AppLifecycleState.resumed;

MeadowPalette _paletteOf(MeadowStage stage) => MeadowPalette.from(
  sky: stage.sky,
  morning: stage.morning,
  heavyShare: stage.year.heavyShare,
);

typedef _Parts = ({
  MeadowTerrain terrain,
  MeadowPlants plants,
  List<MeadowGrassBand> grass,
});

Future<_Parts> _generateGeometry(int seed, MeadowYear year) =>
    Isolate.run<_Parts>(() => _buildParts(seed, year));

_Parts _buildParts(int seed, MeadowYear year) {
  final MeadowTerrain terrain = buildMeadowTerrain(seed: seed, year: year);
  return (
    terrain: terrain,
    plants: buildMeadowPlants(seed: seed, year: year, terrain: terrain),
    grass: buildMeadowGrass(seed: seed, terrain: terrain),
  );
}

_Hit? _hitTest(
  Offset world, {
  required _Geometry geometry,
  required int growthPoint,
}) {
  MeadowPlant? best;
  for (final MeadowPlant plant in geometry.plants.plants) {
    if (plant.hidden || plant.dayIndex >= growthPoint) {
      continue;
    }
    if (best != null && plant.y <= best.y) {
      continue;
    }
    final double reach =
        _headReach + _headSpread * plant.scale / meadowNearScale;
    for (final Offset head in plant.heads) {
      if ((head - world).distanceSquared < reach * reach) {
        best = plant;
        break;
      }
    }
  }
  if (best != null) {
    return _PlantHit(best);
  }
  final MeadowOldSpruce? spruce = geometry.terrain.forest.oldSpruce;
  if (spruce != null &&
      growthPoint > spruce.day &&
      world.dy > spruce.top &&
      world.dy < spruce.y &&
      (world.dx - spruce.x).abs() <
          spruce.width * 0.5 * (world.dy - spruce.top) / spruce.height +
              _spruceSlack) {
    return _SpruceHit(spruce);
  }
  return null;
}

sealed class _Hit {
  const _Hit();

  Offset get anchor;

  bool visibleAt(int growthPoint);

  MeadowTip tip(MeadowYear year);
}

final class _PlantHit extends _Hit {
  const _PlantHit(this.plant);

  final MeadowPlant plant;

  @override
  Offset get anchor {
    final Offset head = plant.heads.last;
    return Offset(head.dx, head.dy - _tipLift * plant.scale / meadowNearScale);
  }

  @override
  bool visibleAt(int growthPoint) => plant.dayIndex < growthPoint;

  @override
  MeadowTip tip(MeadowYear year) => meadowPlantTip(
    year: year.year,
    dayIndex: plant.dayIndex,
    mood: plant.mood,
    entries: plant.entries,
  );

  @override
  bool operator ==(Object other) =>
      other is _PlantHit && identical(other.plant, plant);

  @override
  int get hashCode => identityHashCode(plant);
}

final class _SpruceHit extends _Hit {
  const _SpruceHit(this.spruce);

  final MeadowOldSpruce spruce;

  @override
  Offset get anchor =>
      Offset(spruce.x, spruce.top + spruce.height * _spruceTipRow);

  @override
  bool visibleAt(int growthPoint) => growthPoint > spruce.day;

  @override
  MeadowTip tip(MeadowYear year) => meadowSpruceTip(year);

  @override
  bool operator ==(Object other) =>
      other is _SpruceHit && identical(other.spruce, spruce);

  @override
  int get hashCode => identityHashCode(spruce);
}

class _Geometry {
  const _Geometry({
    required this.seed,
    required this.year,
    required this.terrain,
    required this.plants,
    required this.grass,
  });

  final int seed;
  final MeadowYear year;
  final MeadowTerrain terrain;
  final MeadowPlants plants;
  final List<MeadowGrassBand> grass;
}

class _ImageKey {
  const _ImageKey({
    required this.geometry,
    required this.density,
    required this.full,
  });

  final _Geometry geometry;
  final double density;
  final bool full;

  int get layerBudget => full ? meadowLayerBudget : meadowLayerPageBudget;

  int get plantBudget =>
      full ? meadowPlantSpriteBudget : meadowPlantSpritePageBudget;

  @override
  bool operator ==(Object other) =>
      other is _ImageKey &&
      identical(other.geometry, geometry) &&
      other.density == density &&
      other.full == full;

  @override
  int get hashCode => Object.hash(identityHashCode(geometry), density, full);
}

class _SceneImages {
  const _SceneImages({
    required this.key,
    required this.layers,
    required this.atlas,
    required this.creatures,
    required this.rays,
  });

  final _ImageKey key;
  final MeadowLayers layers;
  final MeadowPlantAtlas atlas;
  final MeadowCreatureArt creatures;
  final MeadowRays rays;

  int get imageBytes =>
      layers.imageBytes +
      atlas.imageBytes +
      creatures.imageBytes +
      rays.imageBytes;

  void dispose() {
    layers.dispose();
    atlas.dispose();
    creatures.dispose();
    rays.dispose();
  }
}

enum _Advance { created, step, layersBuilt, piece, finished }

class _Build {
  _Build(this.key);

  final _ImageKey key;
  MeadowLayers? _layers;
  MeadowPlantAtlas? _atlas;
  MeadowCreatureArt? _creatures;
  MeadowRays? _rays;

  int get imageBytes =>
      (_layers?.imageBytes ?? 0) +
      (_atlas?.imageBytes ?? 0) +
      (_creatures?.imageBytes ?? 0) +
      (_rays?.imageBytes ?? 0);

  MeadowWork get nextWork {
    final MeadowLayers? layers = _layers;
    if (layers == null || !layers.isBuilt) {
      return MeadowWork.layers;
    }
    if (!layers.isReady) {
      return MeadowWork.piece;
    }
    final MeadowPlantAtlas? atlas = _atlas;
    if (atlas == null || !atlas.isReady) {
      return MeadowWork.plants;
    }
    return MeadowWork.finish;
  }

  _Advance advance(MeadowPalette palette) {
    final _Geometry geometry = key.geometry;
    final MeadowLayers? layers = _layers;
    if (layers == null) {
      _layers = MeadowLayers(
        terrain: geometry.terrain,
        grass: geometry.grass,
        density: MeadowLayers.fitDensity(
          terrain: geometry.terrain,
          grass: geometry.grass,
          density: key.density,
          maxBytes: key.layerBudget,
        ),
      )..recolour(palette);
      return _Advance.created;
    }
    if (!layers.isBuilt) {
      layers.step();
      return layers.isBuilt ? _Advance.layersBuilt : _Advance.step;
    }
    if (!layers.isReady) {
      layers.step();
      return _Advance.piece;
    }
    final MeadowPlantAtlas? atlas = _atlas;
    if (atlas == null) {
      _atlas = MeadowPlantAtlas(
        geometry.plants,
        density: key.density,
        maxBytes: key.plantBudget,
      );
      return _Advance.created;
    }
    if (!atlas.isReady) {
      atlas.step();
      return _Advance.step;
    }
    _creatures ??= MeadowCreatureArt.build(density: key.density);
    _rays ??= MeadowRays(palette);
    return _Advance.finished;
  }

  void recolour(MeadowPalette palette) {
    _layers?.recolour(palette);
    _rays?.recolour(palette);
  }

  _SceneImages finish() => _SceneImages(
    key: key,
    layers: _layers!,
    atlas: _atlas!,
    creatures: _creatures!,
    rays: _rays!,
  );

  void dispose() {
    _layers?.dispose();
    _atlas?.dispose();
    _creatures?.dispose();
    _rays?.dispose();
  }
}
