import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show NoteBody;
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart'
    show viewerTitleFieldKey;
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../day_detail/support/day_detail_harness.dart';

const String _date = '2026-07-19';
const String _roses = 'Roses at dawn';
const String _elm = 'Tea under the elm.';

final TargetPlatformVariant _bothLayouts = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.android, TargetPlatform.macOS},
);

Entry _note({
  required String id,
  required int hour,
  required String text,
  String? title,
}) {
  return Entry(
    id: id,
    dayId: 'day-1',
    type: EntryType.text,
    title: title,
    textContent: text,
    createdAt: DateTime(2026, 7, 19, hour).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

Future<FakeJournalRepository> _open(
  WidgetTester tester, {
  required String entryId,
  ThemeData? theme,
}) async {
  final FakeJournalRepository repository = FakeJournalRepository(
    entries: <Entry>[
      _note(id: 'titled', hour: 8, title: _roses, text: 'Watered the roses.'),
      _note(id: 'untitled', hour: 14, text: _elm),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(repository),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        notesMediaResolverProvider.overrideWith(
          (Ref ref) async => FakeMediaResolver(),
        ),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showLogViewer(
                context,
                date: _date,
                entryId: entryId,
                exit: LogViewerExit.back,
              ),
              child: const Text('open log'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open log'));
  await tester.pumpAndSettle();
  return repository;
}

String _shownTitle(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byType(LogViewerPanel),
        matching: find.byKey(viewerTitleFieldKey),
      ),
    )
    .controller!
    .text;

Future<void> _rename(WidgetTester tester, String title) async {
  final Finder field = find.byKey(viewerTitleFieldKey);
  await tester.tap(field);
  await tester.pump();
  await tester.enterText(field, title);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('a note shows its own title or none and renames in place', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = await _open(
      tester,
      entryId: 'untitled',
    );

    expect(find.text('Afternoon note'), findsNothing);
    expect(_shownTitle(tester), isEmpty);
    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(
      find.byWidgetPredicate((Widget w) => w is NoteBody && w.text == _elm),
      findsOneWidget,
    );

    await tester.tap(find.byKey(logViewerEarlierKey));
    await tester.pumpAndSettle();

    expect(find.text('Morning note'), findsNothing);
    expect(_shownTitle(tester), _roses);

    await _rename(tester, 'Roses and rain');

    expect(repository.titleUpdates, <({String id, String? title})>[
      (id: 'titled', title: 'Roses and rain'),
    ]);
  }, variant: _bothLayouts);

  testWidgets('a failed rename puts the title back and says so', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final FakeJournalRepository repository = await _open(
      tester,
      entryId: 'untitled',
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
    );
    repository.updateError = StateError('disk full');

    await _rename(tester, 'The pier');
    await tester.pump();

    expect(find.text('The pier'), findsNothing);
    expect(_shownTitle(tester), isEmpty);
    expect(find.text(logViewerRenameFailedMessage), findsOneWidget);
    expect(repository.titleUpdates, isEmpty);

    repository.updateError = null;
    await _rename(tester, 'The pier');

    expect(repository.titleUpdates, <({String id, String? title})>[
      (id: 'untitled', title: 'The pier'),
    ]);
    await tester.pump(kToastLifetime);
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
