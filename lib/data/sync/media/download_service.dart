import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/file_cipher.dart';
import 'package:field_notes/data/crypto/journal_keys.dart';
import 'package:field_notes/data/crypto/key_store.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/models/media_blob.dart' as domain;
import 'package:path/path.dart' as p;

const String downloadWorkSubdir = 'sync_downloads';
const int maxDownloadsAtOnce = 4;

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

Directory downloadWorkRoot(Directory mediaRoot) =>
    Directory(p.join(p.dirname(mediaRoot.path), downloadWorkSubdir));

final class MediaDownloadProgress {
  const MediaDownloadProgress({
    required this.blobId,
    required this.received,
    required this.total,
  });

  final String blobId;
  final int received;
  final int? total;

  @override
  bool operator ==(Object other) =>
      other is MediaDownloadProgress &&
      other.blobId == blobId &&
      other.received == received &&
      other.total == total;

  @override
  int get hashCode => Object.hash(blobId, received, total);
}

class MediaDownloadException implements Exception {
  const MediaDownloadException(this.message);

  final String message;

  @override
  String toString() => 'MediaDownloadException: $message';
}

final class DownloadService {
  DownloadService({
    required AppDatabase database,
    required this._store,
    required this._keyStore,
    required this._workRoot,
    int Function()? clock,
    Random? random,
  }) : _db = database,
       _clock = clock ?? _systemMillis,
       _random = random ?? Random();

  final AppDatabase _db;
  final FilesystemMediaStore _store;
  final KeyStore _keyStore;
  final Directory _workRoot;
  final int Function() _clock;
  final Random _random;
  final Map<String, Future<bool>> _running = <String, Future<bool>>{};
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();
  int _active = 0;
  final StreamController<MediaDownloadProgress> _progress =
      StreamController<MediaDownloadProgress>.broadcast();

  Stream<MediaDownloadProgress> progress(String mediaId) =>
      _progress.stream.where(
        (MediaDownloadProgress update) => update.blobId.startsWith(mediaId),
      );

  Future<bool> hasFile(String blobId) async {
    final domain.MediaBlob? blob = await _store.blobById(blobId);
    return blob != null && await File(_store.absolutePath(blob)).exists();
  }

  Future<List<String>> eagerBlobIds({required bool keepAll}) async {
    final Set<String> posters = await posterMediaIds(_db);
    final List<String> missingPosters = <String>[];
    for (final String id in posters) {
      if (!await hasFile(id)) {
        missingPosters.add(id);
      }
    }
    final List<String> missingFull = <String>[];
    if (keepAll) {
      for (final MediaBlob row in await _db.select(_db.mediaBlobs).get()) {
        if (!posters.contains(row.id) && !await hasFile(row.id)) {
          missingFull.add(row.id);
        }
      }
    }
    return List<String>.unmodifiable(<String>[
      ...missingPosters..sort(),
      ...missingFull..sort(),
    ]);
  }

  Future<int> downloadEager(
    RelayClient client, {
    required bool keepAll,
    bool Function(TransferKind kind)? allowed,
    FenceCheck mayContinue = alwaysCurrent,
  }) async {
    final Set<String> posters = await posterMediaIds(_db);
    int downloaded = 0;
    for (final String blobId in await eagerBlobIds(keepAll: keepAll)) {
      if (!mayContinue()) {
        break;
      }
      final TransferKind kind = posters.contains(blobId)
          ? TransferKind.poster
          : TransferKind.fullMedia;
      if (allowed != null && !allowed(kind)) {
        continue;
      }
      try {
        if (await download(client, blobId)) {
          downloaded += 1;
        }
      } on MediaDownloadException {
        continue;
      } on CryptoException {
        continue;
      }
    }
    return downloaded;
  }

  Future<bool> download(RelayClient client, String blobId) {
    final Future<bool>? running = _running[blobId];
    if (running != null) {
      return running;
    }
    final Future<bool> started = _inTurn(() => _download(client, blobId))
        .whenComplete(() {
          _running.remove(blobId);
        });
    _running[blobId] = started;
    return started;
  }

  Future<bool> _inTurn(Future<bool> Function() work) async {
    if (_active < maxDownloadsAtOnce) {
      _active += 1;
    } else {
      final Completer<void> turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    try {
      return await work();
    } finally {
      _passTurn();
    }
  }

  void _passTurn() {
    if (_waiting.isEmpty) {
      _active -= 1;
      return;
    }
    _waiting.removeFirst().complete();
  }

  Future<bool> _download(RelayClient client, String blobId) async {
    final domain.MediaBlob? blob = await _store.blobById(blobId);
    if (blob == null) {
      return false;
    }
    if (await File(_store.absolutePath(blob)).exists()) {
      return true;
    }
    await _workRoot.create(recursive: true);
    final String stem = '$blobId-${_random.nextInt(1 << 32)}';
    final File cipher = File(p.join(_workRoot.path, '$stem.enc'));
    final File plain = File(p.join(_workRoot.path, '$stem.part'));
    try {
      final JournalKeys keys = await journalKeysFrom(_keyStore)();
      try {
        await client.downloadBlob(
          KeyedNames(keys).blobName(blobId),
          cipher,
          onProgress: (int received, int? total) => _progress.add(
            MediaDownloadProgress(
              blobId: blobId,
              received: received,
              total: total,
            ),
          ),
        );
      } on RelayRejected catch (error) {
        if (error.statusCode == HttpStatus.notFound) {
          return false;
        }
        rethrow;
      } on RelayBadResponse catch (error) {
        if (error.statusCode == HttpStatus.notFound) {
          return false;
        }
        rethrow;
      }
      await _decrypt(client, cipher, plain, keys);
      if (await sha256HexOfStream(plain.openRead()) != blobId) {
        throw MediaDownloadException('The download of $blobId does not match');
      }
      await _store.restoreFile(blob, plain);
      await _db
          .into(_db.syncMediaCache)
          .insert(
            SyncMediaCacheCompanion.insert(
              blobId: blobId,
              uploaded: const Value(true),
              downloadedAt: Value(_clock()),
            ),
            onConflict: DoUpdate(
              (_) => SyncMediaCacheCompanion(
                uploaded: const Value(true),
                downloadedAt: Value(_clock()),
              ),
            ),
          );
      return true;
    } finally {
      for (final File file in <File>[cipher, plain]) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  Future<void> _decrypt(
    RelayClient client,
    File cipher,
    File plain,
    JournalKeys keys,
  ) async {
    final int epoch = await FileCipher.epochOf(cipher);
    final JournalKeys usable = keys.hasEpoch(epoch)
        ? keys
        : await DeviceService(
            database: _db,
            keyStore: _keyStore,
            client: client,
          ).refreshKeys();
    await FileCipher.decryptFile(cipher, plain, usable);
  }
}
