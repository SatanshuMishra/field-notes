import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/features/reminders/reminder_providers.dart';
import 'package:field_notes/features/search/search_entries_provider.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/settings/support/fake_settings_repository.dart';
import '../../features/settings/support/recording_reminder_scheduler.dart';

class FakeJournalRepository implements JournalRepository {
  @override
  Stream<List<Day>> watchAllDays() => Stream<List<Day>>.value(const <Day>[]);

  @override
  Stream<List<Day>> watchDaysInMonth({
    required int year,
    required int month,
  }) =>
      Stream<List<Day>>.value(const <Day>[]);

  @override
  Stream<Day?> watchDayForDate(String date) => Stream<Day?>.value(null);

  @override
  Stream<List<Entry>> watchEntriesForDate(String date) =>
      Stream<List<Entry>>.value(const <Entry>[]);

  @override
  Stream<List<Entry>> watchEntriesForDay(String dayId) =>
      Stream<List<Entry>>.value(const <Entry>[]);

  @override
  Stream<List<EntryPhoto>> watchPhotosForEntry(String entryId) =>
      Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]);

  @override
  Future<List<Day>> onThisDay({required int month, required int day}) async =>
      const <Day>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> shellOverrides() => <Override>[
      journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
      journaledDatesProvider.overrideWith(
        (_) => Stream<List<String>>.value(const <String>[]),
      ),
      searchAllEntriesProvider.overrideWith(
        (_) => Stream<List<Entry>>.value(const <Entry>[]),
      ),
      reminderClockProvider.overrideWithValue(() => DateTime(2026, 7, 20, 9)),
      reminderSchedulerProvider.overrideWithValue(RecordingReminderScheduler()),
    ];

Future<void> pumpShell(
  WidgetTester tester,
  Widget child, {
  TargetPlatform platform = TargetPlatform.macOS,
  Size surface = const Size(1200, 900),
  List<Override> overrides = const <Override>[],
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[...shellOverrides(), ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: child,
      ),
    ),
  );
  await tester.pump();
}
