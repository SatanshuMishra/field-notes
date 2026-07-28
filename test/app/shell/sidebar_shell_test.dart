import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';

import '../app_harness.dart';

SidebarShell _shell({
  ShellDestination selected = ShellDestination.today,
  ValueChanged<ShellDestination>? onSelect,
  VoidCallback? onSound,
}) {
  return SidebarShell(
    destinations: ShellDestination.primary,
    selected: selected,
    onSelect: onSelect ?? (_) {},
    onSound: onSound ?? () {},
    streak: const SizedBox.shrink(),
    body: const SizedBox.shrink(),
  );
}

void main() {
  group('SidebarShell', () {
    testWidgets('renders the traffic lights and every rail destination',
        (WidgetTester tester) async {
      await tester.pumpWidget(appHarness(_shell()));

      expect(find.byKey(const ValueKey<String>('traffic-lights')),
          findsOneWidget);
      for (final ShellDestination d in ShellDestination.primary) {
        expect(find.byKey(ValueKey<String>('rail-${d.name}')), findsOneWidget);
      }
    });

    testWidgets('the title bar shows the window caption',
        (WidgetTester tester) async {
      await tester.pumpWidget(appHarness(_shell()));

      expect(find.text('field notes — a journal of days'), findsOneWidget);
    });

    testWidgets('a rail item reports its destination on tap',
        (WidgetTester tester) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(_shell(onSelect: (ShellDestination d) => picked = d)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('rail-garden')));
      expect(picked, ShellDestination.garden);
    });

    testWidgets('the settings button selects the settings destination',
        (WidgetTester tester) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(_shell(onSelect: (ShellDestination d) => picked = d)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('settings-button')));
      expect(picked, ShellDestination.settings);
    });

    testWidgets('the sound button invokes onSound',
        (WidgetTester tester) async {
      bool sounded = false;
      await tester.pumpWidget(
        appHarness(_shell(onSound: () => sounded = true)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('sound-button')));
      expect(sounded, isTrue);
    });
  });
}
