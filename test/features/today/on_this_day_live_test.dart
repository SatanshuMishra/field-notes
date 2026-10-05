import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/merge/record_state.dart';
import 'package:field_notes/data/sync/merge/state_applier.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/features/today/on_this_day_card.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  for (int round = 0; round < 8; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

RecordState _remoteDay(String date, int millis) {
  final String clock = Hlc(
    millis: millis,
    counter: 0,
    nodeId: 'phone',
  ).encode();
  return RecordState(
    table: SyncedTables.days,
    rowId: 'day-$date',
    fields: <String, Object?>{
      'id': 'day-$date',
      'date': date,
      'moodId': null,
      'createdAt': millis,
      'updatedAt': millis,
      'deletedAt': null,
    },
    clocks: <String, String>{
      for (final String field in SyncedTables.dayFields) field: clock,
    },
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets(
    'an On this day memory arriving by sync appears without leaving Today',
    (WidgetTester tester) async {
      late AppDatabase database;
      late ChangeRecorder recorder;
      await tester.runAsync(() async {
        database = AppDatabase(NativeDatabase.memory());
        recorder = ChangeRecorder(database);
      });
      addTearDown(() => tester.runAsync(database.close));
      final DateTime today = DateTime(2026, 7, 19, 9);
      tester.view.physicalSize = todayPhoneSurface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            journalRepositoryProvider.overrideWithValue(
              DriftJournalRepository(database, recorder: recorder),
            ),
            todayClockProvider.overrideWithValue(() => today),
          ],
          child: todayHarness(const OnThisDayRailCard()),
        ),
      );
      await _settle(tester);
      expect(
        find.text('No memory from this day in past years yet.'),
        findsOneWidget,
      );

      await tester.runAsync(
        () => StateApplier(
          database: database,
          recorder: recorder,
          localDeviceName: 'Mac',
        ).apply(_remoteDay('2025-07-19', today.millisecondsSinceEpoch)),
      );
      await _settle(tester);

      expect(find.text('memory · 1 year ago'), findsOneWidget);
      expect(
        find.text('No memory from this day in past years yet.'),
        findsNothing,
      );
      expect(
        await tester.runAsync(() => database.select(database.days).get()),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
