import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/file_cipher.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/models/media_blob.dart' as domain;
import 'package:path/path.dart' as p;
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

const int uploadPartBytes = 8 * 1024 * 1024;
const String preparedUploadStatus = 'prepared';
const String uploadWorkSubdir = 'sync_uploads';
const String _cipherSuffix = '.enc';

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
}

final class RelayUploadSender implements UploadSender {
  const RelayUploadSender(this._client);

  final RelayClient _client;

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
    Random? random,
  }) : _db = database,
       _random = random ?? Random.secure();

  final AppDatabase _db;
  final FilesystemMediaStore _store;
  final JournalKeysSource _keys;
  final Directory _workRoot;
  final int partBytes;
  final Random _random;
  Future<int>? _preparing;

  Future<List<String>> unpreparedBlobIds() async {
    final List<MediaBlob> blobs = await _db.select(_db.mediaBlobs).get();
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

  Future<PendingUpload?> prepare(String blobId) async {
    final File? source = await _localFile(blobId);
    if (source == null) {
      return null;
    }
    final JournalKeys keys = await _keys();
    final String uploadId = newSyncId(_random);
    final Directory parts = Directory(p.join(_workRoot.path, blobId));
    final File cipher = File(p.join(_workRoot.path, '$blobId$_cipherSuffix'));
    await _workRoot.create(recursive: true);
    if (await parts.exists()) {
      await parts.delete(recursive: true);
    }
    await parts.create(recursive: true);
    try {
      await FileCipher(keys).encryptFile(source, cipher, keys.currentEpoch);
      final int totalBytes = await cipher.length();
      final int partCount = await _split(cipher, parts, totalBytes);
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
    } finally {
      if (await cipher.exists()) {
        await cipher.delete();
      }
    }
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

  Future<int> requeue(Iterable<String> blobIds) async {
    int queued = 0;
    for (final String blobId in blobIds.toSet()) {
      if (await _localFile(blobId) == null) {
        continue;
      }
      final SyncUpload? row = await (_db.select(
        _db.syncUploads,
      )..where((t) => t.blobId.equals(blobId))).getSingleOrNull();
      await _db.transaction(() async {
        await (_db.delete(
          _db.syncUploads,
        )..where((t) => t.blobId.equals(blobId))).go();
        await (_db.update(_db.syncMediaCache)
              ..where((t) => t.blobId.equals(blobId)))
            .write(const SyncMediaCacheCompanion(uploaded: Value(false)));
      });
      await _deleteParts(row?.partsDir);
      if (await prepare(blobId) != null) {
        queued += 1;
      }
    }
    return queued;
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
    for (final String blobId in await unpreparedBlobIds()) {
      if (await prepare(blobId) != null) {
        prepared += 1;
      }
    }
    return prepared;
  }

  Future<int> _split(File cipher, Directory parts, int totalBytes) async {
    final RandomAccessFile input = await cipher.open();
    int index = 0;
    try {
      int offset = 0;
      while (offset < totalBytes) {
        final int size = min(partBytes, totalBytes - offset);
        final Uint8List bytes = await input.read(size);
        await File(p.join(parts.path, '$index'))
            .writeAsBytes(bytes, flush: true);
        offset += bytes.length;
        index += 1;
      }
    } finally {
      await input.close();
    }
    return index;
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
