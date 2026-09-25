import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';

const Size _phoneSurface = Size(411, 869);
const double _statusBar = 24;
const double _keyboard = 336;

Future<void> _pumpComposer(
  WidgetTester tester, {
  required double keyboardInset,
}) async {
  tester.view.physicalSize = _phoneSurface;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: _statusBar);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DialogHost(
        child: ComposerShell(
          responsive: true,
          child: TextComposerSheet(
            onSave: (String _) {},
            onCancel: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the sheet stays below the status bar with the keyboard up', (
    WidgetTester tester,
  ) async {
    await _pumpComposer(tester, keyboardInset: _keyboard);

    final Rect panel = tester.getRect(find.byKey(composerPanelKey));
    expect(panel.top, greaterThanOrEqualTo(_statusBar));
    expect(
      tester.getRect(find.text('Cancel')).top,
      greaterThanOrEqualTo(_statusBar),
    );
    expect(panel.bottom, lessThanOrEqualTo(_phoneSurface.height - _keyboard));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet stays below the status bar with the keyboard down', (
    WidgetTester tester,
  ) async {
    await _pumpComposer(tester, keyboardInset: 0);

    expect(
      tester.getRect(find.byKey(composerPanelKey)).top,
      greaterThanOrEqualTo(_statusBar),
    );
    expect(tester.takeException(), isNull);
  });
}
