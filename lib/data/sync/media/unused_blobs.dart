import 'package:drift/drift.dart';
import 'package:field_notes/data/crypto/keyed_names.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/sync/engine/pull_cycle.dart';
import 'package:field_notes/data/sync/enrolment/enrolment_service.dart';
import 'package:field_notes/data/sync/media/media_cache.dart';
import 'package:field_notes/data/sync/media/upload_queue.dart';
import 'package:field_notes/data/sync/relay_client.dart';
import 'package:sync_protocol/sync_protocol.dart' hide RecordState;

const Duration fullReferencedReportInterval = Duration(hours: 24);
const String referencedReportAtKey = 'referenced_report_at';
const String reportedNone = 'none';
const String reportedUnused = 'unused';
const String reportedReferenced = 'referenced';
const int blobNamesPerReport = 5000;

int _systemMillis() => DateTime.now().millisecondsSinceEpoch;

final class BlobReport {
  BlobReport({
    required List<String> unused,
    required List<String> referenced,
    required List<String> lacking,
  }) : unused = List<String>.unmodifiable(unused),
       referenced = List<String>.unmodifiable(referenced),
       lacking = List<String>.unmodifiable(lacking);

  static final BlobReport none = BlobReport(
    unused: const <String>[],
    referenced: const <String>[],
    lacking: const <String>[],
  );

  final List<String> unused;
  final List<String> referenced;
  final List<String> lacking;
}

final class UnusedBlobReporter {
  UnusedBlobReporter({
    required AppDatabase database,
    required this._reachable,
    required this._keys,
    required this._uploads,
    int Function()? clock,
  }) : _db = database,
       _clock = clock ?? _systemMillis;

  final AppDatabase _db;
  final ReachableMediaIds _reachable;
  final JournalKeysSource _keys;
  final UploadQueue _uploads;
  final int Function() _clock;

  Future<BlobReport> report(
    RelayClient client, {
    bool full = false,
    FenceCheck isCurrent = alwaysCurrent,
  }) async {
    if (!await pullHasCompleted(_db)) {
      return BlobReport.none;
    }
    final Set<String> reachable = await _reachable();
    final Set<String> known = <String>{
      for (final MediaBlob row in await _db.select(_db.mediaBlobs).get())
        row.id,
    };
    final Map<String, SyncMediaCacheData> cache = <String, SyncMediaCacheData>{
      for (final SyncMediaCacheData row
          in await _db.select(_db.syncMediaCache).get())
        row.blobId: row,
    };
    final int now = _clock();
    final bool fullDue = full || await _fullReportDue(now);
    final List<String> unused = <String>[
      for (final SyncMediaCacheData row in cache.values)
        if (row.uploaded &&
            !reachable.contains(row.blobId) &&
            row.reportedState != reportedUnused)
          row.blobId,
    ]..sort();
    final List<String> referenced = <String>[
      for (final String id in reachable)
        if (known.contains(id) &&
            (fullDue ||
                (cache[id]?.reportedState ?? reportedNone) !=
                    reportedReferenced))
          id,
    ]..sort();
    final KeyedNames names = KeyedNames(await _keys());
    for (final List<String> chunk in _chunks(unused)) {
      await client.reportUnusedBlobs(
        BlobNamesRequest(
          names: <String>[for (final String id in chunk) names.blobName(id)],
        ),
      );
      if (!isCurrent()) {
        return BlobReport.none;
      }
      await _setReported(chunk, reportedUnused);
    }
    final List<String> lacking = await _sendReferenced(
      client,
      referenced,
      isCurrent,
    );
    if (!isCurrent()) {
      return BlobReport.none;
    }
    if (fullDue && isCurrent()) {
      await writeSyncState(_db, referencedReportAtKey, '$now');
    }
    if (lacking.isNotEmpty && isCurrent()) {
      await _uploads.requeue(lacking);
    }
    return BlobReport(unused: unused, referenced: referenced, lacking: lacking);
  }

  Future<List<String>> reportReferenced(
    RelayClient client, {
    FenceCheck isCurrent = alwaysCurrent,
  }) async {
    final Set<String> reachable = await _reachable();
    final List<String> referenced = <String>[
      for (final MediaBlob row in await _db.select(_db.mediaBlobs).get())
        if (reachable.contains(row.id)) row.id,
    ]..sort();
    final List<String> lacking = await _sendReferenced(
      client,
      referenced,
      isCurrent,
    );
    if (!isCurrent()) {
      return const <String>[];
    }
    await writeSyncState(_db, referencedReportAtKey, '${_clock()}');
    if (lacking.isNotEmpty) {
      await _uploads.requeue(lacking);
    }
    return lacking;
  }

  Future<List<String>> _sendReferenced(
    RelayClient client,
    List<String> referenced,
    FenceCheck isCurrent,
  ) async {
    final KeyedNames names = KeyedNames(await _keys());
    final List<String> lacking = <String>[];
    for (final List<String> chunk in _chunks(referenced)) {
      final Map<String, String> idsByName = <String, String>{
        for (final String id in chunk) names.blobName(id): id,
      };
      final BlobNamesResponse answer = await client.reportReferencedBlobs(
        BlobNamesRequest(names: idsByName.keys.toList()),
      );
      if (!isCurrent()) {
        return const <String>[];
      }
      final Set<String> missing = <String>{
        for (final String name in answer.names) ?idsByName[name],
      };
      lacking.addAll(missing);
      await _setReported(chunk, reportedReferenced);
      for (final String id in chunk) {
        if (!missing.contains(id)) {
          await _uploads.markUploaded(id);
        }
      }
    }
    return lacking;
  }

  Future<bool> _fullReportDue(int now) async {
    final int? last = int.tryParse(
      await readSyncState(_db, referencedReportAtKey) ?? '',
    );
    return last == null ||
        now - last >= fullReferencedReportInterval.inMilliseconds;
  }

  Future<void> _setReported(List<String> blobIds, String state) async {
    await _db.batch((Batch batch) {
      for (final String id in blobIds) {
        batch.insert(
          _db.syncMediaCache,
          SyncMediaCacheCompanion.insert(
            blobId: id,
            reportedState: Value(state),
          ),
          onConflict: DoUpdate(
            (_) => SyncMediaCacheCompanion(reportedState: Value(state)),
          ),
        );
      }
    });
  }

  static Iterable<List<String>> _chunks(List<String> ids) sync* {
    for (int start = 0; start < ids.length; start += blobNamesPerReport) {
      yield ids.sublist(
        start,
        start + blobNamesPerReport > ids.length
            ? ids.length
            : start + blobNamesPerReport,
      );
    }
  }
}
