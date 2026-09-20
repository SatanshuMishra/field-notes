import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/entry_cards/notes/note_block_widgets.dart';
import 'package:field_notes/features/entry_cards/notes/note_document.dart';

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
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  group('NoteBody', () {
    testWidgets('renders the note prose in the note body style', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        noteBodyHarness(const NoteBody(text: 'a quiet morning')),
      );

      expect(find.byType(NoteDocument), findsOneWidget);
      final Text text = tester.widget<Text>(find.text('a quiet morning'));
      final TextStyle style = text.textSpan!.style!;
      expect(style, TypographyTokens.noteBody);
      expect(style.fontFamily, TypographyTokens.serif);
      expect(style.fontSize, 16);
      expect(style.height, 1.6);
    });

    testWidgets('renders Markdown as per-block widgets', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        noteBodyHarness(const NoteBody(text: '# Morning\n\nquiet **rain**')),
      );

      expect(find.byType(NoteBlockView), findsNWidgets(2));
      expect(find.byType(NoteHeadingView), findsOneWidget);
      expect(find.byType(NoteParagraphView), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('quiet rain'), findsOneWidget);
      expect(find.textContaining('#'), findsNothing);
      expect(find.textContaining('**'), findsNothing);
    });

    testWidgets('mounts the document under exactly one SelectionArea', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        noteBodyAppHarness(const NoteBody(text: 'one\n\ntwo')),
      );

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SelectionArea),
          matching: find.byType(NoteBlockView),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('shows an empty-note affordance for blank text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(noteBodyHarness(const NoteBody(text: '   ')));

      expect(find.byType(NoteDocument), findsNothing);
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
      await tester.pumpWidget(
        noteBodyHarness(const NoteBody(text: 'a quiet morning')),
      );

      expect(tester.getSize(find.text('a quiet morning')).width, 360);
    });

    testWidgets('clamps the text column to 560 inside a wide parent', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        noteBodyHarness(const NoteBody(text: 'a quiet morning'), width: 900),
      );

      expect(find.byType(NoteColumn), findsOneWidget);
      final Rect text = tester.getRect(find.text('a quiet morning'));
      expect(text.width, 560);
      expect(text.left, 170);
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

      expect(tester.getSize(find.text('Empty note')).width, 560);
    });
  });
}
