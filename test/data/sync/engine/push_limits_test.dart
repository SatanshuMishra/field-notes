import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/crypto/record_cipher.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:field_notes/data/sync/background/upload_result_applier.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const String _push = '/v1/records/push';
const String _pull = '/v1/records';

final class _Uploader implements BackgroundUploader {
  final List<UploadTask> enqueued = <UploadTask>[];
  final Map<String, Task> held = <String, Task>{};

  List<UploadTask> get pushes => <UploadTask>[
    for (final UploadTask task in enqueued)
      if (task.group == recordPushGroup) task,
  ];

  @override
  Future<void> start(void Function(TaskStatusUpdate update) onUpdate) async {}

  @override
  Future<bool> enqueue(UploadTask task) async {
    enqueued.add(task);
    held[task.taskId] = task;
    return true;
  }

  @override
  Future<List<Task>> queuedTasks() async => held.values.toList();

  @override
  Future<void> cancel(Iterable<String> taskIds) async {
    for (final String id in taskIds) {
      held.remove(id);
    }
  }
}

final class _ZoneTimer implements Timer {
  _ZoneTimer(this.dueAt, this._callback);

  final Duration dueAt;
  final void Function() _callback;
  bool _active = true;
  int _tick = 0;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _active = false;
  }

  void fire() {
    if (!_active) {
      return;
    }
    _active = false;
    _tick = 1;
    _callback();
  }
}

final class _ZoneTime {
  final List<_ZoneTimer> _timers = <_ZoneTimer>[];
  Duration _elapsed = Duration.zero;

  Future<T> run<T>(Future<T> Function() body) => runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      createTimer:
          (
            Zone self,
            ZoneDelegate parent,
            Zone zone,
            Duration duration,
            void Function() callback,
          ) {
            final _ZoneTimer timer = _ZoneTimer(_elapsed + duration, callback);
            _timers.add(timer);
            return timer;
          },
    ),
  );

  Future<void> advance(Duration by) async {
    final Duration end = _elapsed + by;
    while (true) {
      final List<_ZoneTimer> due = <_ZoneTimer>[
        for (final _ZoneTimer timer in _timers)
          if (timer.isActive && timer.dueAt <= end) timer,
      ]..sort((_ZoneTimer a, _ZoneTimer b) => a.dueAt.compareTo(b.dueAt));
      if (due.isEmpty) {
        break;
      }
      _elapsed = due.first.dueAt;
      due.first.fire();
      await pumpEventQueue();
    }
    _elapsed = end;
  }
}

final class _Outcome<T> {
  _Outcome(Future<T> work) {
    done = work.then(
      (T value) {
        result = value;
      },
      onError: (Object failure) {
        error = failure;
      },
    );
  }

  late final Future<void> done;
  T? result;
  Object? error;

  bool get pending => result == null && error == null;
}

Future<List<SyncOutboxData>> _outbox(SyncTestDevice device) =>
    device.database.select(device.database.syncOutbox).get();

Future<SyncRecordSeq?> _seqOf(SyncTestDevice device, String recordKey) =>
    (device.database.select(
      device.database.syncRecordSeqs,
    )..where((t) => t.recordKey.equals(recordKey))).getSingleOrNull();

Future<domain.Entry> _note(
  SyncTestDevice device,
  domain.Day day,
  String text,
) => device.journal.createEntry(
  dayId: day.id,
  type: domain.EntryType.text,
  textContent: text,
);

bool _pushHolds(http.BaseRequest request, String recordKey) =>
    request is http.Request &&
    request.method == 'POST' &&
    request.url.path == _push &&
    request.body.contains(recordKey);

File _taskFile(UploadTask task) =>
    File(p.join(p.separator, task.directory, task.filename));

void _forgeRecord(RelayFixture relay, String accountId, String recordKey) {
  final int seq =
      (relay.app.database.selectOne(
                'SELECT last_seq FROM account_seqs WHERE account_id = ?',
                <Object?>[accountId],
              )?['last_seq']
              as int? ??
          0) +
      1;
  relay.app.database.execute(
    'INSERT INTO records (account_id, record_key, seq, epoch, envelope, '
    'change_id, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      accountId,
      recordKey,
      seq,
      1,
      RecordCipher(JournalKeys.generate())
          .seal(utf8.encode('{"sealed":"elsewhere"}'), recordKey, 1),
      newSyncId(),
      DateTime.now().millisecondsSinceEpoch,
    ],
  );
  relay.app.database.execute(
    'INSERT INTO account_seqs (account_id, last_seq) VALUES (?, ?) '
    'ON CONFLICT (account_id) DO UPDATE SET last_seq = excluded.last_seq',
    <Object?>[accountId, seq],
  );
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RelayFixture relay;
  late List<SyncTestDevice> devices;

  setUp(() async {
    relay = await RelayFixture.start(rateBurst: 1000);
    devices = <SyncTestDevice>[];
  });

  tearDown(() async {
    for (final SyncTestDevice device in devices) {
      await device.dispose();
    }
    await relay.dispose();
  });

  SyncTestDevice device(String name) {
    final SyncTestDevice created = SyncTestDevice(name);
    devices.add(created);
    return created;
  }

  test('a record too large to sync does not block the others', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final domain.Day day = await mac.journal.ensureDayForDate('2026-10-09');
    final domain.Entry large = await _note(mac, day, 'x' * maxEnvelopeBytes);
    final domain.Entry small = await _note(mac, day, 'a short note');
    final KeyedNames names = KeyedNames(await mac.journalKeys());
    final String largeKey = names.recordKey(SyncedTables.entries, large.id);
    final String smallKey = names.recordKey(SyncedTables.entries, small.id);
    final SyncEngine engine = mac.engine();

    await engine.start();
    await engine.syncNow();

    final Map<String, int> held = relay.recordSeqs(
      relay.accountOf(await mac.deviceId()),
    );
    expect(held, contains(smallKey));
    expect(held, isNot(contains(largeKey)));
    expect(await _seqOf(mac, smallKey), isNotNull);
    expect(
      (await _outbox(mac)).map((SyncOutboxData row) => row.rowId),
      <String>[large.id],
    );
    expect(engine.consecutiveFailures, 0);
    final int pushes = mac.http.countOf('POST', _push);
    expect(pushes, greaterThan(0));

    for (int failures = 1; failures <= 6; failures++) {
      await mac.clock.advance(backoffAfter(failures));
      await engine.syncNow();
    }

    expect(mac.http.countOf('POST', _push), pushes);
    expect(
      mac.http
          .to('POST', _push)
          .where((SentRequest request) => request.body.contains(largeKey)),
      isEmpty,
    );
    expect(
      (await _outbox(mac)).map((SyncOutboxData row) => row.rowId),
      <String>[large.id],
    );
    expect(engine.consecutiveFailures, 0);
    expect(await engine.status(), const WaitingStatus(1));
  });

  test(
    'a full relay is retried with backoff and keeps saying it is full',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final domain.Day day = await mac.journal.ensureDayForDate('2026-10-10');
      final SyncEngine engine = mac.engine();
      await engine.start();
      await engine.syncNow();
      await eventually(() async => engine.isLive);
      final List<DateTime> pushes = <DateTime>[];
      bool full = true;
      mac.http.intercept = (http.BaseRequest request) async {
        if (request.method != 'POST' || request.url.path != _push) {
          return null;
        }
        pushes.add(mac.clock.now());
        return full
            ? jsonAnswer(
                HttpStatus.insufficientStorage,
                const ErrorResponse(
                  code: SyncErrorCode.storageFull,
                  message: 'The relay is full',
                ).toJson(),
              )
            : null;
      };
      const AttentionStatus fullStatus = AttentionStatus(
        AttentionReason.storageFull,
      );
      final int timers = mac.clock.pendingTimers;

      await _note(mac, day, 'written while the relay is full');
      await eventually(() async => mac.clock.pendingTimers > timers);
      await mac.clock.advance(localWriteDelay);
      await eventually(
        () async => pushes.length == 1 && await engine.status() == fullStatus,
      );
      final DateTime first = pushes.single;
      expect(
        _labelOf(await engine.status()),
        'Needs attention · your server is full',
      );

      Duration waited = Duration.zero;
      for (int failures = 1; failures <= 4; failures++) {
        final Duration wait = backoffAfter(failures);
        await mac.clock.advance(wait - const Duration(milliseconds: 1));
        expect(pushes, hasLength(failures));
        await mac.clock.advance(const Duration(milliseconds: 1));
        await eventually(() async => pushes.length == failures + 1);
        waited += wait;
        expect(pushes.last, first.add(waited));
        await eventually(
          () async => engine.consecutiveFailures == failures + 1,
        );
        expect(await engine.status(), fullStatus);
      }
      expect(engine.consecutiveFailures, greaterThan(unreachableAfterFailures));

      full = false;
      await mac.clock.advance(backoffAfter(engine.consecutiveFailures));
      await eventually(() async => await engine.status() is SyncedStatus);
      expect(pushes, hasLength(6));
      expect(await _outbox(mac), isEmpty);
      expect(engine.consecutiveFailures, 0);
    },
  );

  test('a large upload gets time in proportion to its size', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final RelayClient client = mac.relayClient(
      relay.baseUrl,
      await mac.deviceKeys(),
      (SessionResponse _) {},
    );
    await client.signIn();
    final List<Completer<http.StreamedResponse>> answers =
        <Completer<http.StreamedResponse>>[];
    mac.http.intercept = (http.BaseRequest request) async {
      if (request.method != 'PUT' && request.url.path != _pull) {
        return null;
      }
      final Completer<http.StreamedResponse> answer =
          Completer<http.StreamedResponse>();
      answers.add(answer);
      return answer.future;
    };
    final _ZoneTime time = _ZoneTime();
    const int partBytes = 8 * 1024 * 1024;
    Future<UploadStatusResponse> sendPart() => time.run(
      () => client.uploadPart(
        name: 'blob',
        uploadId: newSyncId(),
        index: 0,
        blobSize: partBytes,
        partSize: partBytes,
        bytes: Uint8List(partBytes),
      ),
    );

    final _Outcome<UploadStatusResponse> answered =
        _Outcome<UploadStatusResponse>(sendPart());
    await eventually(() async => answers.length == 1);
    await time.advance(const Duration(seconds: 541));
    expect(answered.pending, isTrue);
    answers.single.complete(
      jsonAnswer(
        HttpStatus.ok,
        UploadStatusResponse(
          receivedParts: const <int>[0],
          assembled: false,
        ).toJson(),
      ),
    );
    await answered.done;
    expect(answered.error, isNull);
    expect(answered.result!.receivedParts, <int>[0]);

    final _Outcome<UploadStatusResponse> unanswered =
        _Outcome<UploadStatusResponse>(sendPart());
    await eventually(() async => answers.length == 2);
    await time.advance(const Duration(seconds: 541));
    expect(unanswered.pending, isTrue);
    await time.advance(const Duration(seconds: 1));
    await unanswered.done;
    expect(unanswered.error, isA<RelayUnreachable>());

    final _Outcome<PullResponse> pulled = _Outcome<PullResponse>(
      time.run(client.pull),
    );
    await eventually(() async => answers.length == 3);
    await time.advance(const Duration(seconds: 29));
    expect(pulled.pending, isTrue);
    await time.advance(const Duration(seconds: 1));
    await pulled.done;
    expect(pulled.error, isA<RelayUnreachable>());
  });

  test('a stale record a pull cannot repair backs off', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final domain.Day day = await mac.journal.ensureDayForDate('2026-10-11');
    final String recordKey = KeyedNames(await mac.journalKeys())
        .recordKey(SyncedTables.days, day.id);
    _forgeRecord(relay, relay.accountOf(await mac.deviceId()), recordKey);
    final List<DateTime> pushes = <DateTime>[];
    mac.http.intercept = (http.BaseRequest request) async {
      if (_pushHolds(request, recordKey)) {
        final DateTime now = mac.clock.now();
        pushes.add(now);
        if (pushes.where((DateTime at) => at == now).length > 4) {
          mac.network.kind = NetworkKind.offline;
        }
      }
      return null;
    };
    final SyncEngine engine = mac.engine();
    final DateTime start = mac.clock.now();

    await engine.start();
    await engine.syncNow();
    await eventually(
      () async => engine.isLive || mac.network.kind == NetworkKind.offline,
    );
    await engine.syncNow();

    expect(pushes, <DateTime>[start, start]);
    Duration waited = Duration.zero;
    for (int round = 1; round <= 3; round++) {
      final Duration wait = backoffAfter(round);
      await mac.clock.advance(wait - const Duration(milliseconds: 1));
      await engine.syncNow();
      expect(pushes, hasLength(round + 1));
      await mac.clock.advance(const Duration(milliseconds: 1));
      await engine.syncNow();
      waited += wait;
      expect(pushes, hasLength(round + 2));
      expect(pushes.last, start.add(waited));
    }
    expect(engine.consecutiveFailures, 0);
    expect(
      (await _outbox(mac)).map((SyncOutboxData row) => row.rowId),
      contains(day.id),
    );
  });

  test('a stale record is not handed over again before a pull', () async {
    final SyncTestDevice phone = await enrolDevice(relay, device('Phone'));
    final SyncTestMedia media = await SyncTestMedia.create(phone);
    final _Uploader uploader = _Uploader();
    final BackgroundUploads uploads = BackgroundUploads(
      database: phone.database,
      uploader: uploader,
      keyStore: phone.keyStore,
      uploads: media.uploads,
      isVisible: () {
        final AppLifecycleState? state = phone.lifecycle.current;
        return state == null || !isBackgrounded(state);
      },
      pushRoot: pushWorkRoot(media.root),
      allowMobileData: () async => false,
    );
    final BackgroundTransfer transfer = BackgroundTransfer(
      uploads: uploads,
      results: UploadResultApplier(
        database: phone.database,
        uploader: uploader,
        uploads: media.uploads,
        background: uploads,
      ),
    );
    final domain.Day day = await phone.journal.ensureDayForDate('2026-10-12');
    final KeyedNames names = KeyedNames(await phone.journalKeys());
    final String staleKey = names.recordKey(SyncedTables.days, day.id);
    _forgeRecord(relay, relay.accountOf(await phone.deviceId()), staleKey);
    final Completer<void> pullHeld = Completer<void>();
    bool answeredStale = false;
    domain.Entry? written;
    phone.http.intercept = (http.BaseRequest request) async {
      if (_pushHolds(request, staleKey)) {
        answeredStale = true;
        return null;
      }
      if (answeredStale &&
          written == null &&
          request.method == 'GET' &&
          request.url.path == _pull) {
        written = await _note(phone, day, 'written as the app is left');
        phone.lifecycle.state = AppLifecycleState.hidden;
        await pullHeld.future;
      }
      return null;
    };
    final SyncEngine engine = phone.engine(
      media: media.source(),
      background: () async => transfer,
    );

    await engine.start();
    await eventually(() async => uploader.pushes.isNotEmpty);

    final List<PushRequest> handed = <PushRequest>[
      for (final UploadTask task in uploader.pushes)
        PushRequest.fromJson(
          decodeJsonObject(await _taskFile(task).readAsString()),
        ),
    ];
    final Set<String> handedKeys = <String>{
      for (final PushRequest request in handed)
        for (final RecordPush change in request.changes) change.recordKey,
    };
    expect(
      handedKeys,
      contains(names.recordKey(SyncedTables.entries, written!.id)),
    );
    expect(handedKeys, isNot(contains(staleKey)));
    pullHeld.complete();
  });
}

String _labelOf(SyncStatus? status) => status!.label(DateTime.now().toUtc());
