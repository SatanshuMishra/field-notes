import 'dart:async';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/settings/sections/about_section.dart';
import 'package:field_notes/features/settings/sections/data_section.dart';
import 'package:field_notes/features/settings/sections/journal_section.dart';
import 'package:field_notes/features/settings/sections/reminders_sound_section.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:field_notes/features/settings/widgets/settings_notice.dart';
import 'package:field_notes/features/settings/widgets/settings_phone_pages.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/page_opacity.dart';
import '../../support/sync_overrides.dart';
import '../../support/update_overrides.dart';
import 'support/fake_settings_repository.dart';
import 'support/recording_reminder_scheduler.dart';
import 'support/settings_harness.dart';

final TargetPlatformVariant _phoneAndDesktop = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.android, TargetPlatform.macOS},
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FakeSettingsRepository repository,
  Stream<AppSettings> Function()? settingsStream,
}) async {
  useWideSurface(tester);
  await tester.pumpWidget(
    settingsFeatureHarness(
      const SettingsScreen(),
      scrollable: false,
      overrides: <Override>[
        settingsRepositoryProvider.overrideWithValue(repository),
        appSettingsProvider.overrideWith(
          (Ref ref) =>
              settingsStream?.call() ??
              Stream<AppSettings>.value(AppSettings.defaults),
        ),
        entriesForDateProvider.overrideWith(
          (Ref ref, String date) => Stream<List<Entry>>.value(const <Entry>[]),
        ),
        reminderClockProvider.overrideWithValue(() => DateTime(2026, 7, 20, 9)),
        reminderSchedulerProvider.overrideWithValue(
          RecordingReminderScheduler(),
        ),
        ...syncOffOverrides(),
        ...updateQuietOverrides(),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows every settings section once loaded', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, repository: FakeSettingsRepository());

    expect(find.byType(SettingsSectionList), findsOneWidget);
    for (final Type section in <Type>[
      JournalSection,
      SyncStorageSection,
      RemindersSoundSection,
      DataSection,
      AboutSection,
    ]) {
      expect(
        find.byType(section, skipOffstage: false),
        findsOneWidget,
        reason: '$section',
      );
    }
    expect(find.text('preferences'), findsOneWidget);
    for (final SettingsTab tab in SettingsTab.values) {
      expect(find.byKey(settingsTabKey(tab)), findsOneWidget, reason: tab.name);
    }

    await tester.tap(find.byKey(settingsTabKey(SettingsTab.syncStorage)));
    await tester.pumpAndSettle();

    expect(find.byType(SyncStorageSection), findsOneWidget);
    expect(find.byType(SettingsSectionList), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.text('Sync & storage'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the shared loading block while settings are loading', (
    WidgetTester tester,
  ) async {
    final StreamController<AppSettings> pending =
        StreamController<AppSettings>();
    addTearDown(pending.close);

    await _pumpScreen(
      tester,
      repository: FakeSettingsRepository(),
      settingsStream: () => pending.stream,
    );

    expect(find.widgetWithText(StateBlock, 'Loading'), findsOneWidget);
    expect(find.byType(CrossHatchPlaceholder), findsNothing);
    expect(find.byType(SyncStorageSection), findsNothing);
    expect(find.text('preferences'), findsNothing);
  }, variant: _phoneAndDesktop);

  testWidgets('a failed load offers a retry that reloads the settings', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    bool databaseHealed = false;
    await _pumpScreen(
      tester,
      repository: FakeSettingsRepository(),
      settingsStream: () {
        loads++;
        return databaseHealed
            ? Stream<AppSettings>.value(AppSettings.defaults)
            : Stream<AppSettings>.error(StateError('db gone'));
      },
    );

    expect(
      find.widgetWithText(StateBlock, 'Your settings could not be loaded.'),
      findsOneWidget,
    );
    expect(find.byType(SyncStorageSection), findsNothing);

    databaseHealed = true;
    final int loadsBeforeRetry = loads;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(loads, loadsBeforeRetry + 1);

    await tester.pumpAndSettle();
    expect(find.byType(StateBlock), findsNothing);
    expect(
      find.byType(SyncStorageSection, skipOffstage: false),
      findsOneWidget,
    );
  }, variant: _phoneAndDesktop);

  testWidgets('surfaces a failed write as a dismissible notice', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      repository: FakeSettingsRepository(writeError: StateError('disk full')),
    );

    await tester.tap(find.byKey(settingsTabKey(SettingsTab.remindersSound)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SettingsToggle).first);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsNotice), findsOneWidget);
    expect(
      find.text('Could not save your daily reminder setting.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsNotice), findsNothing);
  });

  testWidgets(
    'moving between sections fades the right pane and keeps the list still',
    (WidgetTester tester) async {
      await _pumpScreen(tester, repository: FakeSettingsRepository());
      final Finder list = find.byKey(settingsSidebarColumnKey);
      final Finder pane = find.byKey(settingsContentColumnKey);

      await tester.tap(find.byKey(settingsTabKey(SettingsTab.remindersSound)));
      await tester.pump();
      expect(effectiveOpacity(tester, list), 1);

      for (int elapsed = 15; elapsed <= 300; elapsed += 15) {
        await tester.pump(const Duration(milliseconds: 15));
        expect(effectiveOpacity(tester, list), 1, reason: '$elapsed ms');
        if (elapsed == 45) {
          expect(effectiveOpacity(tester, pane), inExclusiveRange(0, 1));
          expect(find.byType(RemindersSoundSection), findsNothing);
        }
      }

      expect(effectiveOpacity(tester, pane), 1);
      expect(find.byType(RemindersSoundSection), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'opening a section on phone fades the list out, then the page in',
    (WidgetTester tester) async {
      await _pumpScreen(tester, repository: FakeSettingsRepository());

      await tester.tap(find.byKey(settingsTabKey(SettingsTab.syncStorage)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 45));

      expect(
        effectiveOpacity(tester, find.byType(SettingsSectionList)),
        inExclusiveRange(0, 1),
      );
      expect(find.byType(SettingsPageHeading), findsNothing);

      await tester.pump(const Duration(milliseconds: 255));

      expect(find.byType(SettingsSectionList), findsNothing);
      expect(effectiveOpacity(tester, find.byType(SettingsPageHeading)), 1);
    },
  );
}
