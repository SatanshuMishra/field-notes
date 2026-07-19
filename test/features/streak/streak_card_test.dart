import 'package:field_notes/domain/services/streak_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'streak_test_support.dart';

void main() {
  group('StreakCard', () {
    testWidgets('renders the flame, day count, and longest streak', (
      WidgetTester tester,
    ) async {
      await pumpStreakCard(
        tester,
        summary: const StreakSummary(current: 3, longest: 5),
      );

      expect(
        find.byKey(const ValueKey<String>('streak-card')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('longest streak yet: 5'), findsOneWidget);
    });

    testWidgets('uses the singular for a one-day streak', (
      WidgetTester tester,
    ) async {
      await pumpStreakCard(
        tester,
        summary: const StreakSummary(current: 1, longest: 1),
      );

      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('longest streak yet: 1'), findsOneWidget);
    });
  });
}
