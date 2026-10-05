import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/live_connection.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/engine/sync_status.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/hlc.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/merge/record_state.dart' as local;
import 'package:field_notes/data/sync/synced_tables.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sync_protocol/sync_protocol.dart' as protocol show RecordState;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const String _push = '/v1/records/push';

final class _IdleClosingProxy {
  _IdleClosingProxy(this._targetPort, this._clock, this._idleLimit);

  final int _targetPort;
  final SyncClock _clock;
  final Duration _idleLimit;
  final List<_Pipe> _pipes = <_Pipe>[];
  ServerSocket? _server;
  int closed = 0;

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server!.port}');

  Future<void> start() async {
    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    _server = server;
    server.listen((Socket client) async {
      final Socket upstream = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _targetPort,
      );
      final _Pipe pipe = _Pipe(client, upstream, _clock.now());
      _pipes.add(pipe);
      client.listen(
        (List<int> data) {
          pipe.lastActivity = _clock.now();
          upstream.add(data);
        },
        onDone: pipe.close,
        onError: (Object _) => pipe.close(),
      );
      upstream.listen(
        (List<int> data) {
          pipe.lastActivity = _clock.now();
          client.add(data);
        },
        onDone: pipe.close,
        onError: (Object _) => pipe.close(),
      );
    });
  }

  void sweep() {
    final DateTime now = _clock.now();
    for (final _Pipe pipe in _pipes.toList()) {
      if (!pipe.open) {
        _pipes.remove(pipe);
        continue;
      }
      if (now.difference(pipe.lastActivity) >= _idleLimit) {
        pipe.close();
        _pipes.remove(pipe);
        closed += 1;
      }
    }
  }

  Future<void> stop() async {
    for (final _Pipe pipe in _pipes) {
      pipe.close();
    }
    await _server?.close();
  }
}

final class _Pipe {
  _Pipe(this.client, this.upstream, this.lastActivity);

  final Socket client;
  final Socket upstream;
  DateTime lastActivity;
  bool open = true;

  void close() {
    if (!open) {
      return;
    }
    open = false;
    client.destroy();
    upstream.destroy();
  }
}

Future<List<Entry>> _entries(SyncTestDevice device) =>
    device.database.select(device.database.entries).get();

Future<List<Day>> _days(SyncTestDevice device) =>
    device.database.select(device.database.days).get();

Future<List<SyncOutboxData>> _outbox(SyncTestDevice device) =>
    device.database.select(device.database.syncOutbox).get();

Future<SyncRecordSeq?> _seqOf(SyncTestDevice device, String recordKey) =>
    (device.database.select(
      device.database.syncRecordSeqs,
    )..where((t) => t.recordKey.equals(recordKey))).getSingleOrNull();

String _label(SyncStatus? status) => status!.label(DateTime.now().toUtc());

local.RecordState _dayState(int index, String node) {
  final String date = '2026-01-${(index + 1).toString().padLeft(2, '0')}';
  final String clock = Hlc(
    millis: DateTime.now().millisecondsSinceEpoch,
    counter: index,
    nodeId: node,
  ).encode();
  return local.RecordState(
    table: SyncedTables.days,
    rowId: 'day-$date',
    fields: <String, Object?>{
      'id': 'day-$date',
      'date': date,
      'moodId': null,
      'createdAt': 0,
      'updatedAt': 0,
      'deletedAt': null,
    },
    clocks: <String, String>{
      for (final String field in SyncedTables.dayFields) field: clock,
    },
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

  SyncTestDevice device(String name, {Duration ahead = Duration.zero}) {
    final SyncTestDevice created = SyncTestDevice(name, ahead: ahead);
    devices.add(created);
    return created;
  }

  test('a held-back change is applied once the clock catches up', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(
      relay,
      mac,
      device('Phone', ahead: const Duration(minutes: 6)),
    );
    final SyncEngine macEngine = mac.engine();
    final SyncEngine phoneEngine = phone.engine();
    await macEngine.start();
    await phoneEngine.start();
    await macEngine.syncNow();
    await phoneEngine.syncNow();

    await phone.journal.setMoodForDate(
      date: '2026-10-02',
      mood: domain.Mood.values.first,
    );
    await phoneEngine.syncNow();
    await macEngine.syncNow();

    expect(
      _label(await macEngine.status()),
      "Needs attention · this device's clock",
    );
    expect(await _days(mac), isEmpty);
    expect(
      await mac.database.select(mac.database.syncHeldStates).get(),
      hasLength(1),
    );

    mac.wallOffset = const Duration(minutes: 2);
    await macEngine.syncNow();

    final List<Day> days = await _days(mac);
    expect(days.single.date, '2026-10-02');
    expect(days.single.moodId, domain.Mood.values.first.id);
    expect(
      await mac.database.select(mac.database.syncHeldStates).get(),
      isEmpty,
    );
    expect(await macEngine.status(), isA<SyncedStatus>());
  });

  test('a stale push stores the current seq and succeeds on retry', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    final SyncEngine macEngine = mac.engine();
    final SyncEngine phoneEngine = phone.engine();
    await macEngine.start();
    await phoneEngine.start();
    final domain.Day day = await mac.journal.ensureDayForDate('2026-10-03');
    final domain.Entry entry = await mac.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.text,
      textContent: 'a\nb\nc',
    );
    await macEngine.syncNow();
    await phoneEngine.syncNow();
    expect((await _entries(phone)).single.textContent, 'a\nb\nc');

    await mac.journal.updateEntryText(id: entry.id, textContent: 'A\nb\nc');
    await phone.journal.updateEntryText(id: entry.id, textContent: 'a\nb\nC');
    final String recordKey = KeyedNames(await mac.journalKeys())
        .recordKey(SyncedTables.entries, entry.id);
    bool raced = false;
    mac.http.intercept = (http.BaseRequest request) async {
      if (!raced && request.method == 'POST' && request.url.path == _push) {
        raced = true;
        await phoneEngine.syncNow();
      }
      return null;
    };
    final int pushesBefore = mac.http.countOf('POST', _push);

    await macEngine.syncNow();

    expect(raced, isTrue);
    final SyncRecordSeq phoneSeq = (await _seqOf(phone, recordKey))!;
    final SyncRecordSeq macSeq = (await _seqOf(mac, recordKey))!;
    expect(mac.http.countOf('POST', _push) - pushesBefore, 2);
    expect(macSeq.seq, greaterThan(phoneSeq.seq));
    expect((await _entries(mac)).single.textContent, 'A\nb\nC');
    expect(await _outbox(mac), isEmpty);

    await phoneEngine.syncNow();
    expect((await _entries(phone)).single.textContent, 'A\nb\nC');
    expect((await _seqOf(phone, recordKey))!.seq, macSeq.seq);
  });

  test('a device adopts a new epoch after another device is removed', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    final SyncTestDevice tablet = await pairDevice(
      relay,
      mac,
      device('Tablet'),
    );
    final SyncEngine phoneEngine = phone.engine();
    await phoneEngine.start();
    await phoneEngine.syncNow();
    expect((await phone.journalKeys()).currentEpoch, 1);

    final int epoch = await DeviceService(
      database: mac.database,
      keyStore: mac.keyStore,
      client: await mac.plainClient(relay.baseUrl),
    ).remove(await tablet.deviceId());
    expect(epoch, 2);

    final domain.Day day = await phone.journal.ensureDayForDate('2026-10-04');
    await phone.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.text,
      textContent: 'after the removal',
    );
    await phoneEngine.syncNow();

    expect((await phone.journalKeys()).currentEpoch, 2);
    expect(await _outbox(phone), isEmpty);
    final List<SentRequest> pushes = phone.http.to('POST', _push);
    final List<int> epochs = <int>[
      for (final SentRequest push in pushes)
        ...PushRequest.fromJson(decodeJsonObject(push.body)).changes
            .map((RecordPush change) => change.epoch),
    ];
    expect(epochs, containsAllInOrder(<int>[1, 2]));
    final PullResponse pulled = await (await mac.plainClient(relay.baseUrl))
        .pull();
    expect(pulled.states, isNotEmpty);
    expect(
      pulled.states.every((protocol.RecordState state) => state.epoch == 2),
      isTrue,
    );
    final JournalKeys tabletKeys = await tablet.journalKeys();
    expect(tabletKeys.hasEpoch(2), isFalse);
  });

  test('pause survives a restart', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncEngine first = mac.engine();
    await first.start();
    await first.syncNow();

    await first.pause(true);

    expect(_label(await first.status()), 'Sync paused');
    await mac.disposeEngines();
    final int sentBefore = mac.http.sent.length;
    final SyncEngine second = mac.engine();
    await second.start();
    await second.syncNow();
    await mac.clock.advance(const Duration(minutes: 10));

    expect(second.isPaused, isTrue);
    expect(_label(await second.status()), 'Sync paused');
    expect(mac.http.sent.length, sentBefore);
    expect(second.isLive, isFalse);
  });

  test('no connection is opened while sync is off or backgrounded', () async {
    final SyncTestDevice mac = await enrolDevice(
      relay,
      device('Mac'),
      switchOn: false,
    );
    final SyncEngine engine = mac.engine();
    await engine.start();
    await engine.syncNow();
    await mac.clock.advance(const Duration(minutes: 10));
    expect(await engine.status(), isNull);
    expect(mac.http.sent, isEmpty);
    expect(mac.sockets, 0);

    mac.lifecycle.state = AppLifecycleState.hidden;
    await switchSyncOn(mac.database);
    await eventually(() async => engine.isEnabled);
    final domain.Day day = await mac.journal.ensureDayForDate('2026-10-05');
    await engine.syncNow();
    await mac.clock.advance(const Duration(minutes: 10));
    mac.lifecycle.state = AppLifecycleState.paused;
    await mac.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.text,
      textContent: 'written while away',
    );
    await engine.syncNow();
    await mac.clock.advance(const Duration(minutes: 10));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(mac.http.sent, isEmpty);
    expect(mac.sockets, 0);

    mac.lifecycle.state = AppLifecycleState.resumed;
    await eventually(() async => engine.isLive);
    expect(mac.http.sent, isNotEmpty);
    expect(mac.sockets, 1);

    mac.lifecycle.state = AppLifecycleState.inactive;
    await mac.clock.advance(const Duration(seconds: 45));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(engine.isLive, isTrue);
    expect(mac.sockets, 1);

    mac.lifecycle.state = AppLifecycleState.hidden;
    await eventually(() async => !engine.isLive);
    final int sentWhileVisible = mac.http.sent.length;
    await mac.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.text,
      textContent: 'written after hiding',
    );
    await mac.clock.advance(const Duration(minutes: 10));
    await engine.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(mac.http.sent.length, sentWhileVisible);
    expect(mac.sockets, 1);
  });

  test('offline changes reach the relay on reconnect', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    mac.network.kind = NetworkKind.offline;
    final SyncEngine macEngine = mac.engine();
    await macEngine.start();

    final domain.Day day = await mac.journal.ensureDayForDate('2026-10-06');
    final domain.Entry kept = await mac.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.text,
      textContent: 'first draft',
    );
    final domain.Entry dropped = await mac.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.text,
      textContent: 'about to go',
    );
    await mac.journal.updateEntryText(id: kept.id, textContent: 'edited');
    await mac.journal.softDeleteEntry(dropped.id);
    await mac.clock.advance(const Duration(minutes: 10));

    expect(
      _label(await macEngine.status()),
      'Offline · will sync when connected',
    );
    expect(mac.http.sent, isEmpty);

    mac.network.kind = NetworkKind.unmetered;
    await eventually(() async => (await _outbox(mac)).isEmpty);

    final SyncEngine phoneEngine = phone.engine();
    await phoneEngine.start();
    await phoneEngine.syncNow();
    final List<Entry> entries = await _entries(phone);
    expect(entries, hasLength(2));
    expect(
      entries.singleWhere((Entry entry) => entry.id == kept.id).textContent,
      'edited',
    );
    expect(
      entries.singleWhere((Entry entry) => entry.id == dropped.id).deletedAt,
      isNotNull,
    );
  });

  test('an unsupported protocol stops sync with the update message', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    mac.http.intercept = (http.BaseRequest request) async {
      request.headers[SyncHeaders.protocol] = '99';
      return null;
    };
    final SyncEngine engine = mac.engine();
    await engine.start();
    await eventually(() async => await engine.status() is AttentionStatus);

    final AttentionStatus status = (await engine.status())! as AttentionStatus;
    expect(_label(status), 'Needs attention · update Field Notes');
    expect(status.fix, 'Please update Field Notes to keep syncing.');
    final int sent = mac.http.sent.length;
    await engine.syncNow();
    await mac.clock.advance(const Duration(minutes: 10));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(mac.http.sent.length, sent);
    expect(mac.sockets, 0);
  });

  test('pings every thirty seconds keep the live connection through an idle-closing proxy', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    final _IdleClosingProxy proxy = _IdleClosingProxy(
      relay.port,
      mac.clock,
      const Duration(seconds: 100),
    );
    await proxy.start();
    addTearDown(proxy.stop);
    await writeSyncState(
      mac.database,
      SyncStateKeys.relayUrl,
      '${proxy.baseUrl}',
    );
    final SyncEngine macEngine = mac.engine();
    await macEngine.start();
    await eventually(() async => macEngine.isLive);
    expect(relay.app.live.openCount, 1);

    for (int step = 0; step < 20; step++) {
      await mac.clock.advance(livePingInterval);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      relay.advance(livePingInterval);
      await relay.tick();
      proxy.sweep();
    }

    expect(macEngine.isLive, isTrue);
    expect(mac.sockets, 1);
    expect(relay.app.live.openCount, 1);
    final SyncEngine phoneEngine = phone.engine();
    await phoneEngine.start();
    final domain.Day day = await phone.journal.ensureDayForDate('2026-10-07');
    await phone.journal.createEntry(
      dayId: day.id,
      type: domain.EntryType.text,
      textContent: 'ten quiet minutes later',
    );
    await phoneEngine.syncNow();
    await eventually(
      () async => (await _entries(mac)).isNotEmpty,
      timeout: const Duration(seconds: 5),
    );
    expect((await _entries(mac)).single.textContent, 'ten quiet minutes later');
  });

  test('first-pull progress comes from the pull responses', () async {
    final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
    final JournalKeys keys = await mac.journalKeys();
    final KeyedNames names = KeyedNames(keys);
    final List<RecordPush> changes = <RecordPush>[
      for (int index = 0; index < 5; index++)
        RecordPush(
          recordKey: names.recordKey(
            SyncedTables.days,
            _dayState(index, 'mac').rowId,
          ),
          baseSeq: 0,
          changeId: newSyncId(),
          epoch: keys.currentEpoch,
          envelope: sealRecordState(
            keys,
            _dayState(index, 'mac'),
            names.recordKey(SyncedTables.days, _dayState(index, 'mac').rowId),
            keys.currentEpoch,
          ),
        ),
    ];
    await (await mac.plainClient(relay.baseUrl))
        .push(PushRequest(changes: changes));
    final SyncTestDevice phone = await pairDevice(relay, mac, device('Phone'));
    final SyncEngine engine = phone.engine(pullPageSize: 2);
    final List<FirstPullProgress?> seen = <FirstPullProgress?>[];
    final StreamSubscription<FirstPullProgress?> subscription = engine.progress
        .listen(seen.add);
    addTearDown(subscription.cancel);

    await engine.start();
    await engine.syncNow();

    expect(seen, <FirstPullProgress?>[
      const FirstPullProgress(done: 2, total: 5),
      const FirstPullProgress(done: 4, total: 5),
      null,
    ]);
    expect(engine.firstPullProgress, isNull);
    expect(await _days(phone), hasLength(5));
  });

  test(
    'a long outbox is pushed in requests within the relay\'s limits',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      final domain.Day day = await mac.journal.ensureDayForDate('2026-10-08');
      for (int index = 0; index < 1200; index++) {
        await mac.journal.createEntry(
          dayId: day.id,
          type: domain.EntryType.text,
          textContent: 'note $index',
        );
      }
      expect(await _outbox(mac), hasLength(1201));
      final SyncEngine engine = mac.engine();

      await engine.start();
      await engine.syncNow();

      final List<SentRequest> pushes = mac.http.to('POST', _push);
      expect(pushes, hasLength(3));
      int total = 0;
      for (final SentRequest push in pushes) {
        final PushRequest request = PushRequest.fromJson(
          decodeJsonObject(push.body),
        );
        expect(request.changes.length, lessThanOrEqualTo(maxPushChanges));
        expect(push.bodyBytes, lessThanOrEqualTo(maxPushBodyBytes));
        total += request.changes.length;
      }
      expect(total, 1201);
      expect(await _outbox(mac), isEmpty);
      expect(
        await mac.database.select(mac.database.syncRecordSeqs).get(),
        hasLength(1201),
      );
    },
  );

  test(
    'a rate-limited request waits its Retry-After before trying again',
    () async {
      final SyncTestDevice mac = await enrolDevice(relay, device('Mac'));
      bool limited = false;
      mac.http.intercept = (http.BaseRequest request) async {
        if (!limited && request.url.path == '/v1/session/challenge') {
          limited = true;
          return jsonAnswer(
            HttpStatus.tooManyRequests,
            const ErrorResponse(
              code: SyncErrorCode.tooManyRequests,
              message: 'Too many requests',
            ).toJson(),
            headers: <String, String>{'retry-after': '20'},
          );
        }
        return null;
      };
      final SyncEngine engine = mac.engine();

      await engine.start();
      await eventually(() async => limited);
      await engine.syncNow();
      final int afterLimit = mac.http.sent.length;
      await mac.clock.advance(const Duration(seconds: 19));
      await engine.syncNow();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(mac.http.sent.length, afterLimit);
      expect(engine.consecutiveFailures, 0);
      expect(await engine.status(), isNot(isA<AttentionStatus>()));

      await mac.clock.advance(const Duration(seconds: 1));
      await eventually(() async => engine.isLive);

      expect(mac.http.sent.length, greaterThan(afterLimit));
      expect(engine.consecutiveFailures, 0);
      expect(await engine.status(), isA<SyncedStatus>());
    },
  );
}
