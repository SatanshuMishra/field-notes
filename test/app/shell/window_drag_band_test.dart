import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/shell/sidebar_shell.dart';
import 'package:field_notes/app/shell/window_chrome.dart';

import '../app_harness.dart';

const Key _bandKey = ValueKey<String>('drag-band');

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

void main() {
  testWidgets('dragging the title band moves the window', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<String> calls = _recordWindowCalls(tester);

    await tester.pumpWidget(
      appHarness(
        const Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 1280, child: WindowDragBand(key: _bandKey)),
        ),
      ),
    );

    final Rect band = tester.getRect(find.byKey(_bandKey));
    expect(band.height, shellTitleBarHeight);
    expect(band.width, 1280);

    await tester.drag(find.byKey(_bandKey), const Offset(60, 20));
    await tester.pumpAndSettle();
    expect(calls, <String>[startDragMethod]);

    await tester.tap(find.byKey(_bandKey));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(_bandKey));
    await tester.pumpAndSettle();
    expect(calls, <String>[startDragMethod, titlebarDoubleClickMethod]);

    await tester.pumpWidget(
      appHarness(
        SidebarShell(
          destinations: ShellDestination.primary,
          selected: ShellDestination.today,
          onSelect: (_) {},
          onSound: () {},
          streak: const SizedBox.shrink(),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(tester.widget(find.byKey(windowTitleBarKey)), isA<WindowDragBand>());
    expect(
      tester.getRect(find.byKey(windowTitleBarKey)),
      const Rect.fromLTWH(0, 0, 1280, shellTitleBarHeight),
    );
  });
}
