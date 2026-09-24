import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteReaderView;
import 'package:field_notes/features/note_engine/render/render_note_view.dart'
    show NoteViewBody, RenderNoteView;
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../notes/support/notes_harness.dart' show FakeNoteMediaResolver;

const Size _surface = Size(1200, 800);

Widget noteBodyHarness(Widget child, {double width = 360}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

Widget noteBodyAppHarness(Widget child, {double width = 360}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: NoteMediaScope(
            resolver: FakeNoteMediaResolver()..memoizeAll(),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpReader(
  WidgetTester tester,
  String text, {
  double width = 360,
}) async {
  tester.view.physicalSize = _surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    noteBodyAppHarness(NoteBody(text: text), width: width),
  );
  await tester.pump();
}

RenderNoteView _reader(WidgetTester tester) =>
    tester.renderObject<RenderNoteView>(
      find.descendant(
        of: find.byType(NoteReaderView),
        matching: find.byType(NoteViewBody),
      ),
    );

void main() {
  group('NoteBody', () {
    testWidgets('renders the note prose in the note body style', (
      WidgetTester tester,
    ) async {
      await _pumpReader(tester, 'a quiet morning');

      expect(find.byType(NoteReaderView), findsOneWidget);
      expect(
        tester.widget<NoteReaderView>(find.byType(NoteReaderView)).source,
        'a quiet morning',
      );
      final RenderNoteView reader = _reader(tester);
      expect(reader.visibleText.text, 'a quiet morning');
      expect(
        reader.noteLayout.fragments.first.lineBox.rect.height,
        closeTo(16 * 1.6, 0.01),
      );
    });

    testWidgets('renders Markdown as formatting-free visible text', (
      WidgetTester tester,
    ) async {
      await _pumpReader(tester, '# Morning\n\nquiet **rain**');

      final String visible = _reader(tester).visibleText.text;
      expect(visible, 'Morning\n\nquiet rain');
      expect(visible, isNot(contains('#')));
      expect(visible, isNot(contains('**')));
    });

    testWidgets('mounts the document as exactly one selectable reader', (
      WidgetTester tester,
    ) async {
      await _pumpReader(tester, 'one\n\ntwo');

      expect(find.byType(NoteReaderView), findsOneWidget);
      expect(
        tester.widget<NoteReaderView>(find.byType(NoteReaderView)).selectable,
        isTrue,
      );
      expect(find.byType(SelectionArea), findsNothing);
    });

    testWidgets('shows an empty-note affordance for blank text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(noteBodyHarness(const NoteBody(text: '   ')));

      expect(find.byType(NoteReaderView), findsNothing);
      expect(find.text('Empty note'), findsOneWidget);
      final Text text = tester.widget<Text>(find.text('Empty note'));
      expect(text.style!.fontFamily, TypographyTokens.serif);
      expect(text.style!.fontSize, TypographyTokens.noteBody.fontSize);
      expect(text.style!.fontStyle, FontStyle.italic);
      expect(text.style!.color, Palette.muted);
    });

    testWidgets('fills a narrow parent edge to edge', (
      WidgetTester tester,
    ) async {
      await _pumpReader(tester, 'a quiet morning');

      expect(tester.getSize(find.byType(NoteReaderView)).width, 360);
    });

    testWidgets('clamps the text column to 720 inside a wide parent', (
      WidgetTester tester,
    ) async {
      await _pumpReader(tester, 'a quiet morning', width: 900);

      expect(find.byType(NoteColumn), findsOneWidget);
      final Rect reader = tester.getRect(find.byType(NoteReaderView));
      expect(reader.width, 720);
      expect(reader.left, 90);
    });

    testWidgets('the empty-note affordance shares the same column', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        noteBodyHarness(const NoteBody(text: ''), width: 900),
      );

      expect(tester.getSize(find.text('Empty note')).width, 720);
    });
  });
}
