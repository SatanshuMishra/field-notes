import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/onboarding/onboarding.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart' show shellOverrides;
import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, FakeNoteWriter, NoteSaveCall, newTestDatabase;
import '../mood/support/mood_harness.dart' as mood_harness;

const String _today = '2026-10-01';
const String _lineError = "Couldn't save this line. Keep typing to try again.";

const Duration _pause = Duration(milliseconds: 600);
const Duration _justBeforePause = Duration(milliseconds: 599);
const Duration _restOfPause = Duration(milliseconds: 1);
const Duration _slowSave = Duration(seconds: 2);

final DateTime _lateEvening = DateTime(2026, 10, 1, 23, 58);
final DateTime _pastMidnight = DateTime(2026, 10, 2, 0, 5);

typedef _Layout = ({ShellLayout layout, TargetPlatform platform, Size surface});

const List<_Layout> _layouts = <_Layout>[
  (
    layout: ShellLayout.sidebar,
    platform: TargetPlatform.macOS,
    surface: Size(1280, 800),
  ),
  (
    layout: ShellLayout.bottomBar,
    platform: TargetPlatform.android,
    surface: Size(360, 740),
  ),
];

typedef _Forward = ({
  String name,
  Future<void> Function(WidgetTester tester, OnboardingController controller)
  move,
  OnboardingChapter lands,
});

const List<Mood> _choices = <Mood>[
  Mood.calm,
  Mood.sad,
  Mood.hopeful,
  Mood.grateful,
];

Future<void> _onLayout(_Layout layout, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = layout.platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _flush(WidgetTester tester) async {
  for (int frame = 0; frame < 5; frame++) {
    await tester.pump();
  }
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  _Layout layout, {
  required JournalRepository journal,
  required DateTime Function() clock,
  NoteWriter? writer,
}) async {
  tester.view.physicalSize = layout.surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final Set<Object> replaced = <Object>{journalRepositoryProvider};
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        for (final Override override in shellOverrides())
          if (!replaced.contains(override.origin)) override,
        journalRepositoryProvider.overrideWithValue(journal),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        if (writer case final NoteWriter fake)
          noteWriterProvider.overrideWith((Ref ref) => fake),
        todayClockProvider.overrideWithValue(clock),
        onboardingCountryCodeProvider.overrideWithValue('US'),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: layout.platform),
        home: OnboardingFrame(layout: layout.layout),
      ),
    ),
  );
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(OnboardingFrame)),
  );
  container.read(onboardingControllerProvider.notifier).start();
  await _flush(tester);
  return container;
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (int attempt = 0; attempt < 50 && !done(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _close(WidgetTester tester, db.AppDatabase? database) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
  await database?.close();
}

OnboardingController _controller(ProviderContainer container) =>
    container.read(onboardingControllerProvider.notifier);

OnboardingFlowRunning _running(ProviderContainer container) =>
    container.read(onboardingControllerProvider) as OnboardingFlowRunning;

OnboardingChapter _chapter(ProviderContainer container) =>
    _running(container).chapter;

OnboardingDraft _draft(ProviderContainer container) =>
    _running(container).draft;

Finder get _primary => find.byKey(onboardingPrimaryKey);

Finder get _skip => find.byKey(onboardingSkipKey);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _flush(tester);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.pump();
  await tester.sendKeyEvent(key);
  await _flush(tester);
}

Future<void> _next(WidgetTester tester, OnboardingController controller) =>
    _tap(tester, _primary);

Future<void> _enter(WidgetTester tester, OnboardingController controller) =>
    _key(tester, LogicalKeyboardKey.enter);

Future<void> _rightArrow(
  WidgetTester tester,
  OnboardingController controller,
) => _key(tester, LogicalKeyboardKey.arrowRight);

Future<void> _skipPill(WidgetTester tester, OnboardingController controller) =>
    _tap(tester, _skip);

Future<void> _skipToSetup(
  WidgetTester tester,
  OnboardingController controller,
) async {
  controller.skipToSetup();
  await _flush(tester);
}

List<_Forward> _forwardsFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => <_Forward>[
    (name: 'Next', move: _next, lands: OnboardingChapter.moment),
    (name: 'Enter', move: _enter, lands: OnboardingChapter.moment),
    (name: 'right arrow', move: _rightArrow, lands: OnboardingChapter.moment),
    (name: 'Skip to setup', move: _skipPill, lands: OnboardingChapter.theme),
  ],
  ShellLayout.bottomBar => <_Forward>[
    (name: 'Next', move: _next, lands: OnboardingChapter.moment),
    (name: 'Next again', move: _next, lands: OnboardingChapter.moment),
    (name: 'skip to setup', move: _skipToSetup, lands: OnboardingChapter.theme),
  ],
};

Future<void> _back(
  WidgetTester tester,
  _Layout layout,
  OnboardingController controller,
) async {
  switch (layout.layout) {
    case ShellLayout.sidebar:
      await _key(tester, LogicalKeyboardKey.arrowLeft);
    case ShellLayout.bottomBar:
      controller.back();
      await _flush(tester);
  }
}

Future<void> _growOpening(
  WidgetTester tester,
  ProviderContainer container,
) async {
  _controller(container)
    ..plant()
    ..markGrown();
  await _flush(tester);
}

Future<void> _reachMoment(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await _growOpening(tester, container);
  _controller(container)
    ..next()
    ..next();
  await _flush(tester);
  expect(_chapter(container), OnboardingChapter.moment);
}

Future<List<db.Day>> _days(db.AppDatabase database) =>
    database.select(database.days).get();

Future<List<db.Entry>> _liveEntries(db.AppDatabase database) async =>
    <db.Entry>[
      for (final db.Entry row in await database.select(database.entries).get())
        if (row.deletedAt == null) row,
    ];

Future<void> _expectOneDay(
  db.AppDatabase database,
  Mood mood, {
  required String reason,
}) async {
  final List<db.Day> days = await _days(database);
  expect(days, hasLength(1), reason: reason);
  expect(days.single.date, _today, reason: reason);
  expect(days.single.moodId, mood.id, reason: reason);
}

void main() {
  testWidgets('the mood saves on moving forward from A day and only then', (
    WidgetTester tester,
  ) async {
    for (final _Layout layout in _layouts) {
      await _onLayout(layout, () async {
        final String name = layout.layout.name;
        final db.AppDatabase database = newTestDatabase();
        DateTime now = _lateEvening;
        final ProviderContainer container = await _open(
          tester,
          layout,
          journal: DriftJournalRepository(database),
          clock: () => now,
        );
        final OnboardingController controller = _controller(container);
        expect(_draft(container).entryDate, _today, reason: name);
        now = _pastMidnight;

        await _tap(tester, _skip);
        expect(_chapter(container), OnboardingChapter.theme, reason: name);
        expect(
          await _days(database),
          isEmpty,
          reason: '$name skip from the Opening',
        );

        controller.goTo(OnboardingChapter.opening);
        await _growOpening(tester, container);
        await _tap(tester, _primary);
        expect(_chapter(container), OnboardingChapter.day, reason: name);
        controller.chooseMood(Mood.anxious);
        await _back(tester, layout, controller);
        expect(_chapter(container), OnboardingChapter.opening, reason: name);
        expect(await _days(database), isEmpty, reason: '$name back from A day');
        await _tap(tester, _primary);

        final List<_Forward> forwards = _forwardsFor(layout.layout);
        for (int index = 0; index < forwards.length; index++) {
          final _Forward forward = forwards[index];
          final Mood mood = _choices[index];
          final String reason = '$name ${forward.name}';
          expect(_chapter(container), OnboardingChapter.day, reason: reason);
          controller.chooseMood(mood);
          await _flush(tester);

          await forward.move(tester, controller);

          expect(_chapter(container), forward.lands, reason: reason);
          await _expectOneDay(database, mood, reason: reason);

          controller
            ..goTo(OnboardingChapter.day)
            ..chooseMood(Mood.anxious);
          await _flush(tester);
          await _back(tester, layout, controller);
          expect(
            _chapter(container),
            OnboardingChapter.opening,
            reason: reason,
          );
          await _expectOneDay(database, mood, reason: '$reason, then back');
          await _tap(tester, _primary);
        }
        await _close(tester, database);

        final mood_harness.FakeJournalRepository failing =
            mood_harness.FakeJournalRepository()
              ..setMoodError = StateError('disk full');
        final ProviderContainer broken = await _open(
          tester,
          layout,
          journal: failing,
          clock: () => _lateEvening,
        );
        final OnboardingController retrying = _controller(broken);
        await _growOpening(tester, broken);
        await _tap(tester, _primary);
        retrying.chooseMood(Mood.love);
        await _tap(tester, _primary);

        expect(_chapter(broken), OnboardingChapter.moment, reason: name);
        expect(failing.moodWrites, isEmpty, reason: name);
        expect(_draft(broken).noteError, isNull, reason: name);
        expect(_draft(broken).finishError, isNull, reason: name);
        expect(find.textContaining("Couldn't"), findsNothing, reason: name);

        failing.setMoodError = null;
        retrying.goTo(OnboardingChapter.day);
        await _flush(tester);
        await _tap(tester, _primary);

        expect(_chapter(broken), OnboardingChapter.moment, reason: name);
        expect(failing.moodWrites, <({String date, Mood? mood})>[
          (date: _today, mood: Mood.love),
        ], reason: name);
        await _close(tester, null);
      });
    }
  });

  testWidgets(
    'the first line autosaves into one note and the tick follows the save',
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          final String name = layout.layout.name;
          final db.AppDatabase database = newTestDatabase();
          final DriftJournalRepository journal = DriftJournalRepository(
            database,
          );
          final ProviderContainer container = await _open(
            tester,
            layout,
            journal: journal,
            clock: () => _lateEvening,
          );
          final OnboardingController controller = _controller(container);
          await _reachMoment(tester, container);

          controller.setNote('The ferry');
          await tester.pump(_justBeforePause);
          controller.setNote('The ferry was late');
          await tester.pump(_justBeforePause);
          await _flush(tester);
          expect(_draft(container).noteSave, NoteSaveState.idle, reason: name);
          expect(await _liveEntries(database), isEmpty, reason: name);

          await tester.pump(_restOfPause);
          await _flush(tester);
          final List<db.Entry> created = await _liveEntries(database);
          expect(created, hasLength(1), reason: name);
          final db.Entry note = created.single;
          expect(note.type, EntryType.text.id, reason: name);
          expect(note.textContent, 'The ferry was late', reason: name);
          expect((await journal.dayById(note.dayId))?.date, _today);
          expect(_draft(container).noteEntryId, note.id, reason: name);
          expect(_draft(container).noteSave, NoteSaveState.saved, reason: name);

          controller.setNote('The ferry was late, then the fog lifted');
          await tester.pump(_pause);
          await _flush(tester);
          final List<db.Entry> updated = await _liveEntries(database);
          expect(updated, hasLength(1), reason: name);
          expect(updated.single.id, note.id, reason: name);
          expect(
            updated.single.textContent,
            'The ferry was late, then the fog lifted',
            reason: name,
          );
          expect(_draft(container).noteEntryId, note.id, reason: name);
          expect(_draft(container).noteSave, NoteSaveState.saved, reason: name);

          controller.setNote('   ');
          await tester.pump(_pause);
          await _flush(tester);
          expect(await _liveEntries(database), isEmpty, reason: name);
          expect((await journal.entryById(note.id))?.isDeleted, isTrue);
          expect(_draft(container).noteEntryId, isNull, reason: name);
          expect(_draft(container).noteSave, NoteSaveState.idle, reason: name);

          controller.setNote('A fresh start');
          await tester.pump(_pause);
          await _flush(tester);
          final List<db.Entry> fresh = await _liveEntries(database);
          expect(fresh, hasLength(1), reason: name);
          expect(fresh.single.id, isNot(note.id), reason: name);
          expect(fresh.single.textContent, 'A fresh start', reason: name);
          await _close(tester, database);

          final db.AppDatabase quiet = newTestDatabase();
          final FakeNoteWriter slow = FakeNoteWriter(delay: _slowSave);
          final ProviderContainer overlap = await _open(
            tester,
            layout,
            journal: DriftJournalRepository(quiet),
            clock: () => _lateEvening,
            writer: slow,
          );
          final OnboardingController typing = _controller(overlap);
          await _reachMoment(tester, overlap);

          typing.setNote('First words');
          await tester.pump(_pause);
          await _flush(tester);
          expect(slow.saves, hasLength(1), reason: name);
          expect(slow.saves.single.entryId, isNull, reason: name);
          expect(slow.saves.single.date, _today, reason: name);
          expect(_draft(overlap).noteSave, NoteSaveState.saving, reason: name);

          typing.setNote('First words, then more');
          await tester.pump(_pause);
          await _flush(tester);
          expect(slow.saves, hasLength(1), reason: '$name second save waits');
          expect(_draft(overlap).noteSave, NoteSaveState.saving, reason: name);
          expect(_draft(overlap).noteEntryId, isNull, reason: name);

          await tester.pump(
            _slowSave - _pause - const Duration(milliseconds: 1),
          );
          await _flush(tester);
          expect(slow.saves, hasLength(1), reason: name);
          expect(_draft(overlap).noteSave, NoteSaveState.saving, reason: name);

          await tester.pump(const Duration(milliseconds: 1));
          await _flush(tester);
          expect(slow.saves, hasLength(2), reason: name);
          expect(slow.saves.last.entryId, 'entry-1', reason: name);
          expect(slow.saves.last.source, 'First words, then more');
          expect(_draft(overlap).noteEntryId, 'entry-1', reason: name);
          expect(_draft(overlap).noteSave, NoteSaveState.saving, reason: name);

          await tester.pump(_slowSave);
          await _flush(tester);
          expect(_draft(overlap).noteSave, NoteSaveState.saved, reason: name);
          expect(
            <String?>[for (final NoteSaveCall save in slow.saves) save.entryId],
            <String?>[null, 'entry-1'],
            reason: name,
          );
          await _close(tester, quiet);

          final db.AppDatabase steady = newTestDatabase();
          final FakeNoteWriter refusing = FakeNoteWriter(
            failure: const NoteWriteException('disk full'),
          );
          final ProviderContainer failed = await _open(
            tester,
            layout,
            journal: DriftJournalRepository(steady),
            clock: () => _lateEvening,
            writer: refusing,
          );
          final OnboardingController retrying = _controller(failed);
          await _reachMoment(tester, failed);

          retrying.setNote('Something small');
          await tester.pump(_pause);
          await _flush(tester);
          expect(refusing.saves, hasLength(1), reason: name);
          expect(_draft(failed).noteSave, NoteSaveState.failed, reason: name);
          expect(_draft(failed).noteError, _lineError, reason: name);
          expect(_draft(failed).noteEntryId, isNull, reason: name);

          retrying.setNote('Something small, again');
          await tester.pump(_justBeforePause);
          await _flush(tester);
          expect(refusing.saves, hasLength(1), reason: name);
          await tester.pump(_restOfPause);
          await _flush(tester);
          expect(refusing.saves, hasLength(2), reason: name);
          expect(refusing.saves.last.source, 'Something small, again');
          expect(refusing.saves.last.entryId, isNull, reason: name);
          expect(_draft(failed).noteSave, NoteSaveState.failed, reason: name);
          expect(_draft(failed).noteError, _lineError, reason: name);
          await _close(tester, steady);
        });
      }
    },
  );

  testWidgets(
    "a relaunch starts at the Opening with today's saved mood and note prefilled",
    (WidgetTester tester) async {
      for (final _Layout layout in _layouts) {
        await _onLayout(layout, () async {
          final String name = layout.layout.name;
          final db.AppDatabase database = newTestDatabase();
          int tick = 0;
          final DriftJournalRepository journal = DriftJournalRepository(
            database,
            clock: () => tick += 1000,
          );

          final ProviderContainer firstRun = await _open(
            tester,
            layout,
            journal: journal,
            clock: () => _lateEvening,
          );
          await _growOpening(tester, firstRun);
          _controller(firstRun)
            ..next()
            ..chooseMood(Mood.grateful)
            ..next()
            ..setNote('Fog over the harbour');
          await tester.pump(_pause);
          await _flush(tester);
          final String? noteId = _draft(firstRun).noteEntryId;
          expect(noteId, isNotNull, reason: name);
          await _close(tester, null);
          await journal.saveNote(
            date: _today,
            source: 'A later note',
            photoMediaIds: const <String>[],
          );

          final ProviderContainer relaunch = await _open(
            tester,
            layout,
            journal: journal,
            clock: () => _lateEvening,
          );
          await _until(tester, () => _draft(relaunch).noteEntryId != null);
          expect(_chapter(relaunch), OnboardingChapter.opening, reason: name);
          final OnboardingDraft prefilled = _draft(relaunch);
          expect(prefilled.planted, isFalse, reason: name);
          expect(prefilled.mood, Mood.grateful, reason: name);
          expect(prefilled.noteText, 'Fog over the harbour', reason: name);
          expect(prefilled.noteEntryId, noteId, reason: name);
          expect(prefilled.noteSave, NoteSaveState.saved, reason: name);

          await _growOpening(tester, relaunch);
          _controller(relaunch).next();
          await _flush(tester);
          expect(_chapter(relaunch), OnboardingChapter.day, reason: name);
          expect(_draft(relaunch).mood, Mood.grateful, reason: name);
          _controller(relaunch)
            ..next()
            ..setNote('Fog over the harbour, then sun');
          await tester.pump(_pause);
          await _flush(tester);

          final List<db.Entry> rows = await database
              .select(database.entries)
              .get();
          expect(rows, hasLength(2), reason: name);
          final List<db.Entry> live = await _liveEntries(database);
          expect(
            <String?>[for (final db.Entry row in live) row.textContent],
            unorderedEquals(<String>[
              'Fog over the harbour, then sun',
              'A later note',
            ]),
            reason: name,
          );
          expect(
            live
                .singleWhere(
                  (db.Entry row) =>
                      row.textContent == 'Fog over the harbour, then sun',
                )
                .id,
            noteId,
            reason: name,
          );
          expect(_draft(relaunch).noteEntryId, noteId, reason: name);
          await _expectOneDay(database, Mood.grateful, reason: name);
          await _close(tester, database);
        });
      }
    },
  );
}
