import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/capture/core/capture_test_support.dart';
import '../features/notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, photoIdB, prefixOf;
import 'note_editor_driver.dart';

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpComposer(
  WidgetTester tester, {
  String initialText = '',
  ValueChanged<String>? onSave,
}) async {
  _pinSurface(tester);
  await tester.pumpWidget(
    captureHarness(
      TextComposerSheet(
        onSave: onSave ?? (String _) {},
        onCancel: () {},
        initialText: initialText,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpPhotoNote(WidgetTester tester, String source) async {
  _pinSurface(tester);
  await tester.pumpWidget(
    captureHarness(
      NoteMediaScope(
        resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
          prefixOf(photoIdA): availablePhoto(photoIdA),
          prefixOf(photoIdB): availablePhoto(photoIdB),
        })..memoizeAll(),
        child: TextComposerSheet(
          onSave: (String _) {},
          onCancel: () {},
          initialText: source,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the driver types into the composer and reads the source', (
    WidgetTester tester,
  ) async {
    final List<String> saved = <String>[];
    _pinSurface(tester);
    await tester.pumpWidget(
      captureHarness(TextComposerSheet(onSave: saved.add, onCancel: () {})),
    );
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(driver.find, findsOneWidget);

    await driver.enterText('hello');
    expect(driver.source, 'hello');
    expect(driver.visibleText, 'hello');
    expect(driver.selection, const TextSelection.collapsed(offset: 5));

    await driver.typeText(' world');
    expect(driver.source, 'hello world');

    await driver.setSelection(const TextSelection.collapsed(offset: 5));
    await driver.typeText(',');
    expect(driver.source, 'hello, world');
    expect(driver.selection, const TextSelection.collapsed(offset: 6));

    await driver.press(
      find.text('Save'),
      const Duration(milliseconds: 110),
    );
    expect(saved, <String>['hello, world']);
  });

  testWidgets('the driver finds the nth photo in document order', (
    WidgetTester tester,
  ) async {
    const String source =
        'first\n\n![](photo/a1b2c3d4e5f6 "right full")\n\nsecond\n\n'
        '![](photo/b2c3d4e5f6a1 "right full")\n\nthird\n\n'
        '![](photo/a1b2c3d4e5f6 "right full")';
    expect(source, contains(prefixOf(photoIdA)));
    expect(source, contains(prefixOf(photoIdB)));
    await _pumpPhotoNote(tester, source);
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(driver.photoFinder(0), findsOneWidget);
    expect(driver.photoFinder(1), findsOneWidget);
    expect(driver.photoFinder(2), findsOneWidget);
    expect(driver.photoFinder(3), findsNothing);

    final double first = tester.getRect(driver.photoFinder(0)).top;
    final double second = tester.getRect(driver.photoFinder(1)).top;
    final double third = tester.getRect(driver.photoFinder(2)).top;
    expect(second, greaterThan(first));
    expect(third, greaterThan(second));
  });

  testWidgets('a held press waits the requested time before release', (
    WidgetTester tester,
  ) async {
    const Key k = ValueKey<String>('held-target');
    int taps = 0;
    DateTime? downAt;
    DateTime? upAt;
    int? tapsAtDown;
    int? tapsAtUp;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Listener(
            onPointerDown: (PointerDownEvent _) {
              downAt = tester.binding.clock.now();
              tapsAtDown = taps;
            },
            onPointerUp: (PointerUpEvent _) {
              upAt = tester.binding.clock.now();
              tapsAtUp = taps;
            },
            child: GestureDetector(
              key: k,
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(width: 100, height: 40),
            ),
          ),
        ),
      ),
    );
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    for (final int hold in <int>[30, 110, 300]) {
      final int before = taps;
      await driver.press(find.byKey(k), Duration(milliseconds: hold));
      expect(upAt!.difference(downAt!), Duration(milliseconds: hold));
      expect(tapsAtDown, before);
      expect(tapsAtUp, before);
      expect(taps, before + 1);
    }
  });

  testWidgets('an arrow key moves the caret one unit', (
    WidgetTester tester,
  ) async {
    await _pumpComposer(tester);
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    await driver.enterText('abc');
    await driver.pressKey(LogicalKeyboardKey.arrowLeft);

    expect(driver.selection, const TextSelection.collapsed(offset: 2));
  });

  testWidgets('the caret rect sits inside the editor and follows the offset', (
    WidgetTester tester,
  ) async {
    await _pumpComposer(tester);
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    await driver.enterText('abc');

    await driver.setSelection(const TextSelection.collapsed(offset: 0));
    final Rect start = driver.caretRect;
    await driver.setSelection(const TextSelection.collapsed(offset: 3));
    final Rect end = driver.caretRect;
    final Rect editor = tester.getRect(driver.find);

    expect(editor.contains(start.center), isTrue);
    expect(editor.contains(end.center), isTrue);
    expect(end.left, greaterThan(start.left));
  });

  testWidgets('the content rect spans the column and the whole note', (
    WidgetTester tester,
  ) async {
    await _pumpComposer(
      tester,
      initialText: List<String>.filled(80, 'a long line').join('\n'),
    );
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final Rect editor = tester.getRect(driver.find);
    final Rect content = driver.contentRect;

    expect(content.left, editor.left);
    expect(content.width, editor.width);
    expect(content.height, greaterThanOrEqualTo(80 * 25.6 - 0.5));
  });

  testWidgets('the body style is the note body type', (
    WidgetTester tester,
  ) async {
    await _pumpComposer(tester);
    final TextStyle style = NoteEditorDriver(tester).style;

    expect(style.fontFamily, TypographyTokens.noteBody.fontFamily);
    expect(style.fontSize, TypographyTokens.noteBody.fontSize);
    expect(style.fontWeight, TypographyTokens.noteBody.fontWeight);
    expect(style.height, TypographyTokens.noteBody.height);
  });

  testWidgets('the hint style shows only while the note is empty', (
    WidgetTester tester,
  ) async {
    await _pumpComposer(tester);
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(driver.visibleHintStyle, TypographyTokens.noteBodyPlaceholder);

    await driver.enterText('x');

    expect(driver.visibleHintStyle, isNull);
  });

  testWidgets('typing without an input connection throws', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Text('no editor here'),
      ),
    );

    await expectLater(
      NoteEditorDriver(tester).typeText('x'),
      throwsStateError,
    );
  });

  testWidgets('a photo past the photo count finds nothing', (
    WidgetTester tester,
  ) async {
    await _pumpPhotoNote(
      tester,
      'one\n\n![](photo/a1b2c3d4e5f6 "right full")\n\ntwo\n\n'
      '![](photo/b2c3d4e5f6a1 "right full")',
    );

    expect(NoteEditorDriver(tester).photoFinder(5), findsNothing);
  });
}
