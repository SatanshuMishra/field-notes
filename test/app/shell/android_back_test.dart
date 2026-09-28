import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/state/shell_navigation.dart';

import '../support/app_shell_harness.dart';

const Size _phoneSurface = Size(440, 900);

Future<void> _pumpAndroidShell(WidgetTester tester) => pumpShell(
      tester,
      const AppShell(),
      platform: TargetPlatform.android,
      surface: _phoneSurface,
    );

ShellDestination _selected(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppShell)))
        .read(shellNavigationProvider);

List<String> _recordPlatformCalls(WidgetTester tester) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      calls.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return calls;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey<String>(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('Android back in the bottom-bar shell', () {
    testWidgets('back on calendar returns to today',
        (WidgetTester tester) async {
      await _pumpAndroidShell(tester);
      final List<String> calls = _recordPlatformCalls(tester);

      await _tapKey(tester, 'tab-calendar');
      expect(_selected(tester), ShellDestination.calendar);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(_selected(tester), ShellDestination.today);
      expect(calls, isNot(contains('SystemNavigator.pop')));
    });

    testWidgets('back on garden returns to today',
        (WidgetTester tester) async {
      await _pumpAndroidShell(tester);

      await _tapKey(tester, 'tab-garden');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(_selected(tester), ShellDestination.today);
    });

    testWidgets('back on settings returns to the tab it was opened from',
        (WidgetTester tester) async {
      await _pumpAndroidShell(tester);
      final List<String> calls = _recordPlatformCalls(tester);

      await _tapKey(tester, 'tab-search');
      await _tapKey(tester, 'gear-button');
      expect(_selected(tester), ShellDestination.settings);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(_selected(tester), ShellDestination.search);
      expect(calls, isNot(contains('SystemNavigator.pop')));
    });

    testWidgets('back on settings opened from today returns to today',
        (WidgetTester tester) async {
      await _pumpAndroidShell(tester);

      await _tapKey(tester, 'gear-button');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_selected(tester), ShellDestination.today);
    });

    testWidgets('back on today leaves the app', (WidgetTester tester) async {
      await _pumpAndroidShell(tester);
      final List<String> calls = _recordPlatformCalls(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(calls, contains('SystemNavigator.pop'));
    });
  });
}
