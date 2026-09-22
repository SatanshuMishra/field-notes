import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/art/art.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';

const Key _content = ValueKey<String>('composer-content');

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size window,
  bool responsive = false,
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ComposerShell(
        responsive: responsive,
        child: const SizedBox(key: _content, height: 200),
      ),
    ),
  );
}

double _panelWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(composerPanelKey)).width;

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
      );

      expect(_panelWidth(tester), size.panel);
    });
  }

  testWidgets('a fixed panel stays 640 wide in a wide window',
      (WidgetTester tester) async {
    await _pumpShell(tester, window: const Size(1920, 900));

    expect(_panelWidth(tester), composerPanelWidth);
  });
}
