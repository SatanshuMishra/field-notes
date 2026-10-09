import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/shell/windows_caption_buttons.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _useWindows(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(windowChannel, (MethodCall call) async => null);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, null),
  );
}

Future<void> _onWindows(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Widget _framedApp(ValueListenable<int> darkSurfaces) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: fieldNotesTheme(platform: TargetPlatform.windows),
    builder: (BuildContext context, Widget? child) =>
        WindowsWindowFrame(child: child!),
    home: ValueListenableBuilder<int>(
      valueListenable: darkSurfaces,
      builder: (BuildContext context, int count, Widget? _) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            for (int surface = 0; surface < count; surface++)
              const DarkCaptionSurface(
                child: ColoredBox(
                  color: Palette.mediaGround,
                  child: SizedBox.expand(),
                ),
              ),
          ],
        );
      },
    ),
  );
}

Future<void> _settleSurfaces(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Color _ink(WidgetTester tester) {
  final BuildContext buttons = tester.element(
    find.byType(WindowsCaptionButtons),
  );
  expect(Theme.of(buttons).brightness, Brightness.light);
  return buttons.colors.ink;
}

void _expectGlyphs(WidgetTester tester, Color color) {
  final List<WindowsCaptionGlyph> glyphs = tester
      .widgetList<WindowsCaptionGlyph>(find.byType(WindowsCaptionGlyph))
      .toList();
  expect(glyphs, hasLength(3));
  for (final WindowsCaptionGlyph glyph in glyphs) {
    expect(glyph.color.toARGB32(), color.toARGB32());
  }
}

Color _fill(WidgetTester tester, Key button) {
  return tester
      .widget<ColoredBox>(
        find.descendant(
          of: find.byKey(button),
          matching: find.byType(ColoredBox),
        ),
      )
      .color;
}

void main() {
  testWidgets('the caption glyphs turn light over a dark full-window surface', (
    WidgetTester tester,
  ) async {
    _useWindows(tester);
    final ValueNotifier<int> darkSurfaces = ValueNotifier<int>(0);
    addTearDown(darkSurfaces.dispose);

    await _onWindows(() async {
      await tester.pumpWidget(_framedApp(darkSurfaces));
      await tester.pump();

      final Color ink = _ink(tester);
      expect(ink.toARGB32(), FieldNotesColors.light.ink.toARGB32());
      _expectGlyphs(tester, ink);

      darkSurfaces.value = 1;
      await _settleSurfaces(tester);

      _expectGlyphs(tester, Palette.mediaInk);

      darkSurfaces.value = 0;
      await _settleSurfaces(tester);

      _expectGlyphs(tester, ink);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets(
    'the glyphs stay light until the last dark surface closes and hover darkly',
    (WidgetTester tester) async {
      _useWindows(tester);
      final ValueNotifier<int> darkSurfaces = ValueNotifier<int>(2);
      addTearDown(darkSurfaces.dispose);

      await _onWindows(() async {
        await tester.pumpWidget(_framedApp(darkSurfaces));
        await _settleSurfaces(tester);

        _expectGlyphs(tester, Palette.mediaInk);

        final TestGesture mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(640, 400));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(
          tester.getCenter(find.byKey(windowsMinimizeButtonKey)),
        );
        await tester.pump();

        expect(
          _fill(tester, windowsMinimizeButtonKey).toARGB32(),
          const Color(0xFFFFFFFF).withValues(alpha: 0.0605).toARGB32(),
        );

        await mouse.moveTo(tester.getCenter(find.byKey(windowsCloseButtonKey)));
        await tester.pump();

        expect(_fill(tester, windowsCloseButtonKey).toARGB32(), 0xFFC42B1C);
        expect(
          tester
              .widget<WindowsCaptionGlyph>(
                find.descendant(
                  of: find.byKey(windowsCloseButtonKey),
                  matching: find.byType(WindowsCaptionGlyph),
                ),
              )
              .color
              .toARGB32(),
          0xFFFFFFFF,
        );

        await mouse.moveTo(const Offset(640, 400));
        darkSurfaces.value = 1;
        await _settleSurfaces(tester);

        _expectGlyphs(tester, Palette.mediaInk);

        darkSurfaces.value = 0;
        await _settleSurfaces(tester);

        _expectGlyphs(tester, _ink(tester));
        await mouse.moveTo(
          tester.getCenter(find.byKey(windowsMinimizeButtonKey)),
        );
        await tester.pump();

        expect(
          _fill(tester, windowsMinimizeButtonKey).toARGB32(),
          const Color(0xFF000000).withValues(alpha: 0.0373).toARGB32(),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets('a surface that turns light hands the glyphs back to the theme', (
    WidgetTester tester,
  ) async {
    _useWindows(tester);
    final ValueNotifier<bool> dark = ValueNotifier<bool>(false);
    addTearDown(dark.dispose);

    await _onWindows(() async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.windows),
          builder: (BuildContext context, Widget? child) =>
              WindowsWindowFrame(child: child!),
          home: ValueListenableBuilder<bool>(
            valueListenable: dark,
            builder: (BuildContext context, bool value, Widget? _) =>
                DarkCaptionSurface(dark: value, child: const SizedBox.expand()),
          ),
        ),
      );
      await _settleSurfaces(tester);

      final Color ink = _ink(tester);
      _expectGlyphs(tester, ink);

      dark.value = true;
      await _settleSurfaces(tester);

      _expectGlyphs(tester, Palette.mediaInk);

      dark.value = false;
      await _settleSurfaces(tester);

      _expectGlyphs(tester, ink);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('a dark surface with no Windows frame above it changes nothing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const DarkCaptionSurface(child: SizedBox.expand()),
      ),
    );
    await tester.pump();

    expect(find.byType(DarkCaptionSurface), findsOneWidget);
    expect(find.byType(WindowsCaptionButtons), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
