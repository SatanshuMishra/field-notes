import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_shell_harness.dart';

const int _maxPresses = 90;

const String _lastSettingsControl = 'Delete all…';

Future<void> _selectDataTab(WidgetTester tester) async {
  await tester.tap(find.byKey(settingsTabKey(SettingsTab.data)));
  await tester.pumpAndSettle();
}

bool _inSettings(FocusNode node) =>
    node.context?.findAncestorWidgetOfExactType<SettingsScreen>() != null;

String _label(FocusNode node) {
  String label = '';
  node.context?.visitAncestorElements((Element element) {
    final Widget widget = element.widget;
    if (widget is Semantics && (widget.properties.label ?? '').isNotEmpty) {
      label = widget.properties.label!;
      return false;
    }
    return true;
  });
  return label;
}

void _holdStill(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void _useKeyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

final class _Stop {
  _Stop(this.node)
    : label = _label(node),
      inSettings = _inSettings(node),
      visible = _visible(node);

  final FocusNode node;
  final String label;
  final bool inSettings;
  final bool visible;

  String get name => '${inSettings ? 'page' : 'nav'}:$label';
}

bool _visible(FocusNode node) {
  final BuildContext? context = node.context;
  final RenderObject? viewport = context == null
      ? null
      : Scrollable.maybeOf(context)?.context.findRenderObject();
  if (viewport is! RenderBox) {
    return true;
  }
  final Rect bounds = MatrixUtils.transformRect(
    viewport.getTransformTo(null),
    Offset.zero & viewport.size,
  ).inflate(0.5);
  final Rect rect = node.rect;
  return bounds.contains(rect.topLeft) && bounds.contains(rect.bottomRight);
}

Future<_Stop> _tab(WidgetTester tester, {required bool backward}) async {
  if (backward) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (backward) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.pumpAndSettle();
  return _Stop(FocusManager.instance.primaryFocus!);
}

Future<List<List<_Stop>>> _laps(
  WidgetTester tester,
  int count, {
  bool backward = false,
}) async {
  final _Stop anchor = await _tab(tester, backward: backward);
  final List<List<_Stop>> laps = <List<_Stop>>[];
  List<_Stop> lap = <_Stop>[anchor];
  for (int press = 0; press < _maxPresses && laps.length < count; press++) {
    final _Stop next = await _tab(tester, backward: backward);
    if (identical(next.node, anchor.node)) {
      laps.add(lap);
      lap = <_Stop>[next];
    } else {
      lap.add(next);
    }
  }
  expect(
    laps,
    hasLength(count),
    reason:
        '${backward ? 'Shift+Tab' : 'Tab'} never came back to ${anchor.label} '
        'within $_maxPresses presses: '
        '${lap.map((_Stop stop) => stop.name).join(', ')}',
  );
  return laps;
}

void _expectOneSettingsRun(List<_Stop> lap) {
  int changes = 0;
  for (int index = 1; index < lap.length; index++) {
    if (lap[index].inSettings != lap[index - 1].inSettings) {
      changes++;
    }
  }
  final String order = lap.map((_Stop stop) => stop.name).join(', ');
  expect(
    changes,
    lessThanOrEqualTo(2),
    reason: 'one lap leaves and re-enters Settings more than once: $order',
  );
  expect(
    lap.where((_Stop stop) => stop.inSettings).map((_Stop stop) => stop.label),
    containsAll(<String>[
      for (final SettingsTab tab in SettingsTab.values) tab.label,
    ]),
    reason: 'one lap never reaches every Settings tab: $order',
  );
  expect(
    lap.where((_Stop stop) => stop.inSettings).map((_Stop stop) => stop.label),
    contains(_lastSettingsControl),
    reason: 'one lap never reaches $_lastSettingsControl: $order',
  );
  expect(
    lap.where((_Stop stop) => !stop.visible).map((_Stop stop) => stop.name),
    isEmpty,
    reason: 'Tab focused controls scrolled out of sight: $order',
  );
}

void _expectSameSettingsRun(List<List<_Stop>> laps) {
  List<FocusNode> run(List<_Stop> lap) => <FocusNode>[
    for (final _Stop stop in lap)
      if (stop.inSettings) stop.node,
  ];
  expect(
    run(laps.last),
    orderedEquals(run(laps.first)),
    reason: 'a later lap visits a different set of Settings controls',
  );
}

void main() {
  testWidgets(
    'on a phone one Tab lap walks all of Settings, then the bottom bar',
    (WidgetTester tester) async {
      _holdStill(tester);
      await pumpShell(
        tester,
        const AppShell(),
        platform: TargetPlatform.android,
        surface: const Size(411, 869),
      );
      _useKeyboardHighlight();
      await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
      await tester.pumpAndSettle();
      await _selectDataTab(tester);

      final List<List<_Stop>> laps = await _laps(tester, 2);

      laps.forEach(_expectOneSettingsRun);
      _expectSameSettingsRun(laps);
    },
  );

  testWidgets('on a Mac one Tab lap walks the sidebar, then all of Settings', (
    WidgetTester tester,
  ) async {
    _holdStill(tester);
    await pumpShell(tester, const AppShell(), surface: const Size(1280, 860));
    _useKeyboardHighlight();
    await tester.tap(find.bySemanticsLabel('Settings').first);
    await tester.pumpAndSettle();
    await _selectDataTab(tester);

    final List<List<_Stop>> laps = await _laps(tester, 2);

    laps.forEach(_expectOneSettingsRun);
    _expectSameSettingsRun(laps);
  });

  testWidgets(
    'on a phone one Shift+Tab lap walks all of Settings, then the top bar',
    (WidgetTester tester) async {
      _holdStill(tester);
      await pumpShell(
        tester,
        const AppShell(),
        platform: TargetPlatform.android,
        surface: const Size(411, 869),
      );
      _useKeyboardHighlight();
      await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
      await tester.pumpAndSettle();
      await _selectDataTab(tester);

      final List<List<_Stop>> laps = await _laps(tester, 2, backward: true);

      laps.forEach(_expectOneSettingsRun);
      _expectSameSettingsRun(laps);
    },
  );

  testWidgets(
    'on a Mac one Shift+Tab lap walks all of Settings, then the sidebar',
    (WidgetTester tester) async {
      _holdStill(tester);
      await pumpShell(tester, const AppShell(), surface: const Size(1280, 860));
      _useKeyboardHighlight();
      await tester.tap(find.bySemanticsLabel('Settings').first);
      await tester.pumpAndSettle();
      await _selectDataTab(tester);

      final List<List<_Stop>> laps = await _laps(tester, 2, backward: true);

      laps.forEach(_expectOneSettingsRun);
      _expectSameSettingsRun(laps);
    },
  );
}
