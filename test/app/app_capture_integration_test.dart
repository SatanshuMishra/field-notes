import 'package:field_notes/app/app.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_shell_harness.dart';

void main() {
  testWidgets(
      'the shell capture button opens the chooser with every capture route',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: shellOverrides(),
        child: const FieldNotesApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('capture-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CaptureChooserSheet), findsOneWidget);
    expect(find.text('Write a note'), findsOneWidget);
    expect(find.text('Record voice'), findsOneWidget);
    expect(find.text('Record video'), findsOneWidget);
  });
}
