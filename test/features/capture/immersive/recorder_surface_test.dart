import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

const Key _openKey = ValueKey<String>('open-recorder');
const Key _centreKey = ValueKey<String>('stage-centre');
const Key _statusKey = ValueKey<String>('stage-status');
const Key _actionsKey = ValueKey<String>('stage-actions');
const Key _questionKey = ValueKey<String>('stage-question');
const Key _trailingKey = ValueKey<String>('stage-trailing');

void _useWindow(WidgetTester tester, TargetPlatform platform, Size window) {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(TargetPlatform platform, Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: platform),
    home: home,
  );
}

RecorderSurface _surface({
  VoidCallback? onLeave,
  RecorderArrangement arrangement = RecorderArrangement.voice,
  Widget? question,
}) {
  return RecorderSurface(
    privacyLine: 'Private · only you will hear this',
    onLeave: onLeave ?? () {},
    arrangement: arrangement,
    question: question,
    centre: const SizedBox(key: _centreKey, width: 250, height: 250),
    status: const SizedBox(key: _statusKey, width: 200, height: 50),
    actions: const SizedBox(key: _actionsKey, width: 240, height: 48),
  );
}

List<String> _recordWindowCalls(WidgetTester tester) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowChannel,
    (MethodCall call) async {
      calls.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      null,
    ),
  );
  return calls;
}

Iterable<AnnotatedRegion<SystemUiOverlayStyle>> _overlayRegions(
  WidgetTester tester,
) {
  return tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
    find.byWidgetPredicate(
      (Widget widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
    ),
  );
}

Widget _glow({required bool still, required BreathingGlowMode mode}) {
  return _app(
    TargetPlatform.macOS,
    Builder(
      builder: (BuildContext context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: still),
          child: Center(
            child: BreathingGlow(diameter: 250, mode: mode, ringInset: 34),
          ),
        );
      },
    ),
  );
}

List<double> _glowScales(WidgetTester tester) {
  return tester
      .widgetList<Transform>(
        find.descendant(
          of: find.byType(BreathingGlow),
          matching: find.byType(Transform),
        ),
      )
      .map((Transform transform) => transform.transform.entry(0, 0))
      .toList();
}

List<double> _glowOpacities(WidgetTester tester) {
  return tester
      .widgetList<Opacity>(
        find.descendant(
          of: find.byType(BreathingGlow),
          matching: find.byType(Opacity),
        ),
      )
      .map((Opacity opacity) => opacity.opacity)
      .toList();
}

void main() {
  testWidgets(
    'the sidebar top band keeps 62 px clear for the traffic lights and drags the window',
    (WidgetTester tester) async {
      _useWindow(tester, TargetPlatform.macOS, const Size(1280, 800));
      final List<String> calls = _recordWindowCalls(tester);
      await tester.pumpWidget(_app(TargetPlatform.macOS, _surface()));

      final Rect leave = tester.getRect(find.byKey(recorderLeaveKey));
      expect(leave.left, greaterThanOrEqualTo(62));
      expect(
        leave.left,
        greaterThanOrEqualTo(shellTitleBarPadding + windowButtonsSlotWidth),
      );
      expect(leave.height, greaterThanOrEqualTo(48));
      expect(find.text('Leave'), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);

      final Rect band = tester.getRect(find.byKey(recorderTopBandKey));
      expect(band.top, 0);
      expect(band.width, 1280);

      final Offset emptyBand = Offset(band.left + 320, band.center.dy);
      await tester.dragFrom(emptyBand, const Offset(60, 20));
      await tester.pumpAndSettle();
      expect(calls, <String>[startDragMethod]);

      await tester.tapAt(emptyBand);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(emptyBand);
      await tester.pumpAndSettle();
      expect(calls, <String>[startDragMethod, titlebarDoubleClickMethod]);

      final Offset privacy = tester.getCenter(
        find.text('Private · only you will hear this'),
      );
      expect(privacy.dx, closeTo(640, 12));
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('on Windows the trailing control clears the caption buttons', (
    WidgetTester tester,
  ) async {
    RecorderSurface surface() => RecorderSurface(
      privacyLine: 'Private · only you will hear this',
      onLeave: () {},
      trailing: const SizedBox(key: _trailingKey, width: 120, height: 20),
      centre: const SizedBox(key: _centreKey, width: 250, height: 250),
      status: const SizedBox(key: _statusKey, width: 200, height: 50),
      actions: const SizedBox(key: _actionsKey, width: 240, height: 48),
    );

    _useWindow(tester, TargetPlatform.windows, const Size(1280, 800));
    await tester.pumpWidget(_app(TargetPlatform.windows, surface()));

    final Rect trailing = tester.getRect(find.byKey(_trailingKey));
    expect(
      trailing.right,
      lessThanOrEqualTo(1280 - windowsCaptionButtonsWidth),
    );
    expect(tester.getRect(find.byKey(recorderLeaveKey)).left, 18);
    expect(
      tester.getCenter(find.text('Private · only you will hear this')).dx,
      closeTo(640, 12),
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(_app(TargetPlatform.macOS, surface()));

    expect(tester.getRect(find.byKey(_trailingKey)).right, 1280 - 18);
    expect(
      tester.getRect(find.byKey(recorderLeaveKey)).left,
      windowButtonsClearance,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'the bottom-bar surface switches the status bar to light icons and restores it on close',
    (WidgetTester tester) async {
      _useWindow(tester, TargetPlatform.android, const Size(360, 740));
      tester.view.padding = const FakeViewPadding(top: 24);
      await tester.pumpWidget(
        _app(
          TargetPlatform.android,
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(
              body: Builder(
                builder: (BuildContext context) {
                  return Center(
                    child: TextButton(
                      key: _openKey,
                      onPressed: () => showImmersiveRecorder<void>(
                        context,
                        barrierLabel: 'Dismiss recorder',
                        builder: (BuildContext context) => _surface(
                          onLeave: () => Navigator.of(context).pop(),
                        ),
                      ),
                      child: const Text('Open'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );

      await tester.tap(find.byKey(_openKey));
      await tester.pumpAndSettle();
      expect(
        _overlayRegions(
          tester,
        ).map((AnnotatedRegion<SystemUiOverlayStyle> region) => region.value),
        contains(SystemUiOverlayStyle.light),
      );
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      expect(
        tester.getRect(find.byKey(recorderLeaveKey)).top,
        greaterThanOrEqualTo(24),
      );

      await tester.tap(find.byKey(recorderLeaveKey));
      await tester.pumpAndSettle();
      expect(find.byType(RecorderSurface), findsNothing);
      expect(
        _overlayRegions(
          tester,
        ).map((AnnotatedRegion<SystemUiOverlayStyle> region) => region.value),
        isNot(contains(SystemUiOverlayStyle.light)),
      );
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.dark,
      );
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('a platform other than macOS uses the bottom-bar surface', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.linux, const Size(360, 740));
    int leaves = 0;
    await tester.pumpWidget(
      _app(TargetPlatform.linux, _surface(onLeave: () => leaves++)),
    );

    expect(tester.getSize(find.byKey(recorderLeaveKey)), const Size(48, 48));
    expect(find.text('Leave'), findsNothing);
    expect(find.byKey(recorderTopBandKey), findsNothing);
    expect(_overlayRegions(tester), isNotEmpty);

    final SemanticsHandle semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byKey(recorderLeaveKey)),
      isSemantics(label: 'Leave', isButton: true),
    );
    semantics.dispose();

    await tester.tap(find.byKey(recorderLeaveKey));
    expect(leaves, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the voice stage keeps the question, centre and actions apart', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.android, const Size(360, 640));
    await tester.pumpWidget(
      _app(
        TargetPlatform.android,
        _surface(question: const SizedBox(key: _questionKey, height: 400)),
      ),
    );

    final Rect question = tester.getRect(find.byKey(_questionKey));
    final Rect centre = tester.getRect(find.byKey(_centreKey));
    final Rect status = tester.getRect(find.byKey(_statusKey));
    final Rect actions = tester.getRect(find.byKey(_actionsKey));
    expect(question.bottom, lessThanOrEqualTo(centre.top + 0.5));
    expect(status.top, greaterThanOrEqualTo(centre.bottom - 0.5));
    expect(actions.top, greaterThanOrEqualTo(status.bottom));
    expect(actions.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the video stage places its status directly above the actions', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS, const Size(1280, 800));
    await tester.pumpWidget(
      _app(
        TargetPlatform.macOS,
        _surface(arrangement: RecorderArrangement.video),
      ),
    );

    final Rect status = tester.getRect(find.byKey(_statusKey));
    final Rect actions = tester.getRect(find.byKey(_actionsKey));
    final Rect centre = tester.getRect(find.byKey(_centreKey));
    expect(status.bottom, lessThanOrEqualTo(actions.top));
    expect(actions.top - status.bottom, lessThan(48));
    expect(centre.bottom, lessThanOrEqualTo(status.top));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the breathing glow swells, settles and holds still at rest', (
    WidgetTester tester,
  ) async {
    _useWindow(tester, TargetPlatform.macOS, const Size(1280, 800));
    await tester.pumpWidget(
      _glow(still: false, mode: BreathingGlowMode.breathe),
    );
    expect(_glowScales(tester)[0], closeTo(0.8, 0.001));
    expect(_glowScales(tester)[1], closeTo(1.12, 0.001));
    await tester.pump(const Duration(seconds: 5));
    expect(_glowScales(tester)[0], closeTo(1.12, 0.001));
    expect(_glowOpacities(tester)[0], closeTo(0.95, 0.001));
    expect(_glowScales(tester)[1], closeTo(0.8, 0.001));

    await tester.pumpWidget(
      _glow(still: false, mode: BreathingGlowMode.settle),
    );
    expect(_glowScales(tester)[0], closeTo(0.55, 0.001));
    await tester.pump(const Duration(milliseconds: 1920));
    expect(_glowScales(tester)[0], closeTo(1.14, 0.001));
    await tester.pump(const Duration(milliseconds: 2080));
    expect(_glowScales(tester)[0], closeTo(0.82, 0.001));
    expect(_glowOpacities(tester)[0], closeTo(0.35, 0.001));

    await tester.pumpWidget(
      _glow(still: true, mode: BreathingGlowMode.breathe),
    );
    final List<double> restingScales = _glowScales(tester);
    final List<double> restingOpacities = _glowOpacities(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(_glowScales(tester), restingScales);
    expect(_glowOpacities(tester), restingOpacities);
    expect(restingScales.first, closeTo(0.8, 0.001));
    expect(restingOpacities.first, closeTo(0.35, 0.001));
    expect(tester.hasRunningAnimations, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
