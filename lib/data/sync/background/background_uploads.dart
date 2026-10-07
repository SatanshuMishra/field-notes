import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/engine/push_cycle.dart';
import 'package:field_notes/data/sync/engine/relay_rebase.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

const String mediaPartGroup = 'field_notes_media';
const String recordPushGroup = 'field_notes_records';
const String backgroundUploadsChannel = 'field_notes/background_uploads';
const String pushWorkSubdir = 'sync_pushes';
const String mediaNotificationTitle = 'Uploading to your journal';
const String mediaNotificationBody = '{progress}';
const String mediaNotificationBodyWaitingForWiFi =
    '{progress} · waits for Wi-Fi if you leave';
const String mediaNotificationChannelName = 'Uploads';
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

bool isPartTask(HandedTask task) => task.group == mediaPartGroup;

bool isPushTask(HandedTask task) => task.group == recordPushGroup;

final class HandedTask {
  HandedTask({
    required this.taskId,
    required this.group,
    required this.url,
    required this.method,
    required Map<String, String> headers,
    required this.filePath,
    required this.mimeType,
    required this.requiresWiFi,
    required this.metaData,
  }) : headers = Map<String, String>.unmodifiable(headers);

  factory HandedTask.fromJson(Map<String, Object?> json) {
    final Object? headers = json[_headersKey];
    return HandedTask(
      taskId: _string(json, _taskIdKey),
      group: _string(json, _groupKey),
      url: _string(json, _urlKey),
      method: _string(json, _methodKey),
      headers: <String, String>{
        if (headers is Map<String, Object?>)
          for (final MapEntry<String, Object?> entry in headers.entries)
            if (entry.value is String) entry.key: entry.value! as String,
      },
      filePath: _string(json, _fileKey),
      mimeType: _string(json, _mimeTypeKey),
      requiresWiFi: _boolean(json, _requiresWiFiKey),
      metaData: _string(json, _metaDataKey),
    );
  }

  static const String _taskIdKey = 'taskId';
  static const String _groupKey = 'group';
  static const String _urlKey = 'url';
  static const String _methodKey = 'method';
  static const String _headersKey = 'headers';
  static const String _fileKey = 'file';
  static const String _mimeTypeKey = 'mimeType';
  static const String _requiresWiFiKey = 'requiresWiFi';
  static const String _metaDataKey = 'metaData';

  final String taskId;
  final String group;
  final String url;
  final String method;
  final Map<String, String> headers;
  final String filePath;
  final String mimeType;
  final bool requiresWiFi;
  final String metaData;

  Map<String, Object?> toJson() => <String, Object?>{
    _taskIdKey: taskId,
    _groupKey: group,
    _urlKey: url,
    _methodKey: method,
    _headersKey: headers,
    _fileKey: filePath,
    _mimeTypeKey: mimeType,
    _requiresWiFiKey: requiresWiFi,
    _metaDataKey: metaData,
  };
}

enum HandedStatus { complete, failed }

final class HandedResult {
  const HandedResult(this.task, this.status, {this.statusCode, this.body});

  factory HandedResult.fromJson(Map<String, Object?> json) {
    final Object? task = json['task'];
    if (task is! Map<String, Object?>) {
      throw const FormatException('A handed result has no task');
    }
    final Object? statusCode = json['statusCode'];
    final Object? body = json['body'];
    return HandedResult(
      HandedTask.fromJson(task),
      _string(json, 'status') == HandedStatus.complete.name
          ? HandedStatus.complete
          : HandedStatus.failed,
      statusCode: statusCode is int ? statusCode : null,
      body: body is String ? body : null,
    );
  }

  final HandedTask task;
  final HandedStatus status;
  final int? statusCode;
  final String? body;
}

String _string(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is String) {
    return value;
  }
  throw FormatException('Invalid $key');
}

bool _boolean(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Invalid $key');
}

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

  static PartTaskInfo? of(HandedTask task) {
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

  static PushTaskInfo? of(HandedTask task) {
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

Map<String, Object?> _metaData(HandedTask task) {
  try {
    return decodeJsonObject(task.metaData);
  } on FormatException {
    return const <String, Object?>{};
  }
}

abstract interface class BackgroundUploader {
  Future<void> start(void Function(HandedResult result) onResult);

  Future<void> enqueue(List<HandedTask> tasks);

  Future<List<HandedTask>> queuedTasks();

  Future<void> cancel(Iterable<String> taskIds);

  Future<void> cancelAll();
}

final class ChannelBackgroundUploader implements BackgroundUploader {
  ChannelBackgroundUploader([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(backgroundUploadsChannel);

  final MethodChannel _channel;
  void Function(HandedResult result)? _onResult;

  @override
  Future<void> start(void Function(HandedResult result) onResult) async {
    _onResult = onResult;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == _resultsReady) {
        await _takeResults();
      }
    });
    await _invoke<void>(_start, <String, String>{
      'title': mediaNotificationTitle,
      'body': mediaNotificationBody,
      'bodyWaitingForWiFi': mediaNotificationBodyWaitingForWiFi,
      'channelName': mediaNotificationChannelName,
    });
    await _takeResults();
  }

  @override
  Future<void> enqueue(List<HandedTask> tasks) async {
    if (tasks.isEmpty) {
      return;
    }
    await _invoke<bool>(_enqueue, <String, Object>{
      'tasks': <String>[
        for (final HandedTask task in tasks) jsonEncode(task.toJson()),
      ],
    });
  }

  @override
  Future<List<HandedTask>> queuedTasks() async {
    final List<String> encoded = await _invokeList(_queued);
    return <HandedTask>[for (final String task in encoded) ?_decodeTask(task)];
  }

  @override
  Future<void> cancel(Iterable<String> taskIds) async {
    final List<String> ids = taskIds.toList();
    if (ids.isEmpty) {
      return;
    }
    await _invoke<void>(_cancel, <String, Object>{'taskIds': ids});
  }

  @override
  Future<void> cancelAll() => _invoke<void>(_cancelAll);

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw FileSystemException(
        'Background uploads refused $method: ${error.message ?? error.code}',
      );
    }
  }

  Future<List<String>> _invokeList(String method) async {
    try {
      return await _channel.invokeListMethod<String>(method) ??
          const <String>[];
    } on PlatformException catch (error) {
      throw FileSystemException(
        'Background uploads refused $method: ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _takeResults() async {
    final void Function(HandedResult result)? onResult = _onResult;
    while (true) {
      final List<String> encoded = await _invokeList(_take);
      if (encoded.isEmpty) {
        return;
      }
      for (final String result in encoded) {
        final HandedResult? decoded = _decodeResult(result);
        if (decoded != null) {
          onResult?.call(decoded);
        }
      }
    }
  }

  static HandedTask? _decodeTask(String source) {
    try {
      return HandedTask.fromJson(decodeJsonObject(source));
    } on FormatException {
      return null;
    }
  }

  static HandedResult? _decodeResult(String source) {
    try {
      return HandedResult.fromJson(decodeJsonObject(source));
    } on FormatException {
      return null;
    }
  }

  static const String _start = 'start';
  static const String _enqueue = 'enqueue';
  static const String _queued = 'queued';
  static const String _cancel = 'cancel';
  static const String _cancelAll = 'cancelAll';
  static const String _take = 'takeResults';
  static const String _resultsReady = 'resultsReady';
}

final class BackgroundUploads implements UploadSender {
  BackgroundUploads({
    required AppDatabase database,
    required this._uploader,
    required this._keyStore,
    required this._uploads,
    required this._pushRoot,
    required this._allowMobileData,
    Random? random,
  }) : _db = database,
       _random = random ?? Random.secure();

  final AppDatabase _db;
  final BackgroundUploader _uploader;
  final KeyStore _keyStore;
  final UploadQueue _uploads;
  final Directory _pushRoot;
  final Future<bool> Function() _allowMobileData;
  final Random _random;
  bool _paused = false;
  int _generation = 0;

  bool _fenced(int generation) => _paused || generation != _generation;

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
  ) => _sendParts(upload, indexes, _generation);

  @override
  Future<bool> holdsAll(PendingUpload upload) async {
    final List<int> missing = upload.missingParts;
    if (missing.isEmpty) {
      return false;
    }
    final Set<String> held = <String>{
      for (final HandedTask task in await _uploader.queuedTasks()) task.taskId,
    };
    return missing.every(
      (int index) => held.contains(partTaskId(upload.uploadId, index)),
    );
  }

  Future<void> _sendParts(
    PendingUpload upload,
    List<int> indexes,
    int generation,
  ) async {
    final _Credentials? credentials = await _credentials();
    if (credentials == null) {
      return;
    }
    final Set<String> held = <String>{
      for (final HandedTask task in await _uploader.queuedTasks()) task.taskId,
    };
    final bool allowMobileData = await _allowMobileData();
    final List<HandedTask> tasks = <HandedTask>[
      for (final int index in indexes)
        if (!held.contains(partTaskId(upload.uploadId, index)))
          _partTask(
            upload,
            index,
            credentials: credentials,
            allowMobileData: allowMobileData,
          ),
    ];
    if (_fenced(generation)) {
      return;
    }
    await _uploader.enqueue(tasks);
  }

  Future<void> handOverPrepared({Iterable<String>? blobIds}) async {
    final int generation = _generation;
    final Set<String>? only = blobIds?.toSet();
    for (final PendingUpload upload in await _uploads.pendingUploads()) {
      if (_fenced(generation)) {
        return;
      }
      if (only != null && !only.contains(upload.blobId)) {
        continue;
      }
      await _sendParts(upload, upload.missingParts, generation);
    }
  }

  Future<int> handOverPushes(
    PushCycle push, {
    Set<int> excluding = const <int>{},
  }) async {
    final int generation = _generation;
    final _Credentials? credentials = await _credentials();
    if (credentials == null) {
      return 0;
    }
    final Set<String> heldChangeIds = <String>{
      for (final HandedTask task in await _uploader.queuedTasks())
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
      if (batch == null || _fenced(generation)) {
        return handed;
      }
      skipped.addAll(batch.outboxIds);
      final String id = newSyncId(_random);
      final File file = File(p.join(_pushRoot.path, '$id.json'));
      await file.writeAsString(jsonEncode(batch.request.toJson()), flush: true);
      if (_fenced(generation)) {
        await file.delete();
        return handed;
      }
      await _uploader.enqueue(<HandedTask>[
        _pushTask(id, file, batch.request, credentials: credentials),
      ]);
      handed += 1;
    }
  }

  Future<void> cancelAll() async {
    _generation += 1;
    await _uploader.cancelAll();
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
    for (final HandedTask task in await _uploader.queuedTasks()) {
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

  HandedTask _partTask(
    PendingUpload upload,
    int index, {
    required _Credentials credentials,
    required bool allowMobileData,
  }) => HandedTask(
    taskId: partTaskId(upload.uploadId, index),
    group: mediaPartGroup,
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
    method: SyncRoutes.uploadPart.method,
    headers: <String, String>{
      ...credentials.headers,
      SyncHeaders.blobSize: '${upload.totalBytes}',
      SyncHeaders.partSize: '${upload.partBytes}',
    },
    filePath: upload.partFile(index).path,
    mimeType: _binaryMime,
    requiresWiFi: _requiresWiFi(
      isPoster: upload.isPoster,
      allowMobileData: allowMobileData,
    ),
    metaData: jsonEncode(<String, Object?>{
      _blobIdField: upload.blobId,
      _uploadIdField: upload.uploadId,
      _indexField: index,
      _tagField: credentials.tag.toJson(),
    }),
  );

  HandedTask _pushTask(
    String id,
    File file,
    PushRequest request, {
    required _Credentials credentials,
  }) => HandedTask(
    taskId: pushTaskId(id),
    group: recordPushGroup,
    url: SyncRoutes.pushRecords.uri(credentials.baseUrl).toString(),
    method: SyncRoutes.pushRecords.method,
    headers: credentials.headers,
    filePath: file.path,
    mimeType: _jsonMime,
    requiresWiFi: false,
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
