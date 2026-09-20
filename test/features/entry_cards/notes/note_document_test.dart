import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/notes.dart';
import 'package:field_notes/features/entry_cards/notes/note_block_widgets.dart';
import 'package:field_notes/features/entry_cards/notes/note_document.dart';
import 'package:field_notes/features/entry_cards/notes/note_inline_span.dart';

const String _everyKind = '# Title\n\nbody **bold**\n\n- one\n- two\n\n'
    '> quote\n\n```\ncode\n```\n\n---\n\n![alt](photo/0123456789ab)';

Widget _harness(Widget child, {double width = 560}) {
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

Widget _bareHarness(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
}

RenderParagraph _paragraphOf(WidgetTester tester, String text) {
  return tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
}

Offset _positionOf(RenderParagraph paragraph, int offset) {
  const Rect caret = Rect.fromLTWH(0, 0, 2, 20);
  final Offset local =
      paragraph.getOffsetForCaret(TextPosition(offset: offset), caret) +
          Offset(0, paragraph.preferredLineHeight / 2);
  return paragraph.localToGlobal(local);
}

Iterable<TextSpan> _spans(InlineSpan span) sync* {
  if (span is TextSpan) {
    yield span;
    for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
      yield* _spans(child);
    }
  }
}

TextSpan _run(WidgetTester tester, String whole, String run) {
  final Text text = tester.widget<Text>(find.text(whole));
  return _spans(text.textSpan!)
      .firstWhere((TextSpan s) => s.toPlainText() == run && s.style != null);
}

List<MethodCall> _captureClipboard(WidgetTester tester) {
  final List<MethodCall> log = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      log.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return log;
}

Future<void> _pressWithControl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pumpAndSettle();
}

String _copiedText(List<MethodCall> log) {
  final MethodCall call =
      log.lastWhere((MethodCall c) => c.method == 'Clipboard.setData');
  return (call.arguments as Map<Object?, Object?>)['text']! as String;
}

void main() {
  group('NoteDocument', () {
    testWidgets('renders one block view per block in source order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(const NoteDocument(source: _everyKind)),
      );

      final List<Type> kinds = tester
          .widgetList<NoteBlockView>(find.byType(NoteBlockView))
          .map((NoteBlockView view) => view.block.runtimeType)
          .toList();
      expect(kinds, <Type>[
        HeadingBlock,
        ParagraphBlock,
        BulletBlock,
        BulletBlock,
        QuoteBlock,
        CodeBlock,
        DividerBlock,
        PhotoBlock,
      ]);
      expect(find.byType(NoteHeadingView), findsOneWidget);
      expect(find.byType(NoteParagraphView), findsOneWidget);
      expect(find.byType(NoteBulletView), findsNWidgets(2));
      expect(find.byType(NoteQuoteView), findsOneWidget);
      expect(find.byType(NoteCodeView), findsOneWidget);
      expect(find.byType(NoteDividerView), findsOneWidget);
      expect(find.byType(NotePhotoStub), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('body bold'), findsOneWidget);
      expect(find.text('quote'), findsOneWidget);
      expect(find.text('code'), findsOneWidget);
      expect(find.text('alt'), findsOneWidget);
    });

    testWidgets('sits under exactly one SelectionArea', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(const NoteDocument(source: _everyKind)),
      );

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(NoteSelectionScope), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SelectionArea),
          matching: find.byType(NoteBlockView),
        ),
        findsNWidgets(8),
      );
    });

    testWidgets('list markers are excluded from selection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(const NoteDocument(source: '- one\n\n2. two')),
      );

      for (final String marker in <String>['•', '2.']) {
        expect(
          find.ancestor(
            of: find.text(marker),
            matching: find.byWidgetPredicate(
              (Widget w) => w is SelectionContainer && w.delegate == null,
            ),
          ),
          findsOneWidget,
          reason: marker,
        );
      }
    });

    testWidgets('paragraph prose carries the note body style', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(const NoteDocument(source: 'a quiet morning')),
      );

      final Text text = tester.widget<Text>(find.text('a quiet morning'));
      expect(text.textSpan!.style, TypographyTokens.noteBody);
      expect(tester.getSize(find.text('a quiet morning')).width, 560);
    });

    testWidgets('inline styles reach the span tree', (
      WidgetTester tester,
    ) async {
      const String whole = 'a b c d e f';
      await tester.pumpWidget(
        _harness(const NoteDocument(source: 'a **b** *c* `d` ~~e~~ [f](g)')),
      );

      expect(_run(tester, whole, 'b').style, noteBoldStyle);
      expect(_run(tester, whole, 'c').style, noteItalicStyle);
      expect(_run(tester, whole, 'd').style!.fontFamily, TypographyTokens.mono);
      expect(_run(tester, whole, 'e').style, noteStrikeStyle);
      expect(_run(tester, whole, 'f').style, noteLinkStyle);
    });

    testWidgets('headings take the heading tokens', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(const NoteDocument(source: '# one\n\n## two\n\n### three')),
      );

      expect(tester.widget<Text>(find.text('one')).textSpan!.style,
          TypographyTokens.titleSerif);
      expect(tester.widget<Text>(find.text('two')).textSpan!.style,
          TypographyTokens.headlineSerif);
      expect(tester.widget<Text>(find.text('three')).textSpan!.style,
          TypographyTokens.bannerSerif);
    });

    testWidgets('renders without a selection region when no overlay exists', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _bareHarness(const NoteDocument(source: '# head\n\nbody')),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SelectionArea), findsNothing);
      expect(find.byType(NoteBlockView), findsNWidgets(2));
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('a selection across two blocks copies with the break kept', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> log = _captureClipboard(tester);
      await tester.pumpWidget(
        _harness(
          const NoteDocument(source: 'first paragraph\n\nsecond paragraph'),
        ),
      );
      await tester.pumpAndSettle();

      final RenderParagraph first = _paragraphOf(tester, 'first paragraph');
      final RenderParagraph second = _paragraphOf(tester, 'second paragraph');
      final TestGesture gesture = await tester.startGesture(
        _positionOf(first, 6),
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(_positionOf(second, 6));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(first.selections.single,
          const TextSelection(baseOffset: 6, extentOffset: 15));
      expect(second.selections.single,
          const TextSelection(baseOffset: 0, extentOffset: 6));

      await _pressWithControl(tester, LogicalKeyboardKey.keyC);

      expect(_copiedText(log), 'paragraph\n\nsecond');
    });

    testWidgets('select all copies every block separated by breaks', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> log = _captureClipboard(tester);
      await tester.pumpWidget(
        _harness(const NoteDocument(source: '# head\n\n- one\n- two\n\ntail')),
      );
      await tester.pumpAndSettle();

      final TestGesture gesture = await tester.startGesture(
        _positionOf(_paragraphOf(tester, 'tail'), 1),
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.up();
      await tester.pumpAndSettle();
      await _pressWithControl(tester, LogicalKeyboardKey.keyA);
      await _pressWithControl(tester, LogicalKeyboardKey.keyC);

      expect(_copiedText(log), 'head\n\none\n\ntwo\n\ntail');
    });
  });
}
