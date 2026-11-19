import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/features/opening/opening_cover.dart';
import 'package:field_notes/features/opening/opening_frame.dart';
import 'package:field_notes/features/opening/opening_providers.dart';

const Duration _frame = Duration(milliseconds: 16);
const Duration _wallClockStep = Duration(hours: 1);
const Offset _middle = Offset(192, 416);

class _Gate extends OnboardingGate {
  _Gate(this._answer);

  final Future<OnboardingVisibility> _answer;

  @override
  Future<OnboardingVisibility> build() => _answer;
}

class _TapCounter {
  int taps = 0;

  Widget get child => SizedBox.expand(
    child: TextButton(onPressed: () => taps++, child: const Text('Count')),
  );
}

class _SteppableWallClock {
  _SteppableWallClock(this._underlying);

  final Clock _underlying;
  Duration _step = Duration.zero;

  Clock get clock => Clock(() => _underlying.now().add(_step));

  void stepForward(Duration step) => _step += step;
}

Future<void> _withSteppableWallClock(
  Future<void> Function(_SteppableWallClock wallClock) body,
) {
  final _SteppableWallClock wallClock = _SteppableWallClock(clock);
  return withClock(wallClock.clock, () => body(wallClock));
}

Future<void> _pumpCover(
  WidgetTester tester, {
  required Widget child,
  required Future<OnboardingVisibility> gate,
}) async {
  tester.view.physicalSize = const Size(384, 832);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        playsOpeningProvider.overrideWithValue(true),
        onboardingGateProvider.overrideWith(() => _Gate(gate)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(
          platform: TargetPlatform.android,
          brightness: Brightness.light,
        ),
        builder: (BuildContext context, Widget? app) =>
            OpeningCover(child: app!),
        home: Scaffold(body: child),
      ),
    ),
  );
}

Future<OnboardingVisibility> _hidden() =>
    Future<OnboardingVisibility>.value(OnboardingVisibility.hidden);

void _expectGone() {
  expect(find.byType(OpeningFrame), findsNothing);
  expect(find.byKey(openingPaperKey), findsNothing);
}

void main() {
  testWidgets(
    'a tap skips within a quarter of a second when the wall clock steps '
    'forward just before it',
    (WidgetTester tester) =>
        _withSteppableWallClock((_SteppableWallClock wallClock) async {
          final _TapCounter counter = _TapCounter();
          await _pumpCover(tester, child: counter.child, gate: _hidden());
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.byType(OpeningFrame), findsOneWidget);

          wallClock.stepForward(_wallClockStep);
          await tester.tapAt(_middle);
          expect(counter.taps, 0);
          await tester.pump(_frame);
          await tester.pump(const Duration(milliseconds: 250) - _frame);
          _expectGone();

          await tester.tapAt(_middle);
          expect(counter.taps, 1);
        }),
  );

  testWidgets(
    'a key skips within a quarter of a second when the wall clock steps '
    'forward just before it',
    (WidgetTester tester) =>
        _withSteppableWallClock((_SteppableWallClock wallClock) async {
          final _TapCounter counter = _TapCounter();
          await _pumpCover(tester, child: counter.child, gate: _hidden());
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.byType(OpeningFrame), findsOneWidget);

          wallClock.stepForward(_wallClockStep);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
          await tester.pump(_frame);
          await tester.pump(const Duration(milliseconds: 250) - _frame);
          _expectGone();

          await tester.tapAt(_middle);
          expect(counter.taps, 1);
        }),
  );

  testWidgets(
    'onboarding that will show clears the paper within a quarter of a second '
    'when the wall clock steps forward in the same frame gap',
    (WidgetTester tester) =>
        _withSteppableWallClock((_SteppableWallClock wallClock) async {
          final _TapCounter counter = _TapCounter();
          final Completer<OnboardingVisibility> gate =
              Completer<OnboardingVisibility>();
          await _pumpCover(tester, child: counter.child, gate: gate.future);
          await tester.pump(const Duration(milliseconds: 500));

          wallClock.stepForward(_wallClockStep);
          gate.complete(OnboardingVisibility.shown);
          await tester.pump(_frame);
          await tester.pump(const Duration(milliseconds: 250) - _frame);
          _expectGone();

          await tester.tapAt(_middle);
          expect(counter.taps, 1);
        }),
  );

  testWidgets(
    'a hidden decision inside the second still starts the drawing when the '
    'wall clock steps forward in the same frame gap',
    (WidgetTester tester) =>
        _withSteppableWallClock((_SteppableWallClock wallClock) async {
          final Completer<OnboardingVisibility> gate =
              Completer<OnboardingVisibility>();
          await _pumpCover(tester, child: const SizedBox(), gate: gate.future);
          await tester.pump(const Duration(milliseconds: 500));

          wallClock.stepForward(_wallClockStep);
          gate.complete(OnboardingVisibility.hidden);
          await tester.pump(_frame);
          await tester.pump(_frame);
          expect(find.byType(OpeningFrame), findsOneWidget);
        }),
  );
}
