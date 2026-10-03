import 'package:field_notes/domain/services/streak_service.dart';
import 'package:field_notes/features/streak/streak_pill.dart';
import 'package:field_notes/features/streak/streak_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpStreakPill(
  WidgetTester tester, {
  required StreakSummary summary,
  StreakPillForm form = StreakPillForm.header,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [streakSummaryProvider.overrideWithValue(summary)],
      child: MaterialApp(
        home: Scaffold(body: StreakPill(form: form)),
      ),
    ),
  );
}
