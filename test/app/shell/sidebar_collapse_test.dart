import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/appearance_toggle.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/settings/support/fake_settings_repository.dart';
import '../support/app_shell_harness.dart';

const Key _rail = ValueKey<String>('sidebar-rail');
const Key _toggle = ValueKey<String>('sidebar-toggle');
const Key _settingsButton = ValueKey<String>('settings-button');
const Key _soundButton = ValueKey<String>('sound-button');

const String _collapseLabel = 'Collapse sidebar (⌘\\)';
const String _expandLabel = 'Expand sidebar (⌘\\)';

void _holdStill(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<FakeSettingsRepository> _pumpMac(
  WidgetTester tester, {
  bool collapsed = false,
}) async {
  final FakeSettingsRepository settings = FakeSettingsRepository(
    initial: AppSettings.defaults.copyWith(sidebarCollapsed: collapsed),
  );
  tester.view.physicalSize = const Size(1280, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (override.origin != settingsRepositoryProvider) override,
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

double _railWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(_rail)).width;

Finder _item(ShellDestination d) =>
    find.byKey(ValueKey<String>('rail-${d.name}'));

String _tooltipAbove(WidgetTester tester, Finder finder) => tester
    .widget<Tooltip>(
      find.ancestor(of: finder, matching: find.byType(Tooltip)).first,
    )
    .message!;

Future<void> _pressCommandBackslash(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.backslash);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
}

void _expectOpen(WidgetTester tester) {
  expect(_railWidth(tester), 176);
  for (final ShellDestination d in ShellDestination.primary) {
    expect(
      find.descendant(of: _item(d), matching: find.text(d.label)),
      findsOneWidget,
      reason: d.name,
    );
    expect(tester.getSize(_item(d)).height, 40, reason: d.name);
  }
  expect(find.text('field\nnotes'), findsOneWidget);
  expect(_tooltipAbove(tester, find.byKey(_toggle)), _collapseLabel);
  expect(
    tester.getSemantics(find.byKey(_toggle)),
    isSemantics(label: _collapseLabel, isButton: true, hasTapAction: true),
  );
  final Rect settings = tester.getRect(find.byKey(_settingsButton));
  final Rect sound = tester.getRect(find.byKey(_soundButton));
  expect(sound.top, settings.top);
  expect(sound.left - settings.right, 8);
  expect(
    find.descendant(of: find.byKey(_rail), matching: find.text('0 days')),
    findsOneWidget,
  );
}

void _expectCollapsed(WidgetTester tester) {
  expect(_railWidth(tester), 68);
  for (final ShellDestination d in ShellDestination.primary) {
    expect(
      find.descendant(of: _item(d), matching: find.text(d.label)),
      findsNothing,
      reason: d.name,
    );
    expect(_tooltipAbove(tester, _item(d)), d.label, reason: d.name);
    expect(
      tester.getSemantics(_item(d)),
      isSemantics(label: d.label, isButton: true, hasTapAction: true),
      reason: d.name,
    );
    expect(tester.getSize(_item(d)).height, 40, reason: d.name);
  }
  expect(find.text('field\nnotes'), findsNothing);
  expect(_tooltipAbove(tester, find.byKey(_toggle)), _expandLabel);
  expect(
    tester.getSemantics(find.byKey(_toggle)),
    isSemantics(label: _expandLabel, isButton: true, hasTapAction: true),
  );
  final Rect toggle = tester.getRect(find.byKey(_toggle));
  expect(toggle.size, const Size.square(26));
  expect(toggle.center.dx, moreOrLessEquals(68, epsilon: 0.01));
  final Rect settings = tester.getRect(find.byKey(_settingsButton));
  final Rect sound = tester.getRect(find.byKey(_soundButton));
  expect(sound.center.dx, settings.center.dx);
  expect(sound.top - settings.bottom, 8);
  expect(
    find.descendant(of: find.byKey(_rail), matching: find.text('0')),
    findsOneWidget,
  );
  expect(
    find.descendant(of: find.byKey(_rail), matching: find.text('0 days')),
    findsNothing,
  );
}

void main() {
  testWidgets(
    'the sidebar collapses to a 68-point rail and back with the edge button '
    'and Cmd-backslash',
    (WidgetTester tester) async {
      _holdStill(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final FakeSettingsRepository settings = await _pumpMac(tester);

      _expectOpen(tester);
      final Rect openToggle = tester.getRect(find.byKey(_toggle));
      expect(openToggle.size, const Size.square(26));
      expect(openToggle.right, 176 - 10);
      expect(
        openToggle.top - tester.getRect(find.byKey(_rail)).top,
        moreOrLessEquals(22, epsilon: 0.01),
      );

      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      final AnimatedContainer rail = tester.widget<AnimatedContainer>(
        find.byKey(_rail),
      );
      expect(rail.duration, const Duration(milliseconds: 250));
      expect(rail.curve, const Cubic(0.2, 0.8, 0.2, 1));
      await tester.pumpAndSettle();

      _expectCollapsed(tester);
      expect(settings.sidebarCollapsedWrites, <bool>[true]);

      await _pressCommandBackslash(tester);
      await tester.pumpAndSettle();

      _expectOpen(tester);
      expect(settings.sidebarCollapsedWrites, <bool>[true, false]);

      await _pressCommandBackslash(tester);
      await tester.pumpAndSettle();

      _expectCollapsed(tester);
      expect(settings.sidebarCollapsedWrites, <bool>[true, false, true]);
      expect(tester.takeException(), isNull);

      final FakeSettingsRepository restored = await _pumpMac(
        tester,
        collapsed: true,
      );
      _expectCollapsed(tester);
      expect(restored.sidebarCollapsedWrites, isEmpty);
      handle.dispose();
    },
  );

  testWidgets(
    'the sidebar shows the streak pill and no storage line or theme toggle',
    (WidgetTester tester) async {
      _holdStill(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpMac(tester);

      final Finder sidebar = find.byType(SidebarShell);
      expect(
        find.descendant(of: find.byKey(_rail), matching: find.text('0 days')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('0 days in a row'), findsOneWidget);
      final Rect streak = tester.getRect(
        find.descendant(of: find.byKey(_rail), matching: find.text('0 days')),
      );
      final Rect settingsButton = tester.getRect(find.byKey(_settingsButton));
      expect(streak.bottom, lessThan(settingsButton.top));
      expect(find.text('Stored locally'), findsNothing);
      expect(find.text('on this device only'), findsNothing);
      expect(
        find.descendant(of: sidebar, matching: find.byType(AppearanceToggle)),
        findsNothing,
      );
      expect(find.byKey(appearanceToggleKey), findsNothing);
      expect(find.bySemanticsLabel(appearanceToggleDarkLabel), findsNothing);
      expect(find.byKey(const ValueKey<String>('streak-card')), findsNothing);

      await tester.tap(find.byKey(_settingsButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(settingsTabKey(SettingsTab.syncStorage)));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your journal is stored only on this Mac'),
        findsOneWidget,
      );
      expect(find.byType(AppearanceToggle), findsNothing);
      handle.dispose();
    },
  );
}
