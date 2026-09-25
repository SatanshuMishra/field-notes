import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';

void main() {
  testWidgets('the more menu opens above the keyboard', (
    WidgetTester tester,
  ) async {
    const Size surface = Size(411, 869);
    const double keyboardInset = 300;
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboardInset);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DialogHost(
          child: ComposerShell(
            child: TextComposerSheet(onSave: (String _) {}, onCancel: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(formatMoreKey));
    await tester.pump();

    expect(find.byKey(formatCodeKey), findsOneWidget);
    expect(
      tester.getRect(find.byKey(formatCodeKey)).bottom,
      lessThanOrEqualTo(surface.height - keyboardInset),
    );
  });
}
