import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/field_notes_colors.dart';
import 'package:field_notes/features/onboarding/onboarding_gate.dart';
import 'package:field_notes/features/opening/opening_cover.dart';
import 'package:field_notes/features/opening/opening_frame.dart';
import 'package:field_notes/features/opening/opening_plan.dart';
import 'package:field_notes/features/opening/opening_providers.dart';

const Size _phone = Size(384, 832);
const Duration _frame = Duration(milliseconds: 16);
const Offset _middle = Offset(192, 416);

class _Gate extends OnboardingGate {
  _Gate(this._answer);

  final Future<OnboardingVisibility> _answer;

  @override
  Future<OnboardingVisibility> build() => _answer;
}

class _CountsInit extends StatefulWidget {
  const _CountsInit({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_CountsInit> createState() => _CountsInitState();
}

class _CountsInitState extends State<_CountsInit> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _TapCounter {
  int taps = 0;

  Widget get child => SizedBox.expand(
    child: TextButton(onPressed: () => taps++, child: const Text('Count')),
  );
}

class _KeyRecorder {
  final List<KeyEvent> events = <KeyEvent>[];

  Widget get child => Focus(
    autofocus: true,
    onKeyEvent: (FocusNode node, KeyEvent event) {
      events.add(event);
      return KeyEventResult.handled;
    },
    child: const SizedBox.expand(),
  );
}

Future<OnboardingVisibility> _hidden() =>
    Future<OnboardingVisibility>.value(OnboardingVisibility.hidden);

Future<void> _pumpCover(
  WidgetTester tester, {
  required Widget child,
  bool plays = true,
  Future<OnboardingVisibility>? gate,
  TargetPlatform platform = TargetPlatform.android,
  Size size = _phone,
  Brightness theme = Brightness.light,
  Brightness system = Brightness.light,
  ValueListenable<bool>? screenReader,
  bool disableAnimations = false,
  Key? key,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.platformBrightnessTestValue = system;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final ValueListenable<bool> reader =
      screenReader ?? ValueNotifier<bool>(false);
  await tester.pumpWidget(
    ProviderScope(
      key: key,
      overrides: <Override>[
        playsOpeningProvider.overrideWithValue(plays),
        onboardingGateProvider.overrideWith(() => _Gate(gate ?? _hidden())),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform, brightness: theme),
        builder: (BuildContext context, Widget? app) =>
            ValueListenableBuilder<bool>(
              valueListenable: reader,
              builder: (BuildContext context, bool accessible, Widget? _) =>
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      accessibleNavigation: accessible,
                      disableAnimations: disableAnimations,
                    ),
                    child: OpeningCover(child: app!),
                  ),
            ),
        home: Scaffold(body: child),
      ),
    ),
  );
}

Finder get _paper => find.byKey(openingPaperKey);

Color _paperColour(WidgetTester tester) =>
    tester.widget<ColoredBox>(_paper).color;

Duration _until(double seconds, double from) =>
    Duration(microseconds: ((seconds - from) * 1e6).ceil());

void _expectGone(WidgetTester tester) {
  expect(find.byType(OpeningFrame), findsNothing);
  expect(_paper, findsNothing);
}

void main() {
  final double total = openingPlan().total;

  testWidgets('plays the opening over the app when onboarding stays hidden', (
    WidgetTester tester,
  ) async {
    int inits = 0;
    await _pumpCover(tester, child: _CountsInit(onInit: () => inits++));
    expect(inits, 1);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OpeningFrame), findsOneWidget);
    expect(
      tester.widget<OpeningFrame>(find.byType(OpeningFrame)).seconds,
      closeTo(0.5, 1 / 60),
    );
    expect(_paperColour(tester), FieldNotesColors.light.panelTop);

    await tester.pump(_until(total, 0.5));
    await tester.pump(_frame);
    _expectGone(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(inits, 1);
  });

  testWidgets('the cover shows only the paper while the onboarding decision '
      'loads', (WidgetTester tester) async {
    final Completer<OnboardingVisibility> gate =
        Completer<OnboardingVisibility>();
    await _pumpCover(tester, child: const SizedBox(), gate: gate.future);

    await tester.pump(const Duration(milliseconds: 500));
    expect(_paper, findsOneWidget);
    expect(_paperColour(tester), FieldNotesColors.light.panelTop);
    expect(find.byType(OpeningFrame), findsNothing);

    gate.complete(OnboardingVisibility.hidden);
    await tester.pump(_frame);
    expect(find.byType(OpeningFrame), findsOneWidget);
  });

  testWidgets('the cover starts below the title bar on desktop', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _pumpCover(
      tester,
      child: const SizedBox(),
      platform: TargetPlatform.macOS,
      size: const Size(1140, 768),
    );
    final Rect desktop = tester.getRect(_paper);
    expect(desktop.top, 42);
    expect(desktop.bottom, 768);
    debugDefaultTargetPlatformOverride = null;

    await _pumpCover(tester, child: const SizedBox(), key: UniqueKey());
    expect(tester.getRect(_paper).top, 0);
  });

  testWidgets('the paper eases from the system brightness to the app '
      'appearance', (WidgetTester tester) async {
    await _pumpCover(tester, child: const SizedBox(), system: Brightness.dark);
    expect(_paperColour(tester), FieldNotesColors.dark.panelTop);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_paperColour(tester), FieldNotesColors.light.panelTop);

    await _pumpCover(tester, child: const SizedBox(), key: UniqueKey());
    expect(_paperColour(tester), FieldNotesColors.light.panelTop);
  });

  testWidgets('the app keeps its own keyboard focus under the cover', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final FocusNode field = FocusNode();
    addTearDown(field.dispose);
    await _pumpCover(
      tester,
      child: TextField(autofocus: true, focusNode: field),
      platform: TargetPlatform.macOS,
      size: const Size(1140, 768),
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OpeningFrame), findsOneWidget);
    expect(field.hasPrimaryFocus, isTrue);

    await tester.pump(_until(total, 0.5));
    await tester.pump(_frame);
    _expectGone(tester);
    expect(field.hasPrimaryFocus, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('no opening when onboarding will show', (
    WidgetTester tester,
  ) async {
    await _pumpCover(
      tester,
      child: const SizedBox(),
      gate: Future<OnboardingVisibility>.value(OnboardingVisibility.shown),
    );
    expect(find.byType(OpeningFrame), findsNothing);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(OpeningFrame), findsNothing);
    await tester.pump(const Duration(milliseconds: 130));
    _expectGone(tester);
  });

  testWidgets('no opening when the onboarding decision takes longer than a '
      'second', (WidgetTester tester) async {
    await _pumpCover(
      tester,
      child: const SizedBox(),
      gate: Completer<OnboardingVisibility>().future,
    );
    await tester.pump(const Duration(milliseconds: 990));
    expect(_paper, findsOneWidget);
    expect(find.byType(OpeningFrame), findsNothing);
    await tester.pump(const Duration(milliseconds: 270));
    _expectGone(tester);
  });

  testWidgets('no opening when the app does not ask for it', (
    WidgetTester tester,
  ) async {
    final _TapCounter counter = _TapCounter();
    await _pumpCover(tester, child: counter.child, plays: false);
    _expectGone(tester);

    await tester.tapAt(_middle);
    expect(counter.taps, 1);
  });

  testWidgets('no opening with a screen reader on', (
    WidgetTester tester,
  ) async {
    await _pumpCover(
      tester,
      child: const SizedBox(),
      screenReader: ValueNotifier<bool>(true),
    );
    _expectGone(tester);
    await tester.pump(const Duration(milliseconds: 500));
    _expectGone(tester);
  });

  testWidgets('returning from the background never replays the opening', (
    WidgetTester tester,
  ) async {
    await _pumpCover(tester, child: const SizedBox());
    await tester.pump(_until(total, 0));
    await tester.pump(_frame);
    _expectGone(tester);

    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    for (int step = 0; step < 10; step++) {
      await tester.pump(const Duration(milliseconds: 100));
      _expectGone(tester);
    }
  });

  testWidgets('the app stays readable by a screen reader under the cover', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpCover(tester, child: const Center(child: Text('Today')));

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OpeningFrame), findsOneWidget);
    expect(find.bySemanticsLabel('Today'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a decision after a second never starts the drawing', (
    WidgetTester tester,
  ) async {
    final Completer<OnboardingVisibility> gate =
        Completer<OnboardingVisibility>();
    await _pumpCover(tester, child: const SizedBox(), gate: gate.future);
    await tester.pump(const Duration(milliseconds: 1100));
    gate.complete(OnboardingVisibility.hidden);
    await tester.pump();
    expect(find.byType(OpeningFrame), findsNothing);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(OpeningFrame), findsNothing);
    await tester.pump(const Duration(milliseconds: 80));
    _expectGone(tester);
  });

  testWidgets('the cover steps aside when a screen reader turns on', (
    WidgetTester tester,
  ) async {
    final _TapCounter counter = _TapCounter();
    final ValueNotifier<bool> reader = ValueNotifier<bool>(false);
    addTearDown(reader.dispose);
    await _pumpCover(tester, child: counter.child, screenReader: reader);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(OpeningFrame), findsOneWidget);

    reader.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    _expectGone(tester);

    await tester.tapAt(_middle);
    expect(counter.taps, 1);
  });

  testWidgets('a tap skips to the app within a quarter of a second', (
    WidgetTester tester,
  ) async {
    final _TapCounter counter = _TapCounter();
    await _pumpCover(tester, child: counter.child);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(OpeningFrame), findsOneWidget);

    await tester.tapAt(_middle);
    expect(counter.taps, 0);
    await tester.pump(const Duration(milliseconds: 250));
    _expectGone(tester);

    await tester.tapAt(_middle);
    expect(counter.taps, 1);
  });

  testWidgets('any key skips to the app within a quarter of a second', (
    WidgetTester tester,
  ) async {
    final _KeyRecorder recorder = _KeyRecorder();
    await _pumpCover(tester, child: recorder.child);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(OpeningFrame), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(recorder.events, isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    _expectGone(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    expect(
      recorder.events.map((KeyEvent event) => event.runtimeType).toList(),
      <Type>[KeyDownEvent, KeyUpEvent],
    );
    expect(
      recorder.events.map((KeyEvent event) => event.logicalKey).toSet(),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyB},
    );
  });

  testWidgets('a tap while the onboarding decision loads skips the drawing', (
    WidgetTester tester,
  ) async {
    final _TapCounter counter = _TapCounter();
    final Completer<OnboardingVisibility> gate =
        Completer<OnboardingVisibility>();
    await _pumpCover(tester, child: counter.child, gate: gate.future);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(_middle);
    expect(counter.taps, 0);

    await tester.pump(const Duration(milliseconds: 100));
    gate.complete(OnboardingVisibility.hidden);
    await tester.pump();
    expect(find.byType(OpeningFrame), findsNothing);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(OpeningFrame), findsNothing);
    await tester.pump(const Duration(milliseconds: 80));
    _expectGone(tester);

    await tester.tapAt(_middle);
    expect(counter.taps, 1);
  });

  testWidgets('volume and media keys pass through without skipping', (
    WidgetTester tester,
  ) async {
    final _KeyRecorder recorder = _KeyRecorder();
    await _pumpCover(tester, child: recorder.child);
    await tester.pump(const Duration(milliseconds: 600));

    await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    expect(
      recorder.events.map((KeyEvent event) => event.logicalKey).toList(),
      <LogicalKeyboardKey>[
        LogicalKeyboardKey.audioVolumeUp,
        LogicalKeyboardKey.audioVolumeUp,
        LogicalKeyboardKey.mediaPlayPause,
        LogicalKeyboardKey.mediaPlayPause,
      ],
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OpeningFrame), findsOneWidget);
  });

  testWidgets('a held key that skips never reaches the app after the cover '
      'leaves', (WidgetTester tester) async {
    final _KeyRecorder recorder = _KeyRecorder();
    await _pumpCover(tester, child: recorder.child);
    await tester.pump(const Duration(milliseconds: 600));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.pump(const Duration(milliseconds: 250));
    _expectGone(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyA);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    expect(recorder.events, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    expect(
      recorder.events.map((KeyEvent event) => event.runtimeType).toList(),
      <Type>[KeyDownEvent, KeyUpEvent],
    );
    expect(
      recorder.events.map((KeyEvent event) => event.logicalKey).toSet(),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyB},
    );
  });

  testWidgets('reduce motion shows the finished drawing, then crossfades in '
      '0.3 seconds', (WidgetTester tester) async {
    await _pumpCover(tester, child: const SizedBox(), disableAnimations: true);
    await tester.pump(const Duration(milliseconds: 390));
    final Finder frame = find.byType(OpeningFrame);
    expect(frame, findsOneWidget);
    expect(MediaQuery.of(tester.element(frame)).disableAnimations, isTrue);

    await tester.pump(const Duration(milliseconds: 330));
    _expectGone(tester);
  });
}
