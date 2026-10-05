import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:field_notes/data/sync/background/upload_result_applier.dart';
import 'package:field_notes/data/sync/engine/sync_engine.dart';
import 'package:field_notes/domain/models/models.dart' as domain;
import 'package:flutter_test/flutter_test.dart';

import '../../../support/sync_overrides.dart';
import '../../../sync/support/relay_fixture.dart';

final class _GatedUploader implements BackgroundUploader {
  final Map<String, HandedTask> held = <String, HandedTask>{};
  final List<HandedTask> enqueued = <HandedTask>[];
  Completer<void>? gate;
  bool waiting = false;

  @override
  Future<void> start(void Function(HandedResult result) onResult) async {}

  @override
  Future<void> enqueue(List<HandedTask> tasks) async {
    for (final HandedTask task in tasks) {
      enqueued.add(task);
      held[task.taskId] = task;
    }
  }

  @override
  Future<List<HandedTask>> queuedTasks() async {
    final Completer<void>? closed = gate;
    if (closed != null) {
      gate = null;
      waiting = true;
      await closed.future;
    }
    return held.values.toList();
  }

  @override
  Future<void> cancel(Iterable<String> taskIds) async {
    for (final String id in taskIds) {
      held.remove(id);
    }
  }
}

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (int index) => (index * 31 + seed) % 251);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RelayFixture relay;
  late SyncTestDevice phone;

  setUp(() async {
    relay = await RelayFixture.start(rateBurst: 1000);
    phone = await enrolDevice(relay, SyncTestDevice('Phone'));
  });

  tearDown(() async {
    await phone.dispose();
    await relay.dispose();
  });

  test('pausing sync queues nothing a hand-over had in flight', () async {
    final SyncTestMedia media = await SyncTestMedia.create(phone);
    final _GatedUploader uploader = _GatedUploader();
    final BackgroundUploads uploads = BackgroundUploads(
      database: phone.database,
      uploader: uploader,
      keyStore: phone.keyStore,
      uploads: media.uploads,
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
    final SyncEngine engine = phone.engine(
      media: media.source(),
      background: () async => transfer,
    );
    await engine.start();
    await engine.syncNow();
    await eventually(() async => engine.isLive);
    final Completer<void> gate = Completer<void>();
    uploader.gate = gate;

    await media.store.putBytes(
      bytes: _bytes(1500, 1),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    await eventually(() async => uploader.waiting);
    await engine.pause(true);
    gate.complete();
    await pumpEventQueue();

    expect(uploader.enqueued, isEmpty);
    expect(uploader.held, isEmpty);

    await engine.pause(false);
    await eventually(() async => uploader.held.length == 2);
  });

  test('a wipe queues nothing a hand-over had in flight', () async {
    final SyncTestMedia media = await SyncTestMedia.create(phone);
    final _GatedUploader uploader = _GatedUploader();
    final BackgroundUploads uploads = BackgroundUploads(
      database: phone.database,
      uploader: uploader,
      keyStore: phone.keyStore,
      uploads: media.uploads,
      pushRoot: pushWorkRoot(media.root),
      allowMobileData: () async => false,
    );
    await media.store.putBytes(
      bytes: _bytes(1500, 2),
      mime: 'video/mp4',
      kind: domain.MediaKind.video,
    );
    await media.uploads.prepareAll();
    await phone.keyStore.writeUploadPass(
      UploadPass(
        token: 'pass',
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      ),
    );
    final Completer<void> gate = Completer<void>();
    uploader.gate = gate;

    final Future<void> handOver = uploads.handOverPrepared();
    await eventually(() async => uploader.waiting);
    final Future<void> wipe = uploads.cancelAll();
    gate.complete();
    await Future.wait(<Future<void>>[handOver, wipe]);

    expect(uploader.enqueued, isEmpty);
    expect(uploader.held, isEmpty);

    await uploads.handOverPrepared();
    expect(uploader.held, hasLength(2));
  });
}
