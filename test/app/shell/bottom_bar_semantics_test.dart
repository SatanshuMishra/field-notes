import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';

import '../app_harness.dart';

BottomBarShell _shell({
  ShellDestination selected = ShellDestination.today,
  ValueChanged<ShellDestination>? onSelect,
  VoidCallback? onCapture,
}) {
  return BottomBarShell(
    destinations: ShellDestination.primary,
    selected: selected,
    onSelect: onSelect ?? (_) {},
    onCapture: onCapture ?? () {},
    body: const SizedBox.shrink(),
  );
}

void main() {
  group('BottomBarShell semantics', () {
    testWidgets('the gear and capture buttons are labelled',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        appHarness(_shell(), platform: TargetPlatform.android),
      );

      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      expect(find.bySemanticsLabel('New entry'), findsOneWidget);
      handle.dispose();
    });
  });
}
