import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/text/editor/editor.dart';

const List<String> _corpus = <String>[
  '',
  'plain text with no markers at all',
  '**bold** and _italic_ and ~~struck~~',
  '# one\n## two\n### three',
  '- first\n- second\n1. third',
  '> quoted line\n> and another',
  'a [link](https://example.com) inside a sentence',
  'inline `code` and a fence:\n```dart\nfinal x = 1;\n```',
  '![alt](photo/7f3ac91b2d4e "right medium")',
  '---',
  'unclosed **bold and _italic',
  '***triple*** and ****quad****',
  'trailing markers **\n_ \n> \n# ',
  'emoji 🌲 with **bold 🌲** inside',
  'windows\r\nline\r\nendings',
  '\n\n\n',
  '   leading spaces and a # not-a-heading',
  '[unclosed](link\nand [another](https://a.b)',
];

const String _markerAlphabet = '*_~`[]()#>- \n.abc';

String _fuzz(Random random) {
  final int length = random.nextInt(120);
  return String.fromCharCodes(<int>[
    for (int i = 0; i < length; i++)
      _markerAlphabet.codeUnitAt(random.nextInt(_markerAlphabet.length)),
  ]);
}

TextStyle? _styleAt(TextSpan span, int offset) {
  final List<InlineSpan> children = span.children ?? <InlineSpan>[];
  int cursor = 0;
  for (final InlineSpan child in children) {
    final String text = child.toPlainText(includeSemanticsLabels: false);
    if (offset < cursor + text.length) {
      return child.style;
    }
    cursor += text.length;
  }
  return span.style;
}

void main() {
  late BuildContext context;

  Future<void> pumpContext(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  TextSpan buildFor(
    String text, {
    TextRange? composing,
    bool withComposing = false,
    int styleLimit = MarkdownStyleController.liveStyleLimit,
  }) {
    final MarkdownStyleController controller =
        MarkdownStyleController(styleLimit: styleLimit);
    addTearDown(controller.dispose);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: composing ?? TextRange.empty,
    );
    return controller.buildTextSpan(
      context: context,
      style: TypographyTokens.noteBody,
      withComposing: withComposing,
    );
  }

  testWidgets('the built span is length preserving over the marker corpus',
      (WidgetTester tester) async {
    await pumpContext(tester);

    for (final String source in _corpus) {
      final TextSpan span = buildFor(source);
      expect(
        span.toPlainText(includeSemanticsLabels: false),
        source,
        reason: 'the span must reproduce $source character for character',
      );
    }
  });

  testWidgets('the built span is length preserving over a fuzz corpus',
      (WidgetTester tester) async {
    await pumpContext(tester);
    final Random random = Random(20260920);

    for (int i = 0; i < 400; i++) {
      final String source = _fuzz(random);
      final TextSpan span = buildFor(source);
      expect(
        span.toPlainText(includeSemanticsLabels: false).length,
        source.length,
        reason: 'length drifted for ${source.replaceAll('\n', r'\n')}',
      );
    }
  });

  testWidgets('markers stay visible and dimmed instead of being hidden',
      (WidgetTester tester) async {
    await pumpContext(tester);

    const String source = '**bold**';
    final TextSpan span = buildFor(source);

    expect(span.toPlainText(includeSemanticsLabels: false), source);
    expect(_styleAt(span, 0)?.color, Palette.ink34);
    expect(_styleAt(span, 1)?.color, Palette.ink34);
    expect(_styleAt(span, 2)?.fontWeight, FontWeight.w700);
    expect(_styleAt(span, 2)?.color, isNull);
    expect(_styleAt(span, 6)?.color, Palette.ink34);
  });

  testWidgets('a heading keeps its hashes and emphasises the text',
      (WidgetTester tester) async {
    await pumpContext(tester);

    const String source = '## Title';
    final TextSpan span = buildFor(source);

    expect(span.toPlainText(includeSemanticsLabels: false), source);
    expect(_styleAt(span, 0)?.color, Palette.ink34);
    expect(_styleAt(span, 3)?.fontWeight, FontWeight.w600);
    expect(
      _styleAt(span, 3)?.fontSize,
      greaterThan(TypographyTokens.noteBody.fontSize!),
    );
  });

  testWidgets('a value past the live style limit falls back to one plain span',
      (WidgetTester tester) async {
    await pumpContext(tester);

    final String source = '**bold** ' * 800;
    expect(source.length, greaterThan(MarkdownStyleController.liveStyleLimit));

    final TextSpan span = buildFor(source);

    expect(span.children, isNull);
    expect(span.text, source);
    expect(span.toPlainText(includeSemanticsLabels: false).length,
        source.length);
  });

  testWidgets('a value at the live style limit is still styled',
      (WidgetTester tester) async {
    await pumpContext(tester);

    final String source =
        '**b** '.padRight(MarkdownStyleController.liveStyleLimit, 'x');
    expect(source.length, MarkdownStyleController.liveStyleLimit);

    final TextSpan span = buildFor(source);

    expect(span.children, isNotNull);
    expect(span.toPlainText(includeSemanticsLabels: false), source);
  });

  testWidgets('a raised styleLimit live-styles a buffer past liveStyleLimit',
      (WidgetTester tester) async {
    await pumpContext(tester);

    const String unit = '**bold** and *italic* ';
    final String source =
        unit * (MarkdownStyleController.liveStyleLimit ~/ unit.length + 1);
    expect(source.length, greaterThan(MarkdownStyleController.liveStyleLimit));

    final TextSpan fallback = buildFor(source);

    expect(fallback.children, isNull);
    expect(fallback.text, source);
    expect(fallback.toPlainText(includeSemanticsLabels: false).length,
        source.length);

    final TextSpan styled = buildFor(
      source,
      styleLimit: MarkdownStyleController.liveStyleLimit * 4,
    );

    expect(styled.children, isNotNull);
    expect(styled.children!.length, greaterThan(1));
    expect(styled.toPlainText(includeSemanticsLabels: false), source);
  });

  testWidgets('nothing is ever truncated, however long the note',
      (WidgetTester tester) async {
    await pumpContext(tester);

    final String source = 'a very long note. ' * 4000;
    final TextSpan span = buildFor(source);

    expect(span.toPlainText(includeSemanticsLabels: false).length,
        source.length);
  });

  testWidgets('the composing range carries the IME underline',
      (WidgetTester tester) async {
    await pumpContext(tester);

    const String source = 'hello there';
    final TextSpan span = buildFor(
      source,
      composing: const TextRange(start: 6, end: 11),
      withComposing: true,
    );

    expect(span.toPlainText(includeSemanticsLabels: false), source);
    expect(_styleAt(span, 0)?.decoration, isNull);
    expect(_styleAt(span, 7)?.decoration, TextDecoration.underline);
  });

  testWidgets('the composing underline is dropped when withComposing is false',
      (WidgetTester tester) async {
    await pumpContext(tester);

    final TextSpan span = buildFor(
      'hello there',
      composing: const TextRange(start: 6, end: 11),
    );

    expect(_styleAt(span, 7)?.decoration, isNull);
  });

  testWidgets('a controller attached to another controller shares its value',
      (WidgetTester tester) async {
    await pumpContext(tester);

    final TextEditingController source = TextEditingController(text: 'seed');
    addTearDown(source.dispose);
    final MarkdownStyleController styled =
        MarkdownStyleController.attachedTo(source);
    addTearDown(styled.dispose);

    int notifications = 0;
    styled.addListener(() => notifications++);

    expect(styled.text, 'seed');

    source.text = 'from the source';
    expect(styled.text, 'from the source');
    expect(notifications, 1);

    styled.value = const TextEditingValue(
      text: 'from the editor',
      selection: TextSelection.collapsed(offset: 15),
    );
    expect(source.text, 'from the editor');
    expect(notifications, 2);

    final TextSpan span = styled.buildTextSpan(
      context: context,
      style: TypographyTokens.noteBody,
      withComposing: false,
    );
    expect(span.toPlainText(includeSemanticsLabels: false), 'from the editor');
  });
}
