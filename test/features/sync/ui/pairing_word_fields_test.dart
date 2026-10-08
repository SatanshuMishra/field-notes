import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/data/sync/pairing/pairing_code.dart';
import 'package:field_notes/design/settings_fields/settings_text_field.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/sync/ui/pairing_word_fields.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _phone = Size(384, 832);
const Size _mac = Size(1280, 800);
const double _statusBar = 34;
const double _gestureBar = 24;
const List<String> _empty = <String>['', '', '', '', '', '', '', ''];
const List<String> _letters = <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.android, TargetPlatform.macOS},
);

final RegExp _whitespace = RegExp(r'\s');

final class _Harness {
  _Harness(this.controllers);

  final List<TextEditingController> controllers;
  int submitted = 0;
  int changed = 0;

  List<String> get words => <String>[
    for (final TextEditingController controller in controllers) controller.text,
  ];

  void clear() {
    for (final TextEditingController controller in controllers) {
      controller.clear();
    }
  }
}

void _useSurface(WidgetTester tester, TargetPlatform platform) {
  final bool phone = platform == TargetPlatform.android;
  final FakeViewPadding bars = phone
      ? const FakeViewPadding(top: _statusBar, bottom: _gestureBar)
      : FakeViewPadding.zero;
  tester.view.physicalSize = phone ? _phone : _mac;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = bars;
  tester.view.viewPadding = bars;
  addTearDown(tester.view.reset);
}

List<TextEditingController> _controllers(List<String> words) {
  final List<TextEditingController> controllers = <TextEditingController>[
    for (final String word in words) TextEditingController(text: word),
  ];
  for (final TextEditingController controller in controllers) {
    addTearDown(controller.dispose);
  }
  return controllers;
}

Future<_Harness> _pumpFields(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  bool enabled = true,
}) async {
  final TargetPlatform platform = defaultTargetPlatform;
  _useSurface(tester, platform);
  final _Harness harness = _Harness(_controllers(_empty));
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform, brightness: brightness),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: PairingWordFields(
                controllers: harness.controllers,
                enabled: enabled,
                onSubmitted: () => harness.submitted++,
                onChanged: () => harness.changed++,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return harness;
}

Finder _field(int number) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is SettingsTextField && widget.semanticLabel == 'Word $number',
);

Finder _editable(int number) =>
    find.descendant(of: _field(number), matching: find.byType(EditableText));

FocusNode _focusOf(WidgetTester tester, int number) =>
    tester.widget<SettingsTextField>(_field(number)).focusNode!;

void main() {
  testWidgets('pasting eight words into the first field fills all eight', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpFields(tester);

    await tester.enterText(_editable(1), 'A b c d e f g h');
    await tester.pump();
    expect(harness.words, _letters);

    harness.clear();
    await tester.pump();
    await tester.enterText(_editable(7), 'x y');
    await tester.pump();
    expect(harness.words, <String>['', '', '', '', '', '', 'x', 'y']);

    harness.clear();
    await tester.pump();
    await tester.enterText(_editable(3), 'ab cd');
    await tester.pump();
    expect(harness.words, <String>['', '', 'ab', 'cd', '', '', '', '']);

    await tester.enterText(_editable(5), 'ef ');
    await tester.pump();
    expect(harness.words, <String>['', '', 'ab', 'cd', 'ef', '', '', '']);
    for (final String word in harness.words) {
      expect(_whitespace.hasMatch(word), isFalse, reason: '"$word"');
    }
  }, variant: _bothPlatforms);

  testWidgets('focus moves to the field after the last word written', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpFields(tester);

    await tester.enterText(_editable(1), 'A b c');
    await tester.pump();
    expect(harness.words, <String>['a', 'b', 'c', '', '', '', '', '']);
    expect(_focusOf(tester, 4).hasFocus, isTrue);

    await tester.enterText(_editable(4), 'd');
    await tester.pump();
    expect(_focusOf(tester, 4).hasFocus, isTrue);

    await tester.enterText(_editable(4), 'd ');
    await tester.pump();
    expect(harness.words, <String>['a', 'b', 'c', 'd', '', '', '', '']);
    expect(_focusOf(tester, 5).hasFocus, isTrue);

    await tester.enterText(_editable(7), 'g h i');
    await tester.pump();
    expect(harness.words, <String>['a', 'b', 'c', 'd', '', '', 'g', 'h']);
    expect(_focusOf(tester, 8).hasFocus, isTrue);
    expect(harness.changed, 4);
  }, variant: _bothPlatforms);

  testWidgets('Return in a word field calls onSubmitted', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpFields(tester);

    for (int number = 1; number <= pairingWordCount; number++) {
      final EditableText editable = tester.widget<EditableText>(
        _editable(number),
      );
      expect(
        editable.textInputAction,
        number == pairingWordCount
            ? TextInputAction.done
            : TextInputAction.next,
      );
    }

    await tester.showKeyboard(_editable(2));
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(harness.submitted, 1);

    await tester.showKeyboard(_editable(8));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(harness.submitted, 2);
  }, variant: _bothPlatforms);

  testWidgets('the keyboard never corrects, suggests or learns a word', (
    WidgetTester tester,
  ) async {
    await _pumpFields(tester);

    for (int number = 1; number <= pairingWordCount; number++) {
      final EditableText editable = tester.widget<EditableText>(
        _editable(number),
      );
      expect(editable.autocorrect, isFalse, reason: 'word $number');
      expect(editable.enableSuggestions, isFalse, reason: 'word $number');
      expect(
        editable.enableIMEPersonalizedLearning,
        isFalse,
        reason: 'word $number',
      );
    }
  }, variant: _bothPlatforms);

  testWidgets(
    'eight numbered fields sit in two columns, each at least 48 points tall',
    (WidgetTester tester) async {
      for (final Brightness brightness in Brightness.values) {
        await _pumpFields(tester, brightness: brightness);
        final FieldNotesColors colors = brightness == Brightness.dark
            ? FieldNotesColors.dark
            : FieldNotesColors.light;

        for (int number = 1; number <= pairingWordCount; number++) {
          final Rect field = tester.getRect(_field(number));
          expect(field.height, greaterThanOrEqualTo(pairingWordFieldHeight));
          final Finder label = find.text('$number');
          expect(label, findsOneWidget);
          final Rect labelRect = tester.getRect(label);
          expect(labelRect.right, lessThanOrEqualTo(field.left));
          expect((labelRect.center.dy - field.center.dy).abs(), lessThan(1));
          expect(
            tester.widget<Text>(label).style!.color!.toARGB32(),
            colors.muted.toARGB32(),
          );
          expect(find.bySemanticsLabel('Word $number'), findsOneWidget);
          expect(find.bySemanticsLabel('$number'), findsNothing);
        }

        for (int row = 0; row < pairingWordCount ~/ 2; row++) {
          final Rect left = tester.getRect(_field(row * 2 + 1));
          final Rect right = tester.getRect(_field(row * 2 + 2));
          expect(right.top, left.top);
          expect(right.left, greaterThan(left.right));
          expect(right.width, closeTo(left.width, 0.01));
          if (row > 0) {
            final Rect above = tester.getRect(_field(row * 2 - 1));
            expect(left.top - above.bottom, closeTo(pairingWordGap, 0.01));
          }
        }

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }
    },
    variant: _bothPlatforms,
  );

  testWidgets('a tap anywhere on a word field box focuses it', (
    WidgetTester tester,
  ) async {
    await _pumpFields(tester);

    final Rect fifth = tester.getRect(_field(5));
    await tester.tapAt(Offset(fifth.center.dx, fifth.top + 3));
    await tester.pump();
    expect(_focusOf(tester, 5).hasFocus, isTrue);

    final Rect sixth = tester.getRect(_field(6));
    await tester.tapAt(Offset(sixth.center.dx, sixth.bottom - 3));
    await tester.pump();
    expect(_focusOf(tester, 6).hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('disabled word fields are read-only and never take focus', (
    WidgetTester tester,
  ) async {
    await _pumpFields(tester, enabled: false);

    for (int number = 1; number <= pairingWordCount; number++) {
      expect(tester.widget<EditableText>(_editable(number)).readOnly, isTrue);
    }

    final Rect third = tester.getRect(_field(3));
    await tester.tapAt(third.center);
    await tester.pump();
    await tester.tapAt(Offset(third.center.dx, third.top + 3));
    await tester.pump();
    expect(_focusOf(tester, 3).hasFocus, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('spreadPairingWords spreads several words forward, lower-cased', () {
    expect(spreadPairingWords(_empty, 0, 'A b c d e f g h'), _letters);
    expect(spreadPairingWords(_empty, 6, 'x y'), <String>[
      '',
      '',
      '',
      '',
      '',
      '',
      'x',
      'y',
    ]);
    expect(spreadPairingWords(_empty, 6, 'X y z'), <String>[
      '',
      '',
      '',
      '',
      '',
      '',
      'x',
      'y',
    ]);
    expect(spreadPairingWords(_empty, 2, '  ab\tCD\n'), <String>[
      '',
      '',
      'ab',
      'cd',
      '',
      '',
      '',
      '',
    ]);
    expect(spreadPairingWords(_letters, 3, ' de lta'), <String>[
      'a',
      'b',
      'c',
      'de',
      'lta',
      'f',
      'g',
      'h',
    ]);
  });

  test('spreadPairingWords keeps one word without any whitespace', () {
    expect(spreadPairingWords(_letters, 3, 'Delta'), <String>[
      'a',
      'b',
      'c',
      'Delta',
      'e',
      'f',
      'g',
      'h',
    ]);
    expect(spreadPairingWords(_letters, 3, 'de '), <String>[
      'a',
      'b',
      'c',
      'de',
      'e',
      'f',
      'g',
      'h',
    ]);
    expect(spreadPairingWords(_letters, 3, ''), <String>[
      'a',
      'b',
      'c',
      '',
      'e',
      'f',
      'g',
      'h',
    ]);
    expect(spreadPairingWords(_letters, 3, ' \t '), <String>[
      'a',
      'b',
      'c',
      '',
      'e',
      'f',
      'g',
      'h',
    ]);
    expect(
      spreadPairingWords(
        _empty,
        0,
        ' fieldnotes-pair:https://relay.example.com#AbC-d_E\n',
      ),
      <String>[
        'fieldnotes-pair:https://relay.example.com#AbC-d_E',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
      ],
    );
  });

  test('spreadPairingWords returns a new list and leaves its input alone', () {
    final List<String> words = List<String>.of(_letters);
    final List<String> spread = spreadPairingWords(words, 0, 'x y');

    expect(identical(spread, words), isFalse);
    expect(words, _letters);
    expect(spread, <String>['x', 'y', 'c', 'd', 'e', 'f', 'g', 'h']);
  });

  test('filledPairingWords counts the fields that hold a word', () {
    expect(filledPairingWords(_controllers(_empty)), 0);
    expect(
      filledPairingWords(
        _controllers(<String>['a', '', 'c', 'd', '', '', 'g', '']),
      ),
      4,
    );
    expect(filledPairingWords(_controllers(_letters)), pairingWordCount);
  });
}
