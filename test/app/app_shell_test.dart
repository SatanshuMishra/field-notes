import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';

import 'app_harness.dart';

Finder _body(ShellDestination d) =>
    find.byKey(ValueKey<ShellDestination>(d));

void main() {
  group('AppShell on macOS', () {
    testWidgets('mounts the sidebar shell on the Today destination',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        appHarness(const AppShell(), platform: TargetPlatform.macOS),
      );

      expect(find.byType(SidebarShell), findsOneWidget);
      expect(find.byType(BottomBarShell), findsNothing);
      expect(_body(ShellDestination.today), findsOneWidget);
    });

    testWidgets('selecting a rail item swaps the body',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        appHarness(const AppShell(), platform: TargetPlatform.macOS),
      );

      await tester.tap(find.byKey(const ValueKey<String>('rail-calendar')));
      await tester.pumpAndSettle();

      expect(_body(ShellDestination.calendar), findsOneWidget);
      expect(_body(ShellDestination.today), findsNothing);
    });

    testWidgets('the settings button opens the settings body',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        appHarness(const AppShell(), platform: TargetPlatform.macOS),
      );

      await tester.tap(find.byKey(const ValueKey<String>('settings-button')));
      await tester.pumpAndSettle();

      expect(_body(ShellDestination.settings), findsOneWidget);
    });
  });

  group('AppShell on Android', () {
    testWidgets('mounts the bottom bar shell on the Today destination',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        appHarness(const AppShell(), platform: TargetPlatform.android),
      );

      expect(find.byType(BottomBarShell), findsOneWidget);
      expect(find.byType(SidebarShell), findsNothing);
      expect(_body(ShellDestination.today), findsOneWidget);
    });

    testWidgets('selecting a tab swaps the body',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        appHarness(const AppShell(), platform: TargetPlatform.android),
      );

      await tester.tap(find.byKey(const ValueKey<String>('tab-garden')));
      await tester.pumpAndSettle();

      expect(_body(ShellDestination.garden), findsOneWidget);
      expect(_body(ShellDestination.today), findsNothing);
    });

    testWidgets('the center capture invokes the injected callback',
        (WidgetTester tester) async {
      int captures = 0;
      await tester.pumpWidget(
        appHarness(
          AppShell(onCapturePressed: () => captures++),
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('capture-button')));
      expect(captures, 1);
    });

    testWidgets('the gear opens the settings body',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        appHarness(const AppShell(), platform: TargetPlatform.android),
      );

      await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
      await tester.pumpAndSettle();

      expect(_body(ShellDestination.settings), findsOneWidget);
    });
  });
}
