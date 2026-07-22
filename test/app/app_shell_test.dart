import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/search/search.dart';
import 'package:field_notes/features/settings/settings.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/today/today.dart';

import 'support/app_shell_harness.dart';

Finder _body(ShellDestination d) => find.byKey(ValueKey<ShellDestination>(d));

const Size _phoneSurface = Size(440, 900);

void main() {
  group('AppShell on macOS', () {
    testWidgets('mounts the sidebar shell with the Today screen',
        (WidgetTester tester) async {
      await pumpShell(tester, const AppShell());

      expect(find.byType(SidebarShell), findsOneWidget);
      expect(find.byType(BottomBarShell), findsNothing);
      expect(_body(ShellDestination.today), findsOneWidget);
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('selecting the calendar rail renders the calendar screen',
        (WidgetTester tester) async {
      await pumpShell(tester, const AppShell());

      await tester.tap(find.byKey(const ValueKey<String>('rail-calendar')));
      await tester.pump();

      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
    });

    testWidgets('selecting the garden rail renders the garden screen',
        (WidgetTester tester) async {
      await pumpShell(tester, const AppShell());

      await tester.tap(find.byKey(const ValueKey<String>('rail-garden')));
      await tester.pump();

      expect(find.byType(GardenScreen), findsOneWidget);
    });

    testWidgets('selecting the search rail renders the search screen',
        (WidgetTester tester) async {
      await pumpShell(tester, const AppShell());

      await tester.tap(find.byKey(const ValueKey<String>('rail-search')));
      await tester.pump();

      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('the settings button renders the settings screen',
        (WidgetTester tester) async {
      await pumpShell(tester, const AppShell());

      await tester.tap(find.byKey(const ValueKey<String>('settings-button')));
      await tester.pump();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('surfaces the real streak card in the rail',
        (WidgetTester tester) async {
      await pumpShell(tester, const AppShell());

      expect(find.byType(StreakCard), findsOneWidget);
      expect(find.text('0 days'), findsOneWidget);
    });
  });

  group('AppShell on Android', () {
    testWidgets('mounts the bottom bar shell with the Today screen',
        (WidgetTester tester) async {
      await pumpShell(
        tester,
        const AppShell(),
        platform: TargetPlatform.android,
        surface: _phoneSurface,
      );

      expect(find.byType(BottomBarShell), findsOneWidget);
      expect(find.byType(SidebarShell), findsNothing);
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('selecting the garden tab renders the garden screen',
        (WidgetTester tester) async {
      await pumpShell(
        tester,
        const AppShell(),
        platform: TargetPlatform.android,
        surface: _phoneSurface,
      );

      await tester.tap(find.byKey(const ValueKey<String>('tab-garden')));
      await tester.pump();

      expect(find.byType(GardenScreen), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
    });

    testWidgets('selecting the search tab renders the search screen',
        (WidgetTester tester) async {
      await pumpShell(
        tester,
        const AppShell(),
        platform: TargetPlatform.android,
        surface: _phoneSurface,
      );

      await tester.tap(find.byKey(const ValueKey<String>('tab-search')));
      await tester.pump();

      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('the gear renders the settings screen',
        (WidgetTester tester) async {
      await pumpShell(
        tester,
        const AppShell(),
        platform: TargetPlatform.android,
        surface: _phoneSurface,
      );

      await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
      await tester.pump();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('the center capture invokes the injected callback',
        (WidgetTester tester) async {
      int captures = 0;
      await pumpShell(
        tester,
        AppShell(onCapturePressed: () => captures++),
        platform: TargetPlatform.android,
        surface: _phoneSurface,
      );

      await tester.tap(find.byKey(const ValueKey<String>('capture-button')));
      expect(captures, 1);
    });
  });
}
