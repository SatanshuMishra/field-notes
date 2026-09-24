import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdPhotoSide, MdPhotoSize;
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorView, NoteReaderView;
import 'package:field_notes/features/note_engine/render/photo_figure.dart'
    show
        PhotoFigure,
        photoFigureFrameKey,
        photoFigureUnavailableKey,
        photoFigureUnavailableLabel;
import 'package:field_notes/features/note_engine/render/render_note_view.dart'
    show NoteViewBody, RenderNoteView;
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../../support/note_editor_driver.dart';
import '../../support/photo_line_fixture.dart';
import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, FakeNoteWriter;
import '../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository, FakeMediaStore, entryOf;
import '../entry_cards/support/entry_cards_harness.dart' show FakeMediaResolver;
import '../notes/support/notes_harness.dart'
    show availablePhoto, photoIdA, photoIdB, prefixOf;

const Duration _hold = Duration(milliseconds: 110);

void _pinWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openViewer(
  WidgetTester tester, {
  required List<Entry> entries,
  required String entryId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: entries),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(
              showLogViewer(
                context,
                date: '2026-07-19',
                entryId: entryId,
                exit: LogViewerExit.close,
              ),
            ),
            child: const Text('open log'),
          ),
        ),
      ),
    ),
  );
  await NoteEditorDriver(tester).press(find.text('open log'), _hold);
  await tester.pumpAndSettle();
}

RenderNoteView _reader(WidgetTester tester) =>
    tester.renderObject<RenderNoteView>(
      find.descendant(
        of: find.byType(NoteReaderView),
        matching: find.byType(NoteViewBody),
      ),
    );

void main() {
  testWidgets('the note viewer lays out a six hundred eighty eight pixel '
      'column in a 1280 pixel window', (WidgetTester tester) async {
    _pinWindow(tester, const Size(1280, 900));

    await _openViewer(
      tester,
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'A harbour morning.'),
      ],
      entryId: 'entry-1',
    );

    expect(tester.getSize(find.byKey(composerPanelKey)).width, 768);
    expect(tester.getSize(find.byType(NoteReaderView)).width, 688);
  });

  testWidgets('the note viewer caps its column at 45 em in a 1920 window', (
    WidgetTester tester,
  ) async {
    _pinWindow(tester, const Size(1920, 1200));

    await _openViewer(
      tester,
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'A harbour morning.'),
      ],
      entryId: 'entry-1',
    );

    expect(tester.getSize(find.byType(NoteReaderView)).width, 720);
  });

  testWidgets('the composer writes in the same 688 column in a 1280 window', (
    WidgetTester tester,
  ) async {
    _pinWindow(tester, const Size(1280, 900));
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          noteWriterProvider.overrideWith((Ref ref) => FakeNoteWriter()),
          draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(showTextComposer(context, '2026-07-19')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await NoteEditorDriver(tester).press(find.text('open'), _hold);
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(NoteEditorView)).width, 688);
  });

  testWidgets('an arrow key in the edit composer moves the caret, not the '
      'viewer', (WidgetTester tester) async {
    _pinWindow(tester, const Size(1280, 900));
    const String second = 'The second note of the day.';
    await _openViewer(
      tester,
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'The first note.'),
        entryOf(id: 'entry-2', type: EntryType.text, textContent: second),
      ],
      entryId: 'entry-2',
    );
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    await driver.press(find.byKey(logActionsEditKey), _hold);
    await tester.pumpAndSettle();

    expect(driver.source, second);
    final TextSelection before = driver.selection;
    expect(before.isCollapsed, isTrue);

    await driver.pressKey(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(driver.source, second);
    expect(
      driver.selection,
      TextSelection.collapsed(offset: before.extentOffset - 1),
    );
  });

  group('view mode note photos', () {
    FakeMediaResolver photoResolver() {
      return FakeMediaResolver()
        ..set(prefixOf(photoIdA), availablePhoto(photoIdA))
        ..set(
          prefixOf(photoIdB),
          availablePhoto(photoIdB, width: 900, height: 1600),
        );
    }

    Future<void> pumpNote(
      WidgetTester tester,
      String text, {
      MediaResolver? resolver,
      double width = 320,
    }) async {
      _pinWindow(tester, const Size(1200, 2000));
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: NoteMediaScope(
                    resolver: resolver ?? photoResolver(),
                    child: NoteBody(text: text),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('every photo is the column width at a 320 phone column, and '
        'four distinct centred widths at 688', (WidgetTester tester) async {
      for (final MdPhotoSize size in MdPhotoSize.values) {
        await pumpNote(
          tester,
          'before\n${mdPhotoLine(photoIdA, size: size)}\nafter',
        );

        expect(
          tester.getSize(find.byKey(photoFigureFrameKey)).width,
          closeTo(320, 0.01),
          reason: size.name,
        );
      }

      final Map<MdPhotoSize, double> expected = <MdPhotoSize, double>{
        MdPhotoSize.small: 229.33,
        MdPhotoSize.medium: 344,
        MdPhotoSize.large: 458.67,
        MdPhotoSize.full: 688,
      };
      final List<double> widths = <double>[];
      for (final MdPhotoSize size in MdPhotoSize.values) {
        await pumpNote(
          tester,
          'before\n'
          '${mdPhotoLine(photoIdA, side: MdPhotoSide.centre, size: size)}\n'
          'after',
          width: 688,
        );

        final Finder frame = find.byKey(photoFigureFrameKey);
        expect(frame, findsOneWidget);
        expect(
          tester.getSize(frame).width,
          closeTo(expected[size]!, 0.01),
          reason: size.name,
        );
        expect(
          tester.getCenter(frame).dx,
          closeTo(tester.getCenter(find.byType(NoteReaderView)).dx, 0.01),
          reason: size.name,
        );
        widths.add(tester.getSize(frame).width);
      }

      expect(widths.toSet(), hasLength(4));
    });

    testWidgets('the block keeps the photo aspect and clamps a tall portrait', (
      WidgetTester tester,
    ) async {
      final String fullA = mdPhotoLine(photoIdA, size: MdPhotoSize.full);
      final String fullB = mdPhotoLine(photoIdB, size: MdPhotoSize.full);
      await pumpNote(tester, '$fullA\n$fullB');

      final Finder frames = find.byKey(photoFigureFrameKey);
      expect(frames, findsNWidgets(2));
      expect(tester.getSize(frames.at(0)).height, closeTo(320 / 1.5, 0.01));
      expect(tester.getSize(frames.at(1)).height, closeTo(1.6 * 320, 0.01));

      await pumpNote(tester, fullB, width: 688);

      expect(
        tester.getSize(find.byKey(photoFigureFrameKey)).height,
        closeTo(1100.8, 0.01),
      );
    });

    testWidgets('renders the photo inline and nowhere else', (
      WidgetTester tester,
    ) async {
      await pumpNote(tester, 'before\n${mdPhotoLine(photoIdA)}\nafter');

      expect(find.byType(PhotoFigure), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PhotoFigure),
          matching: find.byType(MediaImage),
        ),
        findsOneWidget,
      );
      expect(_reader(tester).visibleText.text, 'before\n\u{FFFC}\nafter');
    });

    testWidgets('the alt slot is the caption and the screen-reader label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpNote(
        tester,
        mdPhotoLine(photoIdA, caption: 'the porch at dusk'),
      );

      expect(find.text('the porch at dusk'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Photo, the porch at dusk'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('an unresolvable reference renders the unavailable chip', (
      WidgetTester tester,
    ) async {
      await pumpNote(
        tester,
        'before\n![](photo/0123456789ab "right medium")\nafter',
      );

      expect(find.byKey(photoFigureUnavailableKey), findsOneWidget);
      expect(find.text(photoFigureUnavailableLabel), findsOneWidget);
      expect(find.byKey(photoFigureFrameKey), findsNothing);
      expect(_reader(tester).visibleText.text, endsWith('after'));
    });

    testWidgets('an unavailable photo still announces its caption', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpNote(
        tester,
        '![the porch at dusk](photo/0123456789ab "right medium")',
      );

      expect(find.byKey(photoFigureUnavailableKey), findsOneWidget);
      expect(
        find.bySemanticsLabel('Photo, the porch at dusk'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('a pending resolve holds the planned box instead of jumping', (
      WidgetTester tester,
    ) async {
      final String full = mdPhotoLine(photoIdA, size: MdPhotoSize.full);
      await pumpNote(tester, full, resolver: const _NeverResolver());
      for (int i = 0; i < 5; i++) {
        await tester.pump();
        expect(find.byType(PhotoFigure), findsNothing);
        expect(tester.takeException(), isNull);
      }

      final _LateResolver late = _LateResolver();
      await pumpNote(tester, full, resolver: late);
      late.complete(availablePhoto(photoIdA));
      Size? first;
      for (int i = 0; i < 10 && first == null; i++) {
        await tester.pump();
        if (find.byType(PhotoFigure).evaluate().isNotEmpty) {
          first = tester.getSize(find.byType(PhotoFigure));
        }
      }

      expect(first, isNotNull);
      expect(first!.width, closeTo(320, 0.01));
      expect(
        tester.getSize(find.byKey(photoFigureFrameKey)).height,
        closeTo(213.33, 0.01),
      );
    });
  });
}

class _NeverResolver implements MediaResolver {
  const _NeverResolver();

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) =>
      Completer<ResolvedMedia>().future;
}

class _LateResolver implements MediaResolver {
  final Completer<ResolvedMedia> _pending = Completer<ResolvedMedia>();

  void complete(ResolvedMedia media) => _pending.complete(media);

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) => _pending.future;
}
