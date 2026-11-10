import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';

const Key _content = ValueKey<String>('composer-content');

const Size _phone = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size window,
  bool responsive = false,
  TargetPlatform? platform,
  Brightness brightness = Brightness.light,
  Widget child = const SizedBox(key: _content, height: 200),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      key: ValueKey<Brightness>(brightness),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        platform: platform,
        brightness: brightness,
        extensions: <ThemeExtension<dynamic>>[
          brightness == Brightness.dark
              ? FieldNotesColors.dark
              : FieldNotesColors.light,
        ],
      ),
      home: ComposerShell(responsive: responsive, child: child),
    ),
  );
}

void _usePhoneInsets(WidgetTester tester, {double keyboard = 0}) {
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
}

Color _roomColor(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(composerPanelKey)).color;

void main() {
  for (final Size window in <Size>[
    const Size(900, 900),
    const Size(1280, 900),
    const Size(1920, 1200),
  ]) {
    testWidgets('a responsive room fills a $window desktop window', (
      WidgetTester tester,
    ) async {
      await _pumpShell(
        tester,
        window: window,
        responsive: true,
        platform: TargetPlatform.macOS,
      );

      expect(
        tester.getRect(find.byKey(composerPanelKey)),
        Offset.zero & window,
      );
    });
  }

  testWidgets('a fixed panel stays 640 wide in a wide window', (
    WidgetTester tester,
  ) async {
    await _pumpShell(tester, window: const Size(1920, 900));

    expect(
      tester.getSize(find.byKey(composerPanelKey)).width,
      composerPanelWidth,
    );
  });

  testWidgets('a responsive room on the phone runs edge to edge in stage ink', (
    WidgetTester tester,
  ) async {
    _usePhoneInsets(tester);
    await _pumpShell(
      tester,
      window: _phone,
      responsive: true,
      platform: TargetPlatform.android,
      child: const SizedBox.expand(key: _content),
    );

    expect(tester.getRect(find.byKey(composerPanelKey)), Offset.zero & _phone);
    expect(tester.getRect(find.byKey(_content)), Offset.zero & _phone);
    expect(
      _roomColor(tester).toARGB32(),
      FieldNotesColors.light.viewerStage.toARGB32(),
    );
    expect(
      find.descendant(
        of: find.byType(ComposerShell),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });

  testWidgets('the room is paper in Light and dark in Dark', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      await _pumpShell(
        tester,
        window: const Size(1000, 800),
        responsive: true,
        platform: platform,
      );
      expect(
        _roomColor(tester).toARGB32(),
        FieldNotesColors.light.viewerStage.toARGB32(),
        reason: '$platform light',
      );

      await _pumpShell(
        tester,
        window: const Size(1000, 800),
        responsive: true,
        platform: platform,
        brightness: Brightness.dark,
      );
      expect(
        _roomColor(tester).toARGB32(),
        FieldNotesColors.dark.viewerStage.toARGB32(),
        reason: '$platform dark',
      );
    }
  });

  testWidgets('a responsive phone room hands the keyboard inset to its child', (
    WidgetTester tester,
  ) async {
    _usePhoneInsets(tester, keyboard: 300);
    await _pumpShell(
      tester,
      window: _phone,
      responsive: true,
      platform: TargetPlatform.android,
      child: const SizedBox.expand(key: _content),
    );

    expect(tester.getRect(find.byKey(_content)), Offset.zero & _phone);
    expect(
      MediaQuery.viewInsetsOf(tester.element(find.byKey(_content))).bottom,
      300,
    );
  });

  testWidgets('a desktop room reserves the title bar for its child', (
    WidgetTester tester,
  ) async {
    await _pumpShell(
      tester,
      window: const Size(1280, 900),
      responsive: true,
      platform: TargetPlatform.macOS,
      child: const SizedBox.expand(key: _content),
    );

    expect(find.byKey(composerTopBandKey), findsOneWidget);
    expect(
      MediaQuery.paddingOf(tester.element(find.byKey(_content))).top,
      greaterThan(0),
    );
  });

  testWidgets('a fixed panel stays a floating card on the phone', (
    WidgetTester tester,
  ) async {
    _usePhoneInsets(tester);
    await _pumpShell(tester, window: _phone, platform: TargetPlatform.android);

    final Rect panel = tester.getRect(find.byKey(composerPanelKey));
    expect(panel.top, greaterThan(_statusBar));
    final BoxDecoration card =
        tester.widget<Container>(find.byKey(composerPanelKey)).decoration!
            as BoxDecoration;
    expect(card.border, isNotNull);
    expect(card.borderRadius, isNotNull);
  });
}
