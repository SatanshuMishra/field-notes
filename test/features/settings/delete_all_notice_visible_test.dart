import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/settings_data_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_settings_repository.dart';
import 'support/recording_reminder_scheduler.dart';
import 'support/settings_harness.dart';

const String _notice = 'Deleted 1 days and 2 entries.';

void main() {
  testWidgets('the delete-all notice is scrolled into view', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(411, 869);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FakeSettingsDataController controller = FakeSettingsDataController(
      deleteResult: const DataActionSucceeded(_notice),
    );
    await tester.pumpWidget(
      settingsFeatureHarness(
        const SettingsScreen(),
        scrollable: false,
        overrides: <Override>[
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
          appSettingsProvider.overrideWith(
            (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
          ),
          entriesForDateProvider.overrideWith(
            (Ref ref, String date) =>
                Stream<List<Entry>>.value(const <Entry>[]),
          ),
          reminderClockProvider.overrideWithValue(
            () => DateTime(2026, 7, 20, 9),
          ),
          reminderSchedulerProvider.overrideWithValue(
            RecordingReminderScheduler(),
          ),
          settingsDataControllerProvider.overrideWith(
            (Ref ref) async => controller,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delete all…'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    expect(controller.deleteCalls, 1);
    final Finder notice = find.text(_notice);
    expect(notice, findsOneWidget);
    final Rect rect = tester.getRect(notice);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.top, lessThan(869));
    expect(notice.hitTestable(), findsOneWidget);
  });
}
