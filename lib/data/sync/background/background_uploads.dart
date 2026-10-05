import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/engine/push_cycle.dart';
import 'package:field_notes/data/sync/engine/relay_rebase.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:path/path.dart' as p;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

const String mediaPartGroup = 'field_notes_media';
const String recordPushGroup = 'field_notes_records';
const String mediaNotificationGroup = 'field_notes_media_uploads';
const String pushWorkSubdir = 'sync_pushes';
const int backgroundTaskRetries = 10;
const int maxUserInitiatedJobs = 100;
const int userInitiatedPriority = 0;
const int ordinaryPriority = 5;
const int maxUploadsAtOncePerRelay = 2;
const String mediaNotificationTitle = 'Uploading to your journal';
const String mediaNotificationBody = '{progress}';
const String mediaNotificationBodyWaitingForWiFi =
    '{progress} · waits for Wi-Fi if you leave';
const String _partPrefix = 'part';
const String _pushPrefix = 'push';
const String _jsonMime = 'application/json';
const String _binaryMime = 'application/octet-stream';
const String _blobIdField = 'blobId';
const String _uploadIdField = 'uploadId';
const String _indexField = 'index';
const String _fileField = 'file';
const String _changeIdsField = 'changeIds';
const String _tagField = 'tag';

Directory pushWorkRoot(Directory mediaRoot) =>
    Directory(p.join(p.dirname(mediaRoot.path), pushWorkSubdir));

String partTaskId(String uploadId, int index) =>
    '$_partPrefix.$uploadId.$index';

String pushTaskId(String id) => '$_pushPrefix.$id';

bool isPartTask(Task task) => task.group == mediaPartGroup;

bool isPushTask(Task task) => task.group == recordPushGroup;

RelayTag? _tagOf(Map<String, Object?> json) {
  final Object? tag = json[_tagField];
  if (tag is! Map<String, Object?>) {
    return null;
  }
  try {
    return RelayTag.fromJson(tag);
  } on FormatException {
    return null;
  }
}

final class PartTaskInfo {
  const PartTaskInfo({
    required this.blobId,
    required this.uploadId,
    required this.index,
    required this.tag,
  });

  static PartTaskInfo? of(Task task) {
    final Map<String, Object?> json = _metaData(task);
    final Object? blobId = json[_blobIdField];
    final Object? uploadId = json[_uploadIdField];
    final Object? index = json[_indexField];
    if (blobId is! String || uploadId is! String || index is! int) {
      return null;
    }
    return PartTaskInfo(
      blobId: blobId,
      uploadId: uploadId,
      index: index,
      tag: _tagOf(json),
    );
  }

  final String blobId;
  final String uploadId;
  final int index;
  final RelayTag? tag;
}

final class PushTaskInfo {
  PushTaskInfo({
    required this.filePath,
    required List<String> changeIds,
    required this.tag,
  }) : changeIds = List<String>.unmodifiable(changeIds);

  static PushTaskInfo? of(Task task) {
    final Map<String, Object?> json = _metaData(task);
    final Object? file = json[_fileField];
    final Object? changeIds = json[_changeIdsField];
    if (file is! String ||
        changeIds is! List<Object?> ||
        changeIds.any((Object? id) => id is! String)) {
      return null;
    }
    return PushTaskInfo(
      filePath: file,
      changeIds: changeIds.cast<String>(),
      tag: _tagOf(json),
    );
  }

  final String filePath;
  final List<String> changeIds;
  final RelayTag? tag;
}

Map<String, Object?> _metaData(Task task) {
  try {
    return decodeJsonObject(task.metaData);
  } on FormatException {
    return const <String, Object?>{};
  }
}

abstract interface class BackgroundUploader {
  Future<void> start(void Function(TaskStatusUpdate update) onUpdate);

  Future<bool> enqueue(UploadTask task);

  Future<List<Task>> queuedTasks();

  Future<void> cancel(Iterable<String> taskIds);
}

final class PackageBackgroundUploader implements BackgroundUploader {
  PackageBackgroundUploader([FileDownloader? downloader])
    : _downloader = downloader ?? FileDownloader();

  final FileDownloader _downloader;

  @override
  Future<void> start(void Function(TaskStatusUpdate update) onUpdate) async {
    _downloader
      ..registerCallbacks(group: mediaPartGroup, taskStatusCallback: onUpdate)
      ..registerCallbacks(group: recordPushGroup, taskStatusCallback: onUpdate);
    await _downloader.configure(
      androidConfig: <(String, Object)>[
        (Config.runInForeground, Config.always),
        (Config.holdingQueue, (null, maxUploadsAtOncePerRelay, null)),
      ],
    );
    await _downloader.start();
  }

  @override
  Future<bool> enqueue(UploadTask task) => _downloader.enqueue(task);

  @override
  Future<List<Task>> queuedTasks() => _downloader.allTasks(allGroups: true);

  @override
  Future<void> cancel(Iterable<String> taskIds) async {
    await _downloader.cancelTasksWithIds(taskIds);
  }
}

final class BackgroundUploads implements UploadSender {
  BackgroundUploads({
    required AppDatabase database,
    required this._uploader,
    required this._keyStore,
    required this._uploads,
    required this._isVisible,
    required this._pushRoot,
    required this._allowMobileData,
    Random? random,
  }) : _db = database,
       _random = random ?? Random.secure();

  final AppDatabase _db;
  final BackgroundUploader _uploader;
  final KeyStore _keyStore;
  final UploadQueue _uploads;
  final bool Function() _isVisible;
  final Directory _pushRoot;
  final Future<bool> Function() _allowMobileData;
  final Random _random;
  bool _paused = false;

  bool get _visible => _isVisible();

  Future<void> pause() async {
    _paused = true;
    await cancelAll();
  }

  void resume() {
    _paused = false;
  }

  @override
  Future<void> sendParts(
    PendingUpload upload,
    List<int> indexes,
    UploadAnswer onAnswer,
  ) async {
    final _Credentials? credentials = await _credentials();
    if (credentials == null) {
      return;
    }
    final List<Task> queued = await _uploader.queuedTasks();
    final Set<String> held = <String>{
      for (final Task task in queued) task.taskId,
    };
    int userInitiated = queued
        .where(
          (Task task) =>
              isPartTask(task) && task.priority == userInitiatedPriority,
        )
        .length;
    final bool allowMobileData = await _allowMobileData();
    for (final int index in indexes) {
      if (_paused) {
        return;
      }
      if (held.contains(partTaskId(upload.uploadId, index))) {
        continue;
      }
      final bool asUserInitiated =
          _visible && userInitiated < maxUserInitiatedJobs;
      final bool enqueued = await _uploader.enqueue(
        _partTask(
          upload,
          index,
          credentials: credentials,
          userInitiated: asUserInitiated,
          allowMobileData: allowMobileData,
        ),
      );
      if (enqueued && asUserInitiated) {
        userInitiated += 1;
      }
    }
  }

  Future<void> handOverPrepared({Iterable<String>? blobIds}) async {
    final Set<String>? only = blobIds?.toSet();
    for (final PendingUpload upload in await _uploads.pendingUploads()) {
      if (only != null && !only.contains(upload.blobId)) {
        continue;
      }
      await sendParts(upload, upload.missingParts, _ignoreAnswer);
    }
  }

  Future<int> handOverPushes(
    PushCycle push, {
    Set<int> excluding = const <int>{},
  }) async {
    final _Credentials? credentials = await _credentials();
    if (credentials == null) {
      return 0;
    }
    final Set<String> heldChangeIds = <String>{
      for (final Task task in await _uploader.queuedTasks())
        if (isPushTask(task)) ...?PushTaskInfo.of(task)?.changeIds,
    };
    final Set<int> skipped = <int>{
      ...excluding,
      for (final SyncOutboxData row in await _db.select(_db.syncOutbox).get())
        if (row.changeId != null && heldChangeIds.contains(row.changeId))
          row.id,
    };
    int handed = 0;
    await _pushRoot.create(recursive: true);
    while (true) {
      final PushBatch? batch = await push.buildBatch(excluding: skipped);
      if (batch == null || _paused) {
        return handed;
      }
      skipped.addAll(batch.outboxIds);
      final String id = newSyncId(_random);
      final File file = File(p.join(_pushRoot.path, '$id.json'));
      await file.writeAsString(jsonEncode(batch.request.toJson()), flush: true);
      if (_paused) {
        await file.delete();
        return handed;
      }
      if (await _uploader.enqueue(
        _pushTask(id, file, batch.request, credentials: credentials),
      )) {
        handed += 1;
      }
    }
  }

  Future<void> cancelAll() async {
    final List<Task> queued = await _uploader.queuedTasks();
    await _uploader.cancel(<String>[
      for (final Task task in queued)
        if (isPartTask(task) || isPushTask(task)) task.taskId,
    ]);
    try {
      if (await _pushRoot.exists()) {
        await _pushRoot.delete(recursive: true);
      }
    } on FileSystemException {
      return;
    }
  }

  Future<void> rescheduleForNetworkRule() async {
    final bool allowMobileData = await _allowMobileData();
    final Set<String> posters = await posterMediaIds(_db);
    final List<String> stale = <String>[];
    final Set<String> blobs = <String>{};
    for (final Task task in await _uploader.queuedTasks()) {
      final PartTaskInfo? info = isPartTask(task)
          ? PartTaskInfo.of(task)
          : null;
      if (info == null) {
        continue;
      }
      final bool wanted = _requiresWiFi(
        isPoster: posters.contains(info.blobId),
        allowMobileData: allowMobileData,
      );
      if (task.requiresWiFi != wanted) {
        stale.add(task.taskId);
        blobs.add(info.blobId);
      }
    }
    if (stale.isEmpty) {
      return;
    }
    await _uploader.cancel(stale);
    await handOverPrepared(blobIds: blobs);
  }

  UploadTask _partTask(
    PendingUpload upload,
    int index, {
    required _Credentials credentials,
    required bool userInitiated,
    required bool allowMobileData,
  }) {
    final bool requiresWiFi = _requiresWiFi(
      isPoster: upload.isPoster,
      allowMobileData: allowMobileData,
    );
    return UploadTask.fromFile(
      file: upload.partFile(index),
      taskId: partTaskId(upload.uploadId, index),
      url: SyncRoutes.uploadPart
          .uri(
            credentials.baseUrl,
            parameters: <String, Object>{
              SyncRoutes.nameParameter: upload.blobName,
              SyncRoutes.uploadIdParameter: upload.uploadId,
              SyncRoutes.indexParameter: index,
            },
          )
          .toString(),
      headers: <String, String>{
        ...credentials.headers,
        SyncHeaders.blobSize: '${upload.totalBytes}',
        SyncHeaders.partSize: '${upload.partBytes}',
      },
      httpRequestMethod: SyncRoutes.uploadPart.method,
      post: 'binary',
      mimeType: _binaryMime,
      group: mediaPartGroup,
      updates: Updates.statusAndProgress,
      requiresWiFi: requiresWiFi,
      retries: backgroundTaskRetries,
      priority: userInitiated ? userInitiatedPriority : ordinaryPriority,
      metaData: jsonEncode(<String, Object?>{
        _blobIdField: upload.blobId,
        _uploadIdField: upload.uploadId,
        _indexField: index,
        _tagField: credentials.tag.toJson(),
      }),
      notificationConfig: TaskNotificationConfig(
        running: TaskNotification(
          mediaNotificationTitle,
          requiresWiFi
              ? mediaNotificationBodyWaitingForWiFi
              : mediaNotificationBody,
        ),
        progressBar: true,
        groupNotificationId: mediaNotificationGroup,
      ),
    );
  }

  UploadTask _pushTask(
    String id,
    File file,
    PushRequest request, {
    required _Credentials credentials,
  }) => UploadTask.fromFile(
    file: file,
    taskId: pushTaskId(id),
    url: SyncRoutes.pushRecords.uri(credentials.baseUrl).toString(),
    headers: credentials.headers,
    httpRequestMethod: SyncRoutes.pushRecords.method,
    post: 'binary',
    mimeType: _jsonMime,
    group: recordPushGroup,
    requiresWiFi: false,
    retries: backgroundTaskRetries,
    priority: ordinaryPriority,
    metaData: jsonEncode(<String, Object?>{
      _fileField: file.path,
      _changeIdsField: <String>[
        for (final RecordPush change in request.changes) change.changeId,
      ],
      _tagField: credentials.tag.toJson(),
    }),
  );

  bool _requiresWiFi({required bool isPoster, required bool allowMobileData}) =>
      NetworkPolicy(
        allowMobileDataForMedia: allowMobileData,
      ).requiresWiFi(isPoster ? TransferKind.poster : TransferKind.fullMedia);

  Future<_Credentials?> _credentials() async {
    final String? address = await readSyncState(_db, SyncStateKeys.relayUrl);
    final UploadPass? pass = await _keyStore.readUploadPass();
    if (address == null ||
        pass == null ||
        !pass.isValidAt(DateTime.now().toUtc())) {
      return null;
    }
    return _Credentials(
      baseUrl: Uri.parse(address),
      pass: pass,
      tag: await readRelayTag(_db),
    );
  }

  static Future<void> _ignoreAnswer(UploadStatusResponse _) =>
      Future<void>.value();
}

final class _Credentials {
  const _Credentials({
    required this.baseUrl,
    required this.pass,
    required this.tag,
  });

  final Uri baseUrl;
  final UploadPass pass;
  final RelayTag tag;

  Map<String, String> get headers => <String, String>{
    SyncHeaders.protocol: '$syncProtocolVersion',
    SyncHeaders.authorization: AuthCredential(
      AuthScheme.uploadPass,
      pass.token,
    ).authorization,
  };
}
