import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/background/background_uploads.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/engine/push_cycle.dart';
import 'package:field_notes/data/sync/engine/relay_rebase.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

final class UploadResultApplier {
  UploadResultApplier({
    required AppDatabase database,
    required this._uploader,
    required this._uploads,
    required this._background,
  }) : _db = database;

  final AppDatabase _db;
  final BackgroundUploader _uploader;
  final UploadQueue _uploads;
  final BackgroundUploads _background;
  final List<TaskStatusUpdate> _finished = <TaskStatusUpdate>[];
  final List<File> _resend = <File>[];
  final StreamController<void> _arrivals = StreamController<void>.broadcast();
  Future<void>? _started;

  Stream<void> get arrivals => _arrivals.stream;

  bool get hasPending => _finished.isNotEmpty || _resend.isNotEmpty;

  Future<void> start() => _started ??= _uploader.start(_collect);

  Future<void> applyPending({
    required PushCycle push,
    RelayClient? client,
    FenceCheck isCurrent = alwaysCurrent,
  }) async {
    await start();
    final List<TaskStatusUpdate> finished = List<TaskStatusUpdate>.of(
      _finished,
    );
    _finished.clear();
    final Set<String> failedBlobs = <String>{};
    for (final TaskStatusUpdate update in finished) {
      if (!isCurrent()) {
        return;
      }
      if (isPushTask(update.task)) {
        await _applyPush(update, push, isCurrent);
      } else if (isPartTask(update.task)) {
        final String? failed = await _applyPart(update, isCurrent);
        if (failed != null) {
          failedBlobs.add(failed);
        }
      }
    }
    if (client != null) {
      await _resendPushes(client, push, isCurrent);
    }
    if (failedBlobs.isEmpty || !isCurrent()) {
      return;
    }
    await _handOverAgain(failedBlobs, client, isCurrent);
  }

  void _collect(TaskStatusUpdate update) {
    if (!update.status.isFinalState) {
      return;
    }
    _finished.add(update);
    if (!_arrivals.isClosed) {
      _arrivals.add(null);
    }
  }

  Future<void> _applyPush(
    TaskStatusUpdate update,
    PushCycle push,
    FenceCheck isCurrent,
  ) async {
    final PushTaskInfo? info = PushTaskInfo.of(update.task);
    if (info == null) {
      return;
    }
    final File file = File(info.filePath);
    final PushRequest? request = await _readRequest(file);
    if (request == null) {
      return;
    }
    if (update.status != TaskStatus.complete || !await _admits(info.tag)) {
      await _delete(file);
      return;
    }
    final PushResponse? response = _decode(
      update.responseBody,
      PushResponse.fromJson,
    );
    if (response == null) {
      _resend.add(file);
      return;
    }
    if (isCurrent()) {
      await push.applyResponse(request, response, isCurrent: isCurrent);
    }
    await _delete(file);
  }

  Future<String?> _applyPart(
    TaskStatusUpdate update,
    FenceCheck isCurrent,
  ) async {
    final PartTaskInfo? info = PartTaskInfo.of(update.task);
    if (info == null) {
      return null;
    }
    final PendingUpload? upload = await _current(info);
    if (upload == null || !await _admits(info.tag)) {
      return null;
    }
    if (update.status != TaskStatus.complete) {
      return info.blobId;
    }
    final UploadStatusResponse? answer = _decode(
      update.responseBody,
      UploadStatusResponse.fromJson,
    );
    if (answer != null && isCurrent()) {
      await _uploads.recordAnswer(info.blobId, answer);
    }
    return null;
  }

  Future<void> _resendPushes(
    RelayClient client,
    PushCycle push,
    FenceCheck isCurrent,
  ) async {
    final List<File> files = List<File>.of(_resend);
    _resend.clear();
    for (final File file in files) {
      final PushRequest? request = await _readRequest(file);
      if (request == null) {
        continue;
      }
      if (!isCurrent()) {
        return;
      }
      final PushResponse response = await client.push(request);
      if (isCurrent()) {
        await push.applyResponse(request, response, isCurrent: isCurrent);
      }
      await _delete(file);
    }
  }

  Future<void> _handOverAgain(
    Set<String> blobIds,
    RelayClient? client,
    FenceCheck isCurrent,
  ) async {
    if (client == null) {
      await _background.handOverPrepared(blobIds: blobIds);
      return;
    }
    for (final PendingUpload upload in await _uploads.pendingUploads()) {
      if (!blobIds.contains(upload.blobId) || !isCurrent()) {
        continue;
      }
      await _uploads.sendOne(client, _background, upload, isCurrent: isCurrent);
    }
  }

  Future<bool> _admits(RelayTag? made) async =>
      made == null || (await readRelayTag(_db)).admits(made);

  Future<PendingUpload?> _current(PartTaskInfo info) async {
    for (final PendingUpload upload in await _uploads.pendingUploads()) {
      if (upload.blobId == info.blobId && upload.uploadId == info.uploadId) {
        return upload;
      }
    }
    return null;
  }

  static T? _decode<T>(
    String? body,
    T Function(Map<String, Object?> json) fromJson,
  ) {
    if (body == null || body.isEmpty) {
      return null;
    }
    try {
      return fromJson(decodeJsonObject(body));
    } on FormatException {
      return null;
    }
  }

  static Future<PushRequest?> _readRequest(File file) async {
    try {
      return PushRequest.fromJson(decodeJsonObject(await file.readAsString()));
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> _delete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      return;
    }
  }
}
