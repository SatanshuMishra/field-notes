import 'dart:io';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/capture/core/journal_note_writer.dart';
import 'package:field_notes/features/capture/photo/photo_picker.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorView;
import 'package:field_notes/state/draft_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/note_editor_driver.dart';
import '../../notes/support/notes_harness.dart'
    show FakePhotoImporter, denialError;
import '../core/capture_test_support.dart';

const String _heading = '# Morning\n\nbody here';
const String _draftKey = 'new-2026-07-19';
const Size _desktop = Size(1280, 900);
const Duration _longRest = Duration(seconds: 5);

Future<void> _pumpRoom(
  WidgetTester tester, {
  String initialText = '',
  TextEditingController? controller,
  ValueChanged<String>? onSave,
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  tester.view.physicalSize = _desktop;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(platform: platform),
      home: DialogHost(
        child: ComposerShell(
          responsive: true,
          child: TextComposerSheet(
            onSave: onSave ?? (String _) {},
            onCancel: () {},
            controller: controller,
            initialText: initialText,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _ComposerTrigger extends StatelessWidget {
  const _ComposerTrigger();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTextComposer(context, '2026-07-19'),
      child: const Text('open'),
    );
  }
}

Widget _composerApp({
  required NoteWriter writer,
  required FakeDraftStore drafts,
}) {
  return ProviderScope(
    overrides: <Override>[
      noteWriterProvider.overrideWith((Ref ref) => writer),
      draftStoreProvider.overrideWith((Ref ref) => drafts),
    ],
    child: captureHarness(const _ComposerTrigger()),
  );
}

String _titleText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(composerTitleFieldKey))
    .controller!
    .text;

Finder get _surfaceRing => find.descendant(
  of: find.byKey(composerWritingSurfaceKey),
  matching: find.byKey(focusRingKey),
);

Future<void> _pressChord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

Future<void> _useKeyboardHighlight(WidgetTester tester) async {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
}

void main() {
  group('the page outline', () {
    testWidgets('stays off while typing and rings the page after Tab', (
      WidgetTester tester,
    ) async {
      await _useKeyboardHighlight(tester);
      await _pumpRoom(tester);
      final NoteEditorDriver driver = NoteEditorDriver(tester);

      await driver.typeText('a quiet morning');
      await tester.pump();
      expect(_surfaceRing, findsNothing);

      await _pressChord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.tab,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(_surfaceRing, findsOneWidget);

      await driver.typeText('!');
      await tester.pump();
      expect(_surfaceRing, findsNothing);
    });

    testWidgets('stays off after a click in the title or the page', (
      WidgetTester tester,
    ) async {
      await _useKeyboardHighlight(tester);
      await _pumpRoom(tester);
      final Finder ring = find.descendant(
        of: find.byType(TextComposerSheet),
        matching: find.byKey(focusRingKey),
      );
      expect(ring, findsNothing);

      await tester.tap(find.byKey(composerTitleFieldKey));
      await tester.pump();
      expect(ring, findsNothing);

      await tester.tap(find.byKey(composerWritingSurfaceKey));
      await tester.pump();
      expect(ring, findsNothing);
    });
  });

  group('the title field', () {
    testWidgets('is one line, hints Add a title, and sits above the page', (
      WidgetTester tester,
    ) async {
      await _pumpRoom(tester);

      final TextField field = tester.widget<TextField>(
        find.byKey(composerTitleFieldKey),
      );
      expect(field.maxLines, 1);
      expect(find.text('Add a title'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(composerTitleFieldKey)).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(composerWritingSurfaceKey)).top,
        ),
      );

      await tester.enterText(find.byKey(composerTitleFieldKey), 'one\ntwo');
      await tester.pump();
      expect(_titleText(tester), isNot(contains('\n')));
    });

    testWidgets('saves with the note through the titled source', (
      WidgetTester tester,
    ) async {
      final List<String> saved = <String>[];
      await _pumpRoom(tester, onSave: saved.add);

      await NoteEditorDriver(tester).enterText('went walking');
      await tester.enterText(find.byKey(composerTitleFieldKey), 'Tuesday');
      await tester.pump();
      await _pressChord(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.enter,
      );

      expect(saved, <String>[
        titledNoteSource(title: 'Tuesday', body: 'went walking'),
      ]);
    });

    testWidgets('leaves an untitled note as plain source', (
      WidgetTester tester,
    ) async {
      final List<String> saved = <String>[];
      await _pumpRoom(tester, onSave: saved.add);

      await NoteEditorDriver(tester).enterText('went walking');
      await _pressChord(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.enter,
      );

      expect(saved, <String>['went walking']);
    });

    testWidgets('is written to the draft and comes back from it', (
      WidgetTester tester,
    ) async {
      final FakeDraftStore drafts = FakeDraftStore();
      await tester.pumpWidget(
        _composerApp(writer: FakeNoteWriter(), drafts: drafts),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await NoteEditorDriver(tester).enterText('went walking');
      await tester.enterText(find.byKey(composerTitleFieldKey), 'Tuesday');
      await tester.pump(draftIdleDebounceForTest);

      expect(drafts.drafts, <String, String>{
        _draftKey: titledNoteSource(title: 'Tuesday', body: 'went walking'),
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final FakeNoteWriter writer = FakeNoteWriter();
      await tester.pumpWidget(_composerApp(writer: writer, drafts: drafts));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(DraftRestoredChip), findsOneWidget);
      expect(_titleText(tester), 'Tuesday');
      expect(NoteEditorDriver(tester).source, 'went walking');

      await tester.tap(find.text('Keep this'));
      await tester.pumpAndSettle();

      expect(writer.saves.single.source, 'went walking');
      expect(writer.saves.single.title, 'Tuesday');
    });
  });

  group('a note that begins with a heading', () {
    testWidgets('opens with the heading in the title and out of the body', (
      WidgetTester tester,
    ) async {
      await _pumpRoom(tester, initialText: _heading);

      expect(_titleText(tester), 'Morning');
      expect(NoteEditorDriver(tester).source, 'body here');
    });

    testWidgets('stays byte for byte the same unless it is saved', (
      WidgetTester tester,
    ) async {
      final TextEditingController source = TextEditingController(
        text: _heading,
      );
      addTearDown(source.dispose);
      await _pumpRoom(tester, controller: source);
      await tester.pump(_longRest);

      expect(source.text, _heading);

      await tester.enterText(find.byKey(composerTitleFieldKey), 'Evening');
      await tester.pump();
      expect(source.text, isNot(_heading));

      await tester.enterText(find.byKey(composerTitleFieldKey), 'Morning');
      await tester.pump();
      expect(source.text, _heading);
    });

    testWidgets('carries the lifted title when it is saved', (
      WidgetTester tester,
    ) async {
      final List<String> saved = <String>[];
      await _pumpRoom(tester, initialText: _heading, onSave: saved.add);

      await _pressChord(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.enter,
      );

      expect(saved, <String>[
        titledNoteSource(title: 'Morning', body: 'body here'),
      ]);
    });

    testWidgets('keeps a heading that is not first in the body', (
      WidgetTester tester,
    ) async {
      const String note = 'a line\n\n# Later';
      await _pumpRoom(tester, initialText: note);

      expect(_titleText(tester), isEmpty);
      expect(NoteEditorDriver(tester).source, note);
    });
  });

  testWidgets('the placeholder is static and nothing offers a shuffle', (
    WidgetTester tester,
  ) async {
    await _pumpRoom(tester);
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final double? painted = driver.paintedHint?.longestLine;
    expect(painted, isNotNull);
    expect(
      tester.widget<TextComposerSheet>(find.byType(TextComposerSheet)).hintText,
      'Start writing…',
    );

    for (int rest = 0; rest < 4; rest++) {
      await tester.pump(_longRest);
      expect(driver.paintedHint?.longestLine, painted);
    }

    await driver.enterText('words');
    await tester.pump();
    expect(driver.paintedHint, isNull);

    await driver.enterText('');
    await tester.pump();
    expect(driver.paintedHint?.longestLine, painted);

    expect(
      find.textContaining(RegExp('shuffle', caseSensitive: false)),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget.key.toString().toLowerCase().contains('shuffle'),
      ),
      findsNothing,
    );
  });

  for (final ({TargetPlatform platform, LogicalKeyboardKey modifier}) chord
      in <({TargetPlatform platform, LogicalKeyboardKey modifier})>[
        (platform: TargetPlatform.macOS, modifier: LogicalKeyboardKey.metaLeft),
        (
          platform: TargetPlatform.windows,
          modifier: LogicalKeyboardKey.controlLeft,
        ),
      ]) {
    testWidgets('${chord.platform.name} keeps with its own shortcut', (
      WidgetTester tester,
    ) async {
      final List<String> saved = <String>[];
      await _pumpRoom(tester, onSave: saved.add, platform: chord.platform);

      await NoteEditorDriver(tester).enterText('kept');
      await _pressChord(tester, chord.modifier, LogicalKeyboardKey.enter);

      expect(saved, <String>['kept']);
    });
  }

  testWidgets('a refused pick in the room says so with the close glyph', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = _desktop;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: DialogHost(
          child: ComposerShell(
            responsive: true,
            child: TextComposerSheet(
              onSave: (String _) {},
              onCancel: () {},
              onAddPhoto: FakePhotoImporter(error: denialError).call,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await NoteEditorDriver(
      tester,
    ).press(find.byKey(composerAddPhotoKey), const Duration(milliseconds: 110));
    await tester.pump();

    expect(find.text(photoLibraryErrorMessage), findsOneWidget);
    expect(
      tester
          .widget<IconStickerGlyphIcon>(
            find.descendant(
              of: find.byType(Toast),
              matching: find.byType(IconStickerGlyphIcon),
            ),
          )
          .glyph,
      IconStickerGlyph.close,
    );

    await tester.pump(kToastLifetime);
    await tester.pump();
  });

  testWidgets('a layout change keeps the editor and its pending photo', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DialogHost(
          child: ComposerShell(
            responsive: true,
            child: TextComposerSheet(onSave: (String _) {}, onCancel: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    final State editor = tester.state(find.byType(NoteEditorView));

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(find.byKey(composerTitleFieldKey), findsOneWidget);
    expect(
      identical(tester.state(find.byType(NoteEditorView)), editor),
      isTrue,
    );
  });

  test('no SprigArt is left in the composer', () {
    expect(File('lib/design/art/sprig_art.dart').existsSync(), isFalse);
    for (final String path in <String>[
      'lib/features/capture/text/text_composer_sheet.dart',
      'lib/features/capture/text/text_composer.dart',
      'lib/features/capture/text/composer_footer.dart',
      'lib/features/capture/core/composer_shell.dart',
    ]) {
      expect(
        File(path).readAsStringSync().toLowerCase(),
        isNot(contains('sprig')),
        reason: path,
      );
    }
  });
}
