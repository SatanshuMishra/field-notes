import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_shell_harness.dart';

const Size _phone = Size(384, 832);

Future<void> _pumpChrome(
  WidgetTester tester, {
  required ShellDestination selected,
  required Brightness brightness,
}) async {
  tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
  await pumpShell(
    tester,
    BottomBarShell(
      destinations: ShellDestination.primary,
      selected: selected,
      onSelect: (ShellDestination destination) {},
      onCapture: () {},
      body: const SizedBox.expand(),
    ),
    platform: TargetPlatform.android,
    surface: _phone,
    brightness: brightness,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    testWidgets('the phone header and tab labels meet text contrast in the '
        '${brightness.name} theme', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      for (final ShellDestination selected in ShellDestination.primary) {
        if (selected == ShellDestination.garden) {
          continue;
        }
        await _pumpChrome(tester, selected: selected, brightness: brightness);
        expect(find.text('field notes'), findsOneWidget);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });
  }
}
