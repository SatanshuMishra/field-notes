import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/shell/window_chrome.dart';

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

List<String> _recordWindowCalls(WidgetTester tester) {
  final List<String> calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowChannel,
    (MethodCall call) async {
      calls.add(call.method);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      null,
    ),
  );
  return calls;
}

bool _isPaintedDot(Widget widget) {
  if (widget is! Container) {
    return false;
  }
  final Decoration? decoration = widget.decoration;
  return decoration is BoxDecoration && decoration.shape == BoxShape.circle;
}

void main() {
  group('SidebarShell', () {
    testWidgets('the titlebar paints no window buttons and keeps their slot', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(appHarness(_shell()));

      final Rect bar = tester.getRect(find.byKey(windowTitleBarKey));
      expect(bar.top, 0);
      expect(bar.height, shellTitleBarHeight);
      final Rect slot = tester.getRect(
        find.byKey(const ValueKey<String>('traffic-lights')),
      );
      expect(slot.left, shellTitleBarPadding);
      expect(slot.width, windowButtonsSlotWidth);
      expect(
        find.descendant(
          of: find.byKey(windowTitleBarKey),
          matching: find.byWidgetPredicate(_isPaintedDot),
        ),
        findsNothing,
      );
      expect(
        tester.getCenter(find.text('field notes — a journal of days')).dx,
        640,
      );
    });

    testWidgets('dragging the titlebar starts a window drag', (
      WidgetTester tester,
    ) async {
      final List<String> calls = _recordWindowCalls(tester);
      await tester.pumpWidget(appHarness(_shell()));

      await tester.drag(find.byKey(windowTitleBarKey), const Offset(60, 20));
      await tester.pumpAndSettle();

      expect(calls, <String>[startDragMethod]);
    });

    testWidgets('double-clicking the titlebar runs the window double-click', (
      WidgetTester tester,
    ) async {
      final List<String> calls = _recordWindowCalls(tester);
      await tester.pumpWidget(appHarness(_shell()));

      await tester.tap(find.byKey(windowTitleBarKey));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(windowTitleBarKey));
      await tester.pumpAndSettle();

      expect(calls, <String>[titlebarDoubleClickMethod]);
    });

    testWidgets('a single click on the titlebar asks the window for nothing', (
      WidgetTester tester,
    ) async {
      final List<String> calls = _recordWindowCalls(tester);
      await tester.pumpWidget(appHarness(_shell()));

      await tester.tap(find.byKey(windowTitleBarKey));
      await tester.pump(const Duration(milliseconds: 400));

      expect(calls, isEmpty);
    });

    testWidgets('reserves the window-button slot and renders every rail '
        'destination', (WidgetTester tester) async {
      await tester.pumpWidget(appHarness(_shell()));

      expect(
        find.byKey(const ValueKey<String>('traffic-lights')),
        findsOneWidget,
      );
      for (final ShellDestination d in ShellDestination.primary) {
        expect(find.byKey(ValueKey<String>('rail-${d.name}')), findsOneWidget);
      }
    });

    testWidgets('a rail item reports its destination on tap', (
      WidgetTester tester,
    ) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(_shell(onSelect: (ShellDestination d) => picked = d)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('rail-garden')));
      expect(picked, ShellDestination.garden);
    });

    testWidgets('the settings button selects the settings destination', (
      WidgetTester tester,
    ) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(_shell(onSelect: (ShellDestination d) => picked = d)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('settings-button')));
      expect(picked, ShellDestination.settings);
    });

    testWidgets('the sound button invokes onSound', (
      WidgetTester tester,
    ) async {
      bool sounded = false;
      await tester.pumpWidget(
        appHarness(_shell(onSound: () => sounded = true)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('sound-button')));
      expect(sounded, isTrue);
    });

    testWidgets(
      'each rail item is a button that reports whether it is selected',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          appHarness(_shell(selected: ShellDestination.today)),
        );

        expect(
          tester.getSemantics(find.byKey(const ValueKey<String>('rail-today'))),
          isSemantics(
            label: 'Today',
            isButton: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(
            find.byKey(const ValueKey<String>('rail-garden')),
          ),
          isSemantics(
            label: 'Garden',
            isButton: true,
            isSelected: false,
            hasTapAction: true,
          ),
        );

        handle.dispose();
      },
    );

    testWidgets('the settings button reports selected while Settings is open', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        appHarness(_shell(selected: ShellDestination.today)),
      );

      expect(
        tester.getSemantics(
          find.byKey(const ValueKey<String>('settings-button')),
        ),
        isSemantics(label: 'Settings', isButton: true, isSelected: false),
      );

      await tester.pumpWidget(
        appHarness(_shell(selected: ShellDestination.settings)),
      );

      expect(
        tester.getSemantics(
          find.byKey(const ValueKey<String>('settings-button')),
        ),
        isSemantics(label: 'Settings', isButton: true, isSelected: true),
      );

      handle.dispose();
    });
  });
}
