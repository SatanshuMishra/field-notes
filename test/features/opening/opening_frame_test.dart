import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/opening/opening_frame.dart';

const double _pixelRatio = 2;
const double _phoneTopPadding = 34;
const String _framesFolder = 'build/opening_frames';
const Key _boundaryKey = ValueKey<String>('opening-frame-boundary');

enum _Screen {
  phone(Size(384, 832), TargetPlatform.android),
  desktop(Size(1140, 726), TargetPlatform.macOS);

  const _Screen(this.size, this.platform);

  final Size size;
  final TargetPlatform platform;
}

Future<File> _render(
  WidgetTester tester, {
  required _Screen screen,
  required Brightness brightness,
  required double seconds,
  required String stage,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = screen.size * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  final FakeViewPadding padding = screen == _Screen.phone
      ? const FakeViewPadding(top: _phoneTopPadding * _pixelRatio)
      : FakeViewPadding.zero;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<String>(
        '${screen.name}-${brightness.name}-$disableAnimations',
      ),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: screen.platform, brightness: brightness),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: RepaintBoundary(
        key: _boundaryKey,
        child: OpeningFrame(seconds: seconds),
      ),
    ),
  );

  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  final Uint8List? png = await tester.runAsync<Uint8List?>(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: _pixelRatio);
    try {
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  if (png == null) {
    throw StateError('The $stage frame could not be encoded as PNG.');
  }
  final File file = File(
    '$_framesFolder/${screen.name}-${brightness.name}-$stage.png',
  );
  await tester.runAsync(() async {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png, flush: true);
  });
  return file;
}

Future<void> _renderAll(
  WidgetTester tester, {
  required double seconds,
  required String stage,
  bool disableAnimations = false,
}) async {
  for (final _Screen screen in _Screen.values) {
    for (final Brightness brightness in Brightness.values) {
      final File file = await _render(
        tester,
        screen: screen,
        brightness: brightness,
        seconds: seconds,
        stage: stage,
        disableAnimations: disableAnimations,
      );
      expect(file.existsSync(), isTrue, reason: file.path);
      final ui.ImmutableBuffer buffer = (await tester.runAsync(
        () => ui.ImmutableBuffer.fromUint8List(file.readAsBytesSync()),
      ))!;
      final ui.ImageDescriptor descriptor = (await tester.runAsync(
        () => ui.ImageDescriptor.encoded(buffer),
      ))!;
      expect(
        Size(descriptor.width.toDouble(), descriptor.height.toDouble()),
        screen.size * _pixelRatio,
        reason: file.path,
      );
      descriptor.dispose();
      buffer.dispose();
    }
  }
}

void main() {
  testWidgets('renders the pen drawing the petals', (
    WidgetTester tester,
  ) async {
    await _renderAll(tester, seconds: 0.34, stage: 'pen-head');
  });

  testWidgets('renders the pen drawing the leaves', (
    WidgetTester tester,
  ) async {
    await _renderAll(tester, seconds: 0.92, stage: 'pen-leaves');
  });

  testWidgets('renders the last colour washing in', (
    WidgetTester tester,
  ) async {
    await _renderAll(tester, seconds: 1.25, stage: 'washed');
  });

  testWidgets('renders the wind curling in', (WidgetTester tester) async {
    await _renderAll(tester, seconds: 1.45, stage: 'wind');
  });

  testWidgets('renders the pieces blowing away', (WidgetTester tester) async {
    await _renderAll(tester, seconds: 1.95, stage: 'blow');
  });

  testWidgets('renders the still drawing under reduce motion', (
    WidgetTester tester,
  ) async {
    await _renderAll(
      tester,
      seconds: 0.1,
      stage: 'still',
      disableAnimations: true,
    );
  });
}
