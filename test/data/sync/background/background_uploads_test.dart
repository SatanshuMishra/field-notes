import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/journal_delete_all_service.dart';
import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:field_notes/data/sync/background/upload_result_applier.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/engine/push_cycle.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/data/sync/erase/local_journal_wipe.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/merge/state_applier.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

const String _push = '/v1/records/push';

final class _FakeUploader implements BackgroundUploader {
  final List<HandedTask> enqueued = <HandedTask>[];
  final Map<String, HandedTask> held = <String, HandedTask>{};
  final List<String> cancelled = <String>[];
  final List<HandedResult> stored = <HandedResult>[];
  void Function(HandedResult result)? _listener;
  int starts = 0;

  List<HandedTask> get parts => <HandedTask>[
    for (final HandedTask task in enqueued)
      if (task.group == mediaPartGroup) task,
  ];

  List<HandedTask> get pushes => <HandedTask>[
    for (final HandedTask task in enqueued)
      if (task.group == recordPushGroup) task,
  ];

  @override
  Future<void> start(void Function(HandedResult result) onResult) async {
    starts += 1;
    _listener = onResult;
    for (final HandedResult result in stored) {
      onResult(result);
    }
    stored.clear();
  }

  @override
  Future<void> enqueue(List<HandedTask> tasks) async {
    for (final HandedTask task in tasks) {
      enqueued.add(task);
      held[task.taskId] = task;
    }
  }

  @override
  Future<List<HandedTask>> queuedTasks() async => held.values.toList();

  @override
  Future<void> cancel(Iterable<String> taskIds) async {
    for (final String id in taskIds) {
      cancelled.add(id);
      held.remove(id);
    }
  }

  @override
  Future<void> cancelAll() => cancel(held.keys.toList());

  void finish(HandedTask task, HandedStatus status, {String? body}) {
    held.remove(task.taskId);
    _listener?.call(HandedResult(task, status, body: body));
  }
}

final class _Background {
  _Background(this.device, this.media, this.uploader, {Directory? pushRoot})
    : pushRoot = pushRoot ?? pushWorkRoot(media.root) {
    uploads = BackgroundUploads(
      database: device.database,
      uploader: uploader,
      keyStore: device.keyStore,
      uploads: media.uploads,
      pushRoot: this.pushRoot,
      allowMobileData: () async => media.settings.allowMobileDataForMedia,
    );
    results = UploadResultApplier(
      database: device.database,
      uploader: uploader,
      uploads: media.uploads,
      background: uploads,
    );
  }

  final SyncTestDevice device;
  final SyncTestMedia media;
  final _FakeUploader uploader;
  final Directory pushRoot;
  late final BackgroundUploads uploads;
  late final UploadResultApplier results;

  BackgroundTransfer get transfer =>
      BackgroundTransfer(uploads: uploads, results: results);

  SyncEngine engine({LeaveRule leaveRule = LeaveRule.hidden}) => device.engine(
    media: media.source(),
    background: () async => transfer,
    leaveRule: leaveRule,
  );

  PushCycle pushCycle() => PushCycle(
    database: device.database,
    applier: StateApplier(
      database: device.database,
      recorder: device.recorder,
      localDeviceName: device.name,
    ),
    keys: journalKeysFrom(device.keyStore),
    refreshKeys: journalKeysFrom(device.keyStore),
  );
}

File _taskFile(HandedTask task) => File(task.filePath);

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 23 + seed) % 251);

Future<void> _note(SyncTestDevice device, String text) async {
  final domain.Day day = await device.journal.ensureDayForDate('2026-10-20');
  await device.journal.createEntry(
    dayId: day.id,
    type: domain.EntryType.text,
    textContent: text,
  );
}

Future<void> _grantPass(SyncTestDevice device) async {
  await device.keyStore.writeUploadPass(
    UploadPass(
      token: 'pass-${device.name}',
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
    ),
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

  Future<_Background> enrolled(
    String name, {
    AppSettings settings = AppSettings.defaults,
  }) async {
    final SyncTestDevice phone = SyncTestDevice(name);
    devices.add(phone);
    await enrolDevice(relay, phone);
    final SyncTestMedia media = await SyncTestMedia.create(
      phone,
      settings: settings,
    );
    return _Background(phone, media, _FakeUploader());
  }

  test('prepared media parts are handed to the uploader at once', () async {
    final _Background phone = await enrolled('Phone');
    final SyncEngine engine = phone.engine();
    await engine.start();
    await engine.syncNow();
    final UploadPass pass = (await phone.device.keyStore.readUploadPass())!;

    final domain.MediaBlob video = await phone.media.store.putBytes(
      bytes: _bytes(3000, 1),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    await eventually(() async => phone.uploader.parts.length == 3);

    final PendingUpload upload =
        (await phone.media.uploads.pendingUploads()).single;
    expect(upload.blobId, video.id);
    expect(phone.uploader.parts.map((HandedTask task) => task.taskId), <String>[
      for (int index = 0; index < 3; index++)
        partTaskId(upload.uploadId, index),
    ]);
    for (final HandedTask task in phone.uploader.parts) {
      final int index = int.parse(task.taskId.split('.').last);
      expect(task.method, 'PUT');
      expect(task.mimeType, 'application/octet-stream');
      expect(
        Uri.parse(task.url).path,
        '/v1/blobs/${upload.blobName}/uploads/${upload.uploadId}/parts/$index',
      );
      expect(task.headers['Authorization'], 'Upload ${pass.token}');
      expect(task.headers['X-Sync-Protocol'], '$syncProtocolVersion');
      expect(task.headers['X-Blob-Size'], '${upload.totalBytes}');
      expect(task.headers['X-Part-Size'], '${upload.partBytes}');
      expect(_taskFile(task).path, upload.partFile(index).path);
    }
    expect(
      phone.device.http.sent.where((SentRequest r) => r.method == 'PUT'),
      isEmpty,
    );
  });

  test('leaving the app hands every pending push to the uploader', () async {
    final _Background phone = await enrolled('Phone');
    final SyncEngine engine = phone.engine();
    await engine.start();
    await engine.syncNow();
    final UploadPass pass = (await phone.device.keyStore.readUploadPass())!;
    await _note(phone.device, 'saved before leaving');
    await _note(phone.device, 'and another');

    phone.device.lifecycle.state = AppLifecycleState.hidden;
    await eventually(() async => phone.uploader.pushes.isNotEmpty);

    final HandedTask task = phone.uploader.pushes.single;
    expect(task.method, 'POST');
    expect(task.mimeType, 'application/json');
    expect(Uri.parse(task.url).path, _push);
    expect(task.headers['Authorization'], 'Upload ${pass.token}');
    expect(task.headers['X-Sync-Protocol'], '$syncProtocolVersion');
    final PushRequest request = PushRequest.fromJson(
      decodeJsonObject(await _taskFile(task).readAsString()),
    );
    final List<db.SyncOutboxData> outbox = await phone.device.database
        .select(phone.device.database.syncOutbox)
        .get();
    expect(request.changes, hasLength(outbox.length));
    expect(
      request.changes.map((RecordPush change) => change.changeId).toSet(),
      outbox.map((db.SyncOutboxData row) => row.changeId).toSet(),
    );
    expect(phone.device.http.countOf('POST', _push), 0);
  });

  test(
    'an app left in the app switcher hands every pending push to the uploader',
    () async {
      final _Background phone = await enrolled('Phone');
      final SyncEngine engine = phone.engine(leaveRule: LeaveRule.inactive);
      await engine.start();
      await engine.syncNow();
      phone.device.network.kind = NetworkKind.offline;
      await _note(phone.device, 'saved with no signal');
      final int sentBefore = phone.device.http.countOf('POST', _push);

      phone.device.lifecycle.state = AppLifecycleState.inactive;
      await phone.device.clock.advance(inactiveLeaveDelay);
      await eventually(() async => phone.uploader.pushes.isNotEmpty);

      final PushRequest request = PushRequest.fromJson(
        decodeJsonObject(
          await _taskFile(phone.uploader.pushes.single).readAsString(),
        ),
      );
      final List<db.SyncOutboxData> outbox = await phone.device.database
          .select(phone.device.database.syncOutbox)
          .get();
      expect(
        request.changes.map((RecordPush change) => change.changeId).toSet(),
        outbox.map((db.SyncOutboxData row) => row.changeId).toSet(),
      );
      expect(phone.device.http.countOf('POST', _push), sentBefore);
    },
  );

  test('an app back in focus within a second hands nothing over', () async {
    final _Background phone = await enrolled('Phone');
    final SyncEngine engine = phone.engine(leaveRule: LeaveRule.inactive);
    await engine.start();
    await engine.syncNow();
    phone.device.network.kind = NetworkKind.offline;
    await _note(phone.device, 'saved with no signal');

    phone.device.lifecycle.state = AppLifecycleState.inactive;
    await phone.device.clock.advance(inactiveLeaveDelay ~/ 2);
    phone.device.lifecycle.state = AppLifecycleState.resumed;
    await phone.device.clock.advance(inactiveLeaveDelay * 2);
    await pumpEventQueue();

    expect(phone.uploader.pushes, isEmpty);
  });

  test('a window that only loses focus keeps syncing itself', () async {
    final _Background phone = await enrolled('Mac');
    final SyncEngine engine = phone.engine();
    await engine.start();
    await engine.syncNow();
    phone.device.network.kind = NetworkKind.offline;
    await _note(phone.device, 'saved with no signal');

    phone.device.lifecycle.state = AppLifecycleState.inactive;
    await phone.device.clock.advance(inactiveLeaveDelay * 2);
    await pumpEventQueue();

    expect(phone.uploader.pushes, isEmpty);
  });

  test('media parts carry the Wi-Fi rule and follow a change to it', () async {
    final _Background phone = await enrolled('Phone');
    await _grantPass(phone.device);
    final domain.MediaBlob photo = await phone.media.store.putBytes(
      bytes: _bytes(2500, 2),
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );
    final domain.MediaBlob poster = await phone.media.store.putBytes(
      bytes: _bytes(500, 3),
      mime: 'image/jpeg',
      kind: domain.MediaKind.photo,
    );
    await (phone.device.database.update(phone.device.database.mediaBlobs)
          ..where((t) => t.id.equals(photo.id)))
        .write(db.MediaBlobsCompanion(posterId: Value(poster.id)));
    await phone.media.uploads.prepareAll();
    await _note(phone.device, 'a record push');

    await phone.uploads.handOverPrepared();
    await phone.uploads.handOverPushes(phone.pushCycle());

    final List<HandedTask> full = <HandedTask>[
      for (final HandedTask task in phone.uploader.parts)
        if (task.metaData.contains(photo.id)) task,
    ];
    final List<HandedTask> small = <HandedTask>[
      for (final HandedTask task in phone.uploader.parts)
        if (task.metaData.contains(poster.id)) task,
    ];
    expect(full, isNotEmpty);
    expect(small, isNotEmpty);
    expect(
      full.map((HandedTask task) => task.requiresWiFi),
      everyElement(isTrue),
    );
    expect(
      small.map((HandedTask task) => task.requiresWiFi),
      everyElement(isFalse),
    );
    expect(phone.uploader.pushes.single.requiresWiFi, isFalse);

    phone.media.settings = AppSettings.defaults.copyWith(
      allowMobileDataForMedia: true,
    );
    await phone.uploads.rescheduleForNetworkRule();

    expect(
      phone.uploader.cancelled.toSet(),
      full.map((HandedTask task) => task.taskId).toSet(),
    );
    final List<HandedTask> rescheduled = <HandedTask>[
      for (final HandedTask task in await phone.uploader.queuedTasks())
        if (task.metaData.contains(photo.id)) task,
    ];
    expect(rescheduled, hasLength(full.length));
    expect(
      rescheduled.map((HandedTask task) => task.requiresWiFi),
      everyElement(isFalse),
    );
  });

  test('every part of a long video is handed over once', () async {
    final _Background phone = await enrolled('Phone');
    await _grantPass(phone.device);
    await phone.media.store.putBytes(
      bytes: _bytes(130 * 1024 - 100, 7),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    await phone.media.uploads.prepareAll();
    expect((await phone.media.uploads.pendingUploads()).single.partCount, 130);

    await phone.uploads.handOverPrepared();
    await phone.uploads.handOverPrepared();

    expect(phone.uploader.parts, hasLength(130));
    expect(phone.uploader.held, hasLength(130));
  });

  test(
    'results collected on start are applied and failures prepared again',
    () async {
      final _Background first = await enrolled('Phone');
      final SyncTestDevice phone = first.device;
      final SyncEngine engine = first.engine();
      await engine.start();
      await engine.syncNow();
      await phone.disposeEngines();
      final RelayClient client = phone.relayClient(
        relay.baseUrl,
        await phone.deviceKeys(),
        (_) {},
      );
      await _note(phone, 'kept response');
      await first.uploads.handOverPushes(first.pushCycle());
      await _note(phone, 'lost response');
      await first.uploads.handOverPushes(first.pushCycle());
      expect(first.uploader.pushes, hasLength(2));
      final HandedTask kept = first.uploader.pushes[0];
      final HandedTask lost = first.uploader.pushes[1];
      Future<PushRequest> requestOf(HandedTask task) async =>
          PushRequest.fromJson(
            decodeJsonObject(await _taskFile(task).readAsString()),
          );
      final PushRequest keptRequest = await requestOf(kept);
      final PushRequest lostRequest = await requestOf(lost);
      final PushResponse keptResponse = await client.push(keptRequest);
      await client.push(lostRequest);
      await first.media.store.putBytes(
        bytes: _bytes(3000, 8),
        mime: 'video/mp4',
        kind: domain.MediaKind.video,
      );
      await first.media.uploads.prepareAll();
      await first.uploads.handOverPrepared();
      final List<HandedTask> parts = first.uploader.parts;
      expect(parts, hasLength(3));
      final PendingUpload upload =
          (await first.media.uploads.pendingUploads()).single;
      final UploadStatusResponse answer = await client.uploadPart(
        name: upload.blobName,
        uploadId: upload.uploadId,
        index: 0,
        blobSize: upload.totalBytes,
        partSize: upload.partBytes,
        bytes: await upload.partFile(0).readAsBytes(),
      );
      final _FakeUploader restarted = _FakeUploader()
        ..stored.addAll(<HandedResult>[
          HandedResult(
            kept,
            HandedStatus.complete,
            statusCode: 200,
            body: jsonEncode(keptResponse.toJson()),
          ),
          HandedResult(lost, HandedStatus.complete, statusCode: 200),
          HandedResult(
            parts[0],
            HandedStatus.complete,
            statusCode: 200,
            body: jsonEncode(answer.toJson()),
          ),
          HandedResult(parts[1], HandedStatus.failed, statusCode: 503),
          HandedResult(parts[2], HandedStatus.failed),
        ]);
      final _Background second = _Background(phone, first.media, restarted);
      final int sentBefore = phone.http.sent.length;

      final SyncEngine reopened = second.engine();
      await reopened.start();
      await reopened.syncNow();

      expect(restarted.starts, 1);
      expect(
        await phone.database.select(phone.database.syncOutbox).get(),
        isEmpty,
      );
      final List<PushRequest> foreground = <PushRequest>[
        for (final SentRequest request in phone.http.sent.skip(sentBefore))
          if (request.method == 'POST' && request.path == _push)
            PushRequest.fromJson(decodeJsonObject(request.body)),
      ];
      Set<String> idsOf(PushRequest request) => <String>{
        for (final RecordPush change in request.changes) change.changeId,
      };
      expect(idsOf(foreground.first), idsOf(lostRequest));
      expect(
        foreground.where(
          (PushRequest request) =>
              idsOf(request).intersection(idsOf(keptRequest)).isNotEmpty,
        ),
        isEmpty,
      );
      expect(
        foreground.where(
          (PushRequest request) =>
              idsOf(request).intersection(idsOf(lostRequest)).isNotEmpty,
        ),
        hasLength(1),
      );
      expect(
        await phone.database.select(phone.database.syncRecordSeqs).get(),
        hasLength(keptRequest.changes.length + lostRequest.changes.length + 1),
      );
      expect(
        restarted.parts.map((HandedTask task) => task.taskId).toSet(),
        <String>{
          partTaskId(upload.uploadId, 1),
          partTaskId(upload.uploadId, 2),
        },
      );
      expect(
        decodeAckedParts(
          (await phone.database.select(phone.database.syncUploads).getSingle())
              .ackedParts,
        ),
        <int>[0],
      );
      expect(await _taskFile(kept).exists(), isFalse);
      expect(await _taskFile(lost).exists(), isFalse);
    },
  );

  test(
    'results collected on start are applied before an offline hand-over',
    () async {
      final _Background first = await enrolled('Phone');
      final SyncTestDevice phone = first.device;
      final SyncEngine engine = first.engine();
      await engine.start();
      await engine.syncNow();
      await phone.disposeEngines();
      final RelayClient client = phone.relayClient(
        relay.baseUrl,
        await phone.deviceKeys(),
        (_) {},
      );
      await first.media.store.putBytes(
        bytes: _bytes(3000, 11),
        mime: 'video/mp4',
        kind: domain.MediaKind.video,
      );
      await first.media.uploads.prepareAll();
      await first.uploads.handOverPrepared();
      final List<HandedTask> parts = first.uploader.parts;
      expect(parts, hasLength(3));
      final PendingUpload upload =
          (await first.media.uploads.pendingUploads()).single;
      final UploadStatusResponse answer = await client.uploadPart(
        name: upload.blobName,
        uploadId: upload.uploadId,
        index: 0,
        blobSize: upload.totalBytes,
        partSize: upload.partBytes,
        bytes: await upload.partFile(0).readAsBytes(),
      );
      final _FakeUploader restarted = _FakeUploader()
        ..stored.add(
          HandedResult(
            parts[0],
            HandedStatus.complete,
            statusCode: 200,
            body: jsonEncode(answer.toJson()),
          ),
        );
      final _Background second = _Background(phone, first.media, restarted);
      phone.network.kind = NetworkKind.offline;

      final SyncEngine reopened = second.engine();
      await reopened.start();
      await eventually(() async => restarted.parts.isNotEmpty);

      expect(
        restarted.parts.map((HandedTask task) => task.taskId).toSet(),
        <String>{
          partTaskId(upload.uploadId, 1),
          partTaskId(upload.uploadId, 2),
        },
      );
    },
  );

  test('pause and wipe cancel queued uploads', () async {
    final _Background phone = await enrolled('Phone');
    final SyncEngine engine = phone.engine();
    await engine.start();
    await engine.syncNow();
    await _note(phone.device, 'waiting to go');
    phone.device.lifecycle.state = AppLifecycleState.hidden;
    await eventually(() async => phone.uploader.pushes.isNotEmpty);
    phone.device.lifecycle.state = AppLifecycleState.resumed;
    await phone.media.store.putBytes(
      bytes: _bytes(1500, 9),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    await eventually(() async => phone.uploader.parts.length == 2);
    final Set<String> queued = phone.uploader.held.keys.toSet();
    expect(queued, hasLength(3));

    await engine.pause(true);

    expect(phone.uploader.held, isEmpty);
    expect(phone.uploader.cancelled.toSet(), containsAll(queued));

    await engine.pause(false);
    await eventually(
      () async =>
          phone.uploader.held.values
              .where((HandedTask task) => task.group == mediaPartGroup)
              .length ==
          2,
    );
    final Set<String> handedAgain = phone.uploader.held.keys.toSet();
    await LocalJournalWipe(
      database: phone.device.database,
      keyStore: phone.device.keyStore,
      deleteAll: JournalDeleteAllService(
        database: phone.device.database,
        mediaRoot: phone.media.root,
      ),
      cancelUploads: phone.uploads.cancelAll,
    ).wipe();

    expect(phone.uploader.held, isEmpty);
    expect(phone.uploader.cancelled.toSet(), containsAll(handedAgain));
    expect(await phone.pushRoot.exists(), isFalse);
  });

  test('after leaving the app sends nothing itself', () async {
    final _Background phone = await enrolled('Phone');
    final SyncEngine engine = phone.engine();
    await engine.start();
    await engine.syncNow();
    await eventually(() async => engine.isLive);
    await _note(phone.device, 'saved just before leaving');

    phone.device.lifecycle.state = AppLifecycleState.hidden;
    await eventually(() async => !engine.isLive);
    await eventually(() async => phone.uploader.pushes.isNotEmpty);
    final int sentWhenHidden = phone.device.http.sent.length;
    await phone.media.store.putBytes(
      bytes: _bytes(1500, 10),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    await eventually(() async => phone.uploader.parts.length == 2);
    await phone.device.clock.advance(const Duration(minutes: 10));
    await engine.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(phone.device.http.sent.length, sentWhenHidden);
    expect(phone.device.sockets, 1);
    expect(phone.uploader.pushes, hasLength(1));
  });
}
