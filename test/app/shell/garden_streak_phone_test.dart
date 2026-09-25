import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_content.dart';
import 'package:field_notes/features/garden/garden.dart';

import '../support/app_shell_harness.dart';

const Size _phoneSurface = Size(440, 900);

Finder _streakCard() => find.byKey(const ValueKey<String>('streak-card'));

void main() {
  testWidgets('the phone garden shows the streak above the garden',
      (WidgetTester tester) async {
    await pumpShell(
      tester,
      const AppShell(),
      platform: TargetPlatform.android,
      surface: _phoneSurface,
    );

    await tester.tap(find.byKey(const ValueKey<String>('tab-garden')));
    await tester.pump();

    expect(_streakCard(), findsOneWidget);
    expect(find.byType(GardenScreen), findsOneWidget);
    expect(
      tester.getTopLeft(_streakCard()).dy,
      lessThan(tester.getTopLeft(find.byType(GardenScreen)).dy),
    );
  });

  testWidgets('the desktop garden adds no streak card',
      (WidgetTester tester) async {
    await pumpShell(tester, const AppShell());

    await tester.tap(find.byKey(const ValueKey<String>('rail-garden')));
    await tester.pump();

    expect(find.byType(GardenScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ShellContent),
        matching: _streakCard(),
      ),
      findsNothing,
    );
  });
}
