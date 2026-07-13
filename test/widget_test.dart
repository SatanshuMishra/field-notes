import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/app.dart';
import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';

void main() {
  testWidgets('boots into the adaptive shell on the Today destination',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FieldNotesApp()));
    await tester.pump();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(BottomBarShell), findsOneWidget);
    expect(
      find.byKey(const ValueKey<ShellDestination>(ShellDestination.today)),
      findsOneWidget,
    );
  });
}
