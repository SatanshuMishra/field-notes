import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/note_engine.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;
import 'package:field_notes/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/note_editor_driver.dart';
import '../../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, prefixOf;
import '../core/capture_test_support.dart';

const Duration _hold = Duration(milliseconds: 110);

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

NoteEditorView _view(WidgetTester tester) =>
    tester.widget<NoteEditorView>(find.byType(NoteEditorView));

class _ComposerTrigger extends StatelessWidget {
  const _ComposerTrigger({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTextComposer(context, date),
      child: const Text('open'),
    );
  }
}

Widget _composerApp({
  FakeNoteWriter? writer,
  FakeDraftStore? drafts,
  List<Override> overrides = const <Override>[],
  bool watchTextScale = false,
}) {
  const Widget trigger = _ComposerTrigger(date: '2026-07-19');
  return ProviderScope(
    overrides: <Override>[
      noteWriterProvider.overrideWith((Ref ref) => writer ?? FakeNoteWriter()),
      draftStoreProvider.overrideWith((Ref ref) => drafts ?? FakeDraftStore()),
      ...overrides,
    ],
    child: captureHarness(
      watchTextScale
          ? Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                ref.watch(textScaleProvider);
                return child!;
              },
              child: trigger,
            )
          : trigger,
    ),
  );
}

Future<void> _open(WidgetTester tester, Widget app) async {
  _pinSurface(tester);
  await tester.pumpWidget(app);
  await NoteEditorDriver(tester).press(find.text('open'), _hold);
  await tester.pumpAndSettle();
}

Future<void> _pumpSheet(WidgetTester tester, Widget sheet) async {
  _pinSurface(tester);
  await tester.pumpWidget(
    captureHarness(
      NoteMediaScope(
        resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
          prefixOf(photoIdA): availablePhoto(photoIdA),
        })..memoizeAll(),
        child: sheet,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TextEditingController _plain(String text) {
  final TextEditingController controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  testWidgets('the composer writes with the new note editor', (
    WidgetTester tester,
  ) async {
    final List<String> saved = <String>[];
    _pinSurface(tester);
    await tester.pumpWidget(
      captureHarness(TextComposerSheet(onSave: saved.add, onCancel: () {})),
    );
    await tester.pump();
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(find.byType(NoteEditorView), findsOneWidget);
    expect(find.byKey(noteEditorKey), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    expect(_view(tester).controller, isA<NoteEditorController>());

    await driver.enterText('a good day');
    await driver.press(find.text('Save'), _hold);

    expect(saved, <String>['a good day']);

    final TextEditingController plain = _plain('');
    await tester.pumpWidget(
      captureHarness(
        TextComposerSheet(
          key: const ValueKey<String>('attached-sheet'),
          controller: plain,
          onSave: (String _) {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump();
    await driver.enterText('draft');

    expect(plain.text, 'draft');
  });

  testWidgets('a new note opens focused with the caret at the start', (
    WidgetTester tester,
  ) async {
    await _open(tester, _composerApp());
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(_view(tester).focusNode.hasPrimaryFocus, isTrue);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(driver.selection, const TextSelection.collapsed(offset: 0));

    await driver.typeText('hello');

    expect(driver.source, 'hello');
  });

  testWidgets('editing a note that ends with a photo puts the caret above it', (
    WidgetTester tester,
  ) async {
    final TextEditingController plain = _plain(
      'Low tide at noon\n![](photo/a1b2c3d4e5f6 "left medium")',
    );
    await _pumpSheet(
      tester,
      TextComposerSheet(
        controller: plain,
        onSave: (String _) {},
        onCancel: () {},
      ),
    );
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(driver.selection, const TextSelection.collapsed(offset: 16));
    expect(_view(tester).focusNode.hasPrimaryFocus, isTrue);
    expect(find.byKey(const ValueKey<String>('photo-toolbar')), findsNothing);
  });

  testWidgets('escape with nothing to dismiss asks to discard', (
    WidgetTester tester,
  ) async {
    await _open(tester, _composerApp());
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    await driver.typeText('never mind');
    await driver.pressKey(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text(composerDiscardTitle), findsOneWidget);
    expect(find.byType(TextComposerSheet), findsOneWidget);

    await driver.press(find.byKey(composerKeepEditingKey), _hold);
    await tester.pumpAndSettle();

    expect(find.text(composerDiscardTitle), findsNothing);
    expect(_view(tester).focusNode.hasFocus, isTrue);
    expect(driver.source, 'never mind');
  });

  testWidgets('an edit composer opens with the caret at the end', (
    WidgetTester tester,
  ) async {
    await _pumpSheet(
      tester,
      TextComposerSheet(
        controller: _plain('a good day'),
        onSave: (String _) {},
        onCancel: () {},
      ),
    );

    expect(
      NoteEditorDriver(tester).selection,
      const TextSelection.collapsed(offset: 10),
    );
  });

  testWidgets('a note that is only a photo opens with the caret at the start', (
    WidgetTester tester,
  ) async {
    await _pumpSheet(
      tester,
      TextComposerSheet(
        controller: _plain('![](photo/a1b2c3d4e5f6 "left medium")'),
        onSave: (String _) {},
        onCancel: () {},
      ),
    );

    expect(
      NoteEditorDriver(tester).selection,
      const TextSelection.collapsed(offset: 0),
    );
  });

  testWidgets('a restored draft shows with the caret at its end and no undo', (
    WidgetTester tester,
  ) async {
    await _open(
      tester,
      _composerApp(
        drafts: FakeDraftStore(
          drafts: <String, String>{'new-2026-07-19': 'left by a crash'},
        ),
      ),
    );
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(driver.source, 'left by a crash');
    expect(driver.selection, const TextSelection.collapsed(offset: 15));
    expect(
      tester.getSemantics(find.byKey(formatUndoKey)),
      isSemantics(isEnabled: false),
    );
  });

  testWidgets('a clean new composer closes on escape without a prompt', (
    WidgetTester tester,
  ) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    await _open(tester, _composerApp(writer: writer));

    await NoteEditorDriver(tester).pressKey(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text(composerDiscardTitle), findsNothing);
    expect(find.byType(TextComposerSheet), findsNothing);
    expect(writer.saves, isEmpty);
  });

  testWidgets('the driver replaces formatted text and types across instances', (
    WidgetTester tester,
  ) async {
    await _pumpSheet(
      tester,
      TextComposerSheet(
        initialText: '# Title\n\nsome **bold**',
        onSave: (String _) {},
        onCancel: () {},
      ),
    );

    await NoteEditorDriver(tester).enterText('plain');

    expect(NoteEditorDriver(tester).source, 'plain');

    await _pumpSheet(
      tester,
      TextComposerSheet(
        key: const ValueKey<String>('empty-sheet'),
        onSave: (String _) {},
        onCancel: () {},
      ),
    );
    await NoteEditorDriver(tester).typeText('a');
    await NoteEditorDriver(tester).typeText('b');

    expect(NoteEditorDriver(tester).source, 'ab');
  });

  testWidgets('the composer follows the spell-check setting when it is live', (
    WidgetTester tester,
  ) async {
    final Override settings = appSettingsProvider.overrideWith(
      (Ref ref) => Stream<AppSettings>.value(
        AppSettings.defaults.copyWith(spellCheckEnabled: true),
      ),
    );
    await _open(
      tester,
      _composerApp(overrides: <Override>[settings], watchTextScale: true),
    );

    expect(_view(tester).spellCheckEnabled, spellCheckAvailable);
  });

  testWidgets('the composer never opens the settings on its own', (
    WidgetTester tester,
  ) async {
    final Override settings = appSettingsProvider.overrideWith(
      (Ref ref) => Stream<AppSettings>.value(
        AppSettings.defaults.copyWith(spellCheckEnabled: true),
      ),
    );
    await _open(tester, _composerApp(overrides: <Override>[settings]));

    expect(_view(tester).spellCheckEnabled, isFalse);
  });

  testWidgets('the composer hands the editor a photo media importer', (
    WidgetTester tester,
  ) async {
    await _open(tester, _composerApp());

    expect(_view(tester).photoMediaImporter, isNotNull);
  });
}
