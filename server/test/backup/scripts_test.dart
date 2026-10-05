import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/blobs.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import '../support/relay_harness.dart';

const String unitSeparator = '\u001f';
const String heartbeatBase = 'https://heartbeat.invalid';

final String serverDirectory = p.dirname(defaultMigrationsDirectory());
final String deployDirectory = p.join(serverDirectory, 'deploy');

const String shebang = '#!/bin/bash\n';

const String recordingLines = r'''log="$STUB_LOGS/$(basename "$0").log"
for argument in "$@"; do
  printf '%s\037' "$argument" >> "$log"
done
printf '\n' >> "$log"
''';

const String recordingPrelude = '$shebang$recordingLines';

const String rsyncStub =
    '''$shebang
if [ "\$1" = "--version" ]; then
  printf 'rsync  version %s  protocol version 32\\n' "\${STUB_RSYNC_VERSION:-3.4.1}"
  exit 0
fi
$recordingLines
for host in \${STUB_RSYNC_FAIL:-}; do
  for argument in "\$@"; do
    case "\$argument" in
      *"@\$host/"*) exit 10 ;;
    esac
  done
done
last=""
for argument in "\$@"; do
  last="\$argument"
done
if [ -n "\${STUB_NAS:-}" ]; then
  case "\$last" in
    rsync://*) ;;
    *) cp -R "\$STUB_NAS/." "\$last" ;;
  esac
fi
exit 0
''';

const String dockerStub = '''$recordingPrelude
command="\$1"
shift
case "\$command" in
  ps)
    for argument in "\$@"; do
      case "\$argument" in
        label=com.docker.compose.service=*)
          printf 'container-%s\\n' "\${argument#label=com.docker.compose.service=}"
          ;;
      esac
    done
    ;;
  exec)
    shift
    if [ "\$2" = "snapshot-db" ]; then
      if [ "\${STUB_SNAPSHOT_FAIL:-}" = "yes" ]; then
        exit 1
      fi
      printf 'snapshot' > "\$4"
      printf 'field-notes-relay-manifest\\t1\\n' > "\$4.manifest"
    elif [ "\$1" = "curl" ]; then
      printf '%s' "\${STUB_HEALTH:-200}"
    fi
    ;;
  run)
    index=0
    for argument in "\$@"; do
      index=\$((index + 1))
      if [ "\$argument" = "verify-copy" ]; then
        shift \$((index - 1))
        exec "\$STUB_RELAY" "\$@"
      fi
    done
    for argument in "\$@"; do
      if [ "\$argument" = "--detach" ]; then
        printf 'stub-drill-container\\n'
      fi
    done
    ;;
esac
exit 0
''';

const String curlStub = '''$recordingPrelude
exit 0
''';

const String msmtpStub = '''$recordingPrelude
cat >> "\$STUB_LOGS/mail.txt"
printf '\\n----\\n' >> "\$STUB_LOGS/mail.txt"
exit 0
''';

String today() {
  final DateTime now = DateTime.now().toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}

void copyTree(Directory source, Directory target) {
  for (final FileSystemEntity entity in source.listSync(recursive: true)) {
    final String relative = p.relative(entity.path, from: source.path);
    if (p.split(relative).contains(stagingFolderName)) {
      continue;
    }
    final String destination = p.join(target.path, relative);
    if (entity is Directory) {
      Directory(destination).createSync(recursive: true);
    } else if (entity is File) {
      Directory(p.dirname(destination)).createSync(recursive: true);
      entity.copySync(destination);
    }
  }
}

final class ScriptBench {
  ScriptBench._(this.root, this.logs, this.config, this.environment);

  static Future<ScriptBench> create() async {
    final Directory root = await Directory.systemTemp.createTemp(
      'relay_scripts_',
    );
    addTearDown(() => root.delete(recursive: true));
    final Directory bin = Directory(p.join(root.path, 'bin'))..createSync();
    final Directory logs = Directory(p.join(root.path, 'logs'))..createSync();
    final Directory config = Directory(p.join(root.path, 'config'))
      ..createSync();
    final Map<String, String> stubs = <String, String>{
      'rsync': rsyncStub,
      'docker': dockerStub,
      'curl': curlStub,
      'msmtp': msmtpStub,
    };
    for (final MapEntry<String, String> stub in stubs.entries) {
      _executable(p.join(bin.path, stub.key), stub.value);
    }
    final String relay = p.join(root.path, 'relay-wrapper');
    _executable(
      relay,
      '#!/bin/bash\n'
      'cd "$serverDirectory" || exit 70\n'
      'exec "${Platform.resolvedExecutable}" run bin/relay.dart "\$@"\n',
    );
    File(p.join(config.path, 'nas-rsync.pass'))
        .writeAsStringSync('stub-password\n');
    File(p.join(config.path, 'heartbeat.env')).writeAsStringSync(
      'FN_NIGHTLY_PING_URL=$heartbeatBase/nightly\n'
      'FN_DRILL_PING_URL=$heartbeatBase/drill\n',
    );
    return ScriptBench._(root, logs, config, <String, String>{
      'PATH': '${bin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
      'STUB_LOGS': logs.path,
      'STUB_RELAY': relay,
      'FN_CONFIG_DIR': config.path,
      'FN_RETRY_DELAY': '0',
      'FN_HEALTH_DELAY': '0',
    });
  }

  static void _executable(String path, String content) {
    File(path).writeAsStringSync(content);
    Process.runSync('chmod', <String>['755', path]);
  }

  final Directory root;
  final Directory logs;
  final Directory config;
  final Map<String, String> environment;

  Future<ProcessResult> run(String script, Map<String, String> extra) =>
      Process.run(
        '/bin/bash',
        <String>[p.join(deployDirectory, script)],
        environment: <String, String>{...environment, ...extra},
      );

  List<List<String>> calls(String command) {
    final File log = File(p.join(logs.path, '$command.log'));
    if (!log.existsSync()) {
      return <List<String>>[];
    }
    return <List<String>>[
      for (final String line in log.readAsLinesSync())
        if (line.isNotEmpty) line.split(unitSeparator)..removeLast(),
    ];
  }

  List<String> heartbeats() => <String>[
    for (final List<String> call in calls('curl')) call.last,
  ];

  String mail() {
    final File file = File(p.join(logs.path, 'mail.txt'));
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  void clearLogs() {
    for (final FileSystemEntity entity in logs.listSync()) {
      entity.deleteSync();
    }
  }

  Directory relayRoot(String name) {
    final Directory folder = Directory(p.join(root.path, name))..createSync();
    File(p.join(folder.path, 'relay.sqlite3')).writeAsStringSync('live');
    File(p.join(folder.path, 'relay.sqlite3-wal')).writeAsStringSync('wal');
    File(p.join(folder.path, 'relay.sqlite3-shm')).writeAsStringSync('shm');
    Directory(p.join(folder.path, 'media', stagingFolderName, 'unfinished'))
        .createSync(recursive: true);
    Directory(p.join(folder.path, 'backup')).createSync();
    return folder;
  }

  Future<({Directory nas, String accountId, List<String> names})>
  nasCopy() async {
    final RelayHarness harness = await RelayHarness.start();
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    await harness.push(me.session, <RecordPush>[
      harness.record('note-0'),
      harness.record('note-1'),
      harness.record('note-2'),
    ]);
    final List<String> names = <String>[harness.blobName(), harness.blobName()];
    for (final String name in names) {
      await harness.uploadBlob(me.session, name, harness.randomOpaque(1500));
    }
    final Directory nas = Directory(p.join(root.path, 'nas'));
    snapshotDatabase(
      databasePath: harness.databasePath,
      target: p.join(nas.path, 'backup', 'relay-2026-10-01.sqlite3'),
    );
    copyTree(
      Directory(harness.mediaDirectory),
      Directory(p.join(nas.path, 'media')),
    );
    return (nas: nas, accountId: account.accountId, names: names);
  }
}

List<String> sourcesOf(List<String> call) => <String>[
  for (final String argument in call.sublist(0, call.length - 1))
    if (!argument.startsWith('-')) argument,
];

List<String> snapshotsIn(Directory relay) {
  final List<String> names = <String>[
    for (final FileSystemEntity entity in Directory(
      p.join(relay.path, 'backup'),
    ).listSync())
      if (p.basename(entity.path).endsWith('.sqlite3')) p.basename(entity.path),
  ]..sort();
  return names;
}

void main() {
  test('the nightly copy skips snapshot folders, falls back to the second address and alerts on failure', () async {
    final ScriptBench bench = await ScriptBench.create();
    final Directory relay = bench.relayRoot('relay');
    final Directory testRelay = bench.relayRoot('relay-test');
    for (int day = 1; day <= 8; day++) {
      final String old = p.join(
        relay.path,
        'backup',
        'relay-2000-01-0$day.sqlite3',
      );
      File(old).writeAsStringSync('old');
      File('$old.manifest').writeAsStringSync('old');
    }
    final Map<String, String> roots = <String, String>{
      'FN_RELAY_ROOT': relay.path,
      'FN_TEST_RELAY_ROOT': testRelay.path,
    };

    final ProcessResult fallback = await bench.run(
      'nightly-copy.sh',
      <String, String>{...roots, 'STUB_RSYNC_FAIL': '10.0.0.246'},
    );

    expect(fallback.exitCode, 0, reason: '${fallback.stderr}');
    final List<List<String>> copies = bench.calls('rsync');
    expect(copies.map((List<String> call) => call.last), <String>[
      'rsync://fn-backup@10.0.0.246/field-notes-backup/',
      'rsync://fn-backup@10.0.0.247/field-notes-backup/',
      'rsync://fn-backup@10.0.0.246/field-notes-backup-test/',
      'rsync://fn-backup@10.0.0.247/field-notes-backup-test/',
    ]);
    for (final List<String> call in copies) {
      expect(
        call,
        containsAll(<String>[
          '--delete',
          '--exclude=#snapshot/',
          '--exclude=@eaDir/',
          '--exclude=.uploads/',
          '--exclude=relay.sqlite3',
          '--exclude=relay.sqlite3-wal',
          '--exclude=relay.sqlite3-shm',
          '--password-file=${p.join(bench.config.path, 'nas-rsync.pass')}',
        ]),
      );
      expect(sourcesOf(call), hasLength(2));
      expect(
        sourcesOf(call).any((String source) => source.contains('sqlite3')),
        isFalse,
      );
    }
    expect(sourcesOf(copies.first), <String>[
      p.join(relay.path, 'backup'),
      p.join(relay.path, 'media'),
    ]);
    expect(sourcesOf(copies.last), <String>[
      p.join(testRelay.path, 'backup'),
      p.join(testRelay.path, 'media'),
    ]);
    final List<List<String>> snapshots = <List<String>>[
      for (final List<String> call in bench.calls('docker'))
        if (call.first == 'exec') call,
    ];
    expect(snapshots.map((List<String> call) => call[1]), <String>[
      'container-fn-relay',
      'container-fn-relay-test',
    ]);
    expect(snapshots.map((List<String> call) => call.last), <String>[
      p.join(relay.path, 'backup', 'relay-${today()}.sqlite3'),
      p.join(testRelay.path, 'backup', 'relay-${today()}.sqlite3'),
    ]);
    final List<String> kept = snapshotsIn(relay);
    expect(kept, hasLength(7));
    expect(kept.last, 'relay-${today()}.sqlite3');
    expect(kept, isNot(contains('relay-2000-01-01.sqlite3')));
    expect(kept, isNot(contains('relay-2000-01-02.sqlite3')));
    expect(
      File(p.join(relay.path, 'backup', 'relay-2000-01-01.sqlite3.manifest'))
          .existsSync(),
      isFalse,
    );
    expect(bench.calls('msmtp'), isEmpty);

    bench.clearLogs();
    final ProcessResult failed = await bench.run(
      'nightly-copy.sh',
      <String, String>{...roots, 'STUB_RSYNC_FAIL': '10.0.0.246 10.0.0.247'},
    );

    expect(failed.exitCode, isNot(0));
    expect(bench.calls('rsync'), hasLength(8));
    expect(
      bench.calls('docker').where((List<String> call) => call.first == 'exec'),
      hasLength(4),
    );
    expect(bench.calls('msmtp'), hasLength(1));
    final String mail = bench.mail();
    expect(mail, contains('To: satanshumishra@outlook.com'));
    expect(mail, contains('nightly copy failed'));
    expect(mail, contains('copy of fn-relay to the NAS'));
  });

  test('the nightly copy reports start and result to the heartbeat', () async {
    final ScriptBench bench = await ScriptBench.create();
    final Map<String, String> roots = <String, String>{
      'FN_RELAY_ROOT': bench.relayRoot('relay').path,
      'FN_TEST_RELAY_ROOT': bench.relayRoot('relay-test').path,
    };

    final ProcessResult succeeded = await bench.run('nightly-copy.sh', roots);

    expect(succeeded.exitCode, 0, reason: '${succeeded.stderr}');
    expect(bench.heartbeats(), <String>[
      '$heartbeatBase/nightly/start',
      '$heartbeatBase/nightly',
    ]);

    bench.clearLogs();
    final ProcessResult failed = await bench.run(
      'nightly-copy.sh',
      <String, String>{...roots, 'STUB_SNAPSHOT_FAIL': 'yes'},
    );

    expect(failed.exitCode, isNot(0));
    expect(bench.heartbeats(), <String>[
      '$heartbeatBase/nightly/start',
      '$heartbeatBase/nightly/fail',
    ]);
    expect(bench.calls('msmtp'), hasLength(1));
    expect(bench.mail(), contains('snapshot of fn-relay'));
  });

  test('the restore drill fails and alerts on a bad copy', () async {
    final ScriptBench bench = await ScriptBench.create();
    final ({Directory nas, String accountId, List<String> names}) copy =
        await bench.nasCopy();
    File(
      blobPath(
        p.join(copy.nas.path, 'media'),
        copy.accountId,
        copy.names.first,
      ),
    ).deleteSync();
    final Directory drillRoot = Directory(p.join(bench.root.path, 'drill'));

    final ProcessResult result = await bench.run(
      'restore-drill.sh',
      <String, String>{
        'STUB_NAS': copy.nas.path,
        'FN_DRILL_ROOT': drillRoot.path,
      },
    );

    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('missing blob ${copy.accountId}/'));
    expect(bench.heartbeats(), <String>[
      '$heartbeatBase/drill/start',
      '$heartbeatBase/drill/fail',
    ]);
    expect(bench.calls('msmtp'), hasLength(1));
    expect(bench.mail(), contains('restore drill failed'));
    expect(bench.mail(), contains('verify-copy of relay-2026-10-01.sqlite3'));
    expect(
      bench
          .calls('docker')
          .where((List<String> call) => call.contains('--detach')),
      isEmpty,
    );
    expect(drillRoot.listSync(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('the restore drill passes on a good copy', () async {
    final ScriptBench bench = await ScriptBench.create();
    final ({Directory nas, String accountId, List<String> names}) copy =
        await bench.nasCopy();
    final Directory drillRoot = Directory(p.join(bench.root.path, 'drill'));

    final ProcessResult result = await bench.run(
      'restore-drill.sh',
      <String, String>{
        'STUB_NAS': copy.nas.path,
        'FN_DRILL_ROOT': drillRoot.path,
      },
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(bench.heartbeats(), <String>[
      '$heartbeatBase/drill/start',
      '$heartbeatBase/drill',
    ]);
    expect(bench.calls('msmtp'), isEmpty);
    final List<List<String>> docker = bench.calls('docker');
    final List<String> started = docker.firstWhere(
      (List<String> call) => call.contains('--detach'),
    );
    expect(started, containsAll(<String>['--network', 'none', '--read-only']));
    expect(
      docker.any(
        (List<String> call) => call.first == 'exec' && call.contains('curl'),
      ),
      isTrue,
    );
    expect(
      docker.any(
        (List<String> call) => call.first == 'rm' && call.contains('--force'),
      ),
      isTrue,
    );
    expect(drillRoot.listSync(), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('the nightly copy refuses an rsync older than 3.4.0', () async {
    final ScriptBench bench = await ScriptBench.create();
    final Map<String, String> roots = <String, String>{
      'FN_RELAY_ROOT': bench.relayRoot('relay').path,
      'FN_TEST_RELAY_ROOT': bench.relayRoot('relay-test').path,
    };

    final ProcessResult old = await bench.run(
      'nightly-copy.sh',
      <String, String>{...roots, 'STUB_RSYNC_VERSION': '3.3.0'},
    );

    expect(old.exitCode, isNot(0));
    expect(bench.calls('rsync'), isEmpty);
    expect(bench.calls('docker'), isEmpty);
    expect(bench.heartbeats(), <String>[
      '$heartbeatBase/nightly/start',
      '$heartbeatBase/nightly/fail',
    ]);
    expect(bench.calls('msmtp'), hasLength(1));
    expect(bench.mail(), contains('nightly copy failed'));
    expect(
      bench.mail(),
      contains('check rsync (found 3.3.0, need 3.4.0 or newer)'),
    );

    bench.clearLogs();
    final ProcessResult current = await bench.run(
      'nightly-copy.sh',
      <String, String>{...roots, 'STUB_RSYNC_VERSION': '3.4.0'},
    );

    expect(current.exitCode, 0, reason: '${current.stderr}');
    expect(bench.calls('rsync'), hasLength(2));
    expect(bench.calls('msmtp'), isEmpty);
  });

  test('the restore drill refuses an rsync older than 3.4.0', () async {
    final ScriptBench bench = await ScriptBench.create();
    final Directory drillRoot = Directory(p.join(bench.root.path, 'drill'));

    final ProcessResult result = await bench.run(
      'restore-drill.sh',
      <String, String>{
        'FN_DRILL_ROOT': drillRoot.path,
        'STUB_RSYNC_VERSION': '3.2.7',
      },
    );

    expect(result.exitCode, isNot(0));
    expect(bench.calls('rsync'), isEmpty);
    expect(bench.calls('docker'), isEmpty);
    expect(bench.heartbeats(), <String>[
      '$heartbeatBase/drill/start',
      '$heartbeatBase/drill/fail',
    ]);
    expect(bench.calls('msmtp'), hasLength(1));
    expect(bench.mail(), contains('restore drill failed'));
    expect(
      bench.mail(),
      contains('check rsync (found 3.2.7, need 3.4.0 or newer)'),
    );
  });

  test(
    'the restore drill refuses a scratch root that is not private',
    () async {
      final ScriptBench bench = await ScriptBench.create();
      final Directory open = Directory(p.join(bench.root.path, 'open-drill'))
        ..createSync();
      Process.runSync('chmod', <String>['755', open.path]);
      final Directory private = Directory(
        p.join(bench.root.path, 'private-drill'),
      )..createSync();
      Process.runSync('chmod', <String>['700', private.path]);
      final Link linked = Link(p.join(bench.root.path, 'linked-drill'))
        ..createSync(private.path);

      for (final String root in <String>[open.path, linked.path]) {
        bench.clearLogs();
        final ProcessResult result = await bench.run(
          'restore-drill.sh',
          <String, String>{'FN_DRILL_ROOT': root},
        );

        expect(result.exitCode, isNot(0), reason: root);
        expect(bench.calls('rsync'), isEmpty, reason: root);
        expect(bench.heartbeats(), <String>[
          '$heartbeatBase/drill/start',
          '$heartbeatBase/drill/fail',
        ], reason: root);
        expect(bench.calls('msmtp'), hasLength(1), reason: root);
        expect(bench.mail(), contains('check the scratch root $root'));
      }
      expect(open.listSync(), isEmpty);
      expect(private.listSync(), isEmpty);
    },
  );

  test(
    'the restore drill pulls without links into a private scratch root',
    () async {
      final ScriptBench bench = await ScriptBench.create();
      final Directory drillRoot = Directory(p.join(bench.root.path, 'drill'));

      final ProcessResult result = await bench.run(
        'restore-drill.sh',
        <String, String>{'FN_DRILL_ROOT': drillRoot.path},
      );

      expect(result.exitCode, isNot(0));
      expect(bench.mail(), contains('find a database copy'));
      final List<String> pull = bench.calls('rsync').single;
      expect(pull.indexOf('-a'), isNonNegative);
      expect(pull.indexOf('--no-links'), greaterThan(pull.indexOf('-a')));
      expect(drillRoot.statSync().type, FileSystemEntityType.directory);
      expect(drillRoot.statSync().modeString(), 'rwx------');
      expect(drillRoot.listSync(), isEmpty);
    },
  );
}
