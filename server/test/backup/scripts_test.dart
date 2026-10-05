@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/blobs.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import '../support/relay_harness.dart';

const String unitSeparator = '\u001f';
const String heartbeatBase = 'https://heartbeat.invalid';
const String stubToday = '2026-10-04';
const String nasPort = '2222';
const String relayRepository = 'ghcr.io/satanshumishra/field-notes-relay';
const String certificateIssuer = 'https://token.actions.githubusercontent.com';
const String certificateIdentity =
    r'^https://github\.com/(?i:satanshumishra)/field-notes/\.github/workflows/relay-image\.yml@refs/heads/main$';
const String workflowRepository = 'SatanshuMishra/field-notes';
const String workflowRef = 'refs/heads/main';
const String stubCommit = '0123456789abcdef0123456789abcdef01234567';
const List<String> shares = <String>[
  'field-notes-backup',
  'field-notes-backup-test',
];
const List<String> keyNames = <String>[
  'push-field-notes-backup',
  'push-field-notes-backup-test',
  'pull-field-notes-backup',
  'pull-field-notes-backup-test',
];

final String verifiedImage = '$relayRepository@sha256:${'5' * 64}';
final String newImage = '$relayRepository@sha256:${'c' * 64}';

final String serverDirectory = p.dirname(defaultMigrationsDirectory());
final String deployDirectory = p.join(serverDirectory, 'deploy');

final bool hostHasJq =
    Process.runSync('/bin/sh', <String>['-c', 'command -v jq']).exitCode == 0;

final String? jqSkip = hostHasJq
    ? null
    : 'jq is not on PATH, and relay-update.sh reads the cosign answer with it';

final bool hostHasOpenssl =
    Process.runSync('/bin/sh', <String>['-c', 'command -v openssl']).exitCode ==
    0;

final String? relayUpdateSkip =
    jqSkip ??
    (hostHasOpenssl
        ? null
        : 'openssl is not on PATH, and relay-update.sh reads the signing certificate with it');

const String workflowShaExtension = '1.3.6.1.4.1.57264.1.3';

final Map<String, String> _signingCertificates = <String, String>{};

String signingCertificate({
  String? commit,
}) => _signingCertificates.putIfAbsent(commit ?? '', () {
  final Directory scratch = Directory.systemTemp.createTempSync(
    'relay_certificate_',
  );
  try {
    final String certificate = p.join(scratch.path, 'certificate.der');
    final ProcessResult made = Process.runSync('openssl', <String>[
      'req',
      '-x509',
      '-newkey',
      'ec',
      '-pkeyopt',
      'ec_paramgen_curve:prime256v1',
      '-nodes',
      '-keyout',
      p.join(scratch.path, 'key.pem'),
      '-subj',
      '/CN=sigstore-stub',
      '-days',
      '1',
      if (commit != null) ...<String>[
        '-addext',
        '$workflowShaExtension=DER:${ascii.encode(commit).map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join()}',
      ],
      '-outform',
      'DER',
      '-out',
      certificate,
    ]);
    expect(made.exitCode, 0, reason: '${made.stderr}');
    return base64Encode(File(certificate).readAsBytesSync());
  } finally {
    scratch.deleteSync(recursive: true);
  }
});

const String shebang = '#!/bin/bash\n';

const String recordingLines = r'''log="$STUB_LOGS/$(basename "$0").log"
for argument in "$@"; do
  printf '%s\037' "$argument" >> "$log"
done
printf '\n' >> "$log"
''';

const String recordingPrelude = '$shebang$recordingLines';

const String rsyncVersionLines = r'''if [ "$1" = "--version" ]; then
  printf 'rsync  version %s  protocol version 32\n' "${STUB_RSYNC_VERSION:-3.4.1}"
  exit 0
fi
''';

const String rsyncTransferLines = r'''transport=""
options=()
operands=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -e)
      transport="$2"
      shift 2
      ;;
    --exclude=*)
      shift
      ;;
    -*)
      options+=("$1")
      shift
      ;;
    *)
      operands+=("$1")
      shift
      ;;
  esac
done
first="${operands[0]}"
last="${operands[${#operands[@]}-1]}"
case "$first" in
  *@*:*)
    remote="$first"
    sender="--sender"
    ;;
  *)
    remote="$last"
    sender=""
    ;;
esac
user="${remote%%@*}"
rest="${remote#*@}"
host="${rest%%:*}"
path="${rest#*:}"
read -r -a shell <<< "$transport"
"${shell[@]}" -l "$user" "$host" rsync --server $sender "${options[@]}" . "$path" || exit 12
if [ -n "$sender" ] && [ -n "${STUB_NAS:-}" ]; then
  cp -R "$STUB_NAS/." "$last"
fi
exit 0
''';

const String rsyncStub =
    '$shebang$rsyncVersionLines$recordingLines$rsyncTransferLines';

const String sshStub =
    '$recordingPrelude${r'''host=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|-i|-o|-l|-F)
      [ "$#" -ge 2 ] || exit 2
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      host="$1"
      break
      ;;
  esac
done
for failing in ${STUB_NAS_FAIL:-}; do
  if [ "$failing" = "$host" ]; then
    exit 255
  fi
done
exit 0
'''}';

const String dockerStub =
    '$recordingPrelude${r'''command="$1"
shift
case "$command" in
  ps)
    for argument in "$@"; do
      case "$argument" in
        label=com.docker.compose.service=*)
          printf 'container-%s\n' "${argument#label=com.docker.compose.service=}"
          ;;
      esac
    done
    ;;
  exec)
    shift
    if [ "$2" = "snapshot-db" ]; then
      if [ "${STUB_SNAPSHOT_FAIL:-}" = "yes" ]; then
        exit 1
      fi
      printf 'snapshot' > "$4"
      printf 'field-notes-relay-manifest\t1\n' > "$4.manifest"
    elif [ "$1" = "curl" ]; then
      printf '%s' "${STUB_HEALTH:-200}"
    fi
    ;;
  run)
    index=0
    for argument in "$@"; do
      index=$((index + 1))
      if [ "$argument" = "verify-copy" ]; then
        if [ "${STUB_VERIFY_COPY:-}" = "pass" ]; then
          exit 0
        fi
        shift $((index - 1))
        exec "$STUB_RELAY" "$@"
      fi
    done
    for argument in "$@"; do
      if [ "$argument" = "--detach" ]; then
        printf 'stub-drill-container\n'
      fi
    done
    ;;
  pull)
    if [ "${STUB_PULL_FAIL:-}" = "yes" ]; then
      exit 1
    fi
    ;;
  image)
    if [ "$1" = "inspect" ]; then
      printf '%s\n' "${STUB_REPO_DIGESTS:-}"
    fi
    ;;
esac
exit 0
'''}';

const String cosignStub =
    '$recordingPrelude${r'''if [ "$1" = "download" ]; then
  for certificate in ${STUB_SIGNATURE_CERTS:-}; do
    printf '{"mediaType":"application/vnd.dev.sigstore.bundle.v0.3+json","verificationMaterial":{"certificate":{"rawBytes":"%s"}},"dsseEnvelope":{}}\n' "$certificate"
  done
  exit 0
fi
if [ "${STUB_COSIGN_FAIL:-}" = "yes" ]; then
  printf 'Error: no matching signatures\n' >&2
  exit 1
fi
previous=""
for argument in "$@"; do
  if [ "$previous" = "--certificate-github-workflow-sha" ] && [ "$argument" != "${STUB_COMMIT:-0123456789abcdef0123456789abcdef01234567}" ]; then
    printf 'Error: none of the expected identities matched what was in the certificate\n' >&2
    exit 1
  fi
  previous="$argument"
  image="$argument"
done
if [ -n "${STUB_COSIGN_OUTPUT+set}" ]; then
  printf '%s\n' "$STUB_COSIGN_OUTPUT"
  exit 0
fi
printf '[{"critical":{"identity":{"docker-reference":"%s"},"image":{"docker-manifest-digest":"%s"},"type":"https://sigstore.dev/cosign/sign/v1"},"optional":{}}]\n' "${image%@*}" "${image#*@}"
exit 0
'''}';

const String dateStub =
    '$shebang${r'''if [ "$#" -eq 2 ] && [ "$1" = "-u" ] && [ "$2" = "+%Y-%m-%d" ]; then
  printf '%s\n' "$STUB_TODAY"
  exit 0
fi
exec /bin/date "$@"
'''}';

const String curlStub = '''$recordingPrelude
exit 0
''';

const String msmtpStub = '''$recordingPrelude
cat >> "\$STUB_LOGS/mail.txt"
printf '\\n----\\n' >> "\$STUB_LOGS/mail.txt"
exit 0
''';

typedef SshCall = ({
  String? port,
  String? key,
  String? user,
  List<String> options,
  String host,
  String command,
});

SshCall parseSsh(List<String> arguments) {
  String? port;
  String? key;
  String? user;
  final List<String> options = <String>[];
  int index = 0;
  while (index + 1 < arguments.length && arguments[index].startsWith('-')) {
    final String value = arguments[index + 1];
    switch (arguments[index]) {
      case '-p':
        port = value;
      case '-i':
        key = value;
      case '-l':
        user = value;
      case '-o':
        options.add(value);
    }
    index += 2;
  }
  return (
    port: port,
    key: key,
    user: user,
    options: options,
    host: arguments[index],
    command: arguments.sublist(index + 1).join(' '),
  );
}

final RegExp authorizedLine = RegExp(
  r'^restrict,from="([^"]*)",command="([^"]*)" (ssh-ed25519 [A-Za-z0-9+/=]+) fn-backup-(\S+)$',
);

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

void writePrivate(String path, String content) {
  File(path).writeAsStringSync(content);
  Process.runSync('chmod', <String>['600', path]);
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
    Process.runSync('chmod', <String>['700', config.path]);
    final Map<String, String> stubs = <String, String>{
      'rsync': rsyncStub,
      'ssh': sshStub,
      'docker': dockerStub,
      'cosign': cosignStub,
      'date': dateStub,
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
    writePrivate(
      p.join(config.path, 'heartbeat.env'),
      'FN_NIGHTLY_PING_URL=$heartbeatBase/nightly\n'
      'FN_DRILL_PING_URL=$heartbeatBase/drill\n',
    );
    writePrivate(p.join(config.path, 'nas.env'), 'NAS_SSH_PORT=$nasPort\n');
    writePrivate(
      p.join(config.path, 'relay-image.env'),
      'RELAY_IMAGE=$verifiedImage\n',
    );
    final ScriptBench bench = ScriptBench._(
      root,
      logs,
      config,
      <String, String>{
        'PATH':
            '${bin.path}:${Platform.environment['PATH'] ?? '/usr/bin:/bin'}',
        'STUB_LOGS': logs.path,
        'STUB_RELAY': relay,
        'STUB_TODAY': stubToday,
        'STUB_SIGNATURE_CERTS': hostHasOpenssl
            ? signingCertificate(commit: stubCommit)
            : '',
        'FN_CONFIG_DIR': config.path,
        'FN_RETRY_DELAY': '0',
        'FN_HEALTH_DELAY': '0',
      },
    );
    final ProcessResult keys = await bench.run(
      'nas-ssh-keys.sh',
      const <String, String>{},
      const <String>['keys'],
    );
    expect(keys.exitCode, 0, reason: '${keys.stderr}');
    final String hostKey = File(
      p.join(bench.keysDirectory, '${keyNames.first}.pub'),
    ).readAsStringSync().trim().split(' ').take(2).join(' ');
    final String saved = p.join(root.path, 'dsm-host-keys.txt');
    File(saved).writeAsStringSync(
      '3072 SHA256:stub root@Pulsar (RSA)\r\n'
      'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQstub root@Pulsar\r\n'
      '256 SHA256:stub root@Pulsar (ED25519)\r\n'
      '$hostKey root@Pulsar\r\n',
    );
    final ProcessResult pinned = await bench.run(
      'nas-ssh-keys.sh',
      const <String, String>{},
      <String>['pin-host', saved],
    );
    expect(pinned.exitCode, 0, reason: '${pinned.stderr}');
    final ProcessResult authorized = await bench.run(
      'nas-ssh-keys.sh',
      const <String, String>{},
      const <String>['authorized'],
    );
    expect(authorized.exitCode, 0, reason: '${authorized.stderr}');
    bench
      ..hostKey = hostKey
      ..authorized = '${authorized.stdout}'
      ..clearLogs();
    return bench;
  }

  static void _executable(String path, String content) {
    File(path).writeAsStringSync(content);
    Process.runSync('chmod', <String>['755', path]);
  }

  final Directory root;
  final Directory logs;
  final Directory config;
  final Map<String, String> environment;
  late final String hostKey;
  late final String authorized;

  String get keysDirectory => p.join(config.path, 'nas-keys');

  String get knownHosts => p.join(config.path, 'nas_known_hosts');

  File get imageFile => File(p.join(config.path, 'relay-image.env'));

  File get historyFile => File(p.join(config.path, 'relay-image.history'));

  String keyPath(String name) => p.join(keysDirectory, name);

  Future<ProcessResult> run(
    String script,
    Map<String, String> extra, [
    List<String> arguments = const <String>[],
  ]) => Process.run(
    '/bin/bash',
    <String>[p.join(deployDirectory, script), ...arguments],
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

  List<List<String>> transfers() => <List<String>>[
    for (final List<String> call in calls('rsync'))
      if (transportOf(call).startsWith('ssh ')) call,
  ];

  List<SshCall> sshCalls() => <SshCall>[
    for (final List<String> call in calls('ssh')) parseSsh(call),
  ];

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

  Map<String, String> authorizedCommands() => <String, String>{
    for (final String line in authorized.trim().split('\n'))
      authorizedLine.firstMatch(line)!.group(4)!: authorizedLine
          .firstMatch(line)!
          .group(2)!,
  };

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

  Map<String, String> relayRoots() => <String, String>{
    'FN_RELAY_ROOT': relayRoot('relay').path,
    'FN_TEST_RELAY_ROOT': relayRoot('relay-test').path,
  };

  Directory fakeNas() {
    final Directory nas = Directory(p.join(root.path, 'fake-nas'));
    Directory(p.join(nas.path, 'backup')).createSync(recursive: true);
    Directory(p.join(nas.path, 'media')).createSync(recursive: true);
    File(p.join(nas.path, 'backup', 'relay-2026-10-01.sqlite3'))
        .writeAsStringSync('copy');
    return nas;
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

String transportOf(List<String> call) {
  final int flag = call.indexOf('-e');
  return flag < 0 || flag + 1 >= call.length ? '' : call[flag + 1];
}

List<String> operandsOf(List<String> call) {
  final List<String> operands = <String>[];
  for (int index = 0; index < call.length; index++) {
    if (call[index] == '-e') {
      index++;
    } else if (!call[index].startsWith('-')) {
      operands.add(call[index]);
    }
  }
  return operands;
}

List<String> sourcesOf(List<String> call) {
  final List<String> operands = operandsOf(call);
  return operands.sublist(0, operands.length - 1);
}

List<String> snapshotsIn(Directory relay) {
  final List<String> names = <String>[
    for (final FileSystemEntity entity in Directory(
      p.join(relay.path, 'backup'),
    ).listSync())
      if (p.basename(entity.path).endsWith('.sqlite3')) p.basename(entity.path),
  ]..sort();
  return names;
}

void expectSshOptions(ScriptBench bench, SshCall call, String keyName) {
  expect(call.port, nasPort);
  expect(call.key, bench.keyPath(keyName));
  expect(call.user, 'fn-backup');
  expect(
    call.options,
    unorderedEquals(<String>[
      'IdentitiesOnly=yes',
      'BatchMode=yes',
      'StrictHostKeyChecking=yes',
      'UserKnownHostsFile=${bench.knownHosts}',
      'ConnectTimeout=30',
    ]),
  );
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
      <String, String>{...roots, 'STUB_NAS_FAIL': '10.0.0.246'},
    );

    expect(fallback.exitCode, 0, reason: '${fallback.stderr}');
    final List<List<String>> copies = bench.transfers();
    expect(copies.map((List<String> call) => call.last), <String>[
      'fn-backup@10.0.0.246:/volume1/field-notes-backup/',
      'fn-backup@10.0.0.247:/volume1/field-notes-backup/',
      'fn-backup@10.0.0.246:/volume1/field-notes-backup-test/',
      'fn-backup@10.0.0.247:/volume1/field-notes-backup-test/',
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
        ]),
      );
      expect(
        call.any((String argument) => argument.contains('password-file')),
        isFalse,
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
      p.join(relay.path, 'backup', 'relay-$stubToday.sqlite3'),
      p.join(testRelay.path, 'backup', 'relay-$stubToday.sqlite3'),
    ]);
    final List<String> kept = snapshotsIn(relay);
    expect(kept, hasLength(7));
    expect(kept.last, 'relay-$stubToday.sqlite3');
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
      <String, String>{...roots, 'STUB_NAS_FAIL': '10.0.0.246 10.0.0.247'},
    );

    expect(failed.exitCode, isNot(0));
    expect(bench.transfers(), hasLength(8));
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
    final Map<String, String> roots = bench.relayRoots();

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
    final Map<String, String> roots = bench.relayRoots();

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
    expect(bench.transfers(), hasLength(2));
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
      final List<String> pull = bench.transfers().single;
      expect(pull.indexOf('-a'), isNonNegative);
      expect(pull.indexOf('--no-links'), greaterThan(pull.indexOf('-a')));
      expect(drillRoot.statSync().type, FileSystemEntityType.directory);
      expect(drillRoot.statSync().modeString(), 'rwx------');
      expect(drillRoot.listSync(), isEmpty);
    },
  );

  test('the nightly copy goes over SSH with a pinned host key', () async {
    final ScriptBench bench = await ScriptBench.create();
    final Map<String, String> roots = bench.relayRoots();

    final ProcessResult result = await bench.run('nightly-copy.sh', roots);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    final List<List<String>> copies = bench.transfers();
    expect(copies, hasLength(shares.length));
    final List<SshCall> connections = bench.sshCalls();
    expect(connections, hasLength(shares.length));
    for (final (int index, String share) in shares.indexed) {
      final String target = 'fn-backup@10.0.0.246:/volume1/$share/';
      final List<String> copy = copies.singleWhere(
        (List<String> call) => call.last == target,
      );
      final String root = index == 0
          ? roots['FN_RELAY_ROOT']!
          : roots['FN_TEST_RELAY_ROOT']!;
      expect(sourcesOf(copy), <String>[
        p.join(root, 'backup'),
        p.join(root, 'media'),
      ]);
      final List<String> transport = transportOf(copy).split(' ');
      expect(transport.first, 'ssh');
      expect(transport, containsAllInOrder(<String>['-p', nasPort]));
      expect(
        transport,
        containsAllInOrder(<String>['-i', bench.keyPath('push-$share')]),
      );
      expect(
        transport,
        containsAll(<String>[
          'IdentitiesOnly=yes',
          'BatchMode=yes',
          'StrictHostKeyChecking=yes',
          'UserKnownHostsFile=${bench.knownHosts}',
        ]),
      );
      final SshCall connection = connections[index];
      expect(connection.host, '10.0.0.246');
      expectSshOptions(bench, connection, 'push-$share');
      expect(connection.command, startsWith('rsync --server '));
      expect(connection.command, endsWith(' . /volume1/$share/'));
      expect(connection.command, isNot(contains('--sender')));
    }
    for (final List<String> call in bench.calls('rsync')) {
      expect(
        call.any(
          (String argument) =>
              argument.startsWith('rsync://') ||
              argument.contains('password-file'),
        ),
        isFalse,
      );
    }
    expect(
      File(bench.knownHosts).readAsStringSync(),
      '[10.0.0.246]:$nasPort,[10.0.0.247]:$nasPort ${bench.hostKey}\n',
    );
    expect(File(bench.knownHosts).statSync().modeString(), 'rw-------');
  });

  test('the restore drill pulls over SSH without following links', () async {
    final ScriptBench bench = await ScriptBench.create();

    for (final String share in shares) {
      bench.clearLogs();
      final Directory drillRoot = Directory(
        p.join(bench.root.path, 'drill-$share'),
      );
      final ProcessResult result = await bench.run(
        'restore-drill.sh',
        <String, String>{
          'FN_DRILL_ROOT': drillRoot.path,
          'FN_DRILL_SHARE': share,
          'STUB_NAS': bench.fakeNas().path,
          'STUB_VERIFY_COPY': 'pass',
        },
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final List<String> pull = bench.transfers().single;
      expect(operandsOf(pull).first, 'fn-backup@10.0.0.246:/volume1/$share/');
      expect(pull.indexOf('-a'), isNonNegative);
      expect(pull.indexOf('--no-links'), greaterThan(pull.indexOf('-a')));
      final List<String> transport = transportOf(pull).split(' ');
      expect(
        transport,
        containsAllInOrder(<String>['-i', bench.keyPath('pull-$share')]),
      );
      final SshCall connection = bench.sshCalls().single;
      expect(connection.host, '10.0.0.246');
      expectSshOptions(bench, connection, 'pull-$share');
      expect(connection.command, startsWith('rsync --server --sender '));
      expect(connection.command, contains('--no-links'));
      expect(connection.command, endsWith(' . /volume1/$share/'));
    }
  });

  test('the pinned commands match what the scripts send', () async {
    final ScriptBench bench = await ScriptBench.create();
    final List<String> lines = bench.authorized.trim().split('\n');
    expect(lines, hasLength(keyNames.length));
    for (final (int index, String line) in lines.indexed) {
      final RegExpMatch? match = authorizedLine.firstMatch(line);
      expect(match, isNotNull, reason: line);
      final String name = keyNames[index];
      expect(match!.group(1), '10.0.0.0/24');
      expect(match.group(2), startsWith('rsync --server '));
      expect(
        File(bench.keyPath('$name.pub')).readAsStringSync(),
        startsWith(match.group(3)!),
      );
      expect(match.group(4), name);
      expect(
        File(bench.keyPath(name)).statSync().modeString(),
        'rw-------',
        reason: name,
      );
    }
    final Map<String, String> pinned = bench.authorizedCommands();
    expect(
      File(p.join(bench.keysDirectory, 'pinned')).readAsStringSync(),
      <String>[for (final String name in keyNames) '$name ${pinned[name]}\n']
          .join(),
    );

    final Map<String, Set<String>> received = <String, Set<String>>{};
    void collect() {
      for (final SshCall call in bench.sshCalls()) {
        received
            .putIfAbsent(p.basename(call.key!), () => <String>{})
            .add(call.command);
      }
    }

    final ProcessResult nightly = await bench.run(
      'nightly-copy.sh',
      bench.relayRoots(),
    );
    expect(nightly.exitCode, 0, reason: '${nightly.stderr}');
    collect();
    for (final String share in shares) {
      bench.clearLogs();
      final ProcessResult drill = await bench.run(
        'restore-drill.sh',
        <String, String>{
          'FN_DRILL_ROOT': p.join(bench.root.path, 'drill-$share'),
          'FN_DRILL_SHARE': share,
          'STUB_NAS': bench.fakeNas().path,
          'STUB_VERIFY_COPY': 'pass',
        },
      );
      expect(drill.exitCode, 0, reason: '${drill.stderr}');
      collect();
    }

    expect(received.keys.toSet(), keyNames.toSet());
    for (final String name in keyNames) {
      expect(received[name], <String>{pinned[name]!}, reason: name);
    }
  });

  test('a changed rsync command stops the copy with an alert', () async {
    final ScriptBench bench = await ScriptBench.create();
    final File pinned = File(p.join(bench.keysDirectory, 'pinned'));
    pinned.writeAsStringSync(
      pinned.readAsStringSync().replaceAll('--timeout=600', '--timeout=300'),
    );

    final ProcessResult nightly = await bench.run(
      'nightly-copy.sh',
      bench.relayRoots(),
    );

    expect(nightly.exitCode, isNot(0));
    expect(bench.calls('ssh'), isEmpty);
    expect(bench.transfers(), isEmpty);
    expect(bench.calls('docker'), isEmpty);
    expect(bench.heartbeats(), <String>[
      '$heartbeatBase/nightly/start',
      '$heartbeatBase/nightly/fail',
    ]);
    expect(bench.calls('msmtp'), hasLength(1));
    expect(bench.mail(), contains('nightly copy failed'));
    expect(bench.mail(), contains('run nas-ssh-keys.sh authorized'));
    expect(bench.mail(), contains('update authorized_keys on the NAS'));

    bench.clearLogs();
    final ProcessResult drill = await bench.run(
      'restore-drill.sh',
      <String, String>{
        'FN_DRILL_ROOT': p.join(bench.root.path, 'drill'),
        'STUB_NAS': bench.fakeNas().path,
      },
    );

    expect(drill.exitCode, isNot(0));
    expect(bench.calls('ssh'), isEmpty);
    expect(bench.transfers(), isEmpty);
    expect(bench.calls('docker'), isEmpty);
    expect(bench.calls('msmtp'), hasLength(1));
    expect(bench.mail(), contains('restore drill failed'));
    expect(bench.mail(), contains('run nas-ssh-keys.sh authorized'));
  });

  test('relay-update records a verified image by digest', () async {
    final ScriptBench bench = await ScriptBench.create();

    final ProcessResult result = await bench.run(
      'relay-update.sh',
      <String, String>{
        'STUB_REPO_DIGESTS':
            'registry.invalid/mirror@sha256:${'b' * 64}\n$newImage',
      },
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(bench.imageFile.readAsStringSync(), 'RELAY_IMAGE=$newImage\n');
    expect(bench.imageFile.statSync().modeString(), 'rw-------');
    final List<String> printed = '${result.stdout}'.split('\n');
    expect(printed.first, 'RELAY_IMAGE=$newImage');
    expect('${result.stdout}', contains('RELAY_TEST_IMAGE=$newImage'));
    expect(
      '${result.stdout}',
      contains('https://sync-test.satanshu.tech/health'),
    );
    expect(
      bench.calls('docker').where((List<String> call) => call.first == 'pull'),
      <List<String>>[
        <String>['pull', '--quiet', '$relayRepository:main'],
      ],
    );
    expect(bench.calls('cosign'), <List<String>>[
      <String>[
        'verify',
        '--certificate-oidc-issuer',
        certificateIssuer,
        '--certificate-identity-regexp',
        certificateIdentity,
        '--certificate-github-workflow-repository',
        workflowRepository,
        '--certificate-github-workflow-ref',
        workflowRef,
        '--output',
        'json',
        newImage,
      ],
      <String>['download', 'signature', newImage],
      <String>[
        'verify',
        '--certificate-oidc-issuer',
        certificateIssuer,
        '--certificate-identity-regexp',
        certificateIdentity,
        '--certificate-github-workflow-repository',
        workflowRepository,
        '--certificate-github-workflow-ref',
        workflowRef,
        '--certificate-github-workflow-sha',
        stubCommit,
        '--output',
        'json',
        newImage,
      ],
    ]);
    expect(bench.calls('msmtp'), isEmpty);
    expect(
      bench.historyFile.readAsStringSync(),
      startsWith('sha256:${'c' * 64} $stubCommit '),
    );
    expect(
      bench.config.listSync().where(
        (FileSystemEntity entity) =>
            p.basename(entity.path).startsWith('.relay-image.env.'),
      ),
      isEmpty,
    );

    bench.clearLogs();
    final ProcessResult tagged = await bench.run(
      'relay-update.sh',
      <String, String>{'STUB_REPO_DIGESTS': verifiedImage},
      const <String>['sha-0123456789ab'],
    );

    expect(tagged.exitCode, 0, reason: '${tagged.stderr}');
    expect(bench.calls('docker').first, <String>[
      'pull',
      '--quiet',
      '$relayRepository:sha-0123456789ab',
    ]);
    expect(bench.imageFile.readAsStringSync(), 'RELAY_IMAGE=$verifiedImage\n');
  }, skip: relayUpdateSkip);

  test(
    'relay-update refuses an image whose signature does not verify',
    () async {
      final ScriptBench bench = await ScriptBench.create();
      final String before = bench.imageFile.readAsStringSync();

      final ProcessResult result = await bench.run(
        'relay-update.sh',
        <String, String>{
          'STUB_REPO_DIGESTS': newImage,
          'STUB_COSIGN_FAIL': 'yes',
        },
      );

      expect(result.exitCode, isNot(0));
      expect(bench.imageFile.readAsStringSync(), before);
      expect(bench.imageFile.statSync().modeString(), 'rw-------');
      expect(bench.calls('cosign'), hasLength(1));
      expect(bench.calls('msmtp'), hasLength(1));
      expect(bench.mail(), contains('relay update failed'));
      expect(bench.mail(), contains('verify the signature of $newImage'));
      expect('${result.stdout}', isNot(contains('RELAY_IMAGE=')));
      expect(
        File(p.join(bench.config.path, 'relay-image.history')).existsSync(),
        isFalse,
      );
      expect(
        bench.config.listSync().where(
          (FileSystemEntity entity) =>
              p.basename(entity.path).startsWith('.relay-image.env.'),
        ),
        isEmpty,
      );
    },
  );

  test('the restore drill runs the verified image', () async {
    final ScriptBench bench = await ScriptBench.create();

    final ProcessResult passed = await bench.run(
      'restore-drill.sh',
      <String, String>{
        'FN_DRILL_ROOT': p.join(bench.root.path, 'drill'),
        'STUB_NAS': bench.fakeNas().path,
        'STUB_VERIFY_COPY': 'pass',
      },
    );

    expect(passed.exitCode, 0, reason: '${passed.stderr}');
    final List<List<String>> runs = <List<String>>[
      for (final List<String> call in bench.calls('docker'))
        if (call.first == 'run') call,
    ];
    expect(runs, hasLength(2));
    expect(runs.first, contains('verify-copy'));
    expect(runs.last, contains('--detach'));
    for (final List<String> run in runs) {
      expect(run, contains(verifiedImage));
    }
    for (final List<String> call in bench.calls('docker')) {
      expect(
        call.any((String argument) => argument.endsWith(':main')),
        isFalse,
      );
    }

    for (final String? content in <String?>[
      null,
      'RELAY_IMAGE=$relayRepository:main\n',
    ]) {
      bench.clearLogs();
      if (content == null) {
        bench.imageFile.deleteSync();
      } else {
        writePrivate(bench.imageFile.path, content);
      }

      final ProcessResult refused = await bench.run(
        'restore-drill.sh',
        <String, String>{
          'FN_DRILL_ROOT': p.join(bench.root.path, 'drill'),
          'STUB_NAS': bench.fakeNas().path,
          'STUB_VERIFY_COPY': 'pass',
        },
      );

      expect(refused.exitCode, isNot(0), reason: '$content');
      expect(bench.calls('docker'), isEmpty, reason: '$content');
      expect(bench.transfers(), isEmpty, reason: '$content');
      expect(bench.heartbeats(), <String>[
        '$heartbeatBase/drill/start',
        '$heartbeatBase/drill/fail',
      ], reason: '$content');
      expect(bench.calls('msmtp'), hasLength(1), reason: '$content');
      expect(bench.mail(), contains('restore drill failed'));
      expect(bench.mail(), contains(bench.imageFile.path));
    }
  });

  test('relay-update pins the repository and ref and records the commit', () async {
    final ScriptBench bench = await ScriptBench.create();

    final ProcessResult result = await bench.run(
      'relay-update.sh',
      <String, String>{'STUB_REPO_DIGESTS': newImage},
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    final List<List<String>> calls = bench.calls('cosign');
    expect(calls, hasLength(3));
    final List<String> verify = calls.first;
    expect(verify.first, 'verify');
    expect(verify.last, newImage);
    for (final List<String> pair in <List<String>>[
      <String>['--certificate-oidc-issuer', certificateIssuer],
      <String>['--certificate-identity-regexp', certificateIdentity],
      <String>['--certificate-github-workflow-repository', workflowRepository],
      <String>['--certificate-github-workflow-ref', workflowRef],
      <String>['--output', 'json'],
    ]) {
      expect(verify, containsAllInOrder(pair));
      expect(verify[verify.indexOf(pair.first) + 1], pair.last);
    }
    expect(calls[1], <String>['download', 'signature', newImage]);
    final List<String> confirm = calls.last;
    expect(confirm.first, 'verify');
    expect(confirm.last, newImage);
    expect(
      confirm[confirm.indexOf('--certificate-github-workflow-sha') + 1],
      stubCommit,
    );
    expect('${result.stdout}', contains('built from commit $stubCommit'));
    final List<String> history = bench.historyFile.readAsLinesSync();
    expect(history, hasLength(1));
    expect(
      history.single,
      matches(
        RegExp(
          '^sha256:${'c' * 64} $stubCommit '
          r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$',
        ),
      ),
    );

    final String unrecorded = '$relayRepository@sha256:${'d' * 64}';
    final String otherCommit = 'e' * 40;
    for (final (String, Map<String, String>, String) refusal
        in <(String, Map<String, String>, String)>[
          (
            'no signature bundle',
            <String, String>{'STUB_SIGNATURE_CERTS': ''},
            'read the commit',
          ),
          (
            'a certificate without the workflow commit',
            <String, String>{'STUB_SIGNATURE_CERTS': signingCertificate()},
            'read the commit',
          ),
          (
            'certificates naming two commits',
            <String, String>{
              'STUB_SIGNATURE_CERTS':
                  '${signingCertificate(commit: stubCommit)} '
                  '${signingCertificate(commit: otherCommit)}',
            },
            'read the commit',
          ),
          (
            'a legacy answer naming no commit',
            <String, String>{
              'STUB_SIGNATURE_CERTS': '',
              'STUB_COSIGN_OUTPUT':
                  '[{"optional":{"githubWorkflowSha":"main"}}]',
            },
            'read the commit',
          ),
          (
            'a legacy answer naming two commits',
            <String, String>{
              'STUB_SIGNATURE_CERTS': '',
              'STUB_COSIGN_OUTPUT':
                  '[{"optional":{"githubWorkflowSha":"$stubCommit"}},'
                  '{"optional":{"githubWorkflowSha":"$otherCommit"}}]',
            },
            'read the commit',
          ),
          (
            'an answer that is not JSON',
            <String, String>{
              'STUB_SIGNATURE_CERTS': '',
              'STUB_COSIGN_OUTPUT': 'not json',
            },
            'read the commit',
          ),
          (
            'a downloaded certificate the signature does not back',
            <String, String>{
              'STUB_SIGNATURE_CERTS': signingCertificate(commit: otherCommit),
            },
            'confirm that the signature of $unrecorded names commit $otherCommit',
          ),
        ]) {
      final (String reason, Map<String, String> environment, String step) =
          refusal;
      bench.clearLogs();

      final ProcessResult refused = await bench.run(
        'relay-update.sh',
        <String, String>{'STUB_REPO_DIGESTS': unrecorded, ...environment},
      );

      expect(refused.exitCode, isNot(0), reason: reason);
      expect(
        bench.imageFile.readAsStringSync(),
        'RELAY_IMAGE=$newImage\n',
        reason: reason,
      );
      expect(bench.historyFile.readAsLinesSync(), history, reason: reason);
      expect(bench.calls('msmtp'), hasLength(1), reason: reason);
      expect(bench.mail(), contains(step), reason: reason);
      expect('${refused.stdout}', isNot(contains('RELAY_IMAGE=')));
    }

    bench.clearLogs();
    final ProcessResult legacy = await bench.run(
      'relay-update.sh',
      <String, String>{
        'STUB_REPO_DIGESTS': unrecorded,
        'STUB_SIGNATURE_CERTS': '',
        'STUB_COSIGN_OUTPUT':
            '[{"optional":{"githubWorkflowSha":"$stubCommit"}}]',
      },
    );

    expect(legacy.exitCode, 0, reason: '${legacy.stderr}');
    expect(bench.imageFile.readAsStringSync(), 'RELAY_IMAGE=$unrecorded\n');
    expect(
      bench.historyFile.readAsLinesSync().last,
      startsWith('sha256:${'d' * 64} $stubCommit '),
    );
  }, skip: relayUpdateSkip);

  test(
    'relay-update refuses an older image unless a digest is named',
    () async {
      final ScriptBench bench = await ScriptBench.create();
      final String olderDigest = 'sha256:${'a' * 64}';
      final String olderImage = '$relayRepository@$olderDigest';
      final String newerImage = '$relayRepository@sha256:${'b' * 64}';
      for (final String image in <String>[olderImage, newerImage]) {
        final ProcessResult updated = await bench.run(
          'relay-update.sh',
          <String, String>{'STUB_REPO_DIGESTS': image},
        );
        expect(updated.exitCode, 0, reason: '${updated.stderr}');
      }
      final List<String> recorded = bench.historyFile.readAsLinesSync();
      expect(recorded, hasLength(2));
      bench.clearLogs();

      final ProcessResult refused = await bench.run(
        'relay-update.sh',
        <String, String>{'STUB_REPO_DIGESTS': olderImage},
      );

      expect(refused.exitCode, isNot(0));
      expect(bench.imageFile.readAsStringSync(), 'RELAY_IMAGE=$newerImage\n');
      expect(bench.historyFile.readAsLinesSync(), recorded);
      expect(bench.calls('msmtp'), hasLength(1));
      expect(bench.mail(), contains('relay update failed'));
      expect(bench.mail(), contains(olderDigest));
      expect('${refused.stdout}', isNot(contains('RELAY_IMAGE=')));
      expect(
        bench.config.listSync().where(
          (FileSystemEntity entity) =>
              p.basename(entity.path).startsWith('.relay-image.env.'),
        ),
        isEmpty,
      );

      bench.clearLogs();
      final ProcessResult rolledBack = await bench.run(
        'relay-update.sh',
        <String, String>{'STUB_REPO_DIGESTS': olderImage},
        <String>[olderDigest],
      );

      expect(rolledBack.exitCode, 0, reason: '${rolledBack.stderr}');
      expect(bench.calls('docker').first, <String>[
        'pull',
        '--quiet',
        olderImage,
      ]);
      expect(bench.imageFile.readAsStringSync(), 'RELAY_IMAGE=$olderImage\n');
      final List<String> history = bench.historyFile.readAsLinesSync();
      expect(history, hasLength(3));
      expect(history.last, startsWith('$olderDigest $stubCommit '));

      bench.clearLogs();
      final ProcessResult again = await bench.run(
        'relay-update.sh',
        <String, String>{'STUB_REPO_DIGESTS': olderImage},
      );
      expect(again.exitCode, 0, reason: '${again.stderr}');
      expect(bench.historyFile.readAsLinesSync(), hasLength(4));
    },
    skip: relayUpdateSkip,
  );

  test(
    'the nightly copy leaves trash, health probes and assembly out',
    () async {
      final ScriptBench bench = await ScriptBench.create();

      final ProcessResult result = await bench.run(
        'nightly-copy.sh',
        bench.relayRoots(),
      );

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final List<List<String>> copies = bench.transfers();
      expect(copies, hasLength(shares.length));
      for (final List<String> copy in copies) {
        expect(
          copy,
          containsAll(<String>[
            '--exclude=.uploads/',
            '--exclude=.trash/',
            '--exclude=.assembling/',
            '--exclude=.health-*',
          ]),
        );
        expect(
          transportOf(copy).split(' '),
          containsAllInOrder(<String>['ssh', '-F', '/dev/null']),
        );
      }
      final List<List<String>> connections = bench.calls('ssh');
      expect(connections, hasLength(shares.length));
      for (final List<String> connection in connections) {
        expect(connection, containsAllInOrder(<String>['-F', '/dev/null']));
      }
    },
  );

  test('the copy scripts refuse a config file others can write', () async {
    final ScriptBench bench = await ScriptBench.create();
    final Map<String, String> environment = <String, String>{
      ...bench.relayRoots(),
      'FN_DRILL_ROOT': p.join(bench.root.path, 'drill'),
      'STUB_NAS': bench.fakeNas().path,
      'STUB_VERIFY_COPY': 'pass',
    };

    for (final String name in <String>['nas.env', 'heartbeat.env']) {
      final File file = File(p.join(bench.config.path, name));
      for (final String mode in <String>['620', '602']) {
        Process.runSync('chmod', <String>[mode, file.path]);
        for (final String script in <String>[
          'nightly-copy.sh',
          'restore-drill.sh',
        ]) {
          final String what = '$script with $name at mode $mode';
          bench.clearLogs();

          final ProcessResult refused = await bench.run(script, environment);

          expect(refused.exitCode, isNot(0), reason: what);
          expect(bench.calls('ssh'), isEmpty, reason: what);
          expect(bench.transfers(), isEmpty, reason: what);
          expect(bench.calls('docker'), isEmpty, reason: what);
          expect(bench.calls('msmtp'), hasLength(1), reason: what);
          expect(bench.mail(), contains(file.path), reason: what);
          expect(
            bench.mail(),
            contains('no other user can write'),
            reason: what,
          );
        }
        Process.runSync('chmod', <String>['600', file.path]);
      }
    }

    for (final String script in <String>[
      'nightly-copy.sh',
      'restore-drill.sh',
    ]) {
      bench.clearLogs();
      final ProcessResult passed = await bench.run(script, environment);
      expect(passed.exitCode, 0, reason: '$script: ${passed.stderr}');
    }
  });
  test(
    'relay-update recognises digests recorded in the old history format',
    () async {
      final ScriptBench bench = await ScriptBench.create();
      final String olderDigest = 'sha256:${'a' * 64}';
      final String olderImage = '$relayRepository@$olderDigest';
      final String newerImage = '$relayRepository@sha256:${'b' * 64}';
      final List<String> recorded = <String>[
        '2026-09-01T01:00:00Z main RELAY_IMAGE=$olderImage',
        '2026-09-15T01:00:00Z sha-0123456789ab RELAY_IMAGE=$newerImage',
      ];
      writePrivate(bench.historyFile.path, '${recorded.join('\n')}\n');
      writePrivate(bench.imageFile.path, 'RELAY_IMAGE=$newerImage\n');

      final ProcessResult refused = await bench.run(
        'relay-update.sh',
        <String, String>{'STUB_REPO_DIGESTS': olderImage},
      );

      expect(refused.exitCode, isNot(0));
      expect(bench.imageFile.readAsStringSync(), 'RELAY_IMAGE=$newerImage\n');
      expect(bench.historyFile.readAsLinesSync(), recorded);
      expect(bench.calls('cosign'), isEmpty);
      expect(bench.calls('msmtp'), hasLength(1));
      expect(bench.mail(), contains('relay update failed'));
      expect(bench.mail(), contains(olderDigest));
      expect('${refused.stdout}', isNot(contains('RELAY_IMAGE=')));

      bench.clearLogs();
      final ProcessResult newest = await bench.run(
        'relay-update.sh',
        <String, String>{'STUB_REPO_DIGESTS': newerImage},
      );

      expect(newest.exitCode, 0, reason: '${newest.stderr}');
      expect(bench.imageFile.readAsStringSync(), 'RELAY_IMAGE=$newerImage\n');
      final List<String> history = bench.historyFile.readAsLinesSync();
      expect(history, hasLength(recorded.length + 1));
      expect(history.take(recorded.length), recorded);
      expect(history.last, startsWith('sha256:${'b' * 64} $stubCommit '));
    },
    skip: relayUpdateSkip,
  );

  test('the copy scripts refuse a config folder others can write', () async {
    final ScriptBench bench = await ScriptBench.create();
    final Map<String, String> environment = <String, String>{
      ...bench.relayRoots(),
      'FN_DRILL_ROOT': p.join(bench.root.path, 'drill'),
      'STUB_NAS': bench.fakeNas().path,
      'STUB_VERIFY_COPY': 'pass',
    };
    addTearDown(
      () => Process.runSync('chmod', <String>['700', bench.config.path]),
    );

    for (final String mode in <String>['770', '707']) {
      Process.runSync('chmod', <String>[mode, bench.config.path]);
      for (final String script in <String>[
        'nightly-copy.sh',
        'restore-drill.sh',
      ]) {
        final String what = '$script with the config folder at mode $mode';
        bench.clearLogs();

        final ProcessResult refused = await bench.run(script, environment);

        expect(refused.exitCode, isNot(0), reason: what);
        expect(bench.calls('ssh'), isEmpty, reason: what);
        expect(bench.transfers(), isEmpty, reason: what);
        expect(bench.calls('docker'), isEmpty, reason: what);
        expect(bench.heartbeats(), isEmpty, reason: what);
        expect(bench.calls('msmtp'), hasLength(1), reason: what);
        expect(bench.mail(), contains(bench.config.path), reason: what);
        expect(bench.mail(), contains('no other user can write'), reason: what);
      }
    }

    Process.runSync('chmod', <String>['700', bench.config.path]);
    for (final String script in <String>[
      'nightly-copy.sh',
      'restore-drill.sh',
    ]) {
      bench.clearLogs();
      final ProcessResult passed = await bench.run(script, environment);
      expect(passed.exitCode, 0, reason: '$script: ${passed.stderr}');
    }
  });
}
