import 'dart:math';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/reminders/reminder_scheduler.dart';
import 'package:field_notes/features/settings/sections/sync_storage_section.dart';
import 'package:field_notes/features/sync/ui/recovery_phrase_check.dart';
import 'package:field_notes/features/sync/ui/start_sync_flow.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:field_notes/state/sync_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';
import '../../settings/support/fake_settings_repository.dart';
import '../../settings/support/recording_reminder_scheduler.dart';
import '../../settings/support/settings_harness.dart';

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.macOS, TargetPlatform.android},
);

final RegExp _checkLabel = RegExp(r'^Word (\d+)$');

bool get _onAndroid => defaultTargetPlatform == TargetPlatform.android;

Finder _fieldLabelled(String label) => find
    .descendant(
      of: find
          .ancestor(of: find.text(label), matching: find.byType(Column))
          .first,
      matching: find.byType(EditableText),
    )
    .first;

String _textOf(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).data!;

Future<void> _finishStartSyncing(WidgetTester tester) async {
  await tester.tap(find.text('Start syncing'));
  await tester.pumpAndSettle();
  await tester.enterText(
    _fieldLabelled(serverAddressLabel),
    'https://sync.example.com',
  );
  await tester.enterText(_fieldLabelled(inviteCodeLabel), 'invite-1');
  await tester.pump();
  await tester.tap(find.byKey(startSyncContinueKey));
  await tester.pumpAndSettle();

  expect(find.text(recoveryPhraseTitle), findsOneWidget);
  final Map<int, String> words = <int, String>{
    for (int position = 1; position <= 12; position++)
      position: _textOf(tester, find.byKey(recoveryWordKey(position))),
  };
  await tester.tap(find.byKey(writtenDownKey));
  await tester.pumpAndSettle();

  expect(find.text(checkPhraseTitle), findsOneWidget);
  final List<int> asked = <int>[
    for (final Element element
        in find
            .byWidgetPredicate(
              (Widget widget) =>
                  widget is Text && _checkLabel.hasMatch(widget.data ?? ''),
            )
            .evaluate())
      int.parse(
        _checkLabel.firstMatch((element.widget as Text).data!)!.group(1)!,
      ),
  ];
  expect(asked, hasLength(2));
  for (final int position in asked) {
    await tester.enterText(
      _fieldLabelled(recoveryCheckLabel(position)),
      words[position]!,
    );
  }
  await tester.pump();
  await tester.tap(find.byKey(turnOnSyncKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'turning sync on asks for notifications then offers the battery sheet',
    (WidgetTester tester) async {
      tester.view.physicalSize = _onAndroid
          ? const Size(412, 1400)
          : const Size(1400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final FakeBatterySettings battery = FakeBatterySettings();
      final RecordingReminderScheduler scheduler = RecordingReminderScheduler(
        permission: ReminderPermission.denied,
      );

      await tester.pumpWidget(
        settingsFeatureHarness(
          SyncStorageSection(
            settings: AppSettings.defaults,
            onFeedback: (String _) {},
          ),
          overrides: <Override>[
            for (final Override override in syncOffOverrides(battery: battery))
              if (override.origin != enrolmentServiceProvider) override,
            enrolmentServiceProvider.overrideWithValue(
              stubRelayEnrolment(database, random: Random(11)),
            ),
            settingsRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(),
            ),
            reminderSchedulerProvider.overrideWithValue(scheduler),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await _finishStartSyncing(tester);

      expect(find.text(checkPhraseTitle), findsNothing);
      expect(
        await tester.runAsync<String?>(
          () => readSyncState(database, SyncStateKeys.syncEnabled),
        ),
        syncEnabledValue,
      );
      if (_onAndroid) {
        expect(scheduler.permissionRequests, 1);
        expect(battery.checks, 1);
        expect(find.text(backgroundUploadsTitle), findsOneWidget);
        expect(find.text(backgroundUploadsMessage), findsOneWidget);
        expect(find.text(notNowLabel), findsOneWidget);
        expect(find.text(openBatterySettingsLabel), findsOneWidget);

        await tester.tap(find.text(notNowLabel));
        await tester.pumpAndSettle();
        expect(find.text(backgroundUploadsTitle), findsNothing);
        expect(battery.opens, 0);
      } else {
        expect(scheduler.permissionRequests, 0);
        expect(battery.checks, 0);
        expect(find.text(backgroundUploadsTitle), findsNothing);
      }
    },
    variant: _bothPlatforms,
  );

  testWidgets(
    'no battery sheet follows on Android when Field Notes is already exempt',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final AppDatabase database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final FakeBatterySettings battery = FakeBatterySettings(exempt: true);
      final RecordingReminderScheduler scheduler = RecordingReminderScheduler(
        permission: ReminderPermission.denied,
      );

      await tester.pumpWidget(
        settingsFeatureHarness(
          SyncStorageSection(
            settings: AppSettings.defaults,
            onFeedback: (String _) {},
          ),
          overrides: <Override>[
            for (final Override override in syncOffOverrides(battery: battery))
              if (override.origin != enrolmentServiceProvider) override,
            enrolmentServiceProvider.overrideWithValue(
              stubRelayEnrolment(database, random: Random(13)),
            ),
            settingsRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(),
            ),
            reminderSchedulerProvider.overrideWithValue(scheduler),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await _finishStartSyncing(tester);

      expect(scheduler.permissionRequests, 1);
      expect(battery.checks, 1);
      expect(find.text(backgroundUploadsTitle), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
