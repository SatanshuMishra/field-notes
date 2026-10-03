import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/art/art.dart';
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
  Widget child = const SizedBox(key: _content, height: 200),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: platform == null ? null : ThemeData(platform: platform),
      home: ComposerShell(
        responsive: responsive,
        child: child,
      ),
    ),
  );
}

double _panelWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(composerPanelKey)).width;

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

void main() {
  testWidgets('the sprig paints beneath the composer content',
      (WidgetTester tester) async {
    await _pumpShell(tester, window: const Size(1280, 900));

    final Stack stack = tester.widget<Stack>(
      find
          .descendant(
            of: find.byKey(composerPanelKey),
            matching: find.byType(Stack),
          )
          .first,
    );
    final int sprig = stack.children.indexWhere(
      (Widget child) =>
          find
              .descendant(
                of: find.byWidget(child),
                matching: find.byType(SprigArt),
              )
              .evaluate()
              .isNotEmpty,
    );
    final int content =
        stack.children.indexWhere((Widget child) => child.key == _content);

    expect(sprig, isNonNegative);
    expect(content, isNonNegative);
    expect(sprig, lessThan(content));
  });

  for (final ({double window, double panel}) size
      in <({double window, double panel})>[
    (window: 900, panel: 640),
    (window: 1280, panel: 768),
    (window: 1920, panel: 1000),
    (window: 390, panel: 390),
  ]) {
    testWidgets(
        'a responsive panel is ${size.panel} wide in a ${size.window} window',
        (WidgetTester tester) async {
      await _pumpShell(
        tester,
        window: Size(size.window, 900),
        responsive: true,
        platform: TargetPlatform.macOS,
      );

      expect(_panelWidth(tester), size.panel);
    });
  }

  testWidgets('a fixed panel stays 640 wide in a wide window',
      (WidgetTester tester) async {
    await _pumpShell(tester, window: const Size(1920, 900));

    expect(_panelWidth(tester), composerPanelWidth);
  });

  testWidgets('a responsive panel on the phone fills the screen edge to edge',
      (WidgetTester tester) async {
    _usePhoneInsets(tester);
    await _pumpShell(
      tester,
      window: _phone,
      responsive: true,
      platform: TargetPlatform.android,
      child: const SizedBox.expand(key: _content),
    );

    expect(tester.getRect(find.byKey(composerPanelKey)), Offset.zero & _phone);
    expect(
      tester.getRect(find.byKey(_content)),
      Rect.fromLTRB(0, _statusBar, _phone.width, _phone.height - _gestureBar),
    );
    final BoxDecoration paper = tester
        .widget<Container>(find.byKey(composerPanelKey))
        .decoration! as BoxDecoration;
    expect(paper.border, isNull);
    expect(paper.borderRadius, isNull);
    expect(
      paper.color?.toARGB32(),
      FieldNotesColors.light.composerPaper.toARGB32(),
    );
    expect(
      find.descendant(
        of: find.byType(ComposerShell),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });

  testWidgets('a responsive phone panel ends at the top of the keyboard',
      (WidgetTester tester) async {
    _usePhoneInsets(tester, keyboard: 300);
    await _pumpShell(
      tester,
      window: _phone,
      responsive: true,
      platform: TargetPlatform.android,
      child: const SizedBox.expand(key: _content),
    );

    expect(
      tester.getRect(find.byKey(_content)),
      Rect.fromLTRB(0, _statusBar, _phone.width, _phone.height - 300),
    );
    expect(
      MediaQuery.viewInsetsOf(tester.element(find.byKey(_content))).bottom,
      0,
    );
  });

  testWidgets('a fixed panel stays a floating card on the phone',
      (WidgetTester tester) async {
    _usePhoneInsets(tester);
    await _pumpShell(
      tester,
      window: _phone,
      platform: TargetPlatform.android,
    );

    final Rect panel = tester.getRect(find.byKey(composerPanelKey));
    expect(panel.top, greaterThan(_statusBar));
    final BoxDecoration card = tester
        .widget<Container>(find.byKey(composerPanelKey))
        .decoration! as BoxDecoration;
    expect(card.border, isNotNull);
    expect(card.borderRadius, isNotNull);
  });
}
