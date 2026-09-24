import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../../../tool/probe/lib/gates.dart';

const String _driver = 'tool/probe/macos';

const List<String> _helpers = <String>['inp', 'pasteboard', 'drag_files'];

const List<String> _platformFunctions = <String>[
  'plat_name',
  'plat_launch',
  'plat_kill',
  'plat_origin',
  'plat_click',
  'plat_right_click',
  'plat_drag',
  'plat_scroll',
  'plat_key',
  'plat_type',
  'plat_timed_type',
  'plat_clock_pair',
  'plat_cpu',
  'plat_cpu_format',
  'plat_rss',
  'plat_paste_image',
  'plat_paste_files',
  'plat_paste_mixed',
  'plat_drop_files',
  'plat_owner_step',
  'plat_front',
  'plat_speech_last',
  'plat_text_scales',
  'plat_set_text_scale',
  'plat_columns',
  'plat_reveal_budget_ms',
  'plat_ime_cases',
  'plat_image_insert_cases',
  'plat_a11y_cases',
];

bool _onPath(String executable) {
  final String path = Platform.environment['PATH'] ?? '';
  return path
      .split(':')
      .where((String directory) => directory.isNotEmpty)
      .any((String directory) => File('$directory/$executable').existsSync());
}

final String? _swiftSkip = !_onPath('swiftc')
    ? 'swiftc is not installed'
    : !Platform.isMacOS
    ? 'the Swift helpers need macOS'
    : null;

final String? _zshSkip = _onPath('zsh') ? null : 'zsh is not installed';

List<String> _lines(Object? output) => const LineSplitter().convert('$output');

Future<ProcessResult> _zsh(List<String> arguments) =>
    Process.run('zsh', arguments);

Future<ProcessResult> _library(String script) =>
    _zsh(<String>['-c', 'source $_driver/drive.sh --library; $script']);

Map<String, (int, int)> _mediaTable() {
  final List<String> lines = File(
    'integration_test/probe/corpus/README.md',
  ).readAsLinesSync();
  final int start = lines.indexOf('## Media');
  final Map<String, (int, int)> sizes = <String, (int, int)>{};
  for (final String line in lines.skip(start + 1)) {
    final List<String> cells = line
        .split('|')
        .map((String cell) => cell.trim())
        .where((String cell) => cell.isNotEmpty)
        .toList();
    if (cells.length == 3 && RegExp(r'^[0-9a-f]{12}$').hasMatch(cells[0])) {
      sizes[cells[0]] = (int.parse(cells[1]), int.parse(cells[2]));
    }
  }
  return sizes;
}

final class _Driven {
  const _Driven(this.result, this.work);

  final ProcessResult result;
  final Directory work;

  List<String> lines(String name) {
    final File file = File('${work.path}/$name');
    return file.existsSync() ? file.readAsLinesSync() : const <String>[];
  }

  List<Map<String, Object?>> get samples => <Map<String, Object?>>[
    for (final String line in lines('samples'))
      jsonDecode(line) as Map<String, Object?>,
  ];

  String get output => '${result.stdout}';
}

const String _stubs = r'''
sleep() { :; }
sample() { print -r -- "$1" >> $WORK/samples; }
''';

Future<_Driven> _driven(String script) async {
  final Directory work = Directory.systemTemp.createTempSync('probe_driver');
  addTearDown(() => work.deleteSync(recursive: true));
  final ProcessResult result = await Process.run(
    'zsh',
    <String>['-c', 'source $_driver/drive.sh --library\n$_stubs\n$script'],
    environment: <String, String>{'WORK': work.path, 'PROBE_WORK': work.path},
  );
  return _Driven(result, work);
}

RowOutcome _judge(
  String scenario,
  String row,
  List<Map<String, Object?>> samples, {
  String build = 'profile',
}) => evaluateResult(<String, Object?>{
  'scenario': scenario,
  'platform': 'macos',
  'build': build,
  'commit': 'abc',
  'samples': samples,
}).singleWhere((RowOutcome outcome) => outcome.row == row);

double _number(String text) =>
    double.parse(text.endsWith('.') ? '${text}0' : text);

const String _keyboardStubs = r'''
case_run() { print -r -- "$2" >> $WORK/cases; }
set_text() { :; }
focus_editor() { :; }
select_range() { :; }
plat_kill() { :; }
plat_launch() { :; }
plat_key() { :; }
plat_drag() { :; }
plat_click() { :; }
press_key() { :; }
key_present() { return 1; }
glyph_center() { return 1; }
selection_json() { print -rn -- '[0,0]'; }
state_get() { print -r -- '{"transactions":0}'; }
probe_get() { print -r -- '{}'; }
expect_sample() { print -r -- "$2" >> $WORK/expected; }
probe_post() {
  if [[ $1 == open\?surface=composer* && ! -s ${2:-/dev/null} ]]; then
    print -u2 -r -- 'blank text'
    return 22
  fi
  print -r -- '{"opened":true,"entryId":null,"entryCount":0}'
}
''';

void main() {
  test(
    'the swift helpers typecheck',
    () async {
      for (final String helper in _helpers) {
        final ProcessResult result = await Process.run('swiftc', <String>[
          '-typecheck',
          '$_driver/$helper.swift',
        ]);
        expect(result.exitCode, 0, reason: '$helper: ${result.stderr}');
      }
    },
    skip: _swiftSkip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('the driver scripts parse and list every scenario', () async {
    for (final String script in <String>['run.sh', 'drive.sh']) {
      final ProcessResult parsed = await _zsh(<String>[
        '-n',
        '$_driver/$script',
      ]);
      expect(parsed.exitCode, 0, reason: '$script: ${parsed.stderr}');
      final ProcessResult listed = await _zsh(<String>[
        '$_driver/$script',
        '--list',
      ]);
      expect(listed.exitCode, 0, reason: '$script: ${listed.stderr}');
      expect(_lines(listed.stdout), probeScenarios, reason: script);
    }
    final ProcessResult checked = await _zsh(<String>[
      '$_driver/drive.sh',
      '--check',
    ]);
    expect(checked.exitCode, 0, reason: '${checked.stderr}');
  }, skip: _zshSkip);

  test(
    'each built helper refuses to run without arguments',
    () async {
      final Directory directory = Directory.systemTemp.createTempSync(
        'probe_helpers',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      for (final String helper in _helpers) {
        final String binary = '${directory.path}/$helper';
        final ProcessResult built = await Process.run('swiftc', <String>[
          '-O',
          '$_driver/$helper.swift',
          '-o',
          binary,
        ]);
        expect(built.exitCode, 0, reason: '$helper: ${built.stderr}');
        final ProcessResult run = await Process.run(binary, <String>[]);
        expect(run.exitCode, 2, reason: helper);
        expect('${run.stderr}', startsWith('usage:'), reason: helper);
        expect('${run.stdout}', isEmpty, reason: helper);
      }
    },
    skip: _swiftSkip,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('the corpus helpers read the committed notes and tables', () async {
    final Directory directory = Directory.systemTemp.createTempSync(
      'probe_corpus',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final String copy = '${directory.path}/c500-p0.md';
    final ProcessResult copied = await _library('corpus_note c500-p0 $copy');
    expect(copied.exitCode, 0, reason: '${copied.stderr}');
    expect(
      File(copy).readAsBytesSync(),
      File('integration_test/probe/corpus/c500-p0.md').readAsBytesSync(),
    );

    final ProcessResult ids = await _library('corpus_ids');
    expect(_lines(ids.stdout), <String>[
      'c500-p0',
      'c500-p4',
      'c500-p8',
      'c6000-p0',
      'c6000-p4',
      'c6000-p8',
      'c6000-p24',
      'c20000-p0',
      'c20000-p4',
      'c20000-p8',
      'c20000-p24',
      'c50000-p0',
      'c50000-p4',
      'c50000-p8',
      'c50000-p24',
    ]);

    final ProcessResult media = await _library('corpus_media c500-p4');
    expect(media.exitCode, 0, reason: '${media.stderr}');
    final String note = File(
      'integration_test/probe/corpus/c500-p4.md',
    ).readAsStringSync();
    final Map<String, (int, int)> table = _mediaTable();
    final List<String> entries = '${media.stdout}'.trim().split(',');
    expect(entries, isNotEmpty);
    for (final String entry in entries) {
      final List<String> parts = entry.split(':');
      expect(parts, hasLength(3), reason: entry);
      expect(note, contains('photo/${parts[0]}'), reason: entry);
      expect(table[parts[0]], (int.parse(parts[1]), int.parse(parts[2])));
    }
    expect(
      entries.toSet(),
      hasLength(
        RegExp(r'photo/([0-9a-f]{12})')
            .allMatches(note)
            .map((RegExpMatch match) => match.group(1))
            .toSet()
            .length,
      ),
    );

    final ProcessResult unknown = await _library(
      'corpus_note nope ${directory.path}/nope.md',
    );
    expect(unknown.exitCode, 2);
  }, skip: _zshSkip);

  test('the library defines every platform function and hook', () async {
    final ProcessResult found = await _library(
      'whence -w ${_platformFunctions.join(' ')}',
    );
    expect(found.exitCode, 0, reason: '${found.stderr}');
    expect(_lines(found.stdout), <String>[
      for (final String name in _platformFunctions) '$name: function',
    ]);
    final ProcessResult budget = await _library('plat_reveal_budget_ms');
    expect(_lines(budget.stdout), <String>['150']);
    final ProcessResult name = await _library('plat_name');
    expect(_lines(name.stdout), <String>['macos']);
  }, skip: _zshSkip);

  test('run.sh rejects an unknown scenario before building', () async {
    final ProcessResult result = await _zsh(<String>[
      '$_driver/run.sh',
      'nope',
    ]);
    expect(result.exitCode, 2);
    expect('${result.stderr}', contains('unknown scenario nope'));
    expect('${result.stdout}', isEmpty);
  }, skip: _zshSkip);

  test('the library loads the math functions its arithmetic uses', () async {
    final _Driven run = await _driven(r'''
print -r -- $(( int(1.5) )) $(( int(2.7) ))
now_ms >/dev/null
print -r -- loaded
''');
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    expect(_lines(run.output), <String>['1 2', 'loaded']);
  }, skip: _zshSkip);

  test(
    'scenarios that start on an empty note never save a blank note',
    () async {
      final _Driven run = await _driven('''
$_keyboardStubs
gr6_fixture() { :; }
gr6_run() { :; }
gb5_case() { :; }
scenario_photo_move_matrix
print -r -- 'photo-move-matrix started'
scenario_placement_matrix
print -r -- 'placement-matrix started'
scenario_keyboard_matrix
print -r -- 'keyboard-matrix started'
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(_lines(run.output), <String>[
        'photo-move-matrix started',
        'placement-matrix started',
        'keyboard-matrix started',
      ]);
    },
    skip: _zshSkip,
  );

  test('drag targets aim at window coordinates between the blocks', () async {
    final _Driven run = await _driven(r'''
state='{"blocks":[{"top":0,"globalTop":180,"globalBottom":200},{"top":30,"globalTop":230,"globalBottom":250},{"top":60,"globalTop":262,"globalBottom":300}],"lines":[{"top":0},{"top":60}]}'
gr6_boundary_y "$state" -1
gr6_boundary_y "$state" 0
gr6_boundary_y "$state" 1
gr6_boundary_y "$state" 2
''');
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    final List<double> ys = <double>[
      for (final String line in _lines(run.output)) _number(line),
    ];
    expect(ys, hasLength(4));
    expect(ys[0], inInclusiveRange(180, 200));
    expect(ys[1], inInclusiveRange(200, 230));
    expect(ys[2], inInclusiveRange(250, 262));
    expect(ys[3], greaterThan(300));
  }, skip: _zshSkip);

  test(
    'click sweeps click the selected glyph, revealed inside the window',
    () async {
      final _Driven run = await _driven(r'''
mkdir -p $WORK/bin
print -rl -- '#!/bin/sh' 'echo "$@" >> "$WORK/inp.log"' > $WORK/bin/inp
chmod +x $WORK/bin/inp
PROBE_BIN=$WORK/bin
plat_origin() { print -r -- '0 0'; }
select_range() { :; }
typeset -gi SCROLLED=0
plat_scroll() { SCROLLED=$(( SCROLLED - $3 )); }
probe_get() {
  case $1 in
    state*) print -r -- '{"view":{"width":800,"height":600},"writingSurface":[0,100,800,500],"length":100,"selection":[5,5,"downstream"]}' ;;
    boxes*) print -r -- "{\"glyphs\":[{\"rect\":[0,$(( 20000 - SCROLLED )),8,20],\"selected\":false},{\"rect\":[40,$(( 20000 - SCROLLED )),8,20],\"selected\":true}],\"firstSelected\":1}" ;;
  esac
}
RANDOM=7
gb3_note GB3 c500-p0 1
unsetopt err_exit
plat_click 10 20000
print -r -- "outside $?"
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(_lines(run.output), <String>['outside 3']);
      final List<String> clicks = run.lines('inp.log');
      expect(clicks, hasLength(1));
      final List<String> parts = clicks.single.split(' ');
      expect(parts.first, 'click');
      expect(_number(parts[1]), inInclusiveRange(40, 48));
      expect(_number(parts[2]), inInclusiveRange(100, 600));
      final Map<String, Object?> sample = run.samples.single;
      expect(sample['note'], 'c500-p0');
      expect(sample['glyphLeft'], 40);
    },
    skip: _zshSkip,
  );

  test(
    'an edit-note draft is checked on the same entry after the relaunch',
    () async {
      final _Driven run = await _driven(r'''
probe_post() {
  print -r -- "$1" >> $WORK/posts
  case $1 in
    open*) print -r -- '{"opened":true,"entryId":"entry-1","entryCount":1}' ;;
    *) print -r -- '{}' ;;
  esac
}
plat_type() { :; }
focus_editor() { :; }
select_range() { :; }
plat_kill() { :; }
plat_launch() { :; }
gr8_expected_caret() { print -r -- 9; }
state_get() { print -r -- '{"source":"x","canUndo":false,"selection":[9,9,"downstream"]}'; }
text_present() { return 0; }
gr8_case 'edit note, wait 500 ms, kill' edit wait
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final List<String> opens = run
          .lines('posts')
          .where((String line) => line.startsWith('open'))
          .toList();
      expect(opens, hasLength(2));
      expect(opens.first, startsWith('open?surface=composer&id=fixture'));
      expect(opens.last, startsWith('open?surface=composer&entry=entry-1'));
    },
    skip: _zshSkip,
  );

  test('undo cases type one U1 entry and press Move down itself', () async {
    final _Driven run = await _driven(r'''
undo_case() { print -rn -- "${(pj:\x1f:)@}"$'\x1e' >> $WORK/undo; }
open_text() { :; }
focus_editor() { :; }
select_range() { :; }
plat_key() { :; }
state_get() { print -r -- '{"canUndo":false,"source":"x","transactions":0}'; }
expect_sample() { :; }
scenario_undo_matrix
''');
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    final List<List<String>> calls = <List<String>>[
      for (final String record in File(
        '${run.work.path}/undo',
      ).readAsStringSync().split('\x1e'))
        if (record.isNotEmpty) record.split('\x1f'),
    ];
    final List<String> typing = calls.singleWhere(
      (List<String> call) => call.first == 'typing a word',
    );
    final List<String> typed = <String>[
      for (final String field in typing.skip(1))
        if (field.startsWith('type:')) field.substring(5),
    ];
    expect(typed, isNotEmpty);
    expect(typed.where((String text) => text.contains(' ')), isEmpty);
    expect(typing[1] + typed.join(), 'the quick fox jumps over');
    expect(int.parse(typing[2]), typing[1].length);
    final List<String> move = calls.singleWhere(
      (List<String> call) => call.first == 'photo move down',
    );
    expect(
      move.skip(1).where((String field) => field.startsWith('photo:')),
      isEmpty,
    );
    expect(move, contains('press:photo-toolbar-move-down'));
    final String fixture = move[1];
    final int start = fixture.indexOf('![');
    final int end = fixture.indexOf(')', start) + 1;
    expect(move[4], '[$start,$end]');

    final _Driven direct = await _driven(r'''
open_text() { :; }
focus_editor() { :; }
select_range() { :; }
run_op() { :; }
plat_key() { :; }
state_get() { print -r -- '{"source":"x","selection":[19,40,"downstream"]}'; }
expect_sample() { print -r -- "$3" >> $WORK/expected; }
undo_case 'photo move down' x 0 0 '[19,40]' select:0
''');
    expect(direct.result.exitCode, 0, reason: '${direct.result.stderr}');
    expect(direct.lines('expected').first, contains('"selection":[19,40]'));
  }, skip: _zshSkip);

  test(
    'deleting at a line start may remove the line break before it',
    () async {
      final _Driven run = await _driven(r'''
allowed_range key:backspace '{"source":"abc\ndef","selection":[4,4]}'
allowed_range key:opt+backspace '{"source":"abc\ndef","selection":[4,4]}'
allowed_range key:delete '{"source":"abc\ndef","selection":[3,3]}'
allowed_range key:backspace '{"source":"abc\ndef","selection":[5,5]}'
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final List<String> ranges = _lines(run.output);
      expect(ranges, <String>['[[0,7]]', '[[0,7]]', '[[0,7]]', '[[4,7]]']);
      final RowOutcome joined = _judge(
        'side-edit-audit',
        'GR2',
        <Map<String, Object?>>[
          <String, Object?>{
            'row': 'GR2',
            'kind': 'sideEdit',
            'case': 'enter then backspace',
            'command': 'key:backspace',
            'allowed': jsonDecode(ranges.first),
            'changes': <Object?>[
              <int>[3, 4, 0],
            ],
          },
        ],
      );
      expect(joined.verdict, GateVerdict.pass);
    },
    skip: _zshSkip,
  );

  test(
    'the narrow mode forces a column too narrow for the move controls',
    () async {
      final _Driven run = await _driven(r'''
state_get() { print -r -- '{"column":350,"writingSurface":[0,64,380,700],"photoToolbarNarrowWidth":202.5}'; }
probe_get() { print -r -- "$1" >> $WORK/gets; print -r -- '{}'; }
narrow_toolbar_viewport
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(run.lines('gets'), <String>['viewport?column=170']);
      expect(170 + (380 - 350), lessThan(202.5));
    },
    skip: _zshSkip,
  );

  test(
    'an idle case with a focused caption field counts as a visible caret',
    () async {
      final _Driven run = await _driven(r'''
probe_get() {
  case $1 in
    pid) print -r -- '{"pid":4242}' ;;
    clock) print -r -- '{"now":1000000}' ;;
    timings*) print -r -- '{"refreshHz":120,"frames":[]}' ;;
    state*) print -r -- '{"caret":null,"textFieldFocused":true}' ;;
  esac
}
plat_cpu() { print -r -- '0:00.10'; }
idle_measure 'caption field open'
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final Map<String, Object?> sample = run.samples.single;
      expect(sample['caretVisible'], isTrue);
      expect(sample['windowStartMicros'], 1000000);
      expect(sample['windowEndMicros'], 1000000);
    },
    skip: _zshSkip,
  );

  test(
    'keys go only to a frontmost probe, and owner steps bring it back',
    () async {
      final _Driven run = await _driven(r'''
probe_get() { print -r -- '{"pid":4242}'; }
typeset -g FRONT=999
lsappinfo() {
  if [[ $1 == front ]]; then
    print -r -- 'ASN:0x0-0x1:'
  else
    print -r -- "\"pid\"=$FRONT"
  fi
}
osascript() {
  print -r -- "$*" >> $WORK/osascript.log
  [[ $* == *'set frontmost'* && -n ${ACTIVATES:-} ]] && FRONT=4242
  return 0
}
unsetopt err_exit
plat_key a
print -r -- "key $?"
plat_type hello
print -r -- "type $?"
print -r -- '' > $WORK/tty
PROBE_TTY=$WORK/tty
ACTIVATES=1
plat_owner_step 'switch the input source to Japanese (Romaji)'
print -r -- "owner $?"
plat_key a
print -r -- "key again $?"
''');
      expect(_lines(run.output), <String>[
        'key 3',
        'type 3',
        'owner 0',
        'key again 0',
      ], reason: '${run.result.stderr}');
      final List<String> log = run.lines('osascript.log');
      bool sendsKeys(String line) =>
          line.contains('key code') || line.contains('keystroke');
      expect(log.where(sendsKeys), hasLength(1));
      expect(
        log.indexWhere(sendsKeys),
        greaterThan(
          log.lastIndexWhere((String line) => line.contains('set frontmost')),
        ),
      );
    },
    skip: _zshSkip,
  );

  test('an input-method case fails when nothing reached the editor', () async {
    Future<Map<String, Object?>> committed(String log, String source) async {
      final _Driven run = await _driven('''
probe_get() {
  case \$1 in
    log) print -r -- '{"committed":$log}' ;;
    errors*) print -r -- '{"errors":[],"drops":[]}' ;;
  esac
}
state_get() { print -r -- '{"source":"$source"}'; }
ime_committed_expect 'japanese multi-phrase conversion' non-ascii
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      return run.samples.single;
    }

    expect(
      _judge('ime-matrix', 'GB7', <Map<String, Object?>>[
        await committed('[]', 'fog '),
      ]).verdict,
      GateVerdict.fail,
    );
    expect(
      _judge('ime-matrix', 'GB7', <Map<String, Object?>>[
        await committed('["harbour"]', 'fog harbour'),
      ]).verdict,
      GateVerdict.fail,
    );
    expect(
      _judge('ime-matrix', 'GB7', <Map<String, Object?>>[
        await committed('["日本語"]', 'fog 日本語'),
      ]).verdict,
      GateVerdict.pass,
    );
  }, skip: _zshSkip);

  test(
    'a Finder drop aims below the caret block and expects its boundary bytes',
    () async {
      final _Driven run = await _driven(r'''
GR7_CARET=23
GR7_FIXTURE=$'First paragraph here.\n\n\n\nSecond paragraph.'
GR7_BEFORE='{"length":42}'
state_get() { print -r -- '{"view":{"width":800,"height":600},"blocks":[{"start":0,"end":21,"globalTop":100,"globalBottom":125},{"start":25,"end":42,"globalTop":180,"globalBottom":205}]}'; }
gr7_drop_target
print -r -- "$GR7_DROP_Y"
print -r -- "$GR7_DROP_BOUNDARY"
gr7_drop_expected $'\n![](photo/abc "right medium")' > $WORK/expected
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final List<String> lines = _lines(run.output);
      expect(_number(lines[0]), inExclusiveRange(125, 180));
      expect(lines[1], '21');
      expect(
        File('${run.work.path}/expected').readAsStringSync(),
        'First paragraph here.\n![](photo/abc "right medium")\n\n\n\n'
        'Second paragraph.',
      );
    },
    skip: _zshSkip,
  );

  test('run.sh reaps a probe left running by a relaunch', () async {
    final Directory work = Directory.systemTemp.createTempSync('probe_reap');
    addTearDown(() => work.deleteSync(recursive: true));
    final String name = 'field_notes_probe_reap_$pid';
    final Directory macos = Directory('${work.path}/$name.app/Contents/MacOS')
      ..createSync(recursive: true);
    final String binary = '${macos.path}/$name';
    File('/bin/sleep').copySync(binary);
    await Process.run('chmod', <String>['+x', binary]);
    final Process stray = await Process.start(binary, <String>['60']);
    addTearDown(() => stray.kill(ProcessSignal.sigkill));
    final ProcessResult reaped = await Process.run('zsh', <String>[
      '-c',
      'source $_driver/run.sh --library; PROBE_NAME=$name; reap_probes',
    ]);
    expect(reaped.exitCode, 0, reason: '${reaped.stderr}');
    final int code = await stray.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () => 0,
    );
    expect(code, isNot(0));
  }, skip: _zshSkip);

  test(
    'draft recovery checks Save during a restore and a discarded note',
    () async {
      final _Driven run = await _driven(r'''
gr8_case() { :; }
plat_type() { :; }
focus_editor() { :; }
plat_kill() { :; }
plat_launch() { :; }
probe_post() {
  case $1 in
    open*) print -r -- '{"opened":true,"entryId":null,"entryCount":2}' ;;
    save) print -r -- '{"saved":false,"stored":null,"entryCount":2}' ;;
    close*) print -r -- '{"closed":true,"discarded":true}' ;;
    *) print -r -- '{}' ;;
  esac
}
state_get() { print -r -- '{"source":"fog lifting","entryCount":2}'; }
text_present() { return 0; }
scenario_draft_recovery
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final List<Map<String, Object?>> saves = run.samples
          .where(
            (Map<String, Object?> sample) =>
                sample['case'] == 'save is ignored while the draft loads',
          )
          .toList();
      expect(saves, hasLength(20));
      expect(
        run.samples.where(
          (Map<String, Object?> sample) =>
              sample['case'] == 'a discarded note leaves no draft',
        ),
        hasLength(20),
      );
      expect(
        (saves.first['observed']! as Map<String, Object?>)['saveIgnored'],
        isTrue,
      );
    },
    skip: _zshSkip,
  );

  test('photo commands in the side-edit audit are judged against P3', () async {
    const String photo = '![p](photo/abc123abc123 "right medium")';
    const String source =
        'Head paragraph.\n\nA plain paragraph.\n\n$photo\n\nTail paragraph.';
    final int start = source.indexOf(photo);
    final int end = start + photo.length;
    final int tail = source.indexOf('Tail');
    final String before = jsonEncode(<String, Object?>{
      'source': source,
      'selection': <Object?>[0, 0, 'downstream'],
      'photos': <Object?>[
        <String, Object?>{'reference': 'abc123abc123', 'ordinal': 0},
      ],
      'blocks': <Object?>[
        <String, Object?>{'kind': 'paragraph', 'start': 0, 'end': 15},
        <String, Object?>{'kind': 'paragraph', 'start': 17, 'end': 35},
        <String, Object?>{'kind': 'photoLine', 'start': start, 'end': end},
        <String, Object?>{
          'kind': 'paragraph',
          'start': tail,
          'end': source.length,
        },
      ],
    });
    final String legit = jsonEncode(<Object?>[
      <int>[15, 15, photo.length + 1],
      <int>[start, end + 2, 0],
    ]);
    final String sideEdit = jsonEncode(<Object?>[
      <int>[15, 15, photo.length + 1],
      <int>[start, end + 2, 0],
      <int>[tail, tail + 1, 1],
    ]);
    final _Driven run = await _driven('''
side_edit_sample legit 'photo:0:photo-toolbar-move-up' '$before' '$legit'
side_edit_sample side 'photo:0:photo-toolbar-move-up' '$before' '$sideEdit'
''');
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    final List<Map<String, Object?>> samples = run.samples;
    expect(samples, hasLength(2));
    expect(
      _judge('side-edit-audit', 'GR2', <Map<String, Object?>>[
        samples.first,
      ]).verdict,
      GateVerdict.pass,
    );
    expect(
      _judge('side-edit-audit', 'GR2', <Map<String, Object?>>[
        samples.last,
      ]).verdict,
      GateVerdict.fail,
    );
  }, skip: _zshSkip);

  test(
    'the keyboard matrix covers the P2, C7, C9, P8 and I8 selector rules',
    () async {
      final _Driven run = await _driven('''
$_keyboardStubs
scenario_keyboard_matrix
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final Set<String> names = <String>{
        ...run.lines('cases'),
        ...run.lines('expected'),
      };
      for (final String name in <String>[
        'P2 left from the line after selects the photo',
        'P2 up crosses a photo as one line',
        'P2 down crosses a photo as one line',
        'P2 delete at the end of the line before selects the photo',
        'P2 cmd x cuts a selected photo under P3',
        'P2 cmd c copies a selected photo line',
        'C7 escape with nothing to dismiss reaches the discard prompt',
        'C9 a typed heading marker stays as typed',
        'P8 caption commits with a click outside',
        'I8 option up moves to the paragraph start '
            '(moveToBeginningOfParagraph)',
        'I8 ctrl e moves to the line end (moveToEndOfLine)',
      ]) {
        expect(names, contains(name));
      }
    },
    skip: _zshSkip,
  );

  test(
    'held clicks cover every format-bar control with their case and hold',
    () async {
      final _Driven run = await _driven(r'''
format_selection() { :; }
format_press() { :; }
press_key() { :; }
plat_key() { :; }
plat_click() { :; }
set_text() { :; }
focus_editor() { :; }
select_range() { :; }
open_text() { :; }
errors_total() { print -r -- 0; }
key_present() { return 0; }
state_get() { print -r -- '{"transactions":0,"source":"the quick fox","selection":[4,9,"downstream"]}'; }
probe_get() { print -r -- '{"glyphs":[{"rect":[10,10,8,20],"selected":true}],"firstSelected":0}'; }
held_format_clicks 30
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final List<Map<String, Object?>> samples = run.samples;
      final Map<Object?, int> counts = <Object?, int>{
        for (final Object? clickCase in <Object?>{
          for (final Map<String, Object?> sample in samples)
            sample['clickCase'],
        })
          clickCase: samples
              .where(
                (Map<String, Object?> sample) =>
                    sample['clickCase'] == clickCase,
              )
              .length,
      };
      for (final String control in <String>[
        'format-undo',
        'format-more',
        'format-strikethrough',
        'format-highlight',
        'format-code',
        'format-bold',
        'checkbox',
        'photo figure',
      ]) {
        expect(counts[control], 20, reason: control);
      }
      expect(
        samples.every((Map<String, Object?> sample) => sample['hold'] == 30),
        isTrue,
      );
      final RowOutcome gr3 = _judge('held-clicks', 'GR3', samples);
      expect(gr3.verdict, GateVerdict.fail);
      expect(gr3.measured, startsWith('too few samples'));
    },
    skip: _zshSkip,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'screen-reader samples carry what the semantics tree must show',
    () async {
      final _Driven run = await _driven(r'''
plat_speech_last() { print -r -- 'Harbour day, heading'; }
probe_get() { print -r -- '{"root":{"label":"","value":"","flags":[],"children":[]}}'; }
A11Y_PHOTOS='["Photo, Low tide"]'
A11Y_CHECKBOXES='["passport"]'
a11y_expect 'read the note' 'Harbour day'
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final Map<String, Object?> sample = run.samples.single;
      expect(sample['kind'], 'a11y');
      expect(sample['photos'], <Object?>['Photo, Low tide']);
      expect(sample['checkboxes'], <Object?>['passport']);
      final RowOutcome gb8 = _judge(
        'a11y-matrix',
        'GB8',
        <Map<String, Object?>>[sample],
      );
      expect(gb8.verdict, GateVerdict.fail);
      expect(gb8.measured, contains('no text-field node'));
    },
    skip: _zshSkip,
  );

  test('toolbar placement is judged against the writing surface', () async {
    final _Driven run = await _driven(r'''
scroll_photo_to() { :; }
select_photo() { :; }
probe_get() { print -r -- '{"photo-toolbar":[100,70,300,38]}'; }
state_get() { print -r -- '{"view":{"width":800,"height":860},"writingSurface":[0,120,800,700],"photos":[{"rect":[100,118,400,300]}]}'; }
toolbar_case 'photo at the top of the view' 0
''');
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    final Map<String, Object?> sample = run.samples.single;
    expect(sample['surface'], <Object?>[0, 120, 800, 700]);
    expect(
      _judge('toolbar-placement', 'GB11', <Map<String, Object?>>[
        sample,
      ]).verdict,
      GateVerdict.fail,
    );
  }, skip: _zshSkip);

  test(
    'the random run records its steps and fails when it had to relaunch',
    () async {
      final _Driven run = await _driven(r'''
PROBE_SCENARIOS=()
PROBE_MONKEY_STEPS=500
open_note() { :; }
focus_editor() { :; }
plat_key() { :; }
plat_click() { :; }
plat_drag() { :; }
plat_launch() { print -r -- launched >> $WORK/launches; }
state_get() { print -r -- '{"view":{"width":800,"height":600}}'; }
probe_get() {
  case $1 in
    pid) return 7 ;;
    errors*) print -r -- '{"errors":[],"drops":[]}' ;;
    *) print -r -- '{}' ;;
  esac
}
scenario_monkey
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(run.lines('launches'), <String>['launched']);
      final List<Map<String, Object?>> samples = run.samples;
      final Map<String, Object?> relaunch = samples.singleWhere(
        (Map<String, Object?> sample) =>
            '${sample['case']}'.startsWith('random relaunch'),
      );
      expect(
        (relaunch['errors']! as Map<String, Object?>)['errors'],
        isNotEmpty,
      );
      expect(
        samples.singleWhere(
          (Map<String, Object?> sample) => sample['case'] == 'random',
        )['steps'],
        500,
      );
      expect(
        _judge('monkey', 'GR4', samples, build: 'debug').verdict,
        GateVerdict.fail,
      );
    },
    skip: _zshSkip,
  );

  test(
    'scrolling follows the scroll offset to the end and back to the top',
    () async {
      final _Driven run = await _driven(r'''
typeset -gi OFFSET=0 MAX=5000
plat_scroll() {
  OFFSET=$(( OFFSET - $3 ))
  (( OFFSET < 0 )) && OFFSET=0
  (( OFFSET > MAX )) && OFFSET=$MAX
  print -r -- x >> $WORK/scrolls
}
state_get() { print -r -- "{\"view\":{\"width\":800,\"height\":600},\"scroll\":{\"offset\":$OFFSET,\"max\":$MAX},\"blocks\":[{\"top\":0},{\"top\":9000}]}"; }
scroll_through 120
print -r -- "bottom $OFFSET"
scroll_to_top
print -r -- "top $OFFSET"
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      expect(_lines(run.output), <String>['bottom 5000', 'top 0']);
      expect(run.lines('scrolls').length, lessThan(120));
    },
    skip: _zshSkip,
  );

  test('the end-of-note insertion caret comes from the probe length', () async {
    final _Driven run = await _driven(r'''
open_note() { :; }
focus_editor() { :; }
state_get() { print -r -- '{"length":50000}'; }
select_range() { print -r -- "$1 $2" >> $WORK/selects; }
gr7_prepare 'end of c50000-p24'
print -r -- "caret $GR7_CARET"
''');
    expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
    expect(_lines(run.output), <String>['caret 50000']);
    expect(run.lines('selects'), <String>['50000 50000']);
  }, skip: _zshSkip);

  test(
    'a save reply without stored text is a failed round trip, not a copy',
    () async {
      final _Driven run = await _driven(r'''
open_text() { :; }
focus_editor() { :; }
select_range() { :; }
run_op() { :; }
state_get() { print -r -- '{"source":"Walk "}'; }
probe_post() {
  print -r -- "$1" >> $WORK/posts
  case $1 in
    save) print -r -- '{"saved":true,"stored":null}' ;;
    *) print -r -- '{}' ;;
  esac
}
round_trip_session 'across midnight' key:left
''');
      expect(run.result.exitCode, 0, reason: '${run.result.stderr}');
      final Map<String, Object?> sample = run.samples.single;
      expect(sample['storedMissing'], isTrue);
      expect(
        run.lines('posts').where((String line) => line.contains('roundtrip')),
        isEmpty,
      );
    },
    skip: _zshSkip,
  );
}
