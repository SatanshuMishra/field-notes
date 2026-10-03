import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/shell_content.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/streak/streak.dart';

import '../support/app_shell_harness.dart';

const Size _phoneSurface = Size(440, 900);

Finder _streakCard() => find.byKey(const ValueKey<String>('streak-card'));

final Finder _pill = find.byType(StreakPill);

void main() {
  testWidgets(
    'the phone meadow shows the garden alone with the streak in the header',
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
      expect(_streakCard(), findsNothing);
      expect(
        find.descendant(of: find.byType(ShellContent), matching: _pill),
        findsNothing,
      );
      expect(_pill, findsOneWidget);
      expect(
        tester.widget<StreakPill>(_pill).form,
        StreakPillForm.headerOverScene,
      );
      expect(
        tester.getRect(find.byType(ShellContent)),
        tester.getRect(find.byType(GardenScreen)),
      );
    },
  );

  testWidgets('the desktop garden adds no streak inside the page', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester, const AppShell());

    await tester.tap(find.byKey(const ValueKey<String>('rail-garden')));
    await tester.pump();

    expect(find.byType(GardenScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ShellContent), matching: _streakCard()),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(ShellContent), matching: _pill),
      findsNothing,
    );
  });
}
