import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/file_cipher.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/device_storage.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/models/media_blob.dart' as domain;
import 'package:path/path.dart' as p;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

const int uploadPartBytes = 8 * 1024 * 1024;
const String preparedUploadStatus = 'prepared';
const String uploadWorkSubdir = 'sync_uploads';
const Duration firstPrepareRetry = Duration(minutes: 1);
const Duration maxPrepareRetry = Duration(hours: 1);

DateTime _systemNow() => DateTime.now().toUtc();

final class _Deferral {
  const _Deferral({
    required this.until,
    required this.attempts,
    required this.forSpace,
    required this.measured,
  });

  final DateTime until;
  final int attempts;
  final bool forSpace;
  final bool measured;
}

final class _PartWriter {
  _PartWriter(this._dir, this._partBytes);

  final Directory _dir;
  final int _partBytes;
  RandomAccessFile? _open;
  int _parts = 0;
  int _inPart = 0;
  int written = 0;

  Future<void> add(Uint8List bytes) async {
    int offset = 0;
    while (offset < bytes.length) {
      final RandomAccessFile part = _open ??= await _next();
      final int take = min(_partBytes - _inPart, bytes.length - offset);
      await part.writeFrom(bytes, offset, offset + take);
      offset += take;
      _inPart += take;
      written += take;
      if (_inPart == _partBytes) {
        await _finishPart();
      }
    }
  }

  Future<int> close() async {
    await _finishPart();
    return _parts;
  }

  Future<void> abandon() async {
    await _open?.close();
    _open = null;
  }

  Future<RandomAccessFile> _next() async {
    final RandomAccessFile part = await File(p.join(_dir.path, '$_parts'))
        .open(mode: FileMode.write);
    _parts += 1;
    _inPart = 0;
    return part;
  }

  Future<void> _finishPart() async {
    final RandomAccessFile? part = _open;
    if (part == null) {
      return;
    }
    _open = null;
    try {
      await part.flush();
    } finally {
      await part.close();
    }
  }
}

Directory uploadWorkRoot(Directory mediaRoot) =>
    Directory(p.join(p.dirname(mediaRoot.path), uploadWorkSubdir));

List<int> decodeAckedParts(String encoded) {
  final Object? decoded = jsonDecode(encoded);
  if (decoded is! List<Object?> ||
      decoded.any((Object? part) => part is! int)) {
    return const <int>[];
  }
  return List<int>.unmodifiable(decoded.cast<int>().toSet().toList()..sort());
}

String encodeAckedParts(Iterable<int> parts) =>
    jsonEncode(parts.toSet().toList()..sort());

Future<Set<String>> posterMediaIds(AppDatabase database) async {
  final List<MediaBlob> withPosters = await (database.select(
    database.mediaBlobs,
  )..where((t) => t.posterId.isNotNull())).get();
  final List<Entry> withThumbnails = await (database.select(
    database.entries,
  )..where((t) => t.thumbnailMediaId.isNotNull())).get();
  return Set<String>.unmodifiable(<String>{
    for (final MediaBlob blob in withPosters) ?blob.posterId,
    for (final Entry entry in withThumbnails) ?entry.thumbnailMediaId,
  });
}

Future<void> markBlobUploaded(AppDatabase database, String blobId) => database
    .into(database.syncMediaCache)
    .insert(
      SyncMediaCacheCompanion.insert(
        blobId: blobId,
        uploaded: const Value(true),
      ),
      onConflict: DoUpdate(
        (_) => const SyncMediaCacheCompanion(uploaded: Value(true)),
      ),
    );

final class PendingUpload {
  PendingUpload({
    required this.blobId,
    required this.blobName,
    required this.uploadId,
    required this.totalBytes,
    required this.partCount,
    required this.partBytes,
    required List<int> ackedParts,
    required this.partsDir,
    required this.isPoster,
  }) : ackedParts = List<int>.unmodifiable(ackedParts);

  factory PendingUpload.fromRow(
    SyncUpload row, {
    required bool isPoster,
    required int partBytes,
  }) => PendingUpload(
    blobId: row.blobId,
    blobName: row.blobName,
    uploadId: row.uploadId,
    totalBytes: row.totalBytes,
    partCount: row.partCount,
    partBytes: row.partCount <= 1 ? row.totalBytes : partBytes,
    ackedParts: decodeAckedParts(row.ackedParts),
    partsDir: row.partsDir ?? '',
    isPoster: isPoster,
  );

  final String blobId;
  final String blobName;
  final String uploadId;
  final int totalBytes;
  final int partCount;
  final int partBytes;
  final List<int> ackedParts;
  final String partsDir;
  final bool isPoster;

  List<int> get missingParts => <int>[
    for (int index = 0; index < partCount; index++)
      if (!ackedParts.contains(index)) index,
  ];

  int sizeOfPart(int index) => index == partCount - 1
      ? totalBytes - partBytes * (partCount - 1)
      : partBytes;

  File partFile(int index) => File(p.join(partsDir, '$index'));
}

typedef UploadAnswer = Future<void> Function(UploadStatusResponse answer);

abstract interface class UploadSender {
  Future<void> sendParts(
    PendingUpload upload,
    List<int> indexes,
    UploadAnswer onAnswer,
  );

  Future<bool> holdsAll(PendingUpload upload);
}

final class RelayUploadSender implements UploadSender {
  const RelayUploadSender(this._client);

  final RelayClient _client;

  @override
  Future<bool> holdsAll(PendingUpload upload) async => false;

  @override
  Future<void> sendParts(
    PendingUpload upload,
    List<int> indexes,
    UploadAnswer onAnswer,
  ) async {
    for (final int index in indexes) {
      final UploadStatusResponse answer = await _client.uploadPart(
        name: upload.blobName,
        uploadId: upload.uploadId,
        index: index,
        blobSize: upload.totalBytes,
        partSize: upload.partBytes,
        bytes: await upload.partFile(index).readAsBytes(),
      );
      await onAnswer(answer);
      if (answer.assembled) {
        return;
      }
    }
  }
}

final class UploadQueue {
  UploadQueue({
    required AppDatabase database,
    required this._store,
    required this._keys,
    required this._workRoot,
    this.partBytes = uploadPartBytes,
    this._storage = const UnmeasuredDeviceStorage(),
    DateTime Function()? now,
    Random? random,
  }) : _db = database,
       _now = now ?? _systemNow,
       _random = random ?? Random.secure();

  final AppDatabase _db;
  final FilesystemMediaStore _store;
  final JournalKeysSource _keys;
  final Directory _workRoot;
  final int partBytes;
  final DeviceStorage _storage;
  final DateTime Function() _now;
  final Random _random;
  final Map<String, _Deferral> _deferred = <String, _Deferral>{};
  Future<int>? _preparing;
  Future<void> _turn = Future<void>.value();

  bool get waitingForSpace =>
      _deferred.values.any((_Deferral deferral) => deferral.forSpace);

  Future<List<String>> unpreparedBlobIds() async {
    final List<MediaBlob> blobs =
        await (_db.select(_db.mediaBlobs)
              ..orderBy(<OrderClauseGenerator<$MediaBlobsTable>>[
                (t) => OrderingTerm.asc(t.bytes),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final Set<String> queued = <String>{
      for (final SyncUpload row in await _db.select(_db.syncUploads).get())
        row.blobId,
    };
    final Set<String> uploaded = <String>{
      for (final SyncMediaCacheData row in await (_db.select(
        _db.syncMediaCache,
      )..where((t) => t.uploaded.equals(true))).get())
        row.blobId,
    };
    final List<String> ids = <String>[];
    for (final MediaBlob blob in blobs) {
      if (queued.contains(blob.id) || uploaded.contains(blob.id)) {
        continue;
      }
      if (await _localFile(blob.id) != null) {
        ids.add(blob.id);
      }
    }
    return List<String>.unmodifiable(ids);
  }

  Future<int> prepareAll() =>
      _preparing ??= _prepareAll().whenComplete(() => _preparing = null);

  Future<PendingUpload?> prepare(String blobId) =>
      _oneAtATime(() => _prepare(blobId));

  Future<T> _oneAtATime<T>(Future<T> Function() work) {
    final Future<T> result = _turn.then((_) => work());
    _turn = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<PendingUpload?> _prepare(String blobId) async {
    final File? source = await _localFile(blobId);
    if (source == null) {
      return null;
    }
    final JournalKeys keys = await _keys();
    final String uploadId = newSyncId(_random);
    final Directory parts = Directory(p.join(_workRoot.path, blobId));
    await _workRoot.create(recursive: true);
    if (await parts.exists()) {
      await parts.delete(recursive: true);
    }
    await requireSpace(
      _storage,
      _workRoot,
      encryptedFileLength(await source.length()),
    );
    await parts.create(recursive: true);
    final _PartWriter writer = _PartWriter(parts, partBytes);
    try {
      await FileCipher(keys).encryptInto(source, writer.add, keys.currentEpoch);
      final int partCount = await writer.close();
      final int totalBytes = writer.written;
      await _db
          .into(_db.syncUploads)
          .insertOnConflictUpdate(
            SyncUploadsCompanion.insert(
              blobId: blobId,
              blobName: KeyedNames(keys).blobName(blobId),
              uploadId: uploadId,
              totalBytes: totalBytes,
              partCount: partCount,
              ackedParts: const Value('[]'),
              partsDir: Value(parts.path),
              status: preparedUploadStatus,
            ),
          );
    } catch (_) {
      await writer.abandon();
      await _deleteParts(parts.path);
      rethrow;
    }
    _deferred.remove(blobId);
    return (await pendingUploads()).where((PendingUpload upload) {
      return upload.blobId == blobId;
    }).firstOrNull;
  }

  Future<List<PendingUpload>> pendingUploads() async {
    final Set<String> posters = await posterMediaIds(_db);
    final List<SyncUpload> rows =
        await (_db.select(_db.syncUploads)
              ..orderBy(<OrderClauseGenerator<$SyncUploadsTable>>[
                (t) => OrderingTerm.asc(t.rowId),
              ]))
            .get();
    final List<PendingUpload> uploads = <PendingUpload>[
      for (final SyncUpload row in rows)
        PendingUpload.fromRow(
          row,
          isPoster: posters.contains(row.blobId),
          partBytes: await _partBytesOf(row),
        ),
    ];
    return List<PendingUpload>.unmodifiable(<PendingUpload>[
      ...uploads.where((PendingUpload upload) => upload.isPoster),
      ...uploads.where((PendingUpload upload) => !upload.isPoster),
    ]);
  }

  Future<void> send(
    RelayClient client,
    UploadSender sender, {
    bool Function(PendingUpload upload)? allowed,
    FenceCheck mayContinue = alwaysCurrent,
    FenceCheck isCurrent = alwaysCurrent,
  }) async {
    for (final PendingUpload upload in await pendingUploads()) {
      if (!mayContinue() || !isCurrent()) {
        return;
      }
      if (allowed != null && !allowed(upload)) {
        continue;
      }
      if (await sender.holdsAll(upload)) {
        continue;
      }
      await sendOne(client, sender, upload, isCurrent: isCurrent);
    }
  }

  Future<void> sendOne(
    RelayClient client,
    UploadSender sender,
    PendingUpload upload, {
    FenceCheck isCurrent = alwaysCurrent,
  }) async {
    if (await client.blobExists(upload.blobName)) {
      if (isCurrent()) {
        await markUploaded(upload.blobId);
      }
      return;
    }
    final List<int> missing = await refreshAcked(
      client,
      upload,
      isCurrent: isCurrent,
    );
    if (missing.isEmpty || !isCurrent()) {
      return;
    }
    await sender.sendParts(
      upload,
      missing,
      (UploadStatusResponse answer) => isCurrent()
          ? recordAnswer(upload.blobId, answer)
          : Future<void>.value(),
    );
  }

  Future<List<int>> refreshAcked(
    RelayClient client,
    PendingUpload upload, {
    FenceCheck isCurrent = alwaysCurrent,
  }) async {
    final UploadStatusResponse status = await client.uploadStatus(
      upload.blobName,
      upload.uploadId,
    );
    if (!isCurrent()) {
      return const <int>[];
    }
    await recordAnswer(upload.blobId, status);
    if (status.assembled) {
      return const <int>[];
    }
    return <int>[
      for (int index = 0; index < upload.partCount; index++)
        if (!status.receivedParts.contains(index)) index,
    ];
  }

  Future<void> recordAnswer(String blobId, UploadStatusResponse answer) async {
    if (answer.assembled) {
      await markUploaded(blobId);
      return;
    }
    await (_db.update(
      _db.syncUploads,
    )..where((t) => t.blobId.equals(blobId))).write(
      SyncUploadsCompanion(
        ackedParts: Value(encodeAckedParts(answer.receivedParts)),
      ),
    );
  }

  Future<void> markUploaded(String blobId) async {
    final SyncUpload? row = await (_db.select(
      _db.syncUploads,
    )..where((t) => t.blobId.equals(blobId))).getSingleOrNull();
    await _db.transaction(() async {
      await (_db.delete(
        _db.syncUploads,
      )..where((t) => t.blobId.equals(blobId))).go();
      await markBlobUploaded(_db, blobId);
    });
    await _deleteParts(row?.partsDir);
  }

  Future<int> requeue(
    Iterable<String> blobIds, {
    bool keepInFlight = false,
  }) async {
    int queued = 0;
    for (final String blobId in blobIds.toSet()) {
      if (await _oneAtATime(() => _requeueOne(blobId, keepInFlight))) {
        queued += 1;
      }
    }
    return queued;
  }

  Future<bool> _requeueOne(String blobId, bool keepInFlight) async {
    if (await _localFile(blobId) == null) {
      return false;
    }
    final SyncUpload? row = await (_db.select(
      _db.syncUploads,
    )..where((t) => t.blobId.equals(blobId))).getSingleOrNull();
    if (keepInFlight && row != null) {
      return false;
    }
    await _db.transaction(() async {
      await (_db.delete(
        _db.syncUploads,
      )..where((t) => t.blobId.equals(blobId))).go();
      await (_db.update(_db.syncMediaCache)
            ..where((t) => t.blobId.equals(blobId)))
          .write(const SyncMediaCacheCompanion(uploaded: Value(false)));
    });
    await _deleteParts(row?.partsDir);
    try {
      return await _prepare(blobId) != null;
    } on NotEnoughSpaceException {
      _defer(blobId, forSpace: true, measured: true);
    } on FileSystemException catch (error) {
      _defer(blobId, forSpace: isNoSpaceLeft(error), measured: false);
    }
    return false;
  }

  Future<void> cancelAll() async {
    final List<SyncUpload> rows = await _db.select(_db.syncUploads).get();
    await _db.delete(_db.syncUploads).go();
    for (final SyncUpload row in rows) {
      await _deleteParts(row.partsDir);
    }
  }

  Future<int> _partBytesOf(SyncUpload row) async {
    if (row.partCount <= 1 ||
        (row.totalBytes + partBytes - 1) ~/ partBytes == row.partCount) {
      return partBytes;
    }
    final File first = File(p.join(row.partsDir ?? '', '0'));
    return await first.exists() ? first.length() : partBytes;
  }

  Future<int> _prepareAll() async {
    int prepared = 0;
    final List<String> ids = await unpreparedBlobIds();
    _deferred.removeWhere((String id, _Deferral _) => !ids.contains(id));
    for (final String blobId in ids) {
      final _Deferral? deferral = _deferred[blobId];
      if (deferral != null &&
          _now().isBefore(deferral.until) &&
          !(deferral.measured && await _roomFor(blobId))) {
        continue;
      }
      try {
        if (await prepare(blobId) != null) {
          prepared += 1;
        }
      } on NotEnoughSpaceException {
        _defer(blobId, forSpace: true, measured: true);
      } on FileSystemException catch (error) {
        _defer(blobId, forSpace: isNoSpaceLeft(error), measured: false);
      }
    }
    return prepared;
  }

  Future<bool> _roomFor(String blobId) async {
    final File? source = await _localFile(blobId);
    if (source == null) {
      return false;
    }
    try {
      await requireSpace(
        _storage,
        _workRoot,
        encryptedFileLength(await source.length()),
      );
      return true;
    } on NotEnoughSpaceException {
      return false;
    }
  }

  void _defer(String blobId, {required bool forSpace, required bool measured}) {
    final int attempts = (_deferred[blobId]?.attempts ?? 0) + 1;
    final int millis = min(
      firstPrepareRetry.inMilliseconds * (1 << min(attempts - 1, 20)),
      maxPrepareRetry.inMilliseconds,
    );
    _deferred[blobId] = _Deferral(
      until: _now().add(Duration(milliseconds: millis)),
      attempts: attempts,
      forSpace: forSpace,
      measured: measured,
    );
  }

  Future<File?> _localFile(String blobId) async {
    final domain.MediaBlob? blob = await _store.blobById(blobId);
    if (blob == null) {
      return null;
    }
    final File file = File(_store.absolutePath(blob));
    return await file.exists() ? file : null;
  }

  Future<void> _deleteParts(String? partsDir) async {
    if (partsDir == null || partsDir.isEmpty) {
      return;
    }
    final Directory dir = Directory(partsDir);
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on FileSystemException {
      return;
    }
  }
}
