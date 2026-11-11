import 'package:field_notes/app/shell/shell_content.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/page_opacity.dart';
import '../support/app_shell_harness.dart';

final Finder _today = find.byType(TodayScreen);
final Finder _calendar = find.byType(CalendarScreen);

double _riseOf(WidgetTester tester, Finder page) =>
    tester.getTopLeft(page).dy -
    tester.getTopLeft(find.byType(ShellContent)).dy;

Future<ValueNotifier<ShellDestination>> _pumpContent(
  WidgetTester tester,
) async {
  final ValueNotifier<ShellDestination> destination =
      ValueNotifier<ShellDestination>(ShellDestination.today);
  addTearDown(destination.dispose);
  await pumpShell(
    tester,
    Scaffold(
      body: ValueListenableBuilder<ShellDestination>(
        valueListenable: destination,
        builder: (BuildContext context, ShellDestination shown, Widget? _) =>
            ShellContent(destination: shown),
      ),
    ),
  );
  return destination;
}

void main() {
  final TargetPlatformVariant desktop = TargetPlatformVariant.only(
    TargetPlatform.macOS,
  );

  testWidgets(
    'fades the old page out, then fades the new page in as it rises',
    (WidgetTester tester) async {
      final ValueNotifier<ShellDestination> destination = await _pumpContent(
        tester,
      );
      expect(effectiveOpacity(tester, _today), 1);

      destination.value = ShellDestination.calendar;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 45));

      expect(_calendar, findsNothing);
      expect(_today, findsOneWidget);
      expect(effectiveOpacity(tester, _today), inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 45));
      await tester.pump(const Duration(milliseconds: 105));

      expect(_today, findsNothing);
      expect(_calendar, findsOneWidget);
      expect(effectiveOpacity(tester, _calendar), inExclusiveRange(0, 1));
      expect(_riseOf(tester, _calendar), inExclusiveRange(0, 8));

      await tester.pump(const Duration(milliseconds: 105));

      expect(_today, findsNothing);
      expect(effectiveOpacity(tester, _calendar), 1);
      expect(_riseOf(tester, _calendar), 0);
    },
    variant: desktop,
  );

  testWidgets(
    'with reduced motion the new page cross-fades in place within 150 ms',
    (WidgetTester tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final ValueNotifier<ShellDestination> destination = await _pumpContent(
        tester,
      );

      destination.value = ShellDestination.calendar;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));

      expect(_today, findsNothing);
      expect(effectiveOpacity(tester, _calendar), inExclusiveRange(0, 1));
      expect(_riseOf(tester, _calendar), 0);

      await tester.pump(const Duration(milliseconds: 75));

      expect(effectiveOpacity(tester, _calendar), 1);
      expect(_riseOf(tester, _calendar), 0);
    },
    variant: desktop,
  );
}
