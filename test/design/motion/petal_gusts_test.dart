import 'package:field_notes/design/flowers/petal_art.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _layerKey = ValueKey<String>('gusting-petals');

const Duration _tick = Duration(milliseconds: 100);
const double _tickSeconds = 0.1;
const Duration _second = Duration(seconds: 1);
const int _secondsInFiveMinutes = 300;
const int _quietTicks = 10;
const int _longestGustTicks = 400;
const int _longestRestTicks = 2000;
const int _threeGustsTicks = 6000;
const double _progressTolerance = 1e-9;
const double _scaleTolerance = 1e-12;

const double _entryLeft = -20;
const double _exitReach = 60;
const double _steepestEarlyFall = 210 * 0.35 / 0.5;
const double _heightTolerance = 1;

const List<FlowerKind> _shownFlowers = <FlowerKind>[
  FlowerKind.peony,
  FlowerKind.aster,
  FlowerKind.lavender,
];

typedef _Area = ({
  String name,
  TargetPlatform platform,
  Size size,
  PetalScreen screen,
  int petals,
  double shortestPass,
  double longestPass,
});

typedef _Seen = ({
  Offset corner,
  FlowerKind? flower,
  bool? alternate,
  double scale,
});

const _Area _phone = (
  name: 'phone screen',
  platform: TargetPlatform.android,
  size: Size(384, 832),
  screen: PetalScreen.narrow,
  petals: 4,
  shortestPass: 11,
  longestPass: 18,
);

const _Area _mac = (
  name: 'macOS window',
  platform: TargetPlatform.macOS,
  size: Size(1140, 760),
  screen: PetalScreen.wide,
  petals: 6,
  shortestPass: 17,
  longestPass: 29,
);

const List<_Area> _areas = <_Area>[_phone, _mac];

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void _pinView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _layer(Size size, FlowerKind? flower, {bool still = false}) =>
    MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: still),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PetalDrift(
          key: _layerKey,
          flower: flower,
          rhythm: PetalRhythm.gusts,
        ),
      ),
    );

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

bool _asking(WidgetTester tester) => tester.binding.hasScheduledFrame;

PetalShade _shadeOf(FlowerKind kind) =>
    petalArtFor(kind)!.pieces
        .firstWhere((PetalPiece piece) => piece.shade != null)
        .shade!;

int _inkOf(FlowerKind kind) => _shadeOf(kind).base.toARGB32() & 0xFFFFFF;

List<Invocation> _recorded(void Function(Canvas canvas) paint) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  paint(canvas);
  return <Invocation>[
    for (final RecordedInvocation call in canvas.invocations) call.invocation,
  ];
}

double _scaleIn(List<Invocation> calls) =>
    calls
            .firstWhere((Invocation call) => call.memberName == #scale)
            .positionalArguments[0]
        as double;

double _scaleOn(FlowerKind kind, PetalScreen screen) {
  final PetalArt art = petalArtFor(kind)!;
  return _scaleIn(
    _recorded((Canvas canvas) => art.paint(canvas, size: art.sizeOn(screen))),
  );
}

Paint _paintOf(Invocation draw) => draw.positionalArguments[1] as Paint;

bool? _alternateOf(Paint shaded, FlowerKind? flower) {
  if (flower == null) {
    return null;
  }
  final PetalShade shade = _shadeOf(flower);
  if (identical(shaded.shader, shade.alternateShader)) {
    return true;
  }
  return identical(shaded.shader, shade.shader) ? false : null;
}

_Seen _petalIn(List<Invocation> calls, _Area area) {
  final Invocation translate = calls.first;
  final Offset centre = Offset(
    translate.positionalArguments[0] as double,
    translate.positionalArguments[1] as double,
  );
  final List<Invocation> draws = <Invocation>[
    for (final Invocation call in calls)
      if (call.memberName == #drawPath) call,
  ];
  final int shadedAt = draws.indexWhere(
    (Invocation draw) => _paintOf(draw).shader != null,
  );
  final Paint shaded = _paintOf(draws[shadedAt]);
  final int ink = _paintOf(draws[shadedAt + 1]).color.toARGB32() & 0xFFFFFF;
  final FlowerKind? flower = _shownFlowers
      .where((FlowerKind kind) => _inkOf(kind) == ink)
      .firstOrNull;
  final Size size = flower == null
      ? Size.zero
      : petalArtFor(flower)!.sizeOn(area.screen);
  return (
    corner: centre - Offset(size.width / 2, size.height / 2),
    flower: flower,
    alternate: _alternateOf(shaded, flower),
    scale: _scaleIn(calls),
  );
}

List<_Seen> _seen(WidgetTester tester, _Area area) {
  final Finder painted = find.descendant(
    of: find.byKey(_layerKey),
    matching: find.byType(CustomPaint),
  );
  if (painted.evaluate().isEmpty) {
    return const <_Seen>[];
  }
  final RenderCustomPaint render = tester.renderObject<RenderCustomPaint>(
    painted,
  );
  final List<Invocation> calls = _recorded(
    (Canvas canvas) => render.painter!.paint(canvas, render.size),
  );
  final List<int> starts = <int>[
    for (final (int index, Invocation call) in calls.indexed)
      if (call.memberName == #translate) index,
  ];
  return <_Seen>[
    for (final (int order, int start) in starts.indexed)
      _petalIn(
        calls.sublist(
          start,
          order + 1 < starts.length ? starts[order + 1] : calls.length,
        ),
        area,
      ),
  ];
}

List<FlowerKind?> _flowers(List<_Seen> seen) => <FlowerKind?>[
  for (final _Seen petal in seen) petal.flower,
];

double _progressOf(_Seen petal, _Area area) =>
    (petal.corner.dx - _entryLeft) / (area.size.width + _exitReach);

int _justEntered(List<_Seen> seen, _Area area) => seen
    .where(
      (_Seen petal) =>
          _progressOf(petal, area) <=
          _tickSeconds / area.shortestPass + _progressTolerance,
    )
    .length;

int _aboutToLeave(List<_Seen> seen, _Area area) => seen
    .where(
      (_Seen petal) =>
          _progressOf(petal, area) >=
          1 - _tickSeconds / area.shortestPass - _progressTolerance,
    )
    .length;

void _expectDrawnAs(
  List<_Seen> seen,
  _Area area,
  FlowerKind flower,
  String reason,
) {
  expect(_flowers(seen), everyElement(flower), reason: reason);
  for (final (int index, _Seen petal) in seen.indexed) {
    expect(
      petal.scale,
      closeTo(_scaleOn(flower, area.screen), _scaleTolerance),
      reason: '$reason, petal $index size',
    );
  }
}

void _expectEntering(
  List<_Seen> previous,
  List<_Seen> now,
  _Area area,
  String reason,
) {
  final int arrived = now.length - previous.length;
  expect(arrived, isNonNegative, reason: '$reason, no petal leaves early');
  expect(
    _justEntered(now, area),
    greaterThanOrEqualTo(arrived),
    reason: '$reason, every new petal starts at the left entry',
  );
}

Future<void> _expectQuiet(
  WidgetTester tester,
  _Area area,
  int ticks,
  String reason,
) async {
  for (int tick = 1; tick <= ticks; tick++) {
    await tester.pump(_tick);
    expect(_asking(tester), isFalse, reason: '$reason, tick $tick');
    expect(_seen(tester, area), isEmpty, reason: '$reason, tick $tick');
  }
}

Future<int> _untilGustEnds(
  WidgetTester tester,
  _Area area,
  String reason, {
  required FlowerKind flower,
}) async {
  bool shown = false;
  for (int tick = 1; tick <= _longestGustTicks; tick++) {
    await tester.pump(_tick);
    final List<_Seen> now = _seen(tester, area);
    _expectDrawnAs(now, area, flower, '$reason, tick $tick');
    shown = shown || now.isNotEmpty;
    if (shown && now.isEmpty && !_asking(tester)) {
      return tick;
    }
    expect(_asking(tester), isTrue, reason: '$reason, tick $tick');
  }
  fail('$reason: the gust never ended');
}

Future<int> _untilRestEnds(
  WidgetTester tester,
  _Area area,
  String reason,
) async {
  for (int tick = 1; tick <= _longestRestTicks; tick++) {
    await tester.pump(_tick);
    if (_asking(tester)) {
      return tick;
    }
    expect(_seen(tester, area), isEmpty, reason: '$reason, tick $tick');
  }
  fail('$reason: the rest never ended');
}

Future<({List<_Seen> seen, int ticks})> _untilFull(
  WidgetTester tester,
  _Area area,
  String reason, {
  required FlowerKind flower,
}) async {
  final int withinQuarter = (area.shortestPass / 4 / _tickSeconds).ceil() + 2;
  List<_Seen> previous = const <_Seen>[];
  for (int tick = 1; tick <= withinQuarter; tick++) {
    await tester.pump(_tick);
    final String when = '$reason, tick $tick';
    final List<_Seen> now = _seen(tester, area);
    _expectDrawnAs(now, area, flower, when);
    _expectEntering(previous, now, area, when);
    expect(now.length, lessThanOrEqualTo(area.petals), reason: when);
    expect(_asking(tester), isTrue, reason: when);
    if (now.length == area.petals) {
      return (seen: now, ticks: tick);
    }
    previous = now;
  }
  fail('$reason: not every petal entered in the first quarter of a pass');
}

Future<void> _expectOneGust(WidgetTester tester, _Area area) async {
  _pinView(tester, area.size);
  await tester.pumpWidget(_layer(area.size, FlowerKind.peony));
  expect(_asking(tester), isTrue, reason: '${area.name} mounted');
  final double travel = area.size.width + _exitReach;

  final List<_Seen> full = (await _untilFull(
    tester,
    area,
    area.name,
    flower: FlowerKind.peony,
  )).seen;
  for (final (int index, _Seen petal) in full.indexed) {
    expect(
      petal.alternate,
      index.isOdd,
      reason: '${area.name}, petal $index alternate fill',
    );
  }
  await tester.pump(_tick);
  final List<_Seen> next = _seen(tester, area);
  expect(next, hasLength(area.petals), reason: area.name);
  final List<double> passes = <double>[
    for (int index = 0; index < area.petals; index++)
      travel * _tickSeconds / (next[index].corner.dx - full[index].corner.dx),
  ];
  expect(
    passes,
    everyElement(inInclusiveRange(area.shortestPass, area.longestPass)),
    reason: '${area.name} pass times in seconds',
  );

  List<_Seen> previous = next;
  bool left = false;
  for (int tick = 1; tick <= _longestGustTicks; tick++) {
    await tester.pump(_tick);
    final String reason = '${area.name}, tick $tick after every petal entered';
    final List<_Seen> now = _seen(tester, area);
    _expectDrawnAs(now, area, FlowerKind.peony, reason);
    final int gone = previous.length - now.length;
    expect(gone, isNonNegative, reason: '$reason, no petal enters again');
    expect(
      _aboutToLeave(previous, area),
      greaterThanOrEqualTo(gone),
      reason: '$reason, every petal leaves past the right exit',
    );
    if (now.isEmpty) {
      left = true;
      break;
    }
    previous = now;
  }
  expect(left, isTrue, reason: '${area.name}, the last petal never left');
  expect(find.byKey(_layerKey), paintsNothing, reason: area.name);
  await _expectQuiet(tester, area, _quietTicks, '${area.name} after the gust');
  await _unmount(tester);
}

bool _heightsDiffer(List<_Seen> first, List<_Seen> second, _Area area) {
  for (int index = 0; index < first.length; index++) {
    final double climb = (second[index].corner.dy - first[index].corner.dy)
        .abs();
    final double reach =
        _steepestEarlyFall *
            (_progressOf(second[index], area) - _progressOf(first[index], area))
                .abs() +
        _heightTolerance;
    if (climb > reach) {
      return true;
    }
  }
  return false;
}

Future<void> _expectRestsAndNewHeights(WidgetTester tester, _Area area) async {
  _pinView(tester, area.size);
  await tester.pumpWidget(_layer(area.size, FlowerKind.lavender));
  expect(_asking(tester), isTrue, reason: '${area.name} mounted');

  final List<double> gusts = <double>[];
  final List<double> rests = <double>[];
  final List<List<_Seen>> fulls = <List<_Seen>>[];
  bool gusting = true;
  bool tookFull = false;
  int spanStart = 0;
  for (int tick = 1; tick <= _threeGustsTicks && gusts.length < 3; tick++) {
    await tester.pump(_tick);
    final String reason = '${area.name}, tick $tick';
    final List<_Seen> now = _seen(tester, area);
    final bool asking = _asking(tester);
    if (gusting) {
      _expectDrawnAs(now, area, FlowerKind.lavender, reason);
      if (!tookFull && now.length == area.petals) {
        fulls.add(now);
        tookFull = true;
      }
      if (!asking && now.isEmpty) {
        gusts.add((tick - spanStart) * _tickSeconds);
        gusting = false;
        spanStart = tick;
      }
    } else {
      expect(now, isEmpty, reason: '$reason, a rest paints nothing');
      if (asking) {
        rests.add((tick - spanStart) * _tickSeconds);
        gusting = true;
        tookFull = false;
        spanStart = tick;
      }
    }
  }
  expect(gusts, hasLength(3), reason: '${area.name} gusts');
  expect(rests, hasLength(2), reason: '${area.name} rests');
  expect(fulls, hasLength(3), reason: '${area.name} full gusts');
  for (int index = 0; index < rests.length; index++) {
    expect(
      rests[index],
      inInclusiveRange(
        5 * (gusts[index] - 2 * _tickSeconds),
        6 * gusts[index] + _tickSeconds,
      ),
      reason: '${area.name}, rest $index after a ${gusts[index]} s gust',
    );
  }
  for (int index = 1; index < fulls.length; index++) {
    expect(
      _heightsDiffer(fulls[index - 1], fulls[index], area),
      isTrue,
      reason: '${area.name}, gust $index repeats the heights of the one before',
    );
  }
  await _unmount(tester);
}

Future<void> _expectGustsAnswerTheFlower(WidgetTester tester) async {
  const _Area area = _phone;
  _pinView(tester, area.size);
  await tester.pumpWidget(_layer(area.size, null));
  expect(_asking(tester), isFalse, reason: 'mounted with no flower');
  await _expectQuiet(tester, area, _quietTicks, 'with no flower');

  await tester.pumpWidget(_layer(area.size, FlowerKind.aster));
  expect(_asking(tester), isTrue, reason: 'as aster arrives');
  await _untilFull(tester, area, 'aster gust', flower: FlowerKind.aster);
  await _untilGustEnds(tester, area, 'aster gust', flower: FlowerKind.aster);
  await _expectQuiet(tester, area, _quietTicks, 'resting after aster');

  await tester.pumpWidget(_layer(area.size, FlowerKind.lavender));
  expect(_asking(tester), isTrue, reason: 'as lavender arrives in the rest');
  await _untilFull(tester, area, 'lavender gust', flower: FlowerKind.lavender);
  await _unmount(tester);
}

Future<void> _expectMidGustChanges(WidgetTester tester) async {
  const _Area area = _phone;
  _pinView(tester, area.size);
  await tester.pumpWidget(_layer(area.size, FlowerKind.peony));

  List<_Seen> atChange = const <_Seen>[];
  for (int tick = 1; tick <= _longestGustTicks && atChange.isEmpty; tick++) {
    await tester.pump(_tick);
    atChange = _seen(tester, area);
  }
  expect(atChange, isNotEmpty, reason: 'no peony petal ever showed');
  _expectDrawnAs(atChange, area, FlowerKind.peony, 'before the change');

  await tester.pumpWidget(_layer(area.size, FlowerKind.lavender));
  List<_Seen> previous = _seen(tester, area);
  expect(
    _flowers(previous),
    everyElement(FlowerKind.peony),
    reason: 'at the change',
  );
  int peonies = previous.length;
  bool ended = false;
  for (int tick = 1; tick <= _longestGustTicks; tick++) {
    await tester.pump(_tick);
    final String reason = 'tick $tick after the change';
    final List<_Seen> now = _seen(tester, area);
    expect(
      _flowers(now),
      everyElement(isIn(<FlowerKind>[FlowerKind.peony, FlowerKind.lavender])),
      reason: reason,
    );
    final int peoniesNow = now
        .where((_Seen petal) => petal.flower == FlowerKind.peony)
        .length;
    expect(
      peoniesNow,
      lessThanOrEqualTo(peonies),
      reason: '$reason, a petal that entered after the change is peony',
    );
    expect(
      _aboutToLeave(previous, area),
      greaterThanOrEqualTo(peonies - peoniesNow),
      reason: '$reason, a peony petal turned lavender before it left',
    );
    peonies = peoniesNow;
    if (now.isEmpty) {
      expect(
        _asking(tester),
        isTrue,
        reason: 'the gust after the change follows at once',
      );
      ended = true;
      break;
    }
    previous = now;
  }
  expect(ended, isTrue, reason: 'the changed gust never ended');

  await _untilFull(
    tester,
    area,
    'the gust after the change',
    flower: FlowerKind.lavender,
  );

  await tester.pumpWidget(_layer(area.size, null));
  previous = _seen(tester, area);
  expect(previous, isNotEmpty, reason: 'petals in flight at the clear');
  bool gone = false;
  for (int tick = 1; tick <= _longestGustTicks; tick++) {
    await tester.pump(_tick);
    final String reason = 'tick $tick after the clear';
    final List<_Seen> now = _seen(tester, area);
    _expectDrawnAs(now, area, FlowerKind.lavender, reason);
    expect(
      now.length,
      lessThanOrEqualTo(previous.length),
      reason: '$reason, no petal enters after the clear',
    );
    if (now.isEmpty) {
      gone = true;
      break;
    }
    expect(_asking(tester), isTrue, reason: '$reason, petals in flight finish');
    previous = now;
  }
  expect(gone, isTrue, reason: 'the petals in flight never left');
  for (int second = 1; second <= _secondsInFiveMinutes; second++) {
    await tester.pump(_second);
    final String reason = '$second s after the last petal left';
    expect(_asking(tester), isFalse, reason: reason);
    expect(find.byKey(_layerKey), paintsNothing, reason: reason);
  }
  await _unmount(tester);
}

Future<void> _expectStillUnderReduceMotion(WidgetTester tester) async {
  const _Area area = _phone;
  _pinView(tester, area.size);
  await tester.pumpWidget(_layer(area.size, FlowerKind.peony, still: true));
  for (int second = 1; second <= _secondsInFiveMinutes; second++) {
    await tester.pump(_second);
    final String reason = '$second s under reduce motion';
    expect(_asking(tester), isFalse, reason: reason);
    expect(find.byKey(_layerKey), paintsNothing, reason: reason);
  }
  await _unmount(tester);
}

Future<void> _resize(WidgetTester tester, _Area area) async {
  tester.view.physicalSize = area.size;
  await tester.pumpWidget(_layer(area.size, FlowerKind.peony));
}

Future<void> _expectSetChanges(WidgetTester tester) async {
  _pinView(tester, _phone.size);
  await tester.pumpWidget(_layer(_phone.size, FlowerKind.peony));
  List<_Seen> shown = const <_Seen>[];
  for (int tick = 1; tick <= _longestGustTicks && shown.isEmpty; tick++) {
    await tester.pump(_tick);
    shown = _seen(tester, _phone);
  }
  expect(shown, isNotEmpty, reason: 'no phone petal ever showed');

  await _resize(tester, _mac);
  expect(tester.takeException(), isNull, reason: 'widened mid-gust');
  expect(_asking(tester), isTrue, reason: 'widened mid-gust');
  final int enteredTicks = (await _untilFull(
    tester,
    _mac,
    'the wide gust after widening',
    flower: FlowerKind.peony,
  )).ticks;
  final int leftTicks = await _untilGustEnds(
    tester,
    _mac,
    'the wide gust after widening',
    flower: FlowerKind.peony,
  );
  final double wideGust = (enteredTicks + leftTicks) * _tickSeconds;

  await _resize(tester, _phone);
  expect(tester.takeException(), isNull, reason: 'narrowed in the rest');
  expect(_asking(tester), isFalse, reason: 'narrowed in the rest');
  expect(find.byKey(_layerKey), paintsNothing, reason: 'narrowed in the rest');
  final int restTicks = await _untilRestEnds(
    tester,
    _phone,
    'the rest after narrowing',
  );
  expect(
    restTicks * _tickSeconds,
    inInclusiveRange(
      5 * (wideGust - 2 * _tickSeconds),
      6 * wideGust + _tickSeconds,
    ),
    reason: 'the rest after a $wideGust s wide gust kept running',
  );

  int most = 0;
  for (int tick = 1; tick <= _longestGustTicks; tick++) {
    await tester.pump(_tick);
    final List<_Seen> now = _seen(tester, _phone);
    _expectDrawnAs(now, _phone, FlowerKind.peony, 'phone gust tick $tick');
    most = now.length > most ? now.length : most;
    if (most > 0 && now.isEmpty && !_asking(tester)) {
      break;
    }
  }
  expect(most, _phone.petals, reason: 'the gust after the rest');
  await _unmount(tester);
}

void main() {
  testWidgets(
    'a gust sends every petal across once and then asks for no frames',
    (WidgetTester tester) async {
      for (final _Area area in _areas) {
        await _onPlatform(area.platform, () => _expectOneGust(tester, area));
      }
    },
  );

  testWidgets(
    'each rest lasts five to six gusts and the next gust takes new heights',
    (WidgetTester tester) async {
      for (final _Area area in _areas) {
        await _onPlatform(
          area.platform,
          () => _expectRestsAndNewHeights(tester, area),
        );
      }
    },
  );

  testWidgets(
    'a gust starts at once when a flower arrives or changes during a rest',
    (WidgetTester tester) async {
      await _onPlatform(
        _phone.platform,
        () => _expectGustsAnswerTheFlower(tester),
      );
    },
  );

  testWidgets(
    'a flower changed mid-gust reaches petals still to enter and starts the '
    'next gust at once, and a cleared flower stops new gusts',
    (WidgetTester tester) async {
      await _onPlatform(_phone.platform, () => _expectMidGustChanges(tester));
    },
  );

  testWidgets(
    'reduce motion keeps a gusts layer still and asks for no frames',
    (WidgetTester tester) async {
      await _onPlatform(
        _phone.platform,
        () => _expectStillUnderReduceMotion(tester),
      );
    },
  );

  testWidgets(
    'a layer moved between the phone and wide sets starts a fresh gust '
    'mid-gust and keeps a rest running',
    (WidgetTester tester) async {
      await _onPlatform(_phone.platform, () => _expectSetChanges(tester));
    },
  );
}
