import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/features/streak/streak.dart';

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
    testWidgets('the gear, capture and streak are labelled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streakSummaryProvider.overrideWithValue(
              const StreakSummary(current: 5, longest: 5),
            ),
          ],
          child: appHarness(_shell(), platform: TargetPlatform.android),
        ),
      );

      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      expect(find.bySemanticsLabel('New entry'), findsOneWidget);
      expect(find.bySemanticsLabel('5 days in a row'), findsOneWidget);
      handle.dispose();
    });
  });
}
