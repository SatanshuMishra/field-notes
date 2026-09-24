import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../tool/probe/lib/gates.dart';
// ignore: avoid_relative_lib_imports
import '../../../tool/probe/lib/oracles.dart';

const List<(String, String, String, List<String>)>
_table = <(String, String, String, List<String>)>[
  ('GP1', '≤ 4 ms', '≤ 8 ms', <String>['perf-keystroke']),
  (
    'GP2',
    'p95 ≤ 17 ms, max ≤ 25 ms',
    'p95 ≤ 34 ms, max ≤ 50 ms',
    <String>['perf-keystroke'],
  ),
  ('GP3', '0', '0', <String>['perf-keystroke', 'perf-scroll']),
  (
    'GP4',
    '≤ 2 frames/s (0 when the caret is hidden) and ≤ 1% CPU',
    'same',
    <String>['perf-idle'],
  ),
  ('GP5', '≤ 33 ms', '≤ 66 ms', <String>['perf-open']),
  ('GP6', '100%', '100%', <String>['styling-ceiling']),
  ('GR1', '100%', '100%', <String>['round-trip']),
  ('GR2', '0 side edits', '0 side edits', <String>['side-edit-audit']),
  ('GR3', '100%', '100%', <String>['held-clicks']),
  ('GR4', '0', '0', <String>['monkey']),
  ('GR5', '100%', '100%', <String>['undo-matrix']),
  ('GR6', '100%', '100%', <String>['photo-move-matrix']),
  ('GR7', '100%', '100%', <String>['photo-insert-matrix']),
  ('GR8', '20 of 20 per case', '20 of 20 per case', <String>['draft-recovery']),
  ('GB1', '100%', '100%', <String>['caret-audit']),
  ('GB2', '100%', '100%', <String>['selection-audit']),
  ('GB3', '100%', '100%', <String>['click-sweep']),
  ('GB4', '100%', '100%', <String>['vertical-sweep']),
  ('GB5', '100%', '100%', <String>['placement-matrix']),
  ('GB6', '100%', '100%', <String>['keyboard-matrix']),
  ('GB7', '100%', '100%', <String>['ime-matrix']),
  ('GB8', '100%', '100% (line movement reported)', <String>['a11y-matrix']),
  ('GB9', '100%', '100%', <String>['window-scale-matrix']),
  ('GB10', '100%', '100%', <String>['reader-parity']),
  ('GB11', '100%', '100%', <String>['toolbar-placement']),
  ('GP7', 'reported', 'reported', <String>['perf-memory']),
  ('GT1', '100%, not blocking', '100%, not blocking', <String>['table-matrix']),
  (
    'GSP1',
    '100%, not blocking',
    '100%, not blocking',
    <String>['spell-matrix'],
  ),
];

const Map<String, (GateLimit, GateLimit)> _limits =
    <String, (GateLimit, GateLimit)>{
      'GP1': (
        GateLimit.timing('≤ 4 ms', p95Ms: 4),
        GateLimit.timing('≤ 8 ms', p95Ms: 8),
      ),
      'GP2': (
        GateLimit.timing('p95 ≤ 17 ms, max ≤ 25 ms', p95Ms: 17, maxMs: 25),
        GateLimit.timing('p95 ≤ 34 ms, max ≤ 50 ms', p95Ms: 34, maxMs: 50),
      ),
      'GP3': (GateLimit.count('0', 0), GateLimit.count('0', 0)),
      'GP4': (
        GateLimit.idle(
          '≤ 2 frames/s (0 when the caret is hidden) and ≤ 1% CPU',
          framesPerSecond: 2,
          cpuPercent: 1,
        ),
        GateLimit.idle('same', framesPerSecond: 2, cpuPercent: 1),
      ),
      'GP5': (
        GateLimit.timing('≤ 33 ms', maxMs: 33),
        GateLimit.timing('≤ 66 ms', maxMs: 66),
      ),
      'GR2': (
        GateLimit.count('0 side edits', 0),
        GateLimit.count('0 side edits', 0),
      ),
      'GR4': (GateLimit.count('0', 0), GateLimit.count('0', 0)),
      'GR8': (
        GateLimit.perCase('20 of 20 per case', 20),
        GateLimit.perCase('20 of 20 per case', 20),
      ),
      'GP7': (GateLimit.reported('reported'), GateLimit.reported('reported')),
    };

const String _p = '![p](photo/abc123abc123)';

OracleNote _note(List<Object> blocks, List<String> separators) => OracleNote(
  blocks: <OracleBlock>[
    for (final Object block in blocks)
      block is OracleBlock
          ? block
          : OracleBlock('$block', isPhoto: '$block'.trim().startsWith('![')),
  ],
  separators: separators,
);

Map<String, Object?> _fixture(OracleNote note) => <String, Object?>{
  'blocks': <Object?>[
    for (final OracleBlock block in note.blocks)
      <String, Object?>{
        'source': block.source,
        'isPhoto': block.isPhoto,
        'unclosedFence': block.unclosedFence,
      },
  ],
  'separators': note.separators,
};

Map<String, Object?> _document(
  String scenario,
  List<Map<String, Object?>> samples, {
  String platform = 'macos',
  String build = 'profile',
}) => <String, Object?>{
  'scenario': scenario,
  'platform': platform,
  'build': build,
  'commit': 'abc',
  'samples': samples,
};

RowOutcome _row(Map<String, Object?> document, String id) => evaluateResult(
  document,
).singleWhere((RowOutcome outcome) => outcome.row == id);

Map<String, Object?> _expectSample(
  String row,
  String name,
  Map<String, Object?> expected,
  Map<String, Object?> observed,
) => <String, Object?>{
  'row': row,
  'kind': 'expect',
  'case': name,
  'expected': expected,
  'observed': observed,
};

Map<String, Object?> _keystrokes(String note, List<double> buildMs) =>
    <String, Object?>{
      'row': 'GP1',
      'kind': 'keystroke',
      'note': note,
      'timings': <String, Object?>{
        'keystrokes': <Object?>[
          for (final double value in buildMs)
            <String, Object?>{'handlerMs': 0.5, 'buildMs': value},
        ],
      },
    };

bool _onPath(String executable) {
  final String path = Platform.environment['PATH'] ?? '';
  final String separator = Platform.isWindows ? ';' : ':';
  return path
      .split(separator)
      .where((String directory) => directory.isNotEmpty)
      .any(
        (String directory) =>
            File('$directory${Platform.pathSeparator}$executable').existsSync(),
      );
}

final bool _dartAvailable = _onPath('dart');

Future<ProcessResult> _gates(List<String> arguments) => Process.run(
  'dart',
  <String>['run', 'tool/probe/lib/gates.dart', ...arguments],
);

Map<String, Object?> _relocationSample({
  required OracleNote note,
  required int photo,
  required String op,
  required String afterSource,
  required int delta,
  int? afterBlock,
  bool escaped = false,
  Object? hoverBoundary,
  String? beforeSource,
}) => <String, Object?>{
  'row': 'GR6',
  'kind': 'relocation',
  'case': op,
  'fixture': _fixture(note),
  'photo': photo,
  'op': op,
  'afterBlock': ?afterBlock,
  if (op == 'drag') 'escaped': escaped,
  if (op == 'drag') 'hoverBoundary': hoverBoundary,
  'before': <String, Object?>{
    'source': beforeSource ?? note.source,
    'transactions': 3,
    'photoSelected': 0,
  },
  'after': <String, Object?>{
    'source': afterSource,
    'transactions': 3 + delta,
    'photoSelected': 0,
  },
};

void main() {
  test('every gate row of the spec has a scenario and a threshold', () {
    expect(
      gateRows.map((GateRow row) => row.id).toList(),
      _table
          .map(((String, String, String, List<String>) row) => row.$1)
          .toList(),
    );
    for (int index = 0; index < _table.length; index++) {
      final (String, String, String, List<String>) expected = _table[index];
      final GateRow row = gateRows[index];
      expect(row.scenarios, expected.$4, reason: row.id);
      expect(row.macos.display, expected.$2, reason: row.id);
      expect(row.android.display, expected.$3, reason: row.id);
      final (GateLimit, GateLimit) limits =
          _limits[row.id] ??
          (GateLimit.rate(expected.$2), GateLimit.rate(expected.$3));
      expect(row.macos, limits.$1, reason: row.id);
      expect(row.android, limits.$2, reason: row.id);
      expect(
        row.blocking,
        !<String>['GP7', 'GT1', 'GSP1'].contains(row.id),
        reason: row.id,
      );
    }
    final List<String> named = <String>[
      for (final (String, String, String, List<String>) row in _table)
        ...row.$4,
    ];
    expect(probeScenarios.length, 27);
    expect(probeScenarios.toSet(), named.toSet());
    expect(probeScenarios.toSet().length, probeScenarios.length);
    expect(probeScenarios.take(2).toList(), <String>[
      'table-matrix',
      'spell-matrix',
    ]);
    for (final String scenario in probeScenarios) {
      expect(buildModesFor(scenario), switch (scenario) {
        'held-clicks' => <ProbeBuild>[ProbeBuild.profile, ProbeBuild.debug],
        'monkey' => <ProbeBuild>[ProbeBuild.debug],
        _ => <ProbeBuild>[ProbeBuild.profile],
      }, reason: scenario);
    }
    expect(() => buildModesFor('nope'), throwsArgumentError);
  });

  test('probe scenarios follow the table after the two capability rows', () {
    expect(probeScenarios, <String>[
      'table-matrix',
      'spell-matrix',
      'perf-keystroke',
      'perf-scroll',
      'perf-idle',
      'perf-open',
      'styling-ceiling',
      'round-trip',
      'side-edit-audit',
      'held-clicks',
      'monkey',
      'undo-matrix',
      'photo-move-matrix',
      'photo-insert-matrix',
      'draft-recovery',
      'caret-audit',
      'selection-audit',
      'click-sweep',
      'vertical-sweep',
      'placement-matrix',
      'keyboard-matrix',
      'ime-matrix',
      'a11y-matrix',
      'window-scale-matrix',
      'reader-parity',
      'toolbar-placement',
      'perf-memory',
    ]);
  });

  test('relocation writes the bytes of every P3 example', () {
    expect(
      expectedRelocation(
        _note(<Object>['A', _p, 'B'], <String>['\n\n', '\n\n']),
        photo: 1,
        op: RelocationOp.moveUp,
      ),
      '$_p\nA\n\nB',
    );
    final OracleNote down = _note(
      <Object>['A', _p, 'B'],
      <String>['\n', '\n\n'],
    );
    expect(
      expectedRelocation(down, photo: 1, op: RelocationOp.moveDown),
      'A\n\nB\n$_p',
    );
    expect(
      expectedRelocation(
        _note(<Object>['A', 'B', _p], <String>['\n\n', '\n']),
        photo: 2,
        op: RelocationOp.moveUp,
      ),
      'A\n$_p\n\nB',
    );
    final OracleNote tight = _note(
      <Object>['A', _p, 'B'],
      <String>['\n', '\n'],
    );
    expect(
      expectedRelocation(tight, photo: 1, op: RelocationOp.remove),
      'A\n\nB',
    );
    expect(
      expectedRelocation(tight, photo: 1, op: RelocationOp.moveUp),
      '$_p\nA\n\nB',
    );
    expect(
      expectedRelocation(
        _note(<Object>[_p, '| a |\n| --- |'], <String>['\n']),
        photo: 0,
        op: RelocationOp.moveDown,
      ),
      '| a |\n| --- |\n$_p',
    );
    expect(
      expectedRelocation(
        _note(<Object>['- a', _p, '- b'], <String>['\n', '\n']),
        photo: 1,
        op: RelocationOp.remove,
      ),
      '- a\n\n- b',
    );
    final OracleNote crlf = _note(
      <Object>['A', _p, 'B'],
      <String>['\r\n', '\r\n\r\n'],
    );
    expect(crlf.source, 'A\r\n$_p\r\n\r\nB');
    expect(
      expectedRelocation(crlf, photo: 1, op: RelocationOp.moveDown),
      'A\r\n\r\nB\r\n$_p',
    );
    expect(
      expectedRelocation(
        _note(<Object>['A', '   $_p', 'B'], <String>['\n\n', '\n\n']),
        photo: 1,
        op: RelocationOp.moveDown,
      ),
      'A\n\nB\n$_p',
    );
    expect(
      expectedRelocation(
        _note(<Object>['A', '   $_p \t', 'B'], <String>['\n\n', '\n\n']),
        photo: 1,
        op: RelocationOp.moveDown,
      ),
      'A\n\nB\n$_p',
    );
    final OracleNote first = _note(<Object>[_p, 'A'], <String>['\n\n']);
    expect(
      expectedRelocation(first, photo: 0, op: RelocationOp.moveUp),
      isNull,
    );
    final OracleNote last = _note(<Object>['A', _p], <String>['\n\n']);
    expect(
      expectedRelocation(last, photo: 1, op: RelocationOp.moveDown),
      isNull,
    );
    final OracleNote fenced = _note(
      <Object>['A', _p, const OracleBlock('```\ncode', unclosedFence: true)],
      <String>['\n\n', '\n\n'],
    );
    expect(
      expectedRelocation(fenced, photo: 1, op: RelocationOp.moveDown),
      isNull,
    );
    final OracleNote four = _note(
      <Object>['A', _p, 'B', 'C'],
      <String>['\n\n', '\n\n', '\n\n'],
    );
    expect(
      expectedRelocation(four, photo: 1, op: RelocationOp.drag, afterBlock: 0),
      isNull,
    );
    expect(
      expectedRelocation(four, photo: 1, op: RelocationOp.drag, afterBlock: 1),
      isNull,
    );
    expect(
      expectedRelocation(four, photo: 1, op: RelocationOp.drag, afterBlock: 3),
      'A\n\nB\n\nC\n$_p',
    );
    expect(
      expectedRelocation(four, photo: 1, op: RelocationOp.drag, afterBlock: -1),
      '$_p\nA\n\nB\n\nC',
    );
    expect(
      expectedRelocation(
        _note(<Object>[_p], <String>[]),
        photo: 0,
        op: RelocationOp.remove,
      ),
      '',
    );
    expect(
      expectedRelocation(
        _note(<Object>['A', _p, 'B'], <String>['\n\n\n', '\n\n']),
        photo: 1,
        op: RelocationOp.remove,
      ),
      'A\n\n\nB',
    );
    expect(
      expectedRelocation(
        _note(<Object>['A', _p, 'B'], <String>['\n', '\n  \n']),
        photo: 1,
        op: RelocationOp.remove,
      ),
      'A\n  \nB',
    );
  });

  test('drag boundaries skip unclosed fences and the evaluator judges GR6', () {
    final OracleNote fenced = _note(
      <Object>[
        'Alpha',
        _p,
        const OracleBlock('```\ncode', unclosedFence: true),
      ],
      <String>['\n\n', '\n\n'],
    );
    final int end = fenced.source.length;
    expect(boundaryOffset(fenced, afterBlock: -1), 0);
    expect(boundaryOffset(fenced, afterBlock: 0), 5);
    expect(boundaryOffset(fenced, afterBlock: 2), end);
    expect(isValidBoundary(fenced, 0), isTrue);
    expect(isValidBoundary(fenced, 5), isTrue);
    expect(isValidBoundary(fenced, end), isFalse);
    expect(isValidBoundary(fenced, 2), isFalse);
    expect(
      expectedRelocation(
        fenced,
        photo: 1,
        op: RelocationOp.drag,
        afterBlock: 2,
      ),
      isNull,
    );

    final OracleNote four = _note(
      <Object>['Alpha', _p, 'Bravo', 'Charlie'],
      <String>['\n\n', '\n\n', '\n\n'],
    );
    final String moved = expectedRelocation(
      four,
      photo: 1,
      op: RelocationOp.drag,
      afterBlock: 2,
    )!;
    final int bravoEnd = boundaryOffset(four, afterBlock: 2);
    GateVerdict judge(Map<String, Object?> sample) => _row(
      _document('photo-move-matrix', <Map<String, Object?>>[sample]),
      'GR6',
    ).verdict;

    expect(
      judge(
        _relocationSample(
          note: four,
          photo: 1,
          op: 'drag',
          afterBlock: 2,
          afterSource: moved,
          delta: 1,
          hoverBoundary: bravoEnd,
        ),
      ),
      GateVerdict.pass,
    );
    expect(
      judge(
        _relocationSample(
          note: four,
          photo: 1,
          op: 'drag',
          afterBlock: 2,
          afterSource: moved,
          delta: 1,
          hoverBoundary: 2,
        ),
      ),
      GateVerdict.fail,
    );
    expect(
      judge(
        _relocationSample(
          note: four,
          photo: 1,
          op: 'drag',
          afterBlock: 2,
          afterSource: four.source,
          delta: 0,
          escaped: true,
          hoverBoundary: bravoEnd,
        ),
      ),
      GateVerdict.pass,
    );
    expect(
      judge(
        _relocationSample(
          note: four,
          photo: 1,
          op: 'drag',
          afterBlock: 2,
          afterSource: four.source,
          delta: 1,
          escaped: true,
          hoverBoundary: bravoEnd,
        ),
      ),
      GateVerdict.fail,
    );
    expect(
      judge(
        _relocationSample(
          note: four,
          photo: 1,
          op: 'moveDown',
          afterSource: expectedRelocation(
            four,
            photo: 1,
            op: RelocationOp.moveDown,
          )!,
          delta: 1,
          beforeSource: '${four.source} ',
        ),
      ),
      GateVerdict.fail,
    );
    expect(
      judge(
        _relocationSample(
          note: four,
          photo: 1,
          op: 'moveDown',
          afterSource: expectedRelocation(
            four,
            photo: 1,
            op: RelocationOp.moveDown,
          )!,
          delta: 1,
        ),
      ),
      GateVerdict.pass,
    );
  });

  test('side edits, round trips and the restore caret', () {
    expect(
      changesWithin(
        const <(int, int)>[(0, 4), (10, 12)],
        const <(int, int, int)>[(1, 3, 2), (10, 12, 0)],
      ),
      isTrue,
    );
    expect(
      changesWithin(
        const <(int, int)>[(0, 4)],
        const <(int, int, int)>[(3, 5, 1)],
      ),
      isFalse,
    );
    expect(
      changesWithin(const <(int, int)>[], const <(int, int, int)>[]),
      isTrue,
    );
    expect(roundTripHolds(sourceAtSave: '  a\n', reopened: 'a'), isTrue);
    expect(roundTripHolds(sourceAtSave: '  a\n', reopened: 'a '), isFalse);

    expect(
      expectedRestoreCaret(_note(<Object>['Walk', _p], <String>['\n\n'])),
      4,
    );
    expect(
      expectedRestoreCaret(
        _note(
          <Object>['A', _p, '![q](photo/def456def456)'],
          <String>['\n', '\n'],
        ),
      ),
      1,
    );
    expect(
      expectedRestoreCaret(_note(<Object>['A', _p], <String>['\n  \n'])),
      1,
    );
    expect(expectedRestoreCaret(_note(<Object>[_p], <String>[])), 0);
    expect(
      expectedRestoreCaret(_note(<Object>['A', 'B'], <String>['\n\n'])),
      4,
    );
    expect(
      expectedRestoreCaret(_note(<Object>['Walk', _p], <String>['\r\n\r\n'])),
      4,
    );
    expect(
      () => OracleNote(
        blocks: const <OracleBlock>[OracleBlock('A'), OracleBlock('B')],
        separators: const <String>[],
      ),
      throwsArgumentError,
    );
  });

  test('photo plans follow L3 and L4', () {
    final PhotoPlanExpectation wide = expectedPhotoPlan(
      column: 720,
      em: 16,
      size: OracleSize.large,
      side: OracleSide.left,
      validPlacement: true,
    );
    expect(wide.width, 480);
    expect(wide.floats, isTrue);
    expect((720 - wide.width - 16) / 16, 14);
    final PhotoPlanExpectation narrow = expectedPhotoPlan(
      column: 560,
      em: 16,
      size: OracleSize.large,
      side: OracleSide.left,
      validPlacement: true,
    );
    expect(narrow.width, closeTo(373.33, 0.01));
    expect(narrow.floats, isFalse);
    final PhotoPlanExpectation phone = expectedPhotoPlan(
      column: 350,
      em: 16,
      size: OracleSize.small,
      side: OracleSide.right,
      validPlacement: true,
    );
    expect(phone.width, 350);
    expect(phone.floats, isFalse);
    final PhotoPlanExpectation landscape = expectedPhotoPlan(
      column: 688,
      em: 16,
      size: OracleSize.medium,
      side: OracleSide.right,
      validPlacement: true,
      pixelWidth: 1600,
      pixelHeight: 1200,
    );
    expect(landscape.width, 344);
    expect(landscape.height, 258);
    final PhotoPlanExpectation portrait = expectedPhotoPlan(
      column: 688,
      em: 16,
      size: OracleSize.medium,
      side: OracleSide.centre,
      validPlacement: true,
      pixelWidth: 1000,
      pixelHeight: 3000,
    );
    expect(portrait.height, closeTo(550.4, 1e-9));
    final PhotoPlanExpectation unknown = expectedPhotoPlan(
      column: 688,
      em: 16,
      size: OracleSize.full,
      side: OracleSide.centre,
      validPlacement: true,
    );
    expect(unknown.width, 688);
    expect(unknown.height, closeTo(688 * 2 / 3, 1e-9));
    final PhotoPlanExpectation invalid = expectedPhotoPlan(
      column: 688,
      em: 16,
      size: OracleSize.small,
      side: OracleSide.left,
      validPlacement: false,
    );
    expect(invalid.width, 344);
    expect(invalid.floats, isFalse);
  });

  test('geometry oracles hold their tolerances', () {
    expect(
      verticalGoalHolds(
        caretX: 385,
        goalX: 380,
        glyphAdvance: 6,
        lineShorterThanGoal: false,
        lineEndX: 0,
      ),
      isTrue,
    );
    expect(
      verticalGoalHolds(
        caretX: 387,
        goalX: 380,
        glyphAdvance: 6,
        lineShorterThanGoal: false,
        lineEndX: 0,
      ),
      isFalse,
    );
    expect(
      verticalGoalHolds(
        caretX: 200.4,
        goalX: 380,
        glyphAdvance: 6,
        lineShorterThanGoal: true,
        lineEndX: 200,
      ),
      isTrue,
    );
    expect(
      verticalGoalHolds(
        caretX: 200.6,
        goalX: 380,
        glyphAdvance: 6,
        lineShorterThanGoal: true,
        lineEndX: 200,
      ),
      isFalse,
    );
    bool click(double x, int landed) => clickLandsOnNearerEdge(
      clickX: x,
      glyphLeft: 10,
      glyphRight: 20,
      offsetBefore: 4,
      offsetAfter: 5,
      landed: landed,
    );
    expect(click(15, 5), isTrue);
    expect(click(15, 4), isFalse);
    expect(click(14.9, 4), isTrue);
    expect(click(19, 5), isTrue);

    const ProbeRect line = ProbeRect(0, 0, 100, 20);
    const ProbeRect selectedGlyph = ProbeRect(10, 2, 8, 16);
    const ProbeRect otherGlyph = ProbeRect(120, 2, 8, 16);
    const ProbeRect touchingGlyph = ProbeRect(99.6, 2, 8, 16);
    final SelectionCoverage clean = selectionCoverage(
      selection: const <ProbeRect>[line],
      glyphs: const <(ProbeRect, bool)>[
        (selectedGlyph, true),
        (otherGlyph, false),
        (touchingGlyph, false),
      ],
      photos: const <ProbeRect>[ProbeRect(0, 20.2, 50, 50)],
      gutters: const <ProbeRect>[],
    );
    expect((clean.missing, clean.extra, clean.overlapping), (0, 0, 0));
    final SelectionCoverage broken = selectionCoverage(
      selection: const <ProbeRect>[ProbeRect(0, 0, 12, 20)],
      glyphs: const <(ProbeRect, bool)>[
        (selectedGlyph, true),
        (ProbeRect(2, 2, 8, 16), false),
      ],
      photos: const <ProbeRect>[],
      gutters: const <ProbeRect>[ProbeRect(5, 0, 4, 40)],
    );
    expect((broken.missing, broken.extra, broken.overlapping), (1, 1, 1));

    const ProbeRect float = ProbeRect(0, 0, 200, 300);
    expect(
      fragmentsClearFloat(
        float: float,
        side: OracleSide.left,
        em: 16,
        fragments: const <(double, double)>[(215.5, 600), (216, 500)],
      ),
      isTrue,
    );
    expect(
      fragmentsClearFloat(
        float: float,
        side: OracleSide.left,
        em: 16,
        fragments: const <(double, double)>[(215.4, 600)],
      ),
      isFalse,
    );
    const ProbeRect rightFloat = ProbeRect(400, 0, 200, 300);
    expect(
      fragmentsClearFloat(
        float: rightFloat,
        side: OracleSide.right,
        em: 16,
        fragments: const <(double, double)>[(0, 384.5)],
      ),
      isTrue,
    );
    expect(
      fragmentsClearFloat(
        float: rightFloat,
        side: OracleSide.right,
        em: 16,
        fragments: const <(double, double)>[(0, 384.6)],
      ),
      isFalse,
    );

    const ProbeRect photo = ProbeRect(100, 200, 300, 200);
    expect(
      rectsOverlapOrTouch(const ProbeRect(100, 160, 200, 40), photo),
      isTrue,
    );
    expect(
      rectsOverlapOrTouch(const ProbeRect(100, 159, 200, 40), photo),
      isFalse,
    );
    expect(
      rectsOverlapOrTouch(
        const ProbeRect(100, 150, 200, 40),
        photo,
        tolerance: 10.5,
      ),
      isTrue,
    );
    expect(rectsMatch(photo, const ProbeRect(100.5, 199.5, 300, 200)), isTrue);
    expect(rectsMatch(photo, const ProbeRect(100.6, 200, 300, 200)), isFalse);
    expect(rectInside(const ProbeRect(0, 0, 10, 10), photo), isFalse);
    expect(caretWithin(dx: 1, dTop: -1, dBottom: 0.5), isTrue);
    expect(caretWithin(dx: 1.1, dTop: 0, dBottom: 0), isFalse);
    expect(ProbeRect.fromJson(const <Object?>[1, 2, 3, 4]).bottom, 6);
    expect(
      () => ProbeRect.fromJson(const <Object?>[1, 2, 3]),
      throwsFormatException,
    );
  });

  test('toolbar samples touch their photo within the 10 pt gap', () {
    Map<String, Object?> sample(double top) => <String, Object?>{
      'row': 'GB11',
      'kind': 'toolbar',
      'case': 'middle',
      'toolbar': <Object?>[100, top, 200, 40],
      'surface': <Object?>[0, 0, 800, 600],
      'photo': <Object?>[100, 200, 300, 200],
    };
    GateVerdict judge(Map<String, Object?> toolbar) => _row(
      _document('toolbar-placement', <Map<String, Object?>>[toolbar]),
      'GB11',
    ).verdict;

    expect(judge(sample(150)), GateVerdict.pass);
    expect(judge(sample(149)), GateVerdict.fail);
    expect(
      judge(<String, Object?>{
        ...sample(150),
        'surface': <Object?>[0, 160, 800, 440],
      }),
      GateVerdict.fail,
    );
  });

  test('expect samples, per-case runs and empty rows', () {
    final RowOutcome subset = _row(
      _document('keyboard-matrix', <Map<String, Object?>>[
        _expectSample(
          'GB6',
          'enter',
          <String, Object?>{
            'source': 'a\n',
            'selection': <Object?>[2, 2],
            'state': <String, Object?>{'focused': true},
          },
          <String, Object?>{
            'source': 'a\n',
            'selection': <Object?>[2.0, 2],
            'state': <String, Object?>{'focused': true, 'caret': null},
            'extra': 1,
          },
        ),
      ]),
      'GB6',
    );
    expect(subset.verdict, GateVerdict.pass);
    final RowOutcome nested = _row(
      _document('keyboard-matrix', <Map<String, Object?>>[
        _expectSample(
          'GB6',
          'nested',
          <String, Object?>{
            'state': <String, Object?>{
              'caret': <String, Object?>{'x': 1},
            },
          },
          <String, Object?>{
            'state': <String, Object?>{
              'caret': <String, Object?>{'x': 2, 'y': 3},
            },
          },
        ),
      ]),
      'GB6',
    );
    expect(nested.verdict, GateVerdict.fail);

    List<Map<String, Object?>> runs(String name, int count) =>
        <Map<String, Object?>>[
          for (int index = 0; index < count; index++)
            _expectSample(
              'GR8',
              name,
              <String, Object?>{'caret': 4},
              <String, Object?>{'caret': 4},
            ),
        ];
    expect(
      _row(
        _document('draft-recovery', <Map<String, Object?>>[
          ...runs('new note', 20),
          ...runs('edit note', 20),
        ]),
        'GR8',
      ).verdict,
      GateVerdict.pass,
    );
    expect(
      _row(
        _document('draft-recovery', <Map<String, Object?>>[
          ...runs('new note', 20),
          ...runs('edit note', 19),
        ]),
        'GR8',
      ).verdict,
      GateVerdict.fail,
    );

    final RowOutcome empty = _row(
      _document('styling-ceiling', <Map<String, Object?>>[
        <String, Object?>{
          'row': 'GP6',
          'kind': 'styling',
          'reportedOnly': true,
          'state': <String, Object?>{'blocks': <Object?>[]},
        },
      ]),
      'GP6',
    );
    expect(empty.verdict, GateVerdict.fail);
    expect(empty.measured, 'no samples');
    expect(empty.values['reportedOnly'], hasLength(1));

    final RowOutcome memory = _row(
      _document('perf-memory', <Map<String, Object?>>[
        for (final int rss in <int>[100, 300, 200])
          <String, Object?>{
            'row': 'GP7',
            'kind': 'memory',
            'peakRssBytes': rss,
            'imageCacheBytes': rss ~/ 2,
            'oversizeDecodes': 1,
          },
      ]),
      'GP7',
    );
    expect(memory.verdict, GateVerdict.reported);
    expect(memory.values['peakRssBytes'], 300);
    expect(memory.values['imageCacheBytes'], 150);
    expect(memory.values['oversizeDecodes'], 3);
    expect(
      _row(_document('perf-memory', <Map<String, Object?>>[]), 'GP7').verdict,
      GateVerdict.reported,
    );
  });

  test('key-to-raster maps driver timestamps through the clock', () {
    Map<String, Object?> sample(List<int> keyDownNanos) => <String, Object?>{
      'row': 'GP2',
      'kind': 'keyToRaster',
      'note': 'c50000-p24',
      'keyDownNanos': keyDownNanos,
      'clockPairs': <Object?>[
        <Object?>[1000000, 5000],
        <Object?>[2000000, 6002],
      ],
      'timings': <String, Object?>{
        'keystrokes': <Object?>[
          <String, Object?>{'rasterFinishMicros': 7001 + 10000},
          <String, Object?>{'rasterFinishMicros': 8001 + 12000},
        ],
      },
    };
    final RowOutcome mapped = _row(
      _document('perf-keystroke', <Map<String, Object?>>[
        sample(<int>[3000000, 4000000]),
      ]),
      'GP2',
    );
    expect(mapped.values['p50'], 10.0);
    expect(mapped.values['p95'], 12.0);
    expect(mapped.values['max'], 12.0);
    expect(mapped.verdict, GateVerdict.pass);
    final RowOutcome short = _row(
      _document('perf-keystroke', <Map<String, Object?>>[
        sample(<int>[3000000]),
      ]),
      'GP2',
    );
    expect(short.verdict, GateVerdict.fail);
    expect(short.measured, 'keystroke count mismatch');

    final RowOutcome android = _row(
      _document('perf-keystroke', <Map<String, Object?>>[
        <String, Object?>{
          'row': 'GP2',
          'kind': 'keyToRaster',
          'note': 'c50000-p24',
          'timings': <String, Object?>{
            'keystrokes': <Object?>[
              <String, Object?>{
                'keyDownMicros': 1000,
                'rasterFinishMicros': 41000,
              },
            ],
          },
        },
      ], platform: 'android'),
      'GP2',
    );
    expect(android.values['max'], 40.0);
    expect(android.verdict, GateVerdict.fail);
  });

  test('frames, opens and caret audits report their measures', () {
    final RowOutcome frames = _row(
      _document('perf-scroll', <Map<String, Object?>>[
        <String, Object?>{
          'row': 'GP3',
          'kind': 'frames',
          'note': 'c500-p0',
          'phase': 'scrolling',
          'timings': <String, Object?>{
            'refreshHz': 120,
            'frames': <Object?>[
              <String, Object?>{'buildMs': 2, 'rasterMs': 9},
              <String, Object?>{'buildMs': 2, 'rasterMs': 3},
            ],
          },
        },
      ]),
      'GP3',
    );
    expect(frames.values['janky'], 1);
    expect(frames.verdict, GateVerdict.fail);

    final RowOutcome open = _row(
      _document('perf-open', <Map<String, Object?>>[
        for (final int finish in <int>[20000, 33000])
          <String, Object?>{
            'row': 'GP5',
            'kind': 'open',
            'note': 'c50000-p24',
            'timings': <String, Object?>{
              'open': <String, Object?>{
                'dispatchedMicros': 0,
                'firstLineRasterFinishMicros': finish,
              },
            },
          },
      ]),
      'GP5',
    );
    expect(open.values['max'], 33.0);
    expect(open.verdict, GateVerdict.pass);

    final RowOutcome caret = _row(
      _document('caret-audit', <Map<String, Object?>>[
        <String, Object?>{
          'row': 'GB1',
          'kind': 'caret',
          'case': 'c500-p0 medium 1.0',
          'caretAudit': <String, Object?>{
            'samples': <Object?>[
              <String, Object?>{
                'offset': 0,
                'affinity': 'downstream',
                'blockKind': 'paragraph',
                'dx': -0.4,
                'dTop': 0.1,
                'dBottom': 0.2,
              },
              <String, Object?>{
                'offset': 1,
                'affinity': 'downstream',
                'blockKind': 'paragraph',
                'dx': 0.3,
                'dTop': -0.6,
                'dBottom': 0,
              },
              <String, Object?>{
                'offset': 30,
                'affinity': 'upstream',
                'blockKind': 'heading',
                'dx': 0.25,
                'dTop': -0.9,
                'dBottom': 0.05,
              },
            ],
          },
        },
      ]),
      'GB1',
    );
    expect(caret.verdict, GateVerdict.pass);
    expect(
      caret.measured,
      contains('paragraph |dx| 0.40 |dTop| 0.60 |dBottom| 0.20'),
    );
    expect(
      caret.measured,
      contains('heading |dx| 0.25 |dTop| 0.90 |dBottom| 0.05'),
    );
  });

  test('photo, parity and styling samples follow their oracles', () {
    Map<String, Object?> photo(List<Object?> rects) => <String, Object?>{
      'row': 'GB5',
      'kind': 'photo',
      'case': 'medium right',
      'column': 688,
      'em': 16,
      'size': 'medium',
      'side': 'right',
      'validPlacement': true,
      'pixelWidth': 1600,
      'pixelHeight': 1200,
      'rects': rects,
      'readerRect': <Object?>[344, 0, 344, 258],
      'ringDegrees': -1.2,
      'tiltDegrees': -1.25,
    };
    GateVerdict judgePhoto(Map<String, Object?> sample) => _row(
      _document('placement-matrix', <Map<String, Object?>>[sample]),
      'GB5',
    ).verdict;
    expect(
      judgePhoto(
        photo(<Object?>[
          <Object?>[344, 0, 344, 258],
          <Object?>[344.4, 0, 344, 258],
        ]),
      ),
      GateVerdict.pass,
    );
    expect(
      judgePhoto(
        photo(<Object?>[
          <Object?>[344, 0, 344, 258],
          <Object?>[344, 1, 344, 258],
        ]),
      ),
      GateVerdict.fail,
    );
    expect(
      judgePhoto(
        photo(<Object?>[
          <Object?>[344, 0, 345, 258],
        ]),
      ),
      GateVerdict.fail,
    );

    GateVerdict judgeParity(List<Object?> viewerTops) => _row(
      _document('reader-parity', <Map<String, Object?>>[
        <String, Object?>{
          'row': 'GB10',
          'kind': 'parity',
          'case': 'c500-p0',
          'composerLines': <Object?>['a', 'b'],
          'viewerLines': <Object?>['a', 'b'],
          'composerTops': <Object?>[0, 40],
          'viewerTops': viewerTops,
        },
      ]),
      'GB10',
    ).verdict;
    expect(judgeParity(<Object?>[0.5, 40]), GateVerdict.pass);
    expect(judgeParity(<Object?>[0.6, 40]), GateVerdict.fail);

    GateVerdict judgeStyling(int styledRuns) => _row(
      _document('styling-ceiling', <Map<String, Object?>>[
        <String, Object?>{
          'row': 'GP6',
          'kind': 'styling',
          'state': <String, Object?>{
            'blocks': <Object?>[
              <String, Object?>{
                'kind': 'paragraph',
                'styleKind': 'paragraph',
                'inlineNodes': 3,
                'styledRuns': styledRuns,
              },
            ],
          },
        },
      ]),
      'GP6',
    ).verdict;
    expect(judgeStyling(3), GateVerdict.pass);
    expect(judgeStyling(2), GateVerdict.fail);
  });

  test('documents in a build 6.14 does not judge are rejected', () {
    expect(
      () => evaluateResult(
        _document('perf-keystroke', <Map<String, Object?>>[], build: 'debug'),
      ),
      throwsArgumentError,
    );
    expect(
      () => evaluateResult(_document('nope', <Map<String, Object?>>[])),
      throwsArgumentError,
    );
    expect(
      () => evaluateResult(
        _document('perf-open', <Map<String, Object?>>[], platform: 'ios'),
      ),
      throwsArgumentError,
    );
    expect(
      evaluateResult(
        _document('held-clicks', <Map<String, Object?>>[], build: 'debug'),
      ).single.row,
      'GR3',
    );
    expect(
      evaluateResult(
        _document('perf-keystroke', <Map<String, Object?>>[]),
      ).map((RowOutcome outcome) => outcome.row),
      <String>['GP1', 'GP2', 'GP3'],
    );
  });

  group('command line', () {
    final String? skip = _dartAvailable ? null : 'dart is not on PATH';
    const Timeout timeout = Timeout(Duration(minutes: 2));

    test(
      'list prints the scenarios in order',
      () async {
        final ProcessResult result = await _gates(<String>['list']);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          const LineSplitter().convert('${result.stdout}'),
          probeScenarios,
        );
      },
      skip: skip,
      timeout: timeout,
    );

    test(
      'evaluate prints each note before the GP1 line',
      () async {
        final Directory directory = Directory.systemTemp.createTempSync(
          'gates',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final File passing = File('${directory.path}/pass.json')
          ..writeAsStringSync(
            jsonEncode(
              _document('perf-keystroke', <Map<String, Object?>>[
                _keystrokes('c500-p0', <double>[1, 2, 3]),
                _keystrokes('c50000-p24', <double>[2, 2, 2]),
                <String, Object?>{
                  'row': 'GP2',
                  'kind': 'keyToRaster',
                  'note': 'c50000-p24',
                  'timings': <String, Object?>{
                    'keystrokes': <Object?>[
                      <String, Object?>{
                        'keyDownMicros': 0,
                        'rasterFinishMicros': 9000,
                      },
                    ],
                  },
                },
                <String, Object?>{
                  'row': 'GP3',
                  'kind': 'frames',
                  'note': 'c500-p0',
                  'phase': 'typing',
                  'timings': <String, Object?>{
                    'refreshHz': 120,
                    'frames': <Object?>[
                      <String, Object?>{'buildMs': 2, 'rasterMs': 3},
                    ],
                  },
                },
              ]),
            ),
          );
        final ProcessResult result = await _gates(<String>[
          'evaluate',
          passing.path,
        ]);
        final List<String> lines = const LineSplitter().convert(
          '${result.stdout}',
        );
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(lines[0], 'c500-p0 p50 2.50 p95 3.50 max 3.50');
        expect(lines[1], 'c50000-p24 p50 2.50 p95 2.50 max 2.50');
        expect(lines[2], startsWith('GP1 macos profile '));
        expect(lines[2], endsWith(' PASS'));
        expect(
          lines.where((String line) => line.startsWith('GP')),
          hasLength(3),
        );

        final File failing = File('${directory.path}/fail.json')
          ..writeAsStringSync(
            jsonEncode(
              _document('perf-keystroke', <Map<String, Object?>>[
                _keystrokes('c500-p0', <double>[9, 9, 9]),
              ]),
            ),
          );
        final ProcessResult failed = await _gates(<String>[
          'evaluate',
          failing.path,
        ]);
        expect(failed.exitCode, 1, reason: '${failed.stdout}${failed.stderr}');
        expect('${failed.stdout}', contains(' FAIL'));

        final File broken = File('${directory.path}/broken.json')
          ..writeAsStringSync('{');
        expect((await _gates(<String>['evaluate', broken.path])).exitCode, 2);
      },
      skip: skip,
      timeout: timeout,
    );

    test(
      'restore-caret prints the C8 caret and builds rejects a stranger',
      () async {
        final Directory directory = Directory.systemTemp.createTempSync(
          'gates',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final File fixture = File('${directory.path}/fixture.json')
          ..writeAsStringSync(
            jsonEncode(_fixture(_note(<Object>['Walk', _p], <String>['\n\n']))),
          );
        final ProcessResult caret = await _gates(<String>[
          'restore-caret',
          fixture.path,
        ]);
        expect(caret.exitCode, 0, reason: '${caret.stderr}');
        expect('${caret.stdout}'.trim(), '4');

        final ProcessResult builds = await _gates(<String>[
          'builds',
          'held-clicks',
        ]);
        expect(const LineSplitter().convert('${builds.stdout}'), <String>[
          'profile',
          'debug',
        ]);
        final ProcessResult nope = await _gates(<String>['builds', 'nope']);
        expect(nope.exitCode, 2);
        expect((await _gates(<String>[])).exitCode, 2);
      },
      skip: skip,
      timeout: timeout,
    );
  });
}
