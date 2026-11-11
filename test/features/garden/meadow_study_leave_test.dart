import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';

const int _thisYear = 2026;
const int _pastYear = 2025;
final DateTime _noon = DateTime.utc(_thisYear, 9, 28, 18);

final Finder _gardenRail = find.byKey(const ValueKey<String>('rail-garden'));
final Finder _todayRail = find.byKey(const ValueKey<String>('rail-today'));
final Finder _pastStudy = find.text('Your meadow, $_pastYear');

Future<void> _switchTo(WidgetTester tester, Finder rail) async {
  await tester.tap(rail);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  testWidgets(
    'leaving the Meadow keeps the studied year while it fades, then returns to this year',
    (WidgetTester tester) async {
      await pumpShell(
        tester,
        const AppShell(),
        overrides: <Override>[skyClockProvider.overrideWithValue(() => _noon)],
      );
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      await _switchTo(tester, _gardenRail);
      container
          .read(meadowViewStateProvider.notifier)
          .openYear(_pastYear, currentYear: _thisYear);
      await tester.pump();
      expect(_pastStudy, findsOneWidget);

      await tester.tap(_todayRail);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 45));

      expect(find.byType(GardenScreen), findsOneWidget);
      expect(_pastStudy, findsOneWidget);
      expect(find.text('your meadow'), findsNothing);

      await tester.pump(const Duration(milliseconds: 255));
      await tester.pump();

      expect(find.byType(GardenScreen), findsNothing);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(container.read(meadowViewStateProvider), const MeadowView());

      await _switchTo(tester, _gardenRail);

      expect(_pastStudy, findsNothing);
      expect(find.text('your meadow'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
