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
  group('BottomBarShell', () {
    testWidgets('renders four tabs and the center capture',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        appHarness(_shell(), platform: TargetPlatform.android),
      );

      for (final ShellDestination d in ShellDestination.primary) {
        expect(find.byKey(ValueKey<String>('tab-${d.name}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey<String>('capture-button')),
          findsOneWidget);
    });

    testWidgets('a tab reports its destination on tap',
        (WidgetTester tester) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(
          _shell(onSelect: (ShellDestination d) => picked = d),
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('tab-search')));
      expect(picked, ShellDestination.search);
    });

    testWidgets('the center capture invokes onCapture',
        (WidgetTester tester) async {
      int captures = 0;
      await tester.pumpWidget(
        appHarness(
          _shell(onCapture: () => captures++),
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('capture-button')));
      expect(captures, 1);
    });

    testWidgets('the gear selects the settings destination',
        (WidgetTester tester) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(
          _shell(onSelect: (ShellDestination d) => picked = d),
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
      expect(picked, ShellDestination.settings);
    });
  });
}
