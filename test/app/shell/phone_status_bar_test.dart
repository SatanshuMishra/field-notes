import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_shell_harness.dart';

const Size _phone = Size(384, 832);

SystemUiOverlayStyle _themeBars(Brightness theme) => switch (theme) {
  Brightness.light => const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ),
  Brightness.dark => const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ),
};

Future<void> _pumpChrome(
  WidgetTester tester, {
  required ShellDestination selected,
  required Brightness brightness,
}) async {
  tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
  await pumpShell(
    tester,
    AnnotatedRegion<SystemUiOverlayStyle>(
      value: _themeBars(brightness),
      child: BottomBarShell(
        destinations: ShellDestination.primary,
        selected: selected,
        onSelect: (ShellDestination destination) {},
        onCapture: () {},
        body: const SizedBox.expand(),
      ),
    ),
    platform: TargetPlatform.android,
    surface: _phone,
    brightness: brightness,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    testWidgets('over the Meadow scene the status bar icons are light in the '
        '${brightness.name} theme', (WidgetTester tester) async {
      await _pumpChrome(
        tester,
        selected: ShellDestination.garden,
        brightness: brightness,
      );
      expect(
        SystemChrome.latestStyle?.statusBarIconBrightness,
        Brightness.light,
      );
      expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);
    });
  }

  testWidgets('on a paper page the status bar follows the light theme', (
    WidgetTester tester,
  ) async {
    await _pumpChrome(
      tester,
      selected: ShellDestination.garden,
      brightness: Brightness.light,
    );
    await _pumpChrome(
      tester,
      selected: ShellDestination.today,
      brightness: Brightness.light,
    );
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.light);
  });
}
