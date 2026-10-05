import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:relay_server/relay_server.dart';
import 'package:relay_server/src/probes.dart';
import 'package:sync_protocol/sync_protocol.dart';
import 'package:test/test.dart';

import 'support/relay_harness.dart';

const String linuxDf = '''
Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p2   976761560 123456789 850000000      13% /srv
''';

const String spacedDf = '''
Filesystem    1024-blocks       Used Available Capacity  Mounted on
map auto_home           0          0         0   100%    /System/Volumes/Data/home share
''';

const Duration answerLimit = Duration(seconds: 10);
const Duration dfLimit = Duration(seconds: 5);
const Duration readingLifetime = Duration(seconds: 5);
const int freeFloor = 1024 * 1024 * 1024;
const String failedReadingEvent = 'free_space_failed';

Future<bool> eventually(bool Function() condition) async {
  final Stopwatch watch = Stopwatch()..start();
  while (!condition()) {
    if (watch.elapsed > answerLimit) {
      return false;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return true;
}

bool running(int pid) =>
    Process.runSync('kill', <String>['-0', '$pid']).exitCode == 0;

final class StuckProcess implements Process {
  final Completer<int> exited = Completer<int>();
  final List<ProcessSignal> signals = <ProcessSignal>[];
  final StreamController<List<int>> _out = StreamController<List<int>>();
  final StreamController<List<int>> _errors = StreamController<List<int>>();

  @override
  Future<int> get exitCode => exited.future;

  @override
  Stream<List<int>> get stdout => _out.stream;

  @override
  Stream<List<int>> get stderr => _errors.stream;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);

  @override
  int get pid => 0;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    signals.add(signal);
    return true;
  }

  void finish(String output) {
    _out.add(output.codeUnits);
    unawaited(_out.close());
    unawaited(_errors.close());
    exited.complete(0);
  }
}

void main() {
  test('a part is refused while the media disk is nearly full', () async {
    final RelayHarness harness = await RelayHarness.start();
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    Future<http.Response> sendPart() => harness.putPart(
      me.session,
      name: harness.blobName(),
      uploadId: newSyncId(),
      index: 0,
      blobSize: 1500,
      partSize: 1024,
      bytes: Uint8List(1024),
    );
    expect(harness.config.minFreeBytes, RelayConfig.defaultMinFreeBytes);

    harness.freeBytes = RelayConfig.defaultMinFreeBytes - 1;
    final http.Response refused = await sendPart();

    expect(refused.statusCode, HttpStatus.insufficientStorage);
    expect(errorOf(refused).code, SyncErrorCode.storageFull);
    expect(harness.database.count('SELECT count(*) FROM uploads'), 0);

    harness.freeBytes = RelayConfig.defaultMinFreeBytes + 1024;
    expect(
      errorOf(await sendPart()).code,
      SyncErrorCode.storageFull,
      reason: 'the free space reading is kept for five seconds',
    );
    harness.advance(const Duration(seconds: 5));
    expect((await sendPart()).statusCode, HttpStatus.ok);
  });

  test('free space is read from df', () async {
    expect(parseDfAvailableBytes(linuxDf), 850000000 * 1024);
    expect(parseDfAvailableBytes(spacedDf), 0);
    expect(parseDfAvailableBytes('df: /missing: No such file\n'), isNull);

    for (final String folder in <String>[
      Directory.systemTemp.path,
      '${Directory.systemTemp.path}/no-such-folder-${newSyncId()}',
    ]) {
      final int? free = await dfFreeBytes(folder);
      expect(
        free == null || free > 0,
        isTrue,
        reason: 'a positive number or null for $folder, got $free',
      );
    }
  });

  test('the minimum free space is read from RELAY_MIN_FREE_BYTES', () {
    expect(
      RelayConfig.fromEnvironment(const <String, String>{}).minFreeBytes,
      2 * 1024 * 1024 * 1024,
    );
    expect(
      RelayConfig.fromEnvironment(const <String, String>{
        'RELAY_MIN_FREE_BYTES': '5000000000',
      }).minFreeBytes,
      5000000000,
    );
    for (final String invalid in <String>['-1', 'lots', '2GB']) {
      expect(
        () => RelayConfig.fromEnvironment(<String, String>{
          'RELAY_MIN_FREE_BYTES': invalid,
        }),
        throwsA(isA<ConfigException>()),
        reason: invalid,
      );
    }
  });

  test('a hung df reading fails after five seconds', () async {
    final Directory stubs = await Directory.systemTemp.createTemp('df_stub_');
    addTearDown(() => stubs.delete(recursive: true));
    final File pidFile = File('${stubs.path}/pid');
    final File df = File('${stubs.path}/df');
    await df.writeAsString(
      '#!/bin/sh\necho \$\$ > "${pidFile.path}"\nexec cat\n',
    );
    expect((await Process.run('chmod', <String>['+x', df.path])).exitCode, 0);
    final ManualTimers timers = ManualTimers();
    bool finished = false;
    final Future<int?> reading = dfFreeBytes(
      stubs.path,
      executable: df.path,
      startTimer: timers.start,
    ).whenComplete(() => finished = true);
    String written() =>
        pidFile.existsSync() ? pidFile.readAsStringSync().trim() : '';
    expect(
      await eventually(
        () => timers.pending(dfLimit).length == 1 && written().isNotEmpty,
      ),
      isTrue,
    );
    final int pid = int.parse(written());
    expect(running(pid), isTrue);
    expect(finished, isFalse);

    timers.pending(dfLimit).single.fire();

    expect(await reading.timeout(answerLimit), isNull);
    expect(await eventually(() => !running(pid)), isTrue);
  });

  test('pushes keep working while df fails', () async {
    final RelayHarness harness = await RelayHarness.start(
      minFreeBytes: freeFloor,
      startTimer: ManualTimers().start,
    );
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    Future<int> push(String recordKey) async => (await harness.send(
      SyncRoutes.pushRecords,
      credential: me.session,
      body: PushRequest(changes: <RecordPush>[harness.record(recordKey)]),
    )).statusCode;
    Future<http.Response> sendPart() => harness.putPart(
      me.session,
      name: harness.blobName(),
      uploadId: newSyncId(),
      index: 0,
      blobSize: 1500,
      partSize: 1024,
      bytes: Uint8List(1024),
    );
    List<Map<String, Object?>> warnings() => <Map<String, Object?>>[
      for (final String line in harness.logLines)
        if (decodeJsonObject(line)['event'] == failedReadingEvent)
          decodeJsonObject(line),
    ];

    expect(await push('read'), HttpStatus.ok);
    expect(warnings(), isEmpty);

    harness.freeBytes = null;
    harness.advance(readingLifetime);
    expect(await push('last-good'), HttpStatus.ok);
    final http.Response part = await sendPart();
    expect(part.statusCode, HttpStatus.insufficientStorage);
    expect(errorOf(part).code, SyncErrorCode.storageFull);
    expect(warnings(), hasLength(1));

    harness.advance(const Duration(minutes: 10));
    expect(await push('unread'), HttpStatus.ok);
    expect(warnings(), hasLength(2));

    harness.freeBytes = freeFloor + 512;
    harness.advance(readingLifetime);
    expect(await push('nearly-full'), HttpStatus.insufficientStorage);
    harness.freeBytes = null;
    harness.advance(readingLifetime);
    expect(await push('nearly-full-unread'), HttpStatus.insufficientStorage);
    expect(warnings(), hasLength(3));
    for (final Map<String, Object?> warning in warnings()) {
      expect(warning.keys, unorderedEquals(<String>['ts', 'event']));
    }
    expect(harness.database.count('SELECT count(*) FROM records'), 3);
  });

  test('a df that never exits is not started again', () async {
    final ManualTimers timers = ManualTimers();
    final List<({String directory, StuckProcess process})> started =
        <({String directory, StuckProcess process})>[];
    final DfProbe df = DfProbe(
      startTimer: timers.start,
      startProcess: (String executable, List<String> arguments) async {
        final StuckProcess process = StuckProcess();
        started.add((directory: arguments.last, process: process));
        return process;
      },
    );
    const String media = '/srv/relay/media';
    const String data = '/srv/relay/data';

    final Future<int?> stuck = df.read(media);
    expect(await eventually(() => timers.pending(dfLimit).length == 1), isTrue);
    timers.pending(dfLimit).single.fire();
    expect(await stuck.timeout(answerLimit), isNull);
    final StuckProcess hung = started.single.process;
    expect(hung.signals, <ProcessSignal>[ProcessSignal.sigkill]);

    for (int attempt = 0; attempt < 3; attempt++) {
      expect(await df.read(media).timeout(answerLimit), isNull);
    }
    expect(started, hasLength(1));
    expect(timers.pending(dfLimit), isEmpty);

    final Future<int?> other = df.read(data);
    expect(await eventually(() => started.length == 2), isTrue);
    expect(started.last.directory, data);
    started.last.process.finish(linuxDf);
    expect(await other.timeout(answerLimit), 850000000 * 1024);

    hung.exited.complete(-9);
    await pumpEventQueue();
    final Future<int?> again = df.read(media);
    expect(await eventually(() => started.length == 3), isTrue);
    expect(started.last.directory, media);
    started.last.process.finish(linuxDf);
    expect(await again.timeout(answerLimit), 850000000 * 1024);
  });

  test('a full database answers storage_full', () async {
    final RelayHarness harness = await RelayHarness.start(
      startTimer: ManualTimers().start,
    );
    addTearDown(harness.dispose);
    final TestAccount account = await harness.enrol();
    final SignedIn me = await harness.signIn(account.firstDevice);
    harness.freeBytes = null;
    final int pages = harness.database.count('PRAGMA page_count');
    harness.database.execute('PRAGMA max_page_count = $pages');

    final http.Response full = await harness.send(
      SyncRoutes.pushRecords,
      credential: me.session,
      body: PushRequest(
        changes: <RecordPush>[
          harness.record('note-1', envelope: harness.randomOpaque(256 * 1024)),
        ],
      ),
    );

    expect(full.statusCode, HttpStatus.insufficientStorage);
    expect(errorOf(full).code, SyncErrorCode.storageFull);
    expect(harness.database.count('SELECT count(*) FROM records'), 0);
  });
}
