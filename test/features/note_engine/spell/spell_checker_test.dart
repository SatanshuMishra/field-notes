import 'dart:async';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/spell/spell_checker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeSpellCheckService implements SpellCheckService {
  FakeSpellCheckService({
    this.words = const <String, List<String>>{},
    this.fixed,
    this.hold,
  });

  final Map<String, List<String>> words;
  final List<SuggestionSpan>? fixed;
  final Completer<void>? hold;
  final List<(Locale, String)> calls = <(Locale, String)>[];

  List<String> get texts => <String>[
    for (final (Locale, String) call in calls) call.$2,
  ];

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    calls.add((locale, text));
    final List<SuggestionSpan> spans = fixed ?? _spansIn(text);
    final Completer<void>? gate = hold;
    if (gate != null) {
      await gate.future;
    }
    return spans;
  }

  List<SuggestionSpan> _spansIn(String text) {
    final List<SuggestionSpan> spans = <SuggestionSpan>[
      for (final MapEntry<String, List<String>> entry in words.entries)
        for (final Match match in entry.key.allMatches(text))
          SuggestionSpan(
            TextRange(start: match.start, end: match.end),
            entry.value,
          ),
    ];
    return spans..sort(
      (SuggestionSpan a, SuggestionSpan b) =>
          a.range.start.compareTo(b.range.start),
    );
  }
}

final class _OneAtATimeService extends FakeSpellCheckService {
  _OneAtATimeService({super.words});

  final List<String> rejected = <String>[];
  bool _busy = false;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    if (_busy) {
      rejected.add(text);
      return null;
    }
    _busy = true;
    final List<SuggestionSpan>? spans = await super.fetchSpellCheckSuggestions(
      locale,
      text,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    _busy = false;
    return spans;
  }
}

final class _FailingService extends FakeSpellCheckService {
  _FailingService({required this.failures, super.words});

  final int failures;

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    final List<SuggestionSpan>? spans = await super.fetchSpellCheckSuggestions(
      locale,
      text,
    );
    return calls.length <= failures ? null : spans;
  }
}

const Locale _english = Locale('en', 'GB');

const String _paragraphP =
    'see [teh link](https://exmaple.com/teh) and `teh` and '
    '<https://teh.example>';

final String _paragraphPText =
    'see teh link and ${' ' * 3} and ${' ' * 'https://teh.example'.length}';

EditorState _stateOf(String source) =>
    EditorState.create(source, parse: parseNoteTree);

EditorState _edited(EditorState state, ChangeSet changes) => state.apply(
  Transaction(
    changes: changes,
    selection: const NoteSelection.collapsed(0),
    event: TransactionEvent.inputType,
  ),
);

EditorState _composing(EditorState state, int offset, String text) =>
    state.apply(
      Transaction(
        changes: ChangeSet.single(state.source.length, offset, offset, text),
        selection: NoteSelection.collapsed(offset + text.length),
        event: TransactionEvent.inputIme,
        composing: MdRange(offset, offset + text.length),
      ),
    );

SpellChecker _checker(
  FakeSpellCheckService? service,
  EditorState state, {
  bool enabled = true,
  bool available = true,
}) => SpellChecker(
  service: service,
  state: state,
  locale: _english,
  enabled: enabled,
  available: available,
);

final class _FakeLayout implements NoteLayout {
  const _FakeLayout(this.boxes);

  final Map<int, List<Rect>> boxes;

  @override
  List<Rect> selectionBoxes(NoteSelection selection) =>
      boxes[selection.start] ?? const <Rect>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ClipCanvas implements Canvas {
  final List<Offset> circles = <Offset>[];
  int paths = 0;

  @override
  Rect getLocalClipBounds() => const Rect.fromLTWH(0, 0, 400, 400);

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circles.add(c);
  }

  @override
  void drawPath(Path path, Paint paint) {
    paths += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'changed blocks are checked three hundred milliseconds after typing stops',
    (WidgetTester tester) async {
      final FakeSpellCheckService service = FakeSpellCheckService(
        words: const <String, List<String>>{
          'teh': <String>['the'],
          'liftd': <String>['lifted'],
        },
      );
      final EditorState initial = _stateOf(
        'teh harbour\n\nfog lifted\n\nthe end',
      );
      final SpellChecker checker = _checker(service, initial)
        ..viewport = const MdRange(0, 32);
      await tester.pump(Duration.zero);
      expect(service.texts, <String>['teh harbour', 'fog lifted', 'the end']);
      expect(checker.marks, <SpellMark>[
        const SpellMark(range: MdRange(0, 3), suggestions: <String>['the']),
      ]);

      final ChangeSet deletion = ChangeSet.single(32, 21, 22, '');
      final EditorState liftd = _edited(initial, deletion);
      expect(liftd.source, 'teh harbour\n\nfog liftd\n\nthe end');
      checker.didChange(liftd, deletion);
      await tester.pump(const Duration(milliseconds: 200));
      final ChangeSet insertion = ChangeSet.single(31, 22, 22, 's');
      final EditorState liftds = _edited(liftd, insertion);
      checker.didChange(liftds, insertion);
      await tester.pump(const Duration(milliseconds: 299));
      expect(service.calls, hasLength(3));

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(Duration.zero);
      expect(service.texts, <String>[
        'teh harbour',
        'fog lifted',
        'the end',
        'fog liftds',
      ]);
      checker.dispose();
    },
  );

  testWidgets('code, link destinations and photo lines are never checked', (
    WidgetTester tester,
  ) async {
    const String source =
        '# teh title\n\n```\nteh code\n```\n\n$_paragraphP\n\n'
        '![teh](photo/abc123abc123)';
    final FakeSpellCheckService service = FakeSpellCheckService(
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
    );
    final EditorState state = _stateOf(source);
    final SpellChecker checker = _checker(service, state);
    await tester.pump(Duration.zero);
    expect(service.texts, <String>['teh title', _paragraphPText]);
    for (final String text in service.texts) {
      for (final String banned in <String>[
        'exmaple',
        'https',
        'code',
        'photo',
      ]) {
        expect(text, isNot(contains(banned)));
      }
    }
    expect(
      <String>[
        for (final SpellUnit unit in spellUnitsOf(source, state.tree))
          unit.text,
      ],
      <String>['teh title', _paragraphPText],
    );
    checker.dispose();
  });

  testWidgets('choosing a suggestion is one spell transaction', (
    WidgetTester tester,
  ) async {
    final FakeSpellCheckService service = FakeSpellCheckService(
      fixed: <SuggestionSpan>[
        const SuggestionSpan(TextRange(start: 0, end: 3), <String>[
          'the',
          'tea',
          'ten',
          'tech',
          'then',
          'they',
        ]),
      ],
    );
    final EditorState state = _stateOf('teh harbour');
    final SpellChecker checker = _checker(service, state);
    await tester.pump(Duration.zero);
    expect(checker.markAt(1)?.range, const MdRange(0, 3));

    final List<Transaction? Function(EditorState state)> commands =
        <Transaction? Function(EditorState state)>[];
    final List<ContextMenuButtonItem> items = checker.suggestionItems(
      state: state,
      sourceOffset: 1,
      onCommand: commands.add,
    );
    expect(
      <String?>[for (final ContextMenuButtonItem item in items) item.label],
      <String>['the', 'tea', 'ten', 'tech', 'then'],
    );
    items.first.onPressed!();
    expect(commands, hasLength(1));
    final Transaction? transaction = commands.single(state);
    expect(transaction, isNotNull);
    expect(
      transaction!.changes,
      ChangeSet(
        length: 11,
        replacements: const <TextReplacement>[TextReplacement(0, 3, 'the')],
      ),
    );
    expect(transaction.event, TransactionEvent.spell);
    expect(transaction.addToHistory, isTrue);
    expect(transaction.selection, const NoteSelection.collapsed(3));
    final EditorState next = state.apply(transaction);
    expect(next.source, 'the harbour');
    expect(next.source.substring(3), state.source.substring(3));
    expect(
      checker.suggestionItems(
        state: state,
        sourceOffset: 8,
        onCommand: commands.add,
      ),
      isEmpty,
    );
    checker.dispose();
  });

  testWidgets('nothing is checked when the setting is off', (
    WidgetTester tester,
  ) async {
    final FakeSpellCheckService service = FakeSpellCheckService(
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
    );
    EditorState state = _stateOf('teh harbour');
    final SpellChecker checker = _checker(service, state, enabled: false);
    for (int i = 0; i < 3; i++) {
      final ChangeSet changes = ChangeSet.single(
        state.source.length,
        state.source.length,
        state.source.length,
        'x',
      );
      state = _edited(state, changes);
      checker.didChange(state, changes);
    }
    await tester.pump(const Duration(seconds: 1));
    expect(service.calls, isEmpty);
    expect(checker.marks, isEmpty);
    expect(
      checker.suggestionItems(
        state: state,
        sourceOffset: 1,
        onCommand: (Transaction? Function(EditorState state) command) {},
      ),
      isEmpty,
    );

    checker.enabled = true;
    final ChangeSet edit = ChangeSet.single(state.source.length, 0, 0, 'a');
    state = _edited(state, edit);
    checker.didChange(state, edit);
    await tester.pump(const Duration(milliseconds: 100));
    checker.enabled = false;
    final int callsAtSwitchOff = service.calls.length;
    await tester.pump(const Duration(seconds: 1));
    expect(service.calls, hasLength(callsAtSwitchOff));
    expect(checker.marks, isEmpty);
    checker.dispose();

    final SpellChecker unavailable = _checker(
      service,
      state,
      available: false,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(service.calls, hasLength(callsAtSwitchOff));
    unavailable.dispose();

    final SpellChecker withoutService = _checker(null, state);
    await tester.pump(const Duration(seconds: 1));
    expect(withoutService.marks, isEmpty);
    expect(service.calls, hasLength(callsAtSwitchOff));
    withoutService.dispose();
  });

  testWidgets('turning on checks at once with the units in view first', (
    WidgetTester tester,
  ) async {
    final FakeSpellCheckService service = FakeSpellCheckService(
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
    );
    const String source = 'one\n\ntwo\n\nteh three';
    final SpellChecker checker =
        _checker(service, _stateOf(source), enabled: false)
          ..viewport = MdRange(source.indexOf('teh'), source.length);
    int notified = 0;
    checker
      ..addListener(() => notified += 1)
      ..enabled = true;
    await tester.pump(Duration.zero);
    expect(service.texts, <String>['teh three', 'one', 'two']);
    expect(checker.marks.single.range, const MdRange(10, 13));
    expect(notified, greaterThan(0));
    checker.dispose();
  });

  testWidgets('a long note is checked in idle batches of twenty from the view', (
    WidgetTester tester,
  ) async {
    final List<String> paragraphs = <String>[
      for (int i = 0; i < 50; i++) 'paragraph $i',
    ];
    final String source = paragraphs.join('\n\n');
    final FakeSpellCheckService service = FakeSpellCheckService();
    final SpellChecker checker = _checker(service, _stateOf(source))
      ..viewport = MdRange(
        source.indexOf('paragraph 20'),
        source.indexOf('paragraph 29') + 'paragraph 29'.length,
      );
    expect(service.calls, isEmpty);

    tester.binding.handleEventLoopCallback();
    await tester.pump();
    expect(service.texts, <String>[
      for (int i = 20; i < 30; i++) 'paragraph $i',
      for (int i = 0; i < 10; i++) 'paragraph $i',
    ]);
    tester.binding.handleEventLoopCallback();
    await tester.pump();
    expect(service.texts.skip(20), <String>[
      for (int i = 10; i < 20; i++) 'paragraph $i',
      for (int i = 30; i < 40; i++) 'paragraph $i',
    ]);
    tester.binding.handleEventLoopCallback();
    await tester.pump();
    expect(service.texts.skip(40), <String>[
      for (int i = 40; i < 50; i++) 'paragraph $i',
    ]);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(Duration.zero);
    expect(service.calls, hasLength(50));
    checker.dispose();
  });

  testWidgets(
    'a service that rejects overlapping calls still checks every paragraph',
    (WidgetTester tester) async {
      final _OneAtATimeService service = _OneAtATimeService(
        words: const <String, List<String>>{
          'teh': <String>['the'],
          'liftd': <String>['lifted'],
        },
      );
      final SpellChecker checker = _checker(
        service,
        _stateOf('teh harbour\n\nfog liftd\n\nthe end'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.rejected, isEmpty);
      expect(service.texts, <String>['teh harbour', 'fog liftd', 'the end']);
      expect(checker.marks, <SpellMark>[
        const SpellMark(range: MdRange(0, 3), suggestions: <String>['the']),
        const SpellMark(
          range: MdRange(17, 22),
          suggestions: <String>['lifted'],
        ),
      ]);
      checker.dispose();
    },
  );

  testWidgets('a new pass waits for the call still in flight', (
    WidgetTester tester,
  ) async {
    final _OneAtATimeService service = _OneAtATimeService(
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
    );
    final SpellChecker checker = _checker(
      service,
      _stateOf('teh harbour\n\nfog'),
    );
    await tester.pump(Duration.zero);
    expect(service.calls, const <(Locale, String)>[(_english, 'teh harbour')]);

    checker.locale = const Locale('fr');
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.rejected, isEmpty);
    expect(service.calls, const <(Locale, String)>[
      (_english, 'teh harbour'),
      (Locale('fr'), 'teh harbour'),
      (Locale('fr'), 'fog'),
    ]);
    expect(checker.marks, <SpellMark>[
      const SpellMark(range: MdRange(0, 3), suggestions: <String>['the']),
    ]);
    checker.dispose();
  });

  testWidgets('a unit the service could not check is queued again', (
    WidgetTester tester,
  ) async {
    final _FailingService service = _FailingService(
      failures: 1,
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
    );
    final SpellChecker checker = _checker(service, _stateOf('teh harbour'));
    await tester.pump(Duration.zero);
    expect(service.texts, <String>['teh harbour']);
    expect(checker.marks, isEmpty);

    await tester.pump(spellCheckDelay);
    expect(service.texts, <String>['teh harbour', 'teh harbour']);
    expect(checker.marks, <SpellMark>[
      const SpellMark(range: MdRange(0, 3), suggestions: <String>['the']),
    ]);
    checker.dispose();
  });

  testWidgets(
    'a service that keeps failing is asked a bounded number of times',
    (WidgetTester tester) async {
      final _FailingService service = _FailingService(failures: 100);
      final EditorState initial = _stateOf('one\n\ntwo');
      final SpellChecker checker = _checker(service, initial);
      await tester.pump(const Duration(seconds: 5));
      expect(service.calls, hasLength(spellCheckAttempts));
      expect(checker.marks, isEmpty);

      final ChangeSet edit = ChangeSet.single(8, 8, 8, 's');
      checker.didChange(_edited(initial, edit), edit);
      await tester.pump(const Duration(seconds: 5));
      expect(service.calls, hasLength(spellCheckAttempts * 2));
      checker.dispose();
    },
  );

  testWidgets('identical units share one call and a locale change re-checks', (
    WidgetTester tester,
  ) async {
    final FakeSpellCheckService service = FakeSpellCheckService(
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
    );
    final SpellChecker checker = _checker(
      service,
      _stateOf('teh words\n\nteh words'),
    );
    await tester.pump(Duration.zero);
    expect(service.texts, <String>['teh words']);
    expect(
      <MdRange>[for (final SpellMark mark in checker.marks) mark.range],
      const <MdRange>[MdRange(0, 3), MdRange(11, 14)],
    );

    checker.locale = const Locale('fr');
    await tester.pump(Duration.zero);
    expect(service.calls, hasLength(2));
    expect(service.calls.last.$1, const Locale('fr'));
    checker.dispose();
  });

  testWidgets('a late result after dispose raises and notifies nothing', (
    WidgetTester tester,
  ) async {
    final Completer<void> hold = Completer<void>();
    final FakeSpellCheckService service = FakeSpellCheckService(
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
      hold: hold,
    );
    final SpellChecker checker = _checker(service, _stateOf('teh harbour'));
    int notified = 0;
    checker.addListener(() => notified += 1);
    await tester.pump(Duration.zero);
    expect(service.calls, hasLength(1));
    checker.dispose();
    hold.complete();
    await tester.pump(Duration.zero);
    expect(tester.takeException(), isNull);
    expect(notified, 0);
  });

  testWidgets('marks shift through an edit before them and drop when touched', (
    WidgetTester tester,
  ) async {
    final FakeSpellCheckService service = FakeSpellCheckService(
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
    );
    final EditorState initial = _stateOf('intro teh harbour');
    final SpellChecker checker = _checker(service, initial);
    await tester.pump(Duration.zero);
    expect(checker.marks.single.range, const MdRange(6, 9));

    final ChangeSet before = ChangeSet.single(17, 0, 0, 'x');
    final EditorState shifted = _edited(initial, before);
    checker.didChange(shifted, before);
    expect(checker.marks.single.range, const MdRange(7, 10));
    final SpellMark mark = checker.marks.single;

    final ChangeSet touching = ChangeSet.single(18, 10, 10, 'y');
    final EditorState touched = _edited(shifted, touching);
    checker.didChange(touched, touching);
    expect(checker.marks, isEmpty);
    expect(checker.replacement(touched, mark, 'the'), isNull);
    await tester.pump(spellCheckDelay);
    await tester.pump(Duration.zero);
    checker.dispose();
  });

  testWidgets('no pass runs while a composition is open', (
    WidgetTester tester,
  ) async {
    final FakeSpellCheckService service = FakeSpellCheckService(
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
    );
    final EditorState initial = _stateOf('teh harbour');
    final EditorState composing = _composing(initial, 11, ' fgo');
    expect(composing.composing, isNotNull);
    final SpellChecker checker = _checker(service, composing);
    await tester.pump(const Duration(seconds: 1));
    expect(service.calls, isEmpty);

    final EditorState more = _composing(composing, 15, 'x');
    checker.didChange(more, ChangeSet.single(15, 15, 15, 'x'));
    await tester.pump(const Duration(seconds: 1));
    expect(service.calls, isEmpty);

    final EditorState committed = more.withSelection(
      const NoteSelection.collapsed(15),
    );
    final EditorState plain = EditorState(
      source: committed.source,
      selection: committed.selection,
      tree: parseNoteTree(committed.source),
      parse: parseNoteTree,
    );
    checker.didChange(plain, ChangeSet.empty(16));
    await tester.pump(spellCheckDelay);
    await tester.pump(Duration.zero);
    expect(service.texts, <String>['teh harbour fgox']);
    checker.dispose();
  });

  test('a top-level table is one unit with tabs between cells', () {
    const String source = '| teh | ok |\n| - | - |\n| a | b |';
    final List<SpellUnit> units = spellUnitsOf(source, parseNoteTree(source));
    expect(units, hasLength(1));
    expect(units.single.text, 'teh\tok\na\tb');
    expect(units.single.sourceOffsets, hasLength(units.single.text.length + 1));
    expect(units.single.sourceOffsets.first, 2);
  });

  test('units drop markers and map every offset back to the source', () {
    const String source = '- [ ] a **teh**\n  > q\n\n## Head #';
    final List<SpellUnit> units = spellUnitsOf(source, parseNoteTree(source));
    expect(
      <String>[for (final SpellUnit unit in units) unit.text],
      <String>['a teh', 'q', 'Head'],
    );
    final SpellUnit first = units.first;
    expect(first.sourceOffsets.sublist(2, 5), <int>[10, 11, 12]);
  });

  test('nested inlines in a quote and a table drop markers and blank code', () {
    const String quote = '> **[teh](x) `c`** _a_ <https://y.z>';
    final SpellUnit quoted = spellUnitsOf(quote, parseNoteTree(quote)).single;
    expect(quoted.text, 'teh   a${' ' * 12}');
    expect(
      <int>[...quoted.sourceOffsets.take(8)],
      <int>[5, 6, 7, 12, 14, 18, 20, 22],
    );
    expect(
      <int>[...quoted.sourceOffsets.skip(8)],
      <int>[for (int offset = 24; offset < 35; offset++) offset, 36],
    );

    const String table = '| **teh** `c` | [a](b) |\n| - | - |\n| *x* | y |';
    final SpellUnit cells = spellUnitsOf(table, parseNoteTree(table)).single;
    expect(cells.text, 'teh  \ta\nx\ty');
    expect(cells.sourceOffsets.join(' '), '4 5 6 9 11 13 17 22 38 40 43 44');
  });

  testWidgets('replacement returns null for a mark no longer in marks', (
    WidgetTester tester,
  ) async {
    final FakeSpellCheckService service = FakeSpellCheckService(
      words: const <String, List<String>>{
        'teh': <String>['the'],
      },
    );
    final EditorState state = _stateOf('teh harbour');
    final SpellChecker checker = _checker(service, state);
    await tester.pump(Duration.zero);
    final SpellMark mark = checker.marks.single;
    expect(checker.replacement(state, mark, 'the'), isNotNull);
    checker.enabled = false;
    expect(checker.replacement(state, mark, 'the'), isNull);
    expect(
      checker.replacement(
        state,
        const SpellMark(range: MdRange(4, 7), suggestions: <String>['x']),
        'x',
      ),
      isNull,
    );
    checker.dispose();
  });

  test('underlines are dots on macOS and a zigzag elsewhere', () {
    expect(
      (Canvas c) => paintSpellUnderlines(c, <Rect>[
        const Rect.fromLTWH(0, 0, 9, 20),
      ], TargetPlatform.macOS),
      paints
        ..circle(x: 0.75, y: 18.25, radius: 0.75)
        ..circle(x: 3.75, y: 18.25, radius: 0.75)
        ..circle(x: 6.75, y: 18.25, radius: 0.75),
    );
    expect(
      (Canvas c) => paintSpellUnderlines(c, <Rect>[
        const Rect.fromLTWH(0, 0, 9, 20),
      ], TargetPlatform.android),
      paints..path(),
    );
  });

  test('the decoration paints each mark through the layout and place', () {
    const List<SpellMark> marks = <SpellMark>[
      SpellMark(range: MdRange(0, 3), suggestions: <String>['the']),
      SpellMark(range: MdRange(10, 13), suggestions: <String>['fog']),
      SpellMark(range: MdRange(20, 23), suggestions: <String>['sea']),
    ];
    const _FakeLayout layout = _FakeLayout(<int, List<Rect>>{
      0: <Rect>[Rect.fromLTWH(0, 0, 9, 20)],
      10: <Rect>[Rect.fromLTWH(30, 20, 9, 20)],
      20: <Rect>[Rect.fromLTWH(30, 900, 9, 20)],
    });
    const SpellUnderlineDecoration decoration = SpellUnderlineDecoration(
      marks: marks,
      platform: TargetPlatform.macOS,
    );
    final _ClipCanvas canvas = _ClipCanvas();
    decoration.paint(canvas, layout, (Rect r) => r);
    expect(canvas.circles, const <Offset>[
      Offset(0.75, 18.25),
      Offset(3.75, 18.25),
      Offset(6.75, 18.25),
      Offset(30.75, 38.25),
      Offset(33.75, 38.25),
      Offset(36.75, 38.25),
    ]);

    final _ClipCanvas hidden = _ClipCanvas();
    decoration.paint(hidden, layout, (Rect r) => null);
    expect(hidden.circles, isEmpty);
    expect(hidden.paths, 0);

    expect(
      decoration.shouldRepaint(
        SpellUnderlineDecoration(
          marks: List<SpellMark>.of(marks),
          platform: TargetPlatform.macOS,
        ),
      ),
      isFalse,
    );
    expect(
      decoration.shouldRepaint(
        const SpellUnderlineDecoration(
          marks: <SpellMark>[
            SpellMark(range: MdRange(0, 4), suggestions: <String>['the']),
          ],
          platform: TargetPlatform.macOS,
        ),
      ),
      isTrue,
    );
    expect(
      decoration.shouldRepaint(
        const SpellUnderlineDecoration(
          marks: marks,
          platform: TargetPlatform.android,
        ),
      ),
      isTrue,
    );
  });
}
