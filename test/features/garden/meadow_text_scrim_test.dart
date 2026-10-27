import 'dart:ui' as ui;

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show shellOverrides;

const double _textContrast = 4.5;
const Color _pureWhite = Color(0xFFFFFFFF);
const Color _pureBlack = Color(0xFF000000);
const Size _phoneSize = Size(1080, 2280);
const double _phoneRatio = 2.625;
const double _ringGap = 2;
const int _growFrames = 6000;

final DateTime _noon = DateTime.utc(2026, 9, 28, 18);
final DateTime _midnight = DateTime.utc(2026, 9, 29, 6);
final DateTime _today = DateTime(2026, 9, 28, 9, 30);

typedef _InkOnScrim = ({String text, Color ink, List<Color> scrims});

final List<_InkOnScrim> _inksOnScrims = <_InkOnScrim>[
  (
    text: 'the Meadow header title',
    ink: meadowCream,
    scrims: <Color>[meadowTextScrim],
  ),
  (
    text: 'the Meadow header kicker',
    ink: meadowKickerInk,
    scrims: <Color>[meadowTextScrim],
  ),
  (
    text: 'the Meadow header summary',
    ink: meadowCreamAt(0.88),
    scrims: <Color>[meadowTextScrim],
  ),
  (
    text: 'the compact Meadow header summary',
    ink: meadowCreamAt(0.9),
    scrims: <Color>[meadowTextScrim],
  ),
  (
    text: 'the growing your meadow status',
    ink: meadowTextInk,
    scrims: <Color>[meadowTextScrim],
  ),
  (
    text: 'a bottom bar label over the scene',
    ink: phoneBottomBarSceneInk,
    scrims: <Color>[phoneBottomBarSceneTint],
  ),
  (
    text: 'the selected bottom bar label over the scene in light',
    ink: FieldNotesColors.light.accentTint,
    scrims: <Color>[phoneBottomBarSceneTint, phoneBottomBarScenePill],
  ),
  (
    text: 'the selected bottom bar label over the scene in dark',
    ink: FieldNotesColors.dark.accentTint,
    scrims: <Color>[phoneBottomBarSceneTint, phoneBottomBarScenePill],
  ),
];

double _contrast(Color a, Color b) {
  final double first = a.computeLuminance();
  final double second = b.computeLuminance();
  return first > second
      ? (first + 0.05) / (second + 0.05)
      : (second + 0.05) / (first + 0.05);
}

Color _composite(List<Color> layers, Color frame) => layers.fold(
  frame,
  (Color ground, Color layer) => Color.alphaBlend(layer, ground),
);

typedef _Scene = ({String name, DateTime instant, Brightness brightness});

final List<_Scene> _scenes = <_Scene>[
  (name: 'noon in light', instant: _noon, brightness: Brightness.light),
  (name: 'midnight in dark', instant: _midnight, brightness: Brightness.dark),
];

final Finder _sceneBar = find.byWidgetPredicate(
  (Widget widget) => widget is PhoneBottomBar && widget.overScene,
);

const List<String> _barLabels = <String>[
  'Today',
  'Calendar',
  'Meadow',
  'Search',
];

final class _Frame {
  const _Frame({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final ByteData bytes;

  Color? at(Offset logical) {
    final int x = logical.dx.floor();
    final int y = logical.dy.floor();
    if (x < 0 || y < 0 || x >= width || y >= height) {
      return null;
    }
    final int offset = (y * width + x) * 4;
    return Color.fromARGB(
      0xFF,
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
  }
}

Future<_Frame> _captureView(WidgetTester tester) async {
  final RenderView view = tester.binding.renderViews.first;
  final OffsetLayer layer = view.debugLayer! as OffsetLayer;
  final double ratio = view.flutterView.devicePixelRatio;
  final _Frame? frame = await tester.binding.runAsync(() async {
    final ui.Image image = await layer.toImage(
      Offset.zero & (view.size * ratio),
      pixelRatio: 1 / ratio,
    );
    try {
      final ByteData? bytes = await image.toByteData();
      return _Frame(width: image.width, height: image.height, bytes: bytes!);
    } finally {
      image.dispose();
    }
  });
  return frame!;
}

Iterable<Offset> _ringAround(Rect rect) sync* {
  final Rect ring = rect.inflate(_ringGap);
  for (double x = ring.left; x <= ring.right; x += 1) {
    yield Offset(x, ring.top);
    yield Offset(x, ring.bottom);
  }
  for (double y = ring.top; y <= ring.bottom; y += 1) {
    yield Offset(ring.left, y);
    yield Offset(ring.right, y);
  }
}

Color _inkOf(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(text).text.style?.color ?? _pureBlack;

double _contrastAround(WidgetTester tester, _Frame frame, Finder text) {
  final Color ink = _inkOf(tester, text);
  final List<double> readings = <double>[
    for (final Offset point in _ringAround(tester.getRect(text)))
      if (frame.at(point) case final Color ground)
        _contrast(Color.alphaBlend(ink, ground), ground),
  ]..sort();
  return readings[readings.length ~/ 2];
}

Future<void> _pumpMeadowTab(WidgetTester tester, _Scene scene) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = _phoneRatio;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.platformBrightnessTestValue = scene.brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(
    ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        ...shellOverrides(),
        todayClockProvider.overrideWithValue(() => _today),
        streakClockProvider.overrideWithValue(() => _today),
        skyClockProvider.overrideWithValue(() => scene.instant),
        skyLocationProvider.overrideWith(
          (Ref ref) async =>
              resolveSkyLocation('America/Edmonton', const Duration(hours: -6)),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(
          platform: TargetPlatform.android,
          brightness: scene.brightness,
        ),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('tab-garden')));
  await tester.pump();
}

bool _meadowReady(WidgetTester tester) {
  final Finder stage = find.byType(MeadowStage);
  return stage.evaluate().isNotEmpty &&
      tester.state<MeadowStageState>(stage).debugIsReady;
}

Future<void> _plantStage(WidgetTester tester) async {
  final Finder stage = find.byType(MeadowStage);
  for (int i = 0; i < _growFrames && stage.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
    await tester.pump();
  }
  expect(stage, findsOneWidget, reason: 'the Meadow stage never showed');
}

Future<void> _growMeadow(WidgetTester tester) async {
  for (int i = 0; i < _growFrames && !_meadowReady(tester); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 1));
  }
  expect(_meadowReady(tester), isTrue, reason: 'the Meadow never grew');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _barLabel(String label) =>
    find.descendant(of: _sceneBar, matching: find.text(label));

void main() {
  test('meadow text reads over a scrim on any scene', () {
    for (final _InkOnScrim pair in _inksOnScrims) {
      for (final Color frame in <Color>[_pureWhite, _pureBlack]) {
        final Color ground = _composite(pair.scrims, frame);
        final Color shown = Color.alphaBlend(pair.ink, ground);
        expect(
          _contrast(shown, ground),
          greaterThanOrEqualTo(_textContrast),
          reason: '${pair.text} over $frame',
        );
      }
    }
  });

  testWidgets('meadow text reads in the brightest and darkest scenes', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      for (final _Scene scene in _scenes) {
        await _pumpMeadowTab(tester, scene);
        await _plantStage(tester);
        final Finder growing = find.descendant(
          of: find.byType(MeadowStage),
          matching: find.text(meadowLoadingMessage),
        );
        expect(growing, findsOneWidget, reason: scene.name);
        final _Frame growingFrame = await _captureView(tester);
        expect(
          _contrastAround(tester, growingFrame, growing),
          greaterThanOrEqualTo(_textContrast),
          reason: 'the growing status at ${scene.name}',
        );

        await _growMeadow(tester);
        final _Frame frame = await _captureView(tester);
        final Map<String, Finder> texts = <String, Finder>{
          'the header kicker': find.text('your meadow'),
          'the header title': find.text('Every day, a bloom'),
          'the header summary': find.textContaining('so far in'),
          for (final String label in _barLabels)
            'the $label bar label': _barLabel(label),
        };
        for (final MapEntry<String, Finder> text in texts.entries) {
          expect(text.value, findsOneWidget, reason: text.key);
          expect(
            _contrastAround(tester, frame, text.value),
            greaterThanOrEqualTo(_textContrast),
            reason: '${text.key} at ${scene.name}',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
