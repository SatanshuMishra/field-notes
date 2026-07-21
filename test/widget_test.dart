import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';

import 'app/support/app_shell_harness.dart';

void main() {
  testWidgets('boots into the adaptive shell on the Today destination',
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

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(BottomBarShell), findsOneWidget);
    expect(
      find.byKey(const ValueKey<ShellDestination>(ShellDestination.today)),
      findsOneWidget,
    );
  });
}
