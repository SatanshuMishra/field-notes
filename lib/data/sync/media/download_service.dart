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
import 'package:field_notes/data/media/device_storage.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/media/media_exceptions.dart';
import 'package:field_notes/data/sync/devices/device_service.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/media/media_cache.dart';
import 'package:field_notes/data/sync/media/network_policy.dart';
import 'package:field_notes/data/sync/media/unused_blobs.dart'
    show reportedReferenced;
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:field_notes/domain/models/media_blob.dart' as domain;
import 'package:path/path.dart' as p;
import 'package:sync_protocol/sync_protocol.dart'
    show BlobNamesRequest, BlobNamesResponse;

const String downloadWorkSubdir = 'sync_downloads';
const int maxDownloadsAtOnce = 4;
const int blobNamesPerPresenceCheck = 5000;
const Duration firstDownloadRetry = Duration(minutes: 1);
const Duration maxDownloadRetry = Duration(hours: 1);

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

final class _Failed {
  const _Failed({
    required this.untilMillis,
    required this.attempts,
    required this.forSpace,
  });

  final int untilMillis;
  final int attempts;
  final bool forSpace;
}

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
    this._storage = const UnmeasuredDeviceStorage(),
    this._reachable,
    int Function()? clock,
    Random? random,
  }) : _db = database,
       _clock = clock ?? _systemMillis,
       _random = random ?? Random();

  final AppDatabase _db;
  final FilesystemMediaStore _store;
  final KeyStore _keyStore;
  final Directory _workRoot;
  final DeviceStorage _storage;
  final ReachableMediaIds? _reachable;
  final int Function() _clock;
  final Random _random;
  final Map<String, _Failed> _failed = <String, _Failed>{};
  bool _waitingForSpace = false;

  bool get waitingForSpace =>
      _waitingForSpace ||
      _failed.values.any((_Failed failed) => failed.forSpace);
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
    final Set<String>? reachable = await _reachable?.call();
    bool wanted(String id) => reachable == null || reachable.contains(id);
    final List<String> missingPosters = <String>[];
    for (final String id in posters) {
      if (wanted(id) && !await hasFile(id)) {
        missingPosters.add(id);
      }
    }
    final List<String> missingFull = <String>[];
    if (keepAll) {
      for (final MediaBlob row in await _db.select(_db.mediaBlobs).get()) {
        if (!posters.contains(row.id) &&
            wanted(row.id) &&
            !await hasFile(row.id)) {
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
    final int now = _clock();
    final List<String> eager = await eagerBlobIds(keepAll: keepAll);
    final Set<String> stillWanted = eager.toSet();
    _failed.removeWhere((String id, _Failed _) => !stillWanted.contains(id));
    final List<String> due = <String>[
      for (final String blobId in eager)
        if ((_failed[blobId]?.untilMillis ?? 0) <= now &&
            (allowed == null ||
                allowed(
                  posters.contains(blobId)
                      ? TransferKind.poster
                      : TransferKind.fullMedia,
                )))
          blobId,
    ];
    _waitingForSpace = false;
    if (due.isEmpty || !mayContinue()) {
      return 0;
    }
    final Set<String> held = await _heldByRelay(client, due);
    int downloaded = 0;
    for (final String blobId in due) {
      if (!mayContinue()) {
        break;
      }
      if (!held.contains(blobId)) {
        continue;
      }
      try {
        if (await download(client, blobId)) {
          downloaded += 1;
          _failed.remove(blobId);
        }
      } on NotEnoughSpaceException {
        _waitingForSpace = true;
      } on MediaDownloadException {
        _fail(blobId);
      } on CryptoException {
        _fail(blobId);
      }
    }
    return downloaded;
  }

  Future<Set<String>> _heldByRelay(
    RelayClient client,
    List<String> blobIds,
  ) async {
    final KeyedNames names = KeyedNames(await journalKeysFrom(_keyStore)());
    final Set<String> held = <String>{};
    for (int start = 0; start < blobIds.length;) {
      final int end = min(start + blobNamesPerPresenceCheck, blobIds.length);
      final Map<String, String> idsByName = <String, String>{
        for (final String id in blobIds.sublist(start, end))
          names.blobName(id): id,
      };
      final BlobNamesResponse lacking = await client.reportReferencedBlobs(
        BlobNamesRequest(names: idsByName.keys.toList()),
      );
      final Set<String> missing = lacking.names.toSet();
      final List<String> heldNow = <String>[
        for (final MapEntry<String, String> entry in idsByName.entries)
          if (!missing.contains(entry.key)) entry.value,
      ];
      await _db.batch((Batch batch) {
        for (final String id in idsByName.values) {
          final bool isHeld = !missing.contains(names.blobName(id));
          batch.insert(
            _db.syncMediaCache,
            SyncMediaCacheCompanion.insert(
              blobId: id,
              uploaded: Value(isHeld),
              reportedState: const Value(reportedReferenced),
            ),
            onConflict: DoUpdate(
              (_) => SyncMediaCacheCompanion(
                uploaded: isHeld ? const Value(true) : const Value.absent(),
                reportedState: const Value(reportedReferenced),
              ),
            ),
          );
        }
      });
      held.addAll(heldNow);
      start = end;
    }
    return held;
  }

  Exception _storageFailure(domain.MediaBlob blob, Object? cause) {
    if (cause is FileSystemException && isNoSpaceLeft(cause)) {
      _fail(blob.id, forSpace: true);
      return NotEnoughSpaceException(needed: blob.bytes * 2, free: 0);
    }
    return MediaDownloadException('The download of ${blob.id} was not stored');
  }

  void _fail(String blobId, {bool forSpace = false}) {
    final int attempts = (_failed[blobId]?.attempts ?? 0) + 1;
    final int wait = min(
      firstDownloadRetry.inMilliseconds * (1 << min(attempts - 1, 20)),
      maxDownloadRetry.inMilliseconds,
    );
    _failed[blobId] = _Failed(
      untilMillis: _clock() + wait,
      attempts: attempts,
      forSpace: forSpace,
    );
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
    await requireSpace(_storage, _workRoot, blob.bytes * 2);
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
      await cipher.delete();
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
    } on FileSystemException catch (error) {
      throw _storageFailure(blob, error);
    } on MediaWriteException catch (error) {
      throw _storageFailure(blob, error.cause);
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
