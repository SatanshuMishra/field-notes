import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sync_protocol/sync_protocol.dart';

import 'auth.dart';
import 'database.dart';

typedef AssemblyHook = Future<void> Function(String uploadId);

const int maxPartSize = 16 * 1024 * 1024;
const int maxBlobNames = 100000;
const Duration unusedBlobGrace = Duration(days: 30);
const Duration unfinishedUploadLifetime = Duration(days: 7);
const String stagingFolderName = '.uploads';

final RegExp _blobNamePattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
final RegExp _uploadIdPattern = RegExp(r'^[A-Za-z0-9_-]{22}$');
final RegExp _indexPattern = RegExp(r'^[0-9]{1,9}$');

bool isBlobName(String name) => _blobNamePattern.hasMatch(name);

bool isUploadId(String uploadId) => _uploadIdPattern.hasMatch(uploadId);

String blobPath(String mediaDirectory, String accountId, String name) =>
    p.join(mediaDirectory, accountId, name.substring(0, 2), name);

String accountMediaPath(String mediaDirectory, String accountId) =>
    p.join(mediaDirectory, accountId);

String stagingPath(String mediaDirectory, String uploadId) =>
    p.join(mediaDirectory, stagingFolderName, uploadId);

void _requireName(String name) {
  if (!isBlobName(name)) {
    throw const RelayException(SyncErrorCode.badRequest, 'Invalid blob name');
  }
}

void _requireUploadId(String uploadId) {
  if (!isUploadId(uploadId)) {
    throw const RelayException(SyncErrorCode.badRequest, 'Invalid upload id');
  }
}

final class PartUpload {
  const PartUpload({
    required this.name,
    required this.uploadId,
    required this.index,
    required this.blobSize,
    required this.partSize,
  });

  factory PartUpload.parse({
    required String name,
    required String uploadId,
    required String index,
    required String? blobSize,
    required String? partSize,
  }) {
    _requireName(name);
    _requireUploadId(uploadId);
    final int? parsedIndex = _indexPattern.hasMatch(index)
        ? int.parse(index)
        : null;
    final int? parsedBlobSize = int.tryParse(blobSize?.trim() ?? '');
    final int? parsedPartSize = int.tryParse(partSize?.trim() ?? '');
    if (parsedIndex == null ||
        parsedBlobSize == null ||
        parsedPartSize == null ||
        parsedBlobSize < 1 ||
        parsedPartSize < 1 ||
        parsedPartSize > maxPartSize) {
      throw const RelayException(SyncErrorCode.badRequest, 'Invalid part');
    }
    final PartUpload part = PartUpload(
      name: name,
      uploadId: uploadId,
      index: parsedIndex,
      blobSize: parsedBlobSize,
      partSize: parsedPartSize,
    );
    if (parsedIndex >= part.partCount) {
      throw const RelayException(SyncErrorCode.badRequest, 'Invalid part');
    }
    return part;
  }

  final String name;
  final String uploadId;
  final int index;
  final int blobSize;
  final int partSize;

  int get partCount => (blobSize + partSize - 1) ~/ partSize;

  int get expectedLength =>
      index == partCount - 1 ? blobSize - partSize * (partCount - 1) : partSize;
}

final class _Upload {
  const _Upload({
    required this.id,
    required this.accountId,
    required this.name,
    required this.totalBytes,
    required this.partSize,
    required this.assembling,
    required this.assembled,
  });

  factory _Upload.fromRow(Row row) => _Upload(
    id: row['id'] as String,
    accountId: row['account_id'] as String,
    name: row['name'] as String,
    totalBytes: row['total_bytes'] as int,
    partSize: row['part_size'] as int,
    assembling: (row['assembling'] as int) != 0,
    assembled: (row['assembled'] as int) != 0,
  );

  final String id;
  final String accountId;
  final String name;
  final int totalBytes;
  final int partSize;
  final bool assembling;
  final bool assembled;

  int get partCount => (totalBytes + partSize - 1) ~/ partSize;

  bool get busy => assembling || assembled;
}

final class BlobStore {
  BlobStore({
    required this._database,
    required this.mediaDirectory,
    required this._clock,
    this._beforeAssembly,
  });

  final RelayDatabase _database;
  final String mediaDirectory;
  final DateTime Function() _clock;
  final AssemblyHook? _beforeAssembly;

  void prepare() {
    Directory(p.join(mediaDirectory, stagingFolderName))
        .createSync(recursive: true);
    _database.transaction(() {
      _database.execute(
        'UPDATE uploads SET assembling = 0 WHERE assembling != 0',
      );
    });
  }

  bool holds(String accountId, String name) =>
      _database.count(
        'SELECT count(*) FROM blobs WHERE account_id = ? AND name = ?',
        <Object?>[accountId, name],
      ) >
      0;

  bool exists(String accountId, String name) {
    _requireName(name);
    return holds(accountId, name) &&
        File(blobPath(mediaDirectory, accountId, name)).existsSync();
  }

  File? download(String accountId, String name) {
    _requireName(name);
    if (!holds(accountId, name)) {
      return null;
    }
    final File file = File(blobPath(mediaDirectory, accountId, name));
    return file.existsSync() ? file : null;
  }

  Future<UploadStatusResponse> putPart(
    String accountId,
    PartUpload part,
    Stream<List<int>> body, {
    int? contentLength,
  }) async {
    if (contentLength != null && contentLength != part.expectedLength) {
      await _drain(body);
      throw const RelayException(SyncErrorCode.badRequest, 'Wrong part size');
    }
    if (holds(accountId, part.name)) {
      await _drain(body);
      return UploadStatusResponse(
        receivedParts: const <int>[],
        assembled: true,
      );
    }
    final _Upload upload = _database.transaction(() {
      _database.execute(
        'INSERT OR IGNORE INTO uploads (id, account_id, name, total_bytes, '
        'part_size, created_at, assembling, assembled) '
        'VALUES (?, ?, ?, ?, ?, ?, 0, 0)',
        <Object?>[
          part.uploadId,
          accountId,
          part.name,
          part.blobSize,
          part.partSize,
          toMillis(_clock()),
        ],
      );
      final _Upload stored = _upload(part.uploadId)!;
      if (stored.accountId != accountId ||
          stored.name != part.name ||
          stored.totalBytes != part.blobSize ||
          stored.partSize != part.partSize) {
        throw const RelayException(
          SyncErrorCode.badRequest,
          'Upload does not match',
        );
      }
      return stored;
    });
    if (upload.busy || _hasPart(upload.id, part.index)) {
      await _drain(body);
      return _settle(accountId, upload.id);
    }
    final File received;
    try {
      received = await _receive(part, body);
    } on FileSystemException catch (error) {
      if (isStorageFull(error) || !(_upload(upload.id)?.busy ?? false)) {
        rethrow;
      }
      return _status(accountId, part.name, upload.id);
    }
    final bool claimed = _database.transaction(() {
      final _Upload? current = _upload(upload.id);
      if (current == null || current.busy || _hasPart(upload.id, part.index)) {
        _deleteQuietly(received);
        return current != null && _claim(current);
      }
      received.renameSync(_partPath(upload.id, part.index));
      _database.execute(
        'INSERT OR IGNORE INTO upload_parts (upload_id, part_index) '
        'VALUES (?, ?)',
        <Object?>[upload.id, part.index],
      );
      return _claim(current);
    });
    if (claimed) {
      await _assemble(upload);
    }
    return _status(accountId, part.name, upload.id);
  }

  Future<UploadStatusResponse> status(
    String accountId,
    String name,
    String uploadId,
  ) async {
    _requireName(name);
    _requireUploadId(uploadId);
    final _Upload? upload = _upload(uploadId);
    if (upload == null ||
        upload.accountId != accountId ||
        upload.name != name) {
      return UploadStatusResponse(
        receivedParts: const <int>[],
        assembled: holds(accountId, name),
      );
    }
    return _settle(accountId, uploadId);
  }

  void markUnused(String accountId, BlobNamesRequest request) {
    _requireNames(request.names);
    final int now = toMillis(_clock());
    _database.transaction(() {
      for (final String name in request.names) {
        _database.execute(
          'UPDATE blobs SET unused_since = ? '
          'WHERE account_id = ? AND name = ? AND unused_since IS NULL',
          <Object?>[now, accountId, name],
        );
      }
    });
  }

  BlobNamesResponse markReferenced(String accountId, BlobNamesRequest request) {
    _requireNames(request.names);
    final List<String> missing = _database.transaction(
      () => <String>[
        for (final String name in request.names.toSet())
          if (!_reference(accountId, name)) name,
      ],
    );
    return BlobNamesResponse(names: missing);
  }

  Future<void> purge() async {
    final DateTime now = _clock();
    final int blobCutoff = toMillis(now.subtract(unusedBlobGrace));
    final int uploadCutoff = toMillis(now.subtract(unfinishedUploadLifetime));
    final List<Row> unused = _database.select(
      'SELECT account_id, name FROM blobs '
      'WHERE unused_since IS NOT NULL AND unused_since <= ?',
      <Object?>[blobCutoff],
    );
    for (final Row row in unused) {
      final String accountId = row['account_id'] as String;
      final String name = row['name'] as String;
      _database.transaction(() {
        _database.execute(
          'DELETE FROM blobs WHERE account_id = ? AND name = ? '
          'AND unused_since IS NOT NULL AND unused_since <= ?',
          <Object?>[accountId, name, blobCutoff],
        );
        if (_database.updatedRows == 1) {
          _deleteQuietly(File(blobPath(mediaDirectory, accountId, name)));
        }
      });
    }
    final List<Row> stale = _database.select(
      'SELECT id FROM uploads WHERE created_at <= ? AND assembling = 0',
      <Object?>[uploadCutoff],
    );
    for (final Row row in stale) {
      final String uploadId = row['id'] as String;
      _database.transaction(() {
        _database.execute(
          'DELETE FROM uploads WHERE id = ? AND assembling = 0',
          <Object?>[uploadId],
        );
        if (_database.updatedRows == 1) {
          _database.execute(
            'DELETE FROM upload_parts WHERE upload_id = ?',
            <Object?>[uploadId],
          );
          _deleteQuietly(Directory(stagingPath(mediaDirectory, uploadId)));
        }
      });
    }
  }

  bool _reference(String accountId, String name) {
    _database.execute(
      'UPDATE blobs SET unused_since = NULL WHERE account_id = ? AND name = ?',
      <Object?>[accountId, name],
    );
    return _database.updatedRows == 1;
  }

  void _requireNames(List<String> names) {
    if (names.length > maxBlobNames) {
      throw const RelayException(SyncErrorCode.badRequest, 'Too many names');
    }
    names.forEach(_requireName);
  }

  Future<UploadStatusResponse> _settle(
    String accountId,
    String uploadId,
  ) async {
    final _Upload upload = _upload(uploadId)!;
    final bool claimed = _database.transaction(() {
      final _Upload? current = _upload(uploadId);
      return current != null && _claim(current);
    });
    if (claimed) {
      await _assemble(upload);
    }
    return _status(accountId, upload.name, uploadId);
  }

  bool _claim(_Upload upload) {
    if (upload.busy || holds(upload.accountId, upload.name)) {
      return false;
    }
    final int held = _database.count(
      'SELECT count(*) FROM upload_parts WHERE upload_id = ?',
      <Object?>[upload.id],
    );
    if (held < upload.partCount) {
      return false;
    }
    _database.execute(
      'UPDATE uploads SET assembling = 1 '
      'WHERE id = ? AND assembling = 0 AND assembled = 0',
      <Object?>[upload.id],
    );
    return _database.updatedRows == 1;
  }

  Future<void> _assemble(_Upload upload) async {
    final String staging = stagingPath(mediaDirectory, upload.id);
    final File assembly = File(p.join(staging, '.assembly-${newSecret()}'));
    final String target = blobPath(
      mediaDirectory,
      upload.accountId,
      upload.name,
    );
    try {
      await _beforeAssembly?.call(upload.id);
      final IOSink sink = assembly.openWrite();
      try {
        for (int index = 0; index < upload.partCount; index++) {
          await sink.addStream(File(_partPath(upload.id, index)).openRead());
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (await assembly.length() != upload.totalBytes) {
        throw StateError('Assembled blob has the wrong size');
      }
      await Directory(p.dirname(target)).create(recursive: true);
      _database.transaction(() {
        assembly.renameSync(target);
        _database.execute(
          'INSERT INTO blobs (account_id, name, size, created_at, unused_since) '
          'VALUES (?, ?, ?, ?, NULL) ON CONFLICT (account_id, name) '
          'DO UPDATE SET unused_since = NULL, size = excluded.size',
          <Object?>[
            upload.accountId,
            upload.name,
            upload.totalBytes,
            toMillis(_clock()),
          ],
        );
        _database.execute(
          'UPDATE uploads SET assembled = 1, assembling = 0 WHERE id = ?',
          <Object?>[upload.id],
        );
        _database.execute(
          'DELETE FROM upload_parts WHERE upload_id = ?',
          <Object?>[upload.id],
        );
      });
    } catch (error) {
      _database.transaction(() {
        _database.execute(
          'UPDATE uploads SET assembling = 0 WHERE id = ? AND assembled = 0',
          <Object?>[upload.id],
        );
      });
      _deleteQuietly(assembly);
      if (isStorageFull(error)) {
        throw const RelayException(SyncErrorCode.storageFull);
      }
      rethrow;
    }
    _deleteQuietly(Directory(staging));
  }

  Future<File> _receive(PartUpload part, Stream<List<int>> body) async {
    final Directory staging = Directory(
      stagingPath(mediaDirectory, part.uploadId),
    );
    await staging.create(recursive: true);
    final File temporary = File(
      p.join(staging.path, '.part-${part.index}-${newSecret()}'),
    );
    int received = 0;
    bool overflow = false;
    final IOSink sink = temporary.openWrite();
    try {
      try {
        await for (final List<int> chunk in body) {
          received += chunk.length;
          if (received > part.expectedLength) {
            overflow = true;
            break;
          }
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } catch (error) {
      _deleteQuietly(temporary);
      rethrow;
    }
    if (overflow || received != part.expectedLength) {
      _deleteQuietly(temporary);
      throw const RelayException(SyncErrorCode.badRequest, 'Wrong part size');
    }
    return temporary;
  }

  UploadStatusResponse _status(String accountId, String name, String uploadId) {
    final _Upload? upload = _upload(uploadId);
    final List<int> parts =
        upload == null || upload.accountId != accountId || upload.name != name
        ? const <int>[]
        : <int>[
            for (final Row row in _database.select(
              'SELECT part_index FROM upload_parts WHERE upload_id = ? '
              'ORDER BY part_index',
              <Object?>[uploadId],
            ))
              row['part_index'] as int,
          ];
    return UploadStatusResponse(
      receivedParts: parts,
      assembled: holds(accountId, name),
    );
  }

  _Upload? _upload(String uploadId) {
    final Row? row = _database.selectOne(
      'SELECT id, account_id, name, total_bytes, part_size, assembling, '
      'assembled FROM uploads WHERE id = ?',
      <Object?>[uploadId],
    );
    return row == null ? null : _Upload.fromRow(row);
  }

  bool _hasPart(String uploadId, int index) =>
      _database.count(
        'SELECT count(*) FROM upload_parts WHERE upload_id = ? AND part_index = ?',
        <Object?>[uploadId, index],
      ) >
      0;

  String _partPath(String uploadId, int index) =>
      p.join(stagingPath(mediaDirectory, uploadId), '$index');

  static Future<void> _drain(Stream<List<int>> body) async {
    try {
      await body.drain<void>();
    } on Object {
      return;
    }
  }
}

void _deleteQuietly(FileSystemEntity entity) {
  try {
    if (entity is Directory) {
      entity.deleteSync(recursive: true);
    } else {
      entity.deleteSync();
    }
  } on FileSystemException {
    return;
  }
}
