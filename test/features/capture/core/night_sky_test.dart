import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/core/night_sky.dart';

const Size _window = Size(1440, 900);
const Duration _step = Duration(milliseconds: 200);
const Duration _tenMinutes = Duration(minutes: 10);

void _useWindow(WidgetTester tester) {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _letTheSkyMove() {
  final bool before = debugNightSkyStill;
  debugNightSkyStill = false;
  addTearDown(() => debugNightSkyStill = before);
}

Widget _sky({int? seed, bool holdComets = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      extensions: const <ThemeExtension<dynamic>>[FieldNotesColors.dark],
    ),
    home: NightSky(kind: NightSkyKind.note, seed: seed, holdComets: holdComets),
  );
}

List<Offset> _paintedStars(WidgetTester tester) {
  final TestRecordingCanvas canvas = TestRecordingCanvas();
  tester
      .renderObject(find.byKey(nightSkyStillKey))
      .paint(TestRecordingPaintingContext(canvas), Offset.zero);
  return <Offset>[
    for (final RecordedInvocation call in canvas.invocations)
      if (call.invocation.memberName == #drawCircle)
        call.invocation.positionalArguments.first as Offset,
  ];
}

bool _cometFlying() => find.byKey(nightSkyCometKey).evaluate().isNotEmpty;

List<Offset> _placed(NightSkyField field, Size size) => <Offset>[
  for (final NightSkyStar star in field.stars)
    Offset(star.position.dx * size.width, star.position.dy * size.height),
];

void main() {
  test('the star field holds 55 to 65 stars for any seed', () {
    for (final Size size in const <Size>[
      _window,
      Size(390, 844),
      Size(800, 600),
    ]) {
      for (final NightSkyKind kind in NightSkyKind.values) {
        for (int seed = 0; seed < 200; seed++) {
          final int stars = NightSkyField.scatter(
            seed: seed,
            kind: kind,
            size: size,
          ).stars.length;
          expect(
            stars,
            inInclusiveRange(55, 65),
            reason: '$kind seed $seed in $size',
          );
        }
      }
    }
  });

  test('two seeds scatter the stars differently', () {
    final List<Offset> first = _placed(
      NightSkyField.scatter(seed: 1, kind: NightSkyKind.note, size: _window),
      _window,
    );
    final List<Offset> second = _placed(
      NightSkyField.scatter(seed: 2, kind: NightSkyKind.note, size: _window),
      _window,
    );

    expect(first, isNot(second));
    expect(first.toSet().intersection(second.toSet()), isEmpty);
  });

  test(
    'the sky behind the writing column keeps about a fifth of its stars',
    () {
      const Rect column = Rect.fromLTRB(480, 200, 960, 760);
      final double outerWidth = 2 * 300.0;
      int inside = 0;
      int outside = 0;
      for (int seed = 0; seed < 200; seed++) {
        for (final Offset star in _placed(
          NightSkyField.scatter(
            seed: seed,
            kind: NightSkyKind.note,
            size: _window,
          ),
          _window,
        )) {
          if (column.contains(star)) {
            inside++;
          } else if (star.dx < 300 || star.dx > _window.width - 300) {
            outside++;
          }
        }
      }
      final double insideDensity = inside / (column.width * column.height);
      final double outsideDensity = outside / (outerWidth * _window.height);

      expect(insideDensity / outsideDensity, inInclusiveRange(0.1, 0.35));
    },
  );

  testWidgets('each opening scatters the stars anew', (
    WidgetTester tester,
  ) async {
    _useWindow(tester);
    await tester.pumpWidget(_sky());
    final List<Offset> first = _paintedStars(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_sky());
    final List<Offset> second = _paintedStars(tester);

    expect(first, hasLength(nightSkyStarCount));
    expect(second, hasLength(nightSkyStarCount));
    expect(first, isNot(second));
  });

  testWidgets(
    'no comet comes in the first 30 seconds and no two ever overlap across ten minutes',
    (WidgetTester tester) async {
      _useWindow(tester);
      _letTheSkyMove();
      for (final int seed in const <int>[3, 11, 42]) {
        await tester.pumpWidget(_sky(seed: seed));
        final List<Duration> starts = <Duration>[];
        final List<Duration> flights = <Duration>[];
        Duration now = Duration.zero;
        Duration? since;
        while (now < _tenMinutes) {
          await tester.pump(_step);
          now += _step;
          final bool flying = _cometFlying();
          if (flying && since == null) {
            since = now;
            starts.add(now);
          } else if (!flying && since != null) {
            flights.add(now - since);
            since = null;
          }
        }

        expect(starts.length, greaterThanOrEqualTo(3), reason: 'seed $seed');
        expect(
          starts.first,
          greaterThanOrEqualTo(nightSkyCometQuiet),
          reason: 'seed $seed',
        );
        for (final Duration flight in flights) {
          expect(flight, lessThanOrEqualTo(nightSkyCometFlight + _step * 2));
        }
        for (int index = 1; index < starts.length; index++) {
          expect(
            starts[index] - starts[index - 1],
            greaterThanOrEqualTo(const Duration(minutes: 1)),
            reason: 'seed $seed',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('a held sky starts no comet', (WidgetTester tester) async {
    _useWindow(tester);
    _letTheSkyMove();
    await tester.pumpWidget(_sky(seed: 3, holdComets: true));

    for (Duration now = Duration.zero; now < _tenMinutes; now += _step) {
      await tester.pump(_step);
      expect(find.byKey(nightSkyCometKey), findsNothing);
    }
  });

  testWidgets('a hidden app stops the twinkle and comets until it returns', (
    WidgetTester tester,
  ) async {
    _useWindow(tester);
    _letTheSkyMove();
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(_sky(seed: 3));
    final CustomPainter twinkle = tester
        .widget<CustomPaint>(find.byKey(nightSkyTwinkleKey))
        .painter!;
    int repaints = 0;
    twinkle.addListener(() => repaints++);
    await tester.pump(const Duration(seconds: 1));
    expect(repaints, greaterThanOrEqualTo(10));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    repaints = 0;
    for (Duration now = Duration.zero; now < _tenMinutes; now += _step) {
      await tester.pump(_step);
      expect(find.byKey(nightSkyCometKey), findsNothing);
    }

    expect(repaints, 0);
    expect(tester.binding.transientCallbackCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(repaints, greaterThanOrEqualTo(10));
  });
}
