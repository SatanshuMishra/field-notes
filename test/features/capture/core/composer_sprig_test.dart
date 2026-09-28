import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/art/art.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/repository_providers.dart';

import '../../../support/note_editor_driver.dart';
import '../../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository;
import 'capture_test_support.dart';

const Duration _hold = Duration(milliseconds: 110);

const List<String> _formatKeys = <String>[
  'format-bold',
  'format-italic',
  'format-heading',
  'format-list',
  'format-numbered',
  'format-task',
  'format-quote',
  'format-link',
  'format-table',
  'format-more',
  'format-undo',
];

typedef _Window = ({Size size, TargetPlatform platform, double keyboard});

Future<void> _open(
  WidgetTester tester,
  _Window window,
  List<Override> overrides,
  void Function(BuildContext context) open,
) async {
  tester.view.physicalSize = window.size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: window.keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(
        theme: ThemeData(platform: window.platform),
        home: Builder(
          builder: (BuildContext context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => open(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await NoteEditorDriver(tester).press(find.text('open'), _hold);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

List<Rect> _controlRects(WidgetTester tester) {
  final Finder save = find.ancestor(
    of: find.textContaining('Save'),
    matching: find.byType(GestureDetector),
  );
  final List<Finder> controls = <Finder>[
    find.byKey(composerCloseKey),
    if (save.evaluate().isNotEmpty) save.first,
    for (final String key in _formatKeys) find.byKey(ValueKey<String>(key)),
    find.byKey(composerAddPhotoKey),
  ];
  return <Rect>[
    for (final Finder control in controls)
      if (control.evaluate().isNotEmpty) tester.getRect(control),
  ];
}

void _expectClearRightEdgeSprig(WidgetTester tester, String reason) {
  final Rect panel = tester.getRect(find.byKey(composerPanelKey));
  final Rect sprig = tester.getRect(find.byType(SprigArt));
  final Rect painted = sprig.intersect(panel);
  for (final Rect control in _controlRects(tester)) {
    expect(painted.overlaps(control), isFalse, reason: '$reason $control');
  }
  expect(sprig.center.dy, closeTo(panel.center.dy, 1), reason: reason);
  expect(
    sprig.right,
    closeTo(panel.right - composerPanelBorderWidth + 8, 0.5),
    reason: reason,
  );
}

List<Override> _composerOverrides() => <Override>[
  noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
  draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
];

void main() {
  testWidgets('the sprig never overlaps header controls', (
    WidgetTester tester,
  ) async {
    const List<_Window> windows = <_Window>[
      (
        size: Size(390, 844),
        platform: TargetPlatform.android,
        keyboard: 0,
      ),
      (
        size: Size(844, 390),
        platform: TargetPlatform.android,
        keyboard: 200,
      ),
      (size: Size(900, 900), platform: TargetPlatform.macOS, keyboard: 0),
      (size: Size(1280, 900), platform: TargetPlatform.macOS, keyboard: 0),
      (size: Size(1920, 1200), platform: TargetPlatform.macOS, keyboard: 0),
      (
        size: Size(1280, 900),
        platform: TargetPlatform.android,
        keyboard: 0,
      ),
    ];
    bool checkedDesktop = false;

    for (final _Window window in windows) {
      final String reason = '${window.size} ${window.platform}';
      await _open(
        tester,
        window,
        _composerOverrides(),
        (BuildContext context) =>
            unawaited(showTextComposer(context, '2026-07-19')),
      );

      final Rect panel = tester.getRect(find.byKey(composerPanelKey));
      final bool roomy = panel.height >= composerPanelRoomyHeight;
      expect(
        find.byType(SprigArt),
        roomy ? findsOneWidget : findsNothing,
        reason: reason,
      );
      if (roomy) {
        _expectClearRightEdgeSprig(tester, reason);
      }
      if (window.size == const Size(1280, 900) &&
          window.platform == TargetPlatform.macOS) {
        expect(roomy, isTrue, reason: reason);
        checkedDesktop = true;
      }
    }

    expect(checkedDesktop, isTrue);
  });

  testWidgets('the default placement keeps the header corner sprig', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: ComposerShell(responsive: true, child: SizedBox(height: 200)),
      ),
    );

    final Positioned corner = tester.widget<Positioned>(
      find
          .ancestor(of: find.byType(SprigArt), matching: find.byType(Positioned))
          .first,
    );
    expect(corner.top, -10);
    expect(corner.right, -8);
  });

  testWidgets('the edit composer draws the sprig at the right edge', (
    WidgetTester tester,
  ) async {
    final Entry entry = Entry(
      id: 'entry-1',
      dayId: 'day-1',
      type: EntryType.text,
      textContent: 'a good day',
      createdAt: DateTime(2026, 7, 19, 14, 30).millisecondsSinceEpoch,
      updatedAt: 0,
    );
    await _open(
      tester,
      (size: const Size(1280, 900), platform: TargetPlatform.macOS, keyboard: 0),
      <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: <Entry>[entry]),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
      ],
      (BuildContext context) => unawaited(
        showEditNote(context, entry: entry, date: '2026-07-19'),
      ),
    );

    expect(find.byType(SprigArt), findsOneWidget);
    _expectClearRightEdgeSprig(tester, 'edit composer');
  });

  testWidgets('a short panel with the keyboard up draws no sprig', (
    WidgetTester tester,
  ) async {
    await _open(
      tester,
      (
        size: const Size(844, 390),
        platform: TargetPlatform.android,
        keyboard: 200,
      ),
      _composerOverrides(),
      (BuildContext context) =>
          unawaited(showTextComposer(context, '2026-07-19')),
    );

    expect(find.byType(TextComposerSheet), findsOneWidget);
    expect(find.byType(SprigArt), findsNothing);
  });
}
