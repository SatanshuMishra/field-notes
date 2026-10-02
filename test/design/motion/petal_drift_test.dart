import 'package:field_notes/design/flowers/petal_art.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/mood/flower_kind.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _beneathKey = ValueKey<String>('beneath-the-petals');
const String _beneathLabel = 'Beneath the petals';
const Key _subjectKey = ValueKey<String>('changing-petals');
const Key _twinKey = ValueKey<String>('steady-petals');

const Duration _settled = Duration(seconds: 2);
const Duration _step = Duration(milliseconds: 250);
const Duration _twoSeconds = Duration(seconds: 2);
const Duration _pastLongestLoop = Duration(seconds: 30);
const Duration _halfAppear = Duration(milliseconds: 300);
const double _alphaTolerance = 1e-3;

const double _entryCentre = -15;
const double _exitReach = 60;
const double _midLoopStart = 0.07;
const double _midLoopEnd = 0.93;
const double _midLoopLowest = 0.85;
const double _midLoopHighest = 0.9;

const List<FlowerKind> _shownFlowers = <FlowerKind>[
  FlowerKind.peony,
  FlowerKind.aster,
  FlowerKind.lavender,
];

typedef _Area = ({String name, TargetPlatform platform, Size size, int petals});

typedef _Seen = ({Offset centre, int rgb, double alpha});

const List<_Area> _areas = <_Area>[
  (
    name: 'macOS page body',
    platform: TargetPlatform.macOS,
    size: Size(1063, 758),
    petals: 6,
  ),
  (
    name: 'phone page body',
    platform: TargetPlatform.android,
    size: Size(360, 640),
    petals: 3,
  ),
];

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

Future<void> _pumpLayer(
  WidgetTester tester, {
  required Size size,
  required bool petals,
  required bool still,
  required VoidCallback onTap,
}) async {
  _pinView(tester, size);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: still),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Semantics(
              button: true,
              label: _beneathLabel,
              child: GestureDetector(
                key: _beneathKey,
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: const SizedBox.expand(),
              ),
            ),
            if (petals) const PetalDrift(flower: FlowerKind.peony),
          ],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _pumpPair(
  WidgetTester tester, {
  required Size size,
  required FlowerKind? changing,
  required FlowerKind steady,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PetalDrift(key: _twinKey, flower: steady),
            PetalDrift(key: _subjectKey, flower: changing),
          ],
        ),
      ),
    ),
  );
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

_Seen _petalAt(Invocation translate, Invocation draw) {
  final Paint paint = draw.positionalArguments[1] as Paint;
  return (
    centre: Offset(
      translate.positionalArguments[0] as double,
      translate.positionalArguments[1] as double,
    ),
    rgb: paint.color.toARGB32() & 0xFFFFFF,
    alpha: paint.color.a,
  );
}

List<_Seen> _seen(WidgetTester tester, Key layer) {
  final RenderCustomPaint render = tester.renderObject<RenderCustomPaint>(
    find.descendant(of: find.byKey(layer), matching: find.byType(CustomPaint)),
  );
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  render.painter!.paint(canvas, render.size);
  final List<Invocation> calls = <Invocation>[
    for (final RecordedInvocation call in canvas.invocations) call.invocation,
  ];
  return <_Seen>[
    for (int index = 0; index < calls.length; index++)
      if (calls[index].memberName == #translate)
        _petalAt(
          calls[index],
          calls
              .skip(index + 1)
              .firstWhere((Invocation call) => call.memberName == #drawPath),
        ),
  ];
}

int _rgbOf(FlowerKind kind) {
  final PetalPiece first = petalArtFor(kind)!.pieces.first;
  return (first.fill ?? first.outline)!.toARGB32() & 0xFFFFFF;
}

List<FlowerKind?> _flowers(List<_Seen> seen) => <FlowerKind?>[
  for (final _Seen petal in seen)
    _shownFlowers
        .where((FlowerKind kind) => _rgbOf(kind) == petal.rgb)
        .firstOrNull,
];

List<Offset> _centres(List<_Seen> seen) => <Offset>[
  for (final _Seen petal in seen) petal.centre,
];

double _inkAlpha(FlowerKind kind) {
  final PetalPiece first = petalArtFor(kind)!.pieces.first;
  return (first.fill ?? first.outline)!.a;
}

List<double> _midLoopAlphas(List<_Seen> seen, Size size) => <double>[
  for (final _Seen petal in seen)
    if ((petal.centre.dx - _entryCentre) / (size.width + _exitReach)
        case final double progress
        when progress > _midLoopStart && progress < _midLoopEnd)
      petal.alpha,
];

void _expectMidLoopShown(
  List<_Seen> seen,
  Size size,
  double share,
  String reason,
) {
  final double ink = _inkAlpha(FlowerKind.lavender) * share;
  final List<double> alphas = _midLoopAlphas(seen, size);
  expect(alphas, isNotEmpty, reason: reason);
  expect(
    alphas,
    everyElement(
      inInclusiveRange(
        _midLoopLowest * ink - _alphaTolerance,
        _midLoopHighest * ink + _alphaTolerance,
      ),
    ),
    reason: reason,
  );
}

List<bool> _restartedSince(
  List<bool> restarted,
  List<_Seen> before,
  List<_Seen> now,
) => <bool>[
  for (int index = 0; index < restarted.length; index++)
    restarted[index] || now[index].centre.dx < before[index].centre.dx,
];

int _nodesUnder(SemanticsNode node) {
  final List<SemanticsNode> children = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    children.add(child);
    return true;
  });
  return children.fold<int>(
    1,
    (int count, SemanticsNode child) => count + _nodesUnder(child),
  );
}

int _semanticsNodes(WidgetTester tester) => <int>[
  for (final RenderView view in tester.binding.renderViews)
    if (view.owner?.semanticsOwner?.rootSemanticsNode
        case final SemanticsNode root)
      _nodesUnder(root),
].fold<int>(0, (int total, int count) => total + count);

Future<void> _tapThrough(WidgetTester tester) async {
  final Finder layer = find.byType(PetalDrift);
  expect(tester.getRect(layer), Offset.zero & tester.view.physicalSize);
  await tester.tapAt(tester.getCenter(layer));
  await tester.pump();
}

Future<void> _expectTheNextLoopTakesTheFlower(
  WidgetTester tester,
  _Area area,
) async {
  _pinView(tester, area.size);
  await _pumpPair(
    tester,
    size: area.size,
    changing: FlowerKind.peony,
    steady: FlowerKind.peony,
  );
  await tester.pump(_settled);
  final List<_Seen> before = _seen(tester, _subjectKey);
  expect(before, hasLength(area.petals), reason: area.name);
  expect(_flowers(before), everyElement(FlowerKind.peony), reason: area.name);

  await _pumpPair(
    tester,
    size: area.size,
    changing: FlowerKind.aster,
    steady: FlowerKind.peony,
  );
  List<_Seen> previous = _seen(tester, _subjectKey);
  expect(_centres(previous), _centres(before), reason: area.name);
  expect(_flowers(previous), everyElement(FlowerKind.peony), reason: area.name);

  List<bool> restarted = List<bool>.filled(area.petals, false);
  for (Duration since = _step; since <= _pastLongestLoop; since += _step) {
    await tester.pump(_step);
    final String reason =
        '${area.name}, ${since.inMilliseconds} ms after the change';
    final List<_Seen> now = _seen(tester, _subjectKey);
    final List<_Seen> steady = _seen(tester, _twinKey);
    expect(_centres(now), _centres(steady), reason: reason);
    expect(_flowers(steady), everyElement(FlowerKind.peony), reason: reason);
    restarted = _restartedSince(restarted, previous, now);
    expect(_flowers(now), <FlowerKind>[
      for (final bool fresh in restarted)
        fresh ? FlowerKind.aster : FlowerKind.peony,
    ], reason: reason);
    if (since == _twoSeconds) {
      expect(restarted, contains(false), reason: reason);
    }
    previous = now;
  }
  expect(restarted, everyElement(isTrue), reason: area.name);
  expect(
    _flowers(_seen(tester, _subjectKey)),
    everyElement(FlowerKind.aster),
    reason: area.name,
  );
  await _unmount(tester);
}

List<_Seen> _expectAppearing(WidgetTester tester, _Area area, String when) {
  final String reason = '${area.name}, $when';
  final List<_Seen> shown = _seen(tester, _subjectKey);
  final List<_Seen> steady = _seen(tester, _twinKey);
  expect(shown, hasLength(area.petals), reason: reason);
  expect(_flowers(shown), everyElement(FlowerKind.lavender), reason: reason);
  expect(_centres(shown), _centres(steady), reason: reason);
  expect(_centres(shown).toSet(), hasLength(area.petals), reason: reason);
  expect(
    shown.map((_Seen petal) => petal.alpha),
    everyElement(0),
    reason: reason,
  );
  return steady;
}

Future<void> _expectNoFlowerStopsNewPetals(
  WidgetTester tester,
  _Area area,
) async {
  _pinView(tester, area.size);
  await _pumpPair(
    tester,
    size: area.size,
    changing: FlowerKind.peony,
    steady: FlowerKind.peony,
  );
  await tester.pump(_settled);

  await _pumpPair(
    tester,
    size: area.size,
    changing: null,
    steady: FlowerKind.peony,
  );
  List<_Seen> previous = _seen(tester, _twinKey);
  expect(
    _centres(_seen(tester, _subjectKey)),
    _centres(previous),
    reason: area.name,
  );
  expect(previous, hasLength(area.petals), reason: area.name);

  List<bool> finished = List<bool>.filled(area.petals, false);
  for (Duration since = _step; since <= _pastLongestLoop; since += _step) {
    await tester.pump(_step);
    final String reason =
        '${area.name}, ${since.inMilliseconds} ms after the clear';
    final List<_Seen> steady = _seen(tester, _twinKey);
    final List<_Seen> now = _seen(tester, _subjectKey);
    finished = _restartedSince(finished, previous, steady);
    expect(_centres(now), <Offset>[
      for (int index = 0; index < steady.length; index++)
        if (!finished[index]) steady[index].centre,
    ], reason: reason);
    expect(_flowers(now), everyElement(FlowerKind.peony), reason: reason);
    if (since == _twoSeconds) {
      expect(finished, contains(false), reason: reason);
    }
    previous = steady;
  }
  expect(finished, everyElement(isTrue), reason: area.name);
  expect(find.byKey(_subjectKey), paintsNothing, reason: area.name);
  expect(
    tester.binding.transientCallbackCount,
    1,
    reason: '${area.name}, only the steady layer still asks for frames',
  );

  await _pumpPair(
    tester,
    size: area.size,
    changing: FlowerKind.lavender,
    steady: FlowerKind.peony,
  );
  final List<_Seen> setSteady = _expectAppearing(
    tester,
    area,
    'as the flower is set again',
  );
  await tester.pump(_halfAppear);
  final List<_Seen> halfway = _seen(tester, _subjectKey);
  final List<_Seen> halfwaySteady = _seen(tester, _twinKey);
  expect(_centres(halfway), _centres(halfwaySteady), reason: area.name);
  final List<bool> restartedHalfway = _restartedSince(
    List<bool>.filled(area.petals, false),
    setSteady,
    halfwaySteady,
  );
  for (int index = 0; index < halfway.length; index++) {
    expect(
      halfway[index].alpha,
      closeTo(
        restartedHalfway[index]
            ? halfwaySteady[index].alpha
            : halfwaySteady[index].alpha / 2,
        _alphaTolerance,
      ),
      reason: '${area.name}, petal $index halfway through appearing',
    );
  }
  await tester.pump(_halfAppear);
  final List<_Seen> appeared = _seen(tester, _subjectKey);
  final List<_Seen> appearedSteady = _seen(tester, _twinKey);
  expect(
    _flowers(appeared),
    everyElement(FlowerKind.lavender),
    reason: area.name,
  );
  expect(_centres(appeared), _centres(appearedSteady), reason: area.name);
  for (int index = 0; index < appeared.length; index++) {
    expect(
      appeared[index].alpha,
      closeTo(appearedSteady[index].alpha, _alphaTolerance),
      reason: '${area.name}, petal $index after 0.6 seconds',
    );
  }

  await _unmount(tester);
  await _pumpPair(
    tester,
    size: area.size,
    changing: FlowerKind.lavender,
    steady: FlowerKind.lavender,
  );
  _expectAppearing(tester, area, 'as it mounts with a flower');
  await tester.pump();
  await tester.pump(_halfAppear);
  _expectMidLoopShown(
    _seen(tester, _subjectKey),
    area.size,
    0.5,
    '${area.name}, halfway through appearing after mounting',
  );
  await tester.pump(_halfAppear);
  final List<_Seen> mounted = _seen(tester, _subjectKey);
  _expectMidLoopShown(
    mounted,
    area.size,
    1,
    '${area.name}, 0.6 seconds after mounting',
  );
  expect(mounted, hasLength(area.petals), reason: area.name);
  expect(
    _flowers(mounted),
    everyElement(FlowerKind.lavender),
    reason: area.name,
  );
  expect(
    mounted.map((_Seen petal) => petal.alpha),
    everyElement(greaterThan(0)),
    reason: area.name,
  );
  await _unmount(tester);
}

void main() {
  testWidgets('petals never take input and vanish with reduce motion', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final _Area area in _areas) {
      await _onPlatform(area.platform, () async {
        int taps = 0;
        void onTap() => taps++;

        await _pumpLayer(
          tester,
          size: area.size,
          petals: false,
          still: false,
          onTap: onTap,
        );
        final int bare = _semanticsNodes(tester);
        expect(bare, greaterThan(0), reason: area.name);

        await _pumpLayer(
          tester,
          size: area.size,
          petals: true,
          still: false,
          onTap: onTap,
        );
        expect(find.byType(PetalDrift), findsOneWidget, reason: area.name);
        expect(
          find.byType(PetalDrift),
          paintsExactlyCountTimes(#drawPath, area.petals * 2),
          reason: area.name,
        );
        expect(tester.hasRunningAnimations, isTrue, reason: area.name);
        expect(_semanticsNodes(tester), bare, reason: area.name);
        expect(
          tester.getSemantics(find.byKey(_beneathKey)),
          isSemantics(label: _beneathLabel, isButton: true, hasTapAction: true),
          reason: area.name,
        );
        await _tapThrough(tester);
        expect(taps, 1, reason: area.name);

        await _pumpLayer(
          tester,
          size: area.size,
          petals: true,
          still: true,
          onTap: onTap,
        );
        expect(find.byType(PetalDrift), findsOneWidget, reason: area.name);
        expect(find.byType(PetalDrift), paintsNothing, reason: area.name);
        expect(tester.hasRunningAnimations, isFalse, reason: area.name);
        expect(_semanticsNodes(tester), bare, reason: area.name);
        await _tapThrough(tester);
        expect(taps, 2, reason: area.name);
      });
    }
    handle.dispose();
  });

  testWidgets('a petal takes the current flower when it starts its next loop', (
    WidgetTester tester,
  ) async {
    for (final _Area area in _areas) {
      await _onPlatform(
        area.platform,
        () => _expectTheNextLoopTakesTheFlower(tester, area),
      );
    }
  });

  testWidgets('with no flower petals finish their fall and none start again', (
    WidgetTester tester,
  ) async {
    for (final _Area area in _areas) {
      await _onPlatform(
        area.platform,
        () => _expectNoFlowerStopsNewPetals(tester, area),
      );
    }
  });

  testWidgets('a layer with nothing falling asks for no frames', (
    WidgetTester tester,
  ) async {
    final _Area area = _areas.last;
    _pinView(tester, area.size);
    Future<void> pumpAlone(FlowerKind? flower) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: area.size),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PetalDrift(key: _subjectKey, flower: flower),
        ),
      ),
    );

    await pumpAlone(null);
    await tester.pump(_settled);
    expect(tester.hasRunningAnimations, isFalse, reason: 'mounted bare');
    expect(find.byKey(_subjectKey), paintsNothing, reason: 'mounted bare');

    await pumpAlone(FlowerKind.lavender);
    expect(tester.hasRunningAnimations, isTrue, reason: 'given a flower');
    await tester.pump(_settled);
    expect(
      _seen(tester, _subjectKey),
      hasLength(area.petals),
      reason: 'given a flower',
    );

    await pumpAlone(null);
    await tester.pump(_pastLongestLoop);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse, reason: 'after the last fall');
    expect(
      find.byKey(_subjectKey),
      paintsNothing,
      reason: 'after the last fall',
    );

    await pumpAlone(FlowerKind.lavender);
    expect(tester.hasRunningAnimations, isTrue, reason: 'given it again');
    final List<_Seen> again = _seen(tester, _subjectKey);
    expect(again, hasLength(area.petals), reason: 'given it again');
    expect(
      again.map((_Seen petal) => petal.alpha),
      everyElement(0),
      reason: 'given it again',
    );
    await tester.pump();
    await tester.pump(_halfAppear);
    _expectMidLoopShown(
      _seen(tester, _subjectKey),
      area.size,
      0.5,
      'halfway through appearing again',
    );
    await tester.pump(_halfAppear);
    _expectMidLoopShown(
      _seen(tester, _subjectKey),
      area.size,
      1,
      '0.6 seconds after appearing again',
    );
    await _unmount(tester);
  });
}
